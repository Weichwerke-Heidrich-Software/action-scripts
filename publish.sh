#!/bin/bash

set -e

cd "$(git rev-parse --show-toplevel)"

if [ -f "package.json" ]; then
    major_version=$(node -p "require('./package.json').version.split('.')[0]")
    minor_version=$(node -p "require('./package.json').version.split('.')[1]")
    patch_version=$(node -p "require('./package.json').version.split('.')[2]")
elif [ -f "version.txt" ]; then
    major_version=$(head -n 1 version.txt | cut -d '.' -f 1)
    minor_version=$(head -n 1 version.txt | cut -d '.' -f 2)
    patch_version=$(head -n 1 version.txt | cut -d '.' -f 3)
else
    echo "Neither package.json nor version.txt found. Please ensure one of these files exists with the correct version format."
    exit 1
fi
major_version_tag="v$major_version"
minor_version_tag="v$major_version.$minor_version"
patch_version_tag="v$major_version.$minor_version.$patch_version"

repo_name=$(basename "$(git rev-parse --show-toplevel)")
if [[ "$repo_name" == *scripts ]]; then
    echo "This script needs to be run from the main repository, not from the scripts directory."
    exit 1
fi

action_path="Weichwerke-Heidrich-Software/$repo_name"
for file in .github/workflows/*.yml README.md; do
    sed -i "s:$action_path@.*:$action_path@$major_version_tag:g" "$file"
done

if [ -f "package.json" ]; then
    echo "Updating package-lock.json."
    npm install
fi

if [ -f "src/index.ts" ]; then
    echo "Compiling the project."
    ncc build src/index.ts -o dist --license licenses.txt
fi

if ! git diff-index --quiet HEAD --ignore-space-at-eol --; then
  echo "You have uncommitted changes. Please commit or stash them before publishing."
  exit 1
fi

if [ "$(git rev-parse --abbrev-ref HEAD)" != "main" ]; then
  echo "You must be on the 'main' branch to publish."
  exit 1
fi

if git tag -l | grep -q "$patch_version_tag"; then
    echo "Version $patch_version_tag is already tagged."
    echo "Please update the version in package.json or version.txt."
    exit 1
else
    echo "Everything looks in order."
    read -p "Do you want to publish version $patch_version_tag? (y/[literally anything else]) " confirm
    if [[ "$confirm" != "y" ]]; then
        echo "Another time then."
        exit 1
    fi
    echo "Creating tag $patch_version_tag"
    git tag "$patch_version_tag"
fi

for tag in "$major_version_tag" "$minor_version_tag"; do
    if git tag -l | grep -q "^${tag}$"; then
        echo "Moving tag $tag to current commit."
        git tag -f "$tag"
    else
        echo "Creating new tag $tag."
        git tag "$tag"
    fi
done

git push --tags --force
