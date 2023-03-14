#!/usr/bin/env bash

# shellcheck source=/dev/null
source ./bin/generator-utils/utils.sh

function create_fn_name() {
    slug=$1
    has_canonical_data=$2

    if [ "$has_canonical_data" == false ]; then
        fn_name=$(dash_to_underscore "$slug")
    else
        fn_name=$(jq -r 'first(.. | .property? // empty)' canonical_data.json)
    fi

    echo "$fn_name"

}

function create_test_file_template() {
    local exercise_dir=$1
    local slug=$2
    local has_canonical_data=$3
    local test_file="${exercise_dir}/tests/${slug}.rs"

    cat <<EOT >"$test_file"
use $(dash_to_underscore "$slug")::*;
// Add tests here

EOT

    if [ "$has_canonical_data" == false ]; then

        cat <<EOT >>"$test_file"
// As there isn't a canonical data file for this exercise, you will need to craft your own tests.
// If you happen to devise some outstanding tests, do contemplate sharing them with the community by contributing to this repository:
// https://github.com/exercism/problem-specifications/tree/main/exercises/${slug}
EOT
        message "info" "This exercise doesn't have canonical data."
        message "success" "Stub file for tests has been created!"
    else
        canonical_json=$(cat canonical_data.json)

        # sometimes canonical data has multiple levels with multiple `cases` arrays.
        #(see kindergarten-garden https://github.com/exercism/problem-specifications/blob/main/exercises/kindergarten-garden/canonical-data.json)
        # so let's flatten it
        cases=$(echo "$canonical_json" | jq '[ .. | objects | with_entries(select(.key | IN("uuid", "description", "input", "expected"))) | select(. != {}) | select(has("uuid")) ]')
        fn_name=$(echo "$canonical_json" | jq -r 'first(.. | .property? // empty)')

        first_iteration=true
        # loop through each object
        jq -c '.[]' <<<"$cases" | while read -r case; do
            desc=$(echo "$case" | jq '.description' | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr -cd '[:alnum:]_' | sed 's/^/test_/')
            input=$(echo "$case" | jq -c '.input')
            expected=$(echo "$case" | jq -c '.expected')

            # append each test fn to the test file
            cat <<EOT >>"$test_file"
#[test] $([[ "$first_iteration" == false ]] && printf "\n#[ignore]")
fn ${desc}() {

    let input = ${input};
    let expected = ${expected};

    // TODO: Add assertion
    assert_eq!(${fn_name}(input), expected);
}

EOT
            first_iteration=false
        done
        message "success" "Stub file for tests has been created and populated with canonical data!"
    fi

}

function create_lib_rs_template() {
    local exercise_dir=$1
    local slug=$2
    local has_canonical_data=$3
    fn_name=$(create_fn_name "$slug" "$has_canonical_data")
    cat <<EOT >"${exercise_dir}/src/lib.rs"
pub fn ${fn_name}() {
    unimplemented!("implement ${slug} exercise");
}
EOT
    message "success" "Stub file for lib.rs has been created!"
}

function overwrite_gitignore() {
    local exercise_dir=$1
    cat <<EOT >"$exercise_dir"/.gitignore
# Generated by Cargo
# Will have compiled files and executables
/target/
**/*.rs.bk

# Remove Cargo.lock from gitignore if creating an executable, leave it for libraries
# More information here http://doc.crates.io/guide.html#cargotoml-vs-cargolock
Cargo.lock
EOT
    message "success" ".gitignore has been overwritten!"
}

function create_example_rs_template() {
    local exercise_dir=$1
    local slug=$2
    local has_canonical_data=$3

    fn_name=$(create_fn_name "$slug" "$has_canonical_data")

    mkdir "${exercise_dir}/.meta"
    cat <<EOT >"${exercise_dir}/.meta/example.rs"
pub fn ${fn_name}() {
   // TODO: Create a solution that passes all the tests
   unimplemented!("implement ${slug} exercise");
}

EOT
    message "success" "Stub file for example.rs has been created!"
}

function create_rust_files() {
    local exercise_dir=$1
    local slug=$2
    local has_canonical_data=$3

    message "info" "Creating Rust files"
    cargo new --lib "$exercise_dir" -q
    mkdir -p "$exercise_dir"/tests
    touch "${exercise_dir}/tests/${slug}.rs"

    create_test_file_template "$exercise_dir" "$slug" "$has_canonical_data"
    create_lib_rs_template "$exercise_dir" "$slug" "$has_canonical_data"
    create_example_rs_template "$exercise_dir" "$slug" "$has_canonical_data"
    overwrite_gitignore "$exercise_dir"

    message "success" "Created Rust files succesfully!"

}