#!/usr/bin/env bash

SCRIPT_DIR=$(dirname $(readlink -fn $0))
PROGNAME=$(basename $(readlink -fn $0))
. ${SCRIPT_DIR}/ci.functions

for v in REPO PR_NUMBER TESTSUITE_PR_REGEX ; do
	assert_env_variable $v || exit 1
done

jq_exp=".[].body | match(\"${TESTSUITE_PR_REGEX}\"; \"g\") | .captures[0].string"
testsuite_pr=$(gh api /repos/${REPO}/issues/${PR_NUMBER}/comments \
	--jq "$jq_exp") || \
	{
		debug_out "::error::Unable to retrieve comments for /repos/${REPO}/issues/${PR_NUMBER}"
		exit 1
	}

if [ -z "${testsuite_pr}" ] ; then
	debug_out "No Testsuite PR found (OK)"
	exit 0
fi

debug_out "Testsuite PR: ${testsuite_pr}"

if [ -n "$GITHUB_ENV" ] ; then
	echo "TESTSUITE_TEST_PR=${testsuite_pr}" >> ${GITHUB_ENV}
fi
if [ -n "$GITHUB_OUTPUT" ] ; then
	echo "TESTSUITE_TEST_PR=${testsuite_pr}" >> ${GITHUB_OUTPUT}
fi

echo ${testsuite_pr}

exit 0
