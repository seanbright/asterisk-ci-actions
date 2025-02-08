#!/usr/bin/env bash

SCRIPT_DIR=$(dirname $(readlink -fn $0))
PROGNAME=$(basename $(readlink -fn $0))

VERBOSE=false
WRITE_STEP_SUMMARY=false

. ${SCRIPT_DIR}/ci.functions

for v in REPO WORKFLOW_RUN ; do
	assert_env_variable $v || exit 1
done

set -e

: ${TMP_DIR:="/tmp/run-${WORKFLOW_RUN}"}
: ${JOB_SUMMARY_OUTPUT:=job_summary.txt}

mkdir -p ${TMP_DIR}

gh api /repos/${REPO}/actions/runs/${WORKFLOW_RUN}/jobs \
	| jq '.' > ${TMP_DIR}/jobs.json

gh api /repos/${REPO}/actions/runs/${WORKFLOW_RUN}/artifacts \
	| jq '.' > ${TMP_DIR}/artifacts.json

declare -A jobs
eval $(jq -r '.jobs[] | select(.conclusion == "failure") | "jobs[" + (.id | tostring) + "]=\"" + .name + "\" "' ${TMP_DIR}/jobs.json)

for job in "${!jobs[@]}" ; do
	job_id=${job}
	job_name=${jobs[${job_id}]}
	artifact_name=${job_name##* }
	artifact_id=$(jq -r '.artifacts[] | select(.name == "'${artifact_name}'") | .id' ${TMP_DIR}/artifacts.json)
	[ -z "${artifact_id}" ] && continue
	$VERBOSE && debug_out "Downloading ${artifact_name} - ${artifact_id}"
	gh api /repos/${REPO}/actions/artifacts/${artifact_id}/zip > "${TMP_DIR}/${artifact_name}.zip"
	unzip -o -qq -d ${TMP_DIR}/${artifact_name} "${TMP_DIR}/${artifact_name}.zip"
	if [ -f "${TMP_DIR}/${artifact_name}/${JOB_SUMMARY_OUTPUT}" ] ; then
		html_url="https://github.com/${REPO}/actions/runs/${WORKFLOW_RUN}/job/${job_id}"
		sed -i "s|^|[${artifact_name}](${html_url}): |" "${TMP_DIR}/${artifact_name}/${JOB_SUMMARY_OUTPUT}"
	fi
done

if [ -n "${OUTPUT_DIR}" ] ; then
	mkdir -p ${OUTPUT_DIR}
	$VERBOSE && debug_out "Writing job summary to ${OUTPUT_DIR}/${JOB_SUMMARY_OUTPUT}"
	find ${TMP_DIR} -name ${JOB_SUMMARY_OUTPUT} -exec cat '{}' ';' > "${OUTPUT_DIR}/${JOB_SUMMARY_OUTPUT}"
fi
if ${WRITE_STEP_SUMMARY} && [ -n "${GITHUB_STEP_SUMMARY}" ] ; then
	$VERBOSE && debug_out "Writing job summary to ${GITHUB_STEP_SUMMARY}"
	find ${TMP_DIR} -name ${JOB_SUMMARY_OUTPUT} -exec cat '{}' ';' >> "${GITHUB_STEP_SUMMARY}"
fi
$VERBOSE && find ${TMP_DIR} -name ${JOB_SUMMARY_OUTPUT} -exec cat '{}' ';'

exit 0
