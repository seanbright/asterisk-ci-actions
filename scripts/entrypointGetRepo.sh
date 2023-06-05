#!/usr/bin/bash
set -x
set -e

export GITHUB_TOKEN=${INPUT_GITHUB_TOKEN}
export GH_TOKEN=${INPUT_GITHUB_TOKEN}

SCRIPT_DIR=${GITHUB_WORKSPACE}/$(basename ${GITHUB_ACTION_REPOSITORY})/scripts
REPO_DIR=${GITHUB_WORKSPACE}/$(basename ${INPUT_REPO})
OUTPUT_DIR=${GITHUB_WORKSPACE}/${INPUT_CACHE_DIR}/output

mkdir -p ${REPO_DIR}
mkdir -p ${OUTPUT_DIR}

cd ${GITHUB_WORKSPACE}
${SCRIPT_DIR}/checkoutRepo.sh --repo=${INPUT_REPO} \
	--branch=${INPUT_BASE_BRANCH} --is-cherry-pick=${INPUT_IS_CHERRY_PICK} \
	--pr-number=${INPUT_PR_NUMBER} --destination=${REPO_DIR}

cd ${REPO_DIR}

if [ "x${INPUT_BUILD_SCRIPT}" != "x" ] ; then
	${SCRIPT_DIR}/${INPUT_BUILD_SCRIPT} --github --branch-name=${INPUT_BASE_BRANCH} \
		--ccache-disable \
		--modules-blacklist="${INPUT_MODULES_BLACKLIST// /}" \
		--output-dir=${OUTPUT_DIR}
fi
