#!/usr/bin/env bash

SCRIPT_DIR=$(dirname $(readlink -fn $0))
PROGNAME=$(basename $(readlink -fn $0))

VERBOSE=false
WRITE_STEP_SUMMARY=false
ADD_PR_COMMENT=false

. ${SCRIPT_DIR}/ci.functions

for v in REPO WORKFLOW_RUN ; do
	assert_env_variable $v || exit 1
done

$ADD_PR_COMMENT && { assert_env_variable PR_NUMBER || exit 1; }

: ${TMP_DIR:="/tmp/run-${WORKFLOW_RUN}"}
: ${JOB_SUMMARY_OUTPUT:=job_summary.txt}

mkdir -p ${TMP_DIR}

gh api /repos/${REPO}/actions/runs/${WORKFLOW_RUN}/jobs --paginate  \
	| jq '.' > ${TMP_DIR}/jobs.json

gh api /repos/${REPO}/actions/runs/${WORKFLOW_RUN}/artifacts  --paginate \
	| jq '.' > ${TMP_DIR}/artifacts.json

declare -A jobs
eval $(jq -r '.jobs[] | select(.conclusion == "failure") | "jobs[" + (.id | tostring) + "]=\"" + .name + "\" "' ${TMP_DIR}/jobs.json)

HAS_OUTPUT=false
for job in "${!jobs[@]}" ; do
	job_id=${job}
	job_name=${jobs[${job_id}]}
	artifact_name=${job_name##* }
	artifact_name=${artifact_name/\//-}
	artifact_id=$(jq -r '.artifacts[] | select(.name == "'${artifact_name}'") | .id' ${TMP_DIR}/artifacts.json)
	[ -z "${artifact_id}" ] && continue
	$VERBOSE && debug_out "Downloading ${artifact_name} - ${artifact_id}"
	gh api /repos/${REPO}/actions/artifacts/${artifact_id}/zip > "${TMP_DIR}/${artifact_name}.zip"
	unzip -o -qq -d ${TMP_DIR}/${artifact_name} "${TMP_DIR}/${artifact_name}.zip"
	if [ -f "${TMP_DIR}/${artifact_name}/${JOB_SUMMARY_OUTPUT}" ] ; then
		HAS_OUTPUT=true
		html_url="https://github.com/${REPO}/actions/runs/${WORKFLOW_RUN}/job/${job_id}"
		sed -i "s|^|[${artifact_name}](${html_url}): |" "${TMP_DIR}/${artifact_name}/${JOB_SUMMARY_OUTPUT}"
	fi
done

${HAS_OUTPUT} || {
	$VERBOSE && debug_out "No job summary output found"
	exit 0
}

find ${TMP_DIR} -name ${JOB_SUMMARY_OUTPUT} | sort | xargs cat  > "${TMP_DIR}/summary.txt"

if [ -n "${OUTPUT_DIR}" ] ; then
	mkdir -p ${OUTPUT_DIR}
	$VERBOSE && debug_out "Writing job summary to ${OUTPUT_DIR}/${JOB_SUMMARY_OUTPUT}"
	cp "${TMP_DIR}/summary.txt" "${OUTPUT_DIR}/${JOB_SUMMARY_OUTPUT}"
fi
if ${WRITE_STEP_SUMMARY} && [ -n "${GITHUB_STEP_SUMMARY}" ] ; then
	$VERBOSE && debug_out "Writing job summary to ${GITHUB_STEP_SUMMARY}"
	cat "${TMP_DIR}/summary.txt" >> "${GITHUB_STEP_SUMMARY}"
fi
$VERBOSE && cat "${TMP_DIR}/summary.txt"

if ${ADD_PR_COMMENT} ; then
	gh --repo ${REPO} pr comment ${PR_NUMBER} --body-file "${TMP_DIR}/summary.txt"
fi

exit 0
