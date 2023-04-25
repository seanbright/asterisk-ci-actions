#!/usr/bin/bash

SCRIPT_DIR=$(dirname $(realpath $0))
source ${SCRIPT_DIR}/ci.functions
set -x
set -e

if [ "x${REPO}" == "x" ] ; then
	echo "::error::Missing repo"
	exit 1
fi

if [ "x${DESTINATION}" == "x" ] ; then
	echo "::error::Missing destination"
	exit 1
fi

if [ "x${PR_NUMBER}" == "x" ] ; then
	echo "::error::Missing PR number"
	exit 1
fi

if [ "x${BRANCH}" == "x" ] ; then
	echo "::error::Missing branch"
	exit 1
fi

: ${IS_CHERRY_PICK:=false}


mkdir -p ${DESTINATION}

git clone --depth 5 -q -b ${BRANCH} \
	${GITHUB_SERVER_URL}/${REPO} ${DESTINATION}
git config --global --add safe.directory $(realpath ${DESTINATION})

if [ ${PR_NUMBER} -le 0 ] ; then
	# This is a nightly or dispatch job
	if ${IS_CHERRY_PICK} ; then
		echo "::error::Cherry-pick requested without a PR to cherry-pick"
		exit 1
	fi
	exit 0
fi

git fetch upstream refs/pull/${PR_NUMBER}/head
if ! ${IS_CHERRY_PICK} ; then
	# We're just checking out the PR
	git checkout FETCH_HEAD
	exit 0
fi

# We're cherry-picking
# We should already be on the branch we're cherry-picking to.

echo "Cherry-picking commits"
IFS=$'|'
while read SHA MESSAGE NAME EMAIL ; do
	# We need to set ourselves up as the original author.
	git config --global user.email "$EMAIL"
	git config --global user.name "$NAME"
	# The SHA should already be downloaded in FETCH_HEAD
	# so we should be able to just cherry-pick it. 
	echo "Cherry-picking ${SHA} : ${MESSAGE}"
	git cherry-pick ${SHA} || {
		echo "::error::Unable to cherry-pick commit"
		exit 1
	}
	echo "Success"
done < <(gh api repos/${REPO}/pulls/${PR_NUMBER}/commits --jq '.[] | .sha + "|" + (.commit.message | split("\n")[0]) + "|" + .commit.author.name + "|" + .commit.author.email + "|"')
