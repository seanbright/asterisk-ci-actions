#!/usr/bin/bash
set -x
set -e

# We're not actually creating a fork, just a private copy.

export GITHUB_TOKEN=${INPUT_GITHUB_TOKEN}
export GH_TOKEN=${INPUT_GITHUB_TOKEN}
export GIT_TOKEN=${INPUT_GITHUB_TOKEN}

SCRIPT_DIR=${GITHUB_WORKSPACE}/$(basename ${GITHUB_ACTION_REPOSITORY})/scripts
REPO_DIR=${GITHUB_WORKSPACE}/$(basename ${INPUT_DST_REPO})

echo $GH_TOKEN | md5sum

cd ${GITHUB_WORKSPACE}

# Create the new repo and set it's parameters
gh repo create asterisk/${INPUT_DST_REPO} --private
gh repo edit asterisk/${INPUT_DST_REPO} --allow-forking=false --enable-auto-merge=false \
	--enable-discussions=false --enable-issues=false --enable-merge-commit=false \
	--enable-wiki=false

# Do a bare clone of the source repo
git clone --bare https://github.com/asterisk/${INPUT_SRC_REPO}.git ${REPO_DIR}

# Make sure the directory is trusted
git config --global --add safe.directory ${REPO_DIR}

cd ${REPO_DIR}

# Push everything to the new repo
git push --mirror https://x-access-token:${GITHUB_TOKEN}@github.com/asterisk/${INPUT_DST_REPO}.git &> /tmp/push || \
	{ cat /tmp/push ; exit 1 ; }

cd ..

# Disable the workflows we never want to run in the private repo.
# These will probably fail due to GitHub not enabling actions on the
# repo in the first place.
gh -R asterisk/${INPUT_DST_REPO} workflow disable "Issue Opened" || :
gh -R asterisk/${INPUT_DST_REPO} workflow disable PRMerged || :
gh -R asterisk/${INPUT_DST_REPO} workflow disable CreateDocs || :
gh -R asterisk/${INPUT_DST_REPO} workflow disable MergeApproved || :
gh -R asterisk/${INPUT_DST_REPO} workflow disable NightlyTests || :
gh -R asterisk/${INPUT_DST_REPO} workflow disable NightlyAdmin || :
gh -R asterisk/${INPUT_DST_REPO} workflow disable Releaser || :
