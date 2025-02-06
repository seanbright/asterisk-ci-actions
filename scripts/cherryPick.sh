#!/usr/bin/bash
SCRIPT_DIR=$(dirname $(realpath $0))

PUSH=false
NO_CLONE=false

source ${SCRIPT_DIR}/ci.functions
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
	debug_out "Cloning ${REPO} to ${REPO_DIR}"
	mkdir -p ${REPO_DIR}
	git clone -q --depth 10 --no-tags \
		${GITHUB_SERVER_URL}/${REPO} ${REPO_DIR}
	git config --global --add safe.directory $(realpath ${REPO_DIR})
fi

cd ${REPO_DIR}
debug_out "Fetching PR ${PR_NUMBER}"
git fetch --depth 10 --no-tags origin refs/pull/${PR_NUMBER}/head

# Get commits
debug_out "Getting commits for PR ${PR_NUMBER}"
mapfile COMMITS < <(gh api repos/${REPO}/pulls/${PR_NUMBER}/commits --jq '.[] | .sha + "|" + (.commit.message | split("\n")[0]) + "|" + .commit.author.name + "|" + .commit.author.email + "|"' || echo "@_ERROR_@")
[[ "${COMMITS[0]}" =~ @_ERROR_@ ]] && {
	echo "::error::No commits for PR ${PR_NUMBER}"
	exit 1
}

echo "COMMITS array: "
declare -p COMMITS

debug_out "There are ${#COMMITS[@]} commits for PR ${PR_NUMBER}"
for commit in "${COMMITS[@]}" ; do
	debug_out "Testing: '$commit'"
	[[ "$commit" =~ ([^|]+)\|([^|]+)\|([^|]+)\|([^|]+)\| ]] || {
		echo "::error::Unable to parse commit '$commit'"
		exit 1
	}
	SHA=${BASH_REMATCH[1]}
	MESSAGE=${BASH_REMATCH[2]}
	NAME=${BASH_REMATCH[3]}
	EMAIL=${BASH_REMATCH[4]}
	debug_out "Found commit: SHA: $SHA MESSAGE: $MESSAGE NAME: $NAME EMAIL: $EMAIL"
done

branches=${BRANCHES//[\"\|\'|\]|\[]/}
debug_out "Cherry-picking to branches: $branches"

error_msg=""
RC=0
IFS=$','
for BRANCH in $branches ; do
	debug_out "Cherry-picking commits to branch $BRANCH"
	$NO_CLONE || git fetch --no-tags --depth 10 origin refs/heads/$BRANCH:$BRANCH
	git checkout $BRANCH
	
	for commit in "${COMMITS[@]}" ; do
		[[ "$commit" =~ ([^|]+)\|([^|]+)\|([^|]+)\|([^|]+)\| ]] || {
			error_msg+="Unable to parse commit '$commit'\n"
			RC=1
			continue
		}
		SHA=${BASH_REMATCH[1]}
		MESSAGE=${BASH_REMATCH[2]}
		NAME=${BASH_REMATCH[3]}
		EMAIL=${BASH_REMATCH[4]}
		
		git config --local user.email "$EMAIL"
		git config --local user.name "$NAME"
		# The SHA should already be downloaded in FETCH_HEAD
		# so we should be able to just cherry-pick it.
		debug_out "Cherry-picking: SHA: $SHA MESSAGE: $MESSAGE NAME: $NAME EMAIL: $EMAIL"
		git cherry-pick ${SHA} || {
			error_msg+="Unable to cherry-pick commit '${MESSAGE}' to branch ${BRANCH}\n"
			git cherry-pick --abort || :
			RC=1
			continue
		} 
		debug_out "Success"
	done
	
	# We should already be on the correct branch
	# with the cherry-picks applied.
	# We just need to push unless DRY_RUN is true.
	
	if $PUSH  ; then
		debug_out "Pushing to branch $BRANCH" 
		git push --set-upstream origin $BRANCH
	fi
done

if [ -n "$error_msg" ] ; then
	echo -e "::error::$error_msg"
fi

exit $RC
