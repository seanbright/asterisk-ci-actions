#!/usr/bin/bash
SCRIPT_DIR=$(dirname $(realpath $0))

source ${SCRIPT_DIR}/ci.functions
set -e

for v in REPO WORKFLOW_RUN WORKFLOW_RUN_ID ; do
	assert_env_variable $v || exit 1
done

# Getting PR number from workflow_run.name
debug_out "Attempting to get PR number from triggering workflow run name: '${WORKFLOW_RUN}'"

if [[ "${WORKFLOW_RUN}" =~ ^PR\ ([0-9]+) ]] ; then
	PR_NUMBER=${BASH_REMATCH[1]}
else
	# If the action was "requested", then the triggering workflow
	# may not have a had a chance to change its name from "PRChanged"
	# to "PR nnnn ..." before this workfow was kicked off.  We need
	# to keep checking the triggering workflow's name until it does.
	debug_out "Unable to parse '${WORKFLOW_RUN}' for PR number.  Retrying"
	for x in {1..10} ; do
		wfname=$(gh api /repos/${REPO}/actions/runs/${WORKFLOW_RUN_ID} --jq '.name')
		debug_out "Attempt: ${x} of 10. Triggering workflow run name: '${wfname}'"
		if [[ "${wfname}" =~ ^PR\ ([0-9]+) ]] ; then
			PR_NUMBER=${BASH_REMATCH[1]}
			break;
		fi
		debug_out "Attempt: ${x} of 10. Still unable to parse.  Waiting 5 seconds"
		sleep 5
	done
fi

if [ -z "$PR_NUMBER" ] ; then
	debug_out "::error::Unable to parse PR number"
	exit 1
fi

debug_out "Found PR ${PR_NUMBER}"
URL="/repos/${REPO}/pulls/${PR_NUMBER}"
debug_out "Using URL $URL to find PR ${PR_NUMBER} base branch"
BASE_BRANCH=$(gh api $URL --jq '.base.ref')
if [ -z "$BASE_BRANCH" ] ; then
	debug_out "::error::No base branch found for PR ${PR_NUMBER}"
	exit 1
fi

output="{ \"pr_number\": ${PR_NUMBER}, \"base_branch\": \"${BASE_BRANCH}\" }"
debug_out "Output: ${output}"
echo "${output}"

if [ -n "$GITHUB_ENV" ] ; then
	echo "PR_NUMBER=${PR_NUMBER}" >> ${GITHUB_ENV}
	echo "BASE_BRANCH=${BASE_BRANCH}" >> ${GITHUB_ENV}
fi
if [ -n "$GITHUB_OUTPUT" ] ; then
	echo "PR_NUMBER=${PR_NUMBER}" >> ${GITHUB_OUTPUT}
	echo "BASE_BRANCH=${BASE_BRANCH}" >> ${GITHUB_OUTPUT}
fi

exit 0
