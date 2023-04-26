#!/usr/bin/bash
SCRIPT_DIR=$(dirname $(realpath $0))
source ${SCRIPT_DIR}/ci.functions
set -x
set -e

if [ "x${REPO}" == "x" ] ; then
	echo "::error::Missing repo"
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

if [ "x${GH_TOKEN}" == "x" ] ; then
	echo "::error::Missing GH_TOKEN"
	exit 1
fi

REPO_DIR=${GITHUB_WORKSPACE}/$(basename ${REPO})

mkdir -p ${REPO_DIR}

cd ${GITHUB_WORKSPACE}
gh auth setup-git -h github.com

${SCRIPT_DIR}/checkoutRepo.sh --repo=${REPO} \
	--branch=${BRANCH} --is-cherry-pick=true \
	--pr-number=${PR_NUMBER} --destination=${REPO_DIR}

cd ${REPO_DIR}
# We should already be on the correct branch
# with the cherry-picks applied.
# We just need to push.
git push --force
