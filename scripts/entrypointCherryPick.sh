#!/usr/bin/bash
set -x
set -e

SCRIPT_DIR=${GITHUB_WORKSPACE}/$(basename ${GITHUB_ACTION_REPOSITORY})/scripts
REPO_DIR=${GITHUB_WORKSPACE}/$(basename ${INPUT_REPO})
OUTPUT_DIR=${GITHUB_WORKSPACE}/${INPUT_CACHE_DIR}/output

mkdir -p ${REPO_DIR}
mkdir -p ${OUTPUT_DIR}

cd ${GITHUB_WORKSPACE}
${SCRIPT_DIR}/checkoutRepo.sh --repo=${INPUT_REPO} \
	--branch=${INPUT_BRANCH} --is-cherry-pick=true \
	--pr-number=${INPUT_PR_NUMBER} --destination=${REPO_DIR}

cd ${REPO_DIR}
# We should already be on the correct branch
# with the cherry-picks applied.
# We just need to set up git to use GITHUB_TOKEN
# via gh and push.
export GH_TOKEN="${INPUT_GITHUB_TOKEN}"
gh auth setup-git -h github.com
git push
