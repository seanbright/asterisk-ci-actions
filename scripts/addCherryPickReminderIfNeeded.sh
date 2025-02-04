#!/usr/bin/bash
SCRIPT_DIR=$(dirname $(realpath $0))

PUSH=false
NO_CLONE=false

source ${SCRIPT_DIR}/ci.functions
set -e

for v in REPO PR_NUMBER CHERRY_PICK_REGEX CHERRY_PICK_REMINDER ; do
	assert_env_variable $v || exit 1
done

#If the CPR already exists we can just bail.
debug_out "Checking for existing CPR"
URL="/repos/${REPO}/issues/${PR_NUMBER}/comments"
ALREADY_HAS_CPR=$(gh api $URL --jq '.[] | select(.body | startswith("<!--CPR-->")) | has("body")')

if [ "$ALREADY_HAS_CPR" == "true" ] ; then
	debug_out "    Already has cherry-pick reminder.  No further action needed"
	exit 0
fi
debug_out "No existing CPR found"

# Look for the cherry-pick-to headers.
debug_out "Looking for 'cherry-pick-to' headers"
result=$(${SCRIPT_DIR}/getCherryPickBranchesFromPR.sh --repo=${REPO} \
	--pr-number=${PR_NUMBER} --cherry-pick-regex="${CHERRY_PICK_REGEX}")

FORCED_NONE=$(echo $result | jq -r '.forced_none')
BRANCH_COUNT=$(echo $result | jq -r '.branch_count')
BRANCHES=$(echo $result | jq -cr '.branches')

debug_out "    Forced none: $FORCED_NONE"
debug_out "    Branch count: $BRANCH_COUNT"
debug_out "    Branches: $BRANCHES"

if [ "$FORCED_NONE" == "true" ] || [ ${BRANCH_COUNT} -gt 0 ] ; then
	debug_out "    No cherry-pick reminder needed"
	exit 0
fi

debug_out "Adding cherry-pick reminder"

echo "$CHERRY_PICK_REMINDER" | gh --repo ${REPO} pr comment ${PR_NUMBER} --body-file -

