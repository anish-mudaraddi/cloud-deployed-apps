#!/bin/bash

# Script to check if the changed files to promote are a direct copy of earlier environment

# Function to compare the files, file1 is our original file passed to the script followed by two possible further files
compare_files() {
    file1=$1
    file2=$2

    # Check the number of arguments passed to the function for comparison
    # We then check whether the files exist in the previous environment, if not the PR needs review
    if [ -f $file2 ]; then
        if cmp -s "$file1" "$file2"; then
            echo $((0))
        else
            echo $((1))
        fi
    else
        echo $((1))
    fi
}

# Check the file path to determine if it's from staging or prod folder
# If it's staging we pass it along with a url to the file in dev folder
# If it's from prod we pass both the staging and dev file also for comparison
path=$1
curr_env=$2
comp_env=$3

compare_files "$1" "${path/$curr_env/"$comp_env"}"