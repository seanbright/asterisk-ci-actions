#!/usr/bin/bash
set -x
set -e

# We're not actually creating a fork, just a private copy.

export GITHUB_TOKEN=${INPUT_GITHUB_TOKEN}
export GH_TOKEN=${INPUT_GITHUB_TOKEN}

SCRIPT_DIR=${GITHUB_WORKSPACE}/$(basename ${GITHUB_ACTION_REPOSITORY})/scripts
REPO_DIR=${GITHUB_WORKSPACE}/$(basename ${INPUT_SRC_REPO})


cd ${GITHUB_WORKSPACE}

git clone -q -b master --no-tags \
	https://x-access-token:${GITHUB_TOKEN}@github.com/asterisk/${INPUT_SRC_REPO} ${INPUT_DST_REPO}

git config --global --add safe.directory $(realpath ${INPUT_DST_REPO})

cd ${INPUT_DST_REPO}

git remote rename origin upstream

# We don't want to accidentally push anything to the public repo before
# we're ready so set the "push" url to "nothing"
git remote set-url --push upstream nothing

# Create the new PRIVATE repository from the clone and push the
# current master branch up.
gh repo create asterisk/${INPUT_DST_REPO} --private --disable-issues \
	--disable-wiki --source=. --push

# Set the default repo for subsequent gh commands to the private repo.
gh repo set-default asterisk/${INPUT_DST_REPO}

# We need all the labels so the automation can run.
gh label clone asterisk/${INPUT_SRC_REPO}

# Just like the public repo, we want to disable merge commits
gh repo edit --enable-merge-commit=false

