#!/usr/bin/env bash

SCRIPT_DIR=$(dirname $(readlink -fn $0))
PROGNAME=$(basename $(readlink -fn $0))
. ${SCRIPT_DIR}/ci.functions

for v in REPO WORKFLOW_RUN ; do
	assert_env_variable $v || exit 1
done

: ${TMP_DIR:="/tmp/run-${WORKFLOW_RUN}"}
: ${JOB_SUMMARY_OUTPUT:=job_summary.txt}

mkdir -p ${TMP_DIR}
gh --repo ${REPO} run download ${WORKFLOW_RUN} -D ${TMP_DIR}

if [ -n "${OUTPUT_DIR}" ] ; then
	mkdir -p ${OUTPUT_DIR}
	find ${TMP_DIR} -name ${JOB_SUMMARY_OUTPUT} -exec cat '{}' ';' > ${OUTPUT_DIR}/${JOB_SUMMARY_OUTPUT}
fi
find ${TMP_DIR} -name ${JOB_SUMMARY_OUTPUT} -exec cat '{}' ';'

exit 0
