#!/usr/bin/bash
set -x
set -e

SCRIPT_DIR=${GITHUB_WORKSPACE}/$(basename ${GITHUB_ACTION_REPOSITORY})/scripts
REPO_DIR=${GITHUB_WORKSPACE}/${INPUT_REPO}

mkdir -p ${REPO_DIR}
${SCRIPT_DIR}/checkoutRepo.sh --repo=${INPUT_REPO} \
	--base-branch=${INPUT_BASE_BRANCH} --is-cherry-pick=${INPUT_IS_CHERRY_PICK} \
	--pr-number=${INPUT_PR_NUMBER} --destination=${REPO_DIR}

cd ${REPO_DIR}

if [ "x${INPUT_BUILD_SCRIPT}" != "x" ] ; then
	OUTPUT_DIR=${GITHUB_WORKSPACE}/cache/output
	mkdir -p ${OUTPUT_DIR}

	${SCRIPT_DIR}/${INPUT_BUILD_SCRIPT} --github --branch-name=${INPUT_BASE_BRANCH} \
		--modules-blacklist="${INPUT_MODULES_BLACKLIST// /}" \
		--output-dir=${OUTPUT_DIR}
fi
