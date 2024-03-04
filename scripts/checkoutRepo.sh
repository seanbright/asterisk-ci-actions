#!/usr/bin/bash

SCRIPT_DIR=$(dirname $(realpath $0))
source ${SCRIPT_DIR}/ci.functions
set -x
set -e

if [ -z "${REPO}" ] ; then
	echo "::error::Missing repo"
	exit 1
fi

if [ -z "${DESTINATION}" ] ; then
	echo "::error::Missing destination"
	exit 1
fi

if [ -z "${PR_NUMBER}" ] ; then
	echo "::error::Missing PR number"
	exit 1
fi

if [ -z "${BRANCH}" ] ; then
	echo "::error::Missing branch"
	exit 1
fi

: ${IS_CHERRY_PICK:=false}
: ${NO_TAGS:=false}

mkdir -p ${DESTINATION}

no_tags=""
${NO_TAGS} && no_tags="--no-tags"

git clone -q -b master --depth 10 --no-tags \
	https://x-access-token:${GIT_TOKEN}@github.com/${REPO} ${DESTINATION}

git config --global --add safe.directory $(realpath ${DESTINATION})

if [ ${PR_NUMBER} -le 0 ] ; then
	# This is a nightly or dispatch job
	if ${IS_CHERRY_PICK} ; then
		echo "::error::Cherry-pick requested without a PR to cherry-pick"
		exit 1
	fi
	exit 0
fi

cd ${DESTINATION}

if ! ${IS_CHERRY_PICK} ; then
	git fetch origin refs/pull/${PR_NUMBER}/head
	# We're just checking out the PR
	git checkout FETCH_HEAD
	exit 0
else
	${SCRIPT_DIR}/cherryPick.sh --no-clone --repo=${REPO} \
		--pr-number=${PR_NUMBER} --branch=${BRANCH} \
		--repo-dir=${DESTINATION}
fi
