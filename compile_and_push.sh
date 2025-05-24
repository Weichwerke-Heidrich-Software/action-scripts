#!/bin/bash

# GitHub actions do not install dependencies before running - they need to be included in the repo.
# This script compiles the project and pushes the changes.

set -e

if ! command -v ncc &> /dev/null; then
    npm install -g @vercel/ncc
fi

cd "$(git rev-parse --show-toplevel)"
repo_name=$(basename "$(git rev-parse --show-toplevel)")
if [[ "$repo_name" == *scripts ]]; then
    echo "This script needs to be run from the main repository, not from the scripts directory."
    exit 1
fi

ncc build src/index.ts -o dist --license licenses.txt

branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$branch" != "main" ]; then
    action_path="Weichwerke-Heidrich-Software/$repo_name"
    for file in .github/workflows/*.yml; do
        sed -i "s:$action_path@.*:$action_path@$branch:g" "$file"
    done
fi

commig_message=$1
if [ -z "$commig_message" ]; then
    default_message="Updating compiled files."
    echo "No commit message provided. Shall I use a default message \"$default_message\"?"
    read -p "Enter 'y' for yes or 'n' for no: " answer
    if [ "$answer" == "y" ]; then
        commig_message=$default_message
    else
        echo "Exiting without committing."
        exit 1
    fi
fi

git add .
git commit -m "$commig_message"
git push
