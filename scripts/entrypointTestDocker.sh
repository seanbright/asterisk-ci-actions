#!/usr/bin/bash

set -x
if [ "${INPUT_TEST_TYPE}" == "pass_fail" ] ; then
	echo "Exiting with RC 1 (forced)"
	echo "result=failure" >> $GITHUB_OUTPUT
	exit 1
fi
echo "Exiting with RC 0 (forced)"
echo "result=success" >> $GITHUB_OUTPUT
exit 0
