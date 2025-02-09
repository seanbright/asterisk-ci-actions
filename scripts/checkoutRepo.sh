#!/usr/bin/bash

SCRIPT_DIR=$(dirname $(readlink -fn $0))
source ${SCRIPT_DIR}/ci.functions

for v in REPO REPO_DIR PR_NUMBER BRANCH ; do
	assert_env_variable $v || exit 1
done

printvars REPO REPO_DIR PR_NUMBER BRANCH

: ${IS_CHERRY_PICK:=false}
: ${NO_TAGS:=false}
: ${GITHUB_SERVER_URL:="https://github.com"}

cd $(dirname ${REPO_DIR})

no_tags=""
${NO_TAGS} && no_tags="--no-tags"

debug_out "CD: $(pwd)"
debug_out "Cloning ${REPO} to ${REPO_DIR}"
git clone -q --depth 10 --no-tags \
	${GITHUB_SERVER_URL}/${REPO} ${REPO_DIR}

if [ ! -d ${REPO_DIR}/.git ] ; then
	log_error_msgs "Failed to clone ${REPO} to ${REPO_DIR}"
	exit 1
fi

git config --global --add safe.directory $(realpath ${REPO_DIR})

if [ ${PR_NUMBER} -le 0 ] ; then
	# This is a nightly or dispatch job
	if ${IS_CHERRY_PICK} ; then
		log_error_msgs "Cherry-pick requested without a PR to cherry-pick"
		exit 1
	fi
	exit 0
fi

cd ${REPO_DIR}

if ! ${IS_CHERRY_PICK} ; then
	git fetch origin refs/pull/${PR_NUMBER}/head
	# We're just checking out the PR
	git checkout FETCH_HEAD
	exit 0
else
	${SCRIPT_DIR}/cherryPick.sh --no-clone --repo=${REPO} \
		--pr-number=${PR_NUMBER} --branch=${BRANCH} \
		--repo-dir=${REPO_DIR} || exit 1
fi
