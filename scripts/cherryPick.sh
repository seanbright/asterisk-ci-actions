#!/usr/bin/bash
SCRIPT_DIR=$(dirname $(realpath $0))

PUSH=false
NO_CLONE=false

source ${SCRIPT_DIR}/ci.functions
set -x
set -e

if [ -z "${REPO}" ] ; then
	echo "::error::Missing repo"
	exit 1
fi

if [ -z "${PR_NUMBER}" ] ; then
	echo "::error::Missing PR number"
	exit 1
fi

if [ -z "${BRANCH}" ] && [ -z "${BRANCHES}" ] ; then
	echo "::error::Either --branch or --branches must be specified"
	exit 1
fi

if [ -n "${BRANCH}" ] && [ -n "${BRANCHES}" ] ; then
	echo "::error::Can't specify both --branch and --branches at the same time"
	exit 1
fi

if [ -z "${GH_TOKEN}" ] ; then
	echo "::error::Missing GH_TOKEN in environment"
	exit 1
fi

if ! [[ "${PUSH}" =~ (true|false) ]] ; then
	echo "::error::--push can only be true or false"
	exit 1
fi

if ! [[ "${NO_CLONE}" =~ (true|false) ]] ; then
	echo "::error::--no-clone can only be true or false"
	exit 1
fi


cd ${GITHUB_WORKSPACE}
gh auth setup-git -h github.com

: ${REPO_DIR:=${GITHUB_WORKSPACE}/$(basename ${REPO})}

: ${BRANCHES:=[\'$BRANCH\']}

if ! $NO_CLONE ; then
	mkdir -p ${REPO_DIR}
	git clone -q --depth 10 --no-tags \
		${GITHUB_SERVER_URL}/${REPO} ${REPO_DIR}
	git config --global --add safe.directory $(realpath ${REPO_DIR})
fi

cd ${REPO_DIR}
git fetch --depth 10 --no-tags origin refs/pull/${PR_NUMBER}/head


branches=${BRANCHES//[\"\|\'|\]|\[]/}
echo "Cherry-picking to branches: $branches"

IFS=$',|'
for BRANCH in $branches ; do

	echo "Cherry-picking commits to branch $BRANCH"
	$NO_CLONE || git fetch --no-tags --depth 10 origin refs/heads/$BRANCH:$BRANCH
	git checkout $BRANCH
	while read SHA MESSAGE NAME EMAIL ; do
		# We need to set ourselves up as the original author.
		git config --local user.email "$EMAIL"
		git config --local user.name "$NAME"
		# The SHA should already be downloaded in FETCH_HEAD
		# so we should be able to just cherry-pick it.
		echo "Cherry-picking ${SHA} : ${MESSAGE}"
		git cherry-pick ${SHA} || {
			echo "::error::Unable to cherry-pick commit"
			git cherry-pick --abort || :
			exit 1
		} 
		echo "Success"
	done < <(gh api repos/${REPO}/pulls/${PR_NUMBER}/commits --jq '.[] | .sha + "|" + (.commit.message | split("\n")[0]) + "|" + .commit.author.name + "|" + .commit.author.email + "|"')

	# We should already be on the correct branch
	# with the cherry-picks applied.
	# We just need to push unless DRY_RUN is true.
	
	if $PUSH  ; then
		git push --set-upstream origin $BRANCH
	else
		echo "Push skipped"
	fi
done

exit 0