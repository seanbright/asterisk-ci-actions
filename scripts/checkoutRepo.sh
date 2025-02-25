#!/usr/bin/bash

SCRIPT_DIR=$(dirname $(readlink -fn $0))
source ${SCRIPT_DIR}/ci.functions

for v in REPO REPO_DIR BRANCH ; do
	assert_env_variable $v || exit 1
done

printvars REPO REPO_DIR PR_NUMBER BRANCH

: ${IS_CHERRY_PICK:=false}
: ${NO_TAGS:=false}
: ${GITHUB_SERVER_URL:="https://github.com"}
: ${PR_NUMBER:=-1}

cd $(dirname ${REPO_DIR})

no_tags=""
${NO_TAGS} && no_tags="--no-tags"

debug_out "    CD: $(pwd)"
debug_out "    Cloning ${REPO} to ${REPO_DIR}"
git clone -q --depth 10 --no-tags \
	${GITHUB_SERVER_URL}/${REPO} ${REPO_DIR}

if [ ! -d ${REPO_DIR}/.git ] ; then
	log_error_msgs "Failed to clone ${REPO} to ${REPO_DIR}"
	exit 1
fi

git config --global --add safe.directory $(realpath ${REPO_DIR})

cd ${REPO_DIR}

if [ ${PR_NUMBER} -le 0 ] ; then
	# This is a nightly or dispatch job
	if ${IS_CHERRY_PICK} ; then
		log_error_msgs "Cherry-pick requested without a PR to cherry-pick"
		exit 1
	fi
	debug_out "    Fetching ${BRANCH}"
	git fetch --no-tags --depth 10 origin refs/heads/$BRANCH:$BRANCH
	git checkout ${BRANCH}
	exit 0
fi

if ! ${IS_CHERRY_PICK} ; then
	debug_out "    Fetching PR ${PR_NUMBER}"
	git fetch origin refs/pull/${PR_NUMBER}/head
	# We're just checking out the PR
	git checkout FETCH_HEAD
	exit 0
else
	${SCRIPT_DIR}/cherryPick.sh --no-clone --repo=${REPO} \
		--pr-number=${PR_NUMBER} --branch=${BRANCH} \
		--repo-dir=${REPO_DIR} || exit 1
fi
