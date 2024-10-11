#!/usr/bin/bash

if [ -z "${GITHUB_TOKEN}" ] ; then
	echo "GITHUB_TOKEN must be provided in the environment"
	exit 1
fi

SCRIPT_DIR=$(dirname $(readlink -fn $0))
. $SCRIPT_DIR/ci.functions

set -e

if [ -z "${SRC_REPO}" ] ; then
	echo "--src-repo=<repo> must be provided"
	exit 1
fi

if [ -z "${DST_REPO}" ] ; then
	echo "--dst-repo=<repo> must be provided"
	exit 1
fi

if [ -z "${WORK_DIR}" ] && [ -z "${GITHUB_WORKSPACE}" ] ; then
	echo "--work-dir=<dir> must be provided on the command line or GITHUB_WORKSPACE must be provided in the environment"
	exit 1
fi

if [ -z "${GITHUB_WORKSPACE}" ] ; then
	export GITHUB_WORKSPACE=${WORK_DIR}
fi

export GH_TOKEN=${GITHUB_TOKEN}
export GIT_TOKEN=${GITHUB_TOKEN}

REPO_DIR=${GITHUB_WORKSPACE}/$(basename ${DST_REPO})

cd ${GITHUB_WORKSPACE}

# Create the new repo and set it's parameters
gh repo create asterisk/${DST_REPO} --private
gh repo edit asterisk/${DST_REPO} --allow-forking=false --enable-auto-merge=false \
	--enable-discussions=false --enable-issues=false --enable-merge-commit=false \
	--enable-wiki=false

# Do a bare clone of the source repo
git clone --bare https://github.com/asterisk/${SRC_REPO}.git ${REPO_DIR}

# Make sure the directory is trusted
git config --global --add safe.directory ${REPO_DIR}

cd ${REPO_DIR}

gh auth setup-git -h github.com

# Push everything to the new repo
git push --mirror https://github.com/asterisk/${DST_REPO}.git &> /tmp/push || \
	{ cat /tmp/push ; exit 1 ; }

gh repo edit asterisk/${DST_REPO} --default-branch master

# Clone all the labels from the soure repo.

gh label clone asterisk/${SRC_REPO} -f

# Sleep for a bit to allow github to catch up and recognize the
# workflows on the master branch.
sleep 5

gh api \
	--method PUT \
	-H "Accept: application/vnd.github+json" \
	-H "X-GitHub-Api-Version: 2022-11-28" \
	/orgs/asterisk/actions/permissions/repositories/${DST_REPO} || :

gh api --method PUT \
	-H "Accept: application/vnd.github+json" \
	-H "X-GitHub-Api-Version: 2022-11-28" \
	/repos/asterisk/${DST_REPO}/actions/permissions \
	-F "enabled=true" -f "allowed_actions=all" || :

sleep 5

# Disable the workflows we never want to run in the private repo.
# These will probably fail due to GitHub not enabling actions on the
# repo in the first place.
gh -R asterisk/${DST_REPO} workflow disable CreateDocs || :
gh -R asterisk/${DST_REPO} workflow disable "Issue Opened" || :
gh -R asterisk/${DST_REPO} workflow disable NightlyAdmin || :
gh -R asterisk/${DST_REPO} workflow disable NightlyTests || :
gh -R asterisk/${DST_REPO} workflow disable PRMergeApproved || :
gh -R asterisk/${DST_REPO} workflow disable Releaser || :
