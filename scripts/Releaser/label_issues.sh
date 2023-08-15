#!/bin/bash
set -e

declare needs=( end_tag )
declare wants=( src_repo dst_dir help dry_run )
declare tests=( end_tag src_repo dst_dir )

progdir="$(dirname $(realpath $0) )"
source "${progdir}/common.sh"

debug "Labelling issues for ${END_TAG}"
if [ ! -f "${DST_DIR}/issues_to_close.txt" ] ; then
	bail "File '${DST_DIR}/issues_to_close.txt' doesn't exist."
fi

issuelist=$( cat "${DST_DIR}/issues_to_close.txt" )
if [ ${#issuelist[*]} -le 0 ] ; then
	echo "${progname}: No issues to label"
	exit 0
fi

# We need to create a label like 'Release/20.1.0' if
# one doesn't already exist.
gh --repo asterisk/$(basename "${SRC_REPO}") \
	label list --json name --search "Release/${END_TAG}" |\
	grep -q "Release/${END_TAG}" || {
		debug "Creating label Release/${END_TAG}"
		${ECHO_CMD} gh --repo asterisk/$(basename ${SRC_REPO}) \
		label create "Release/${END_TAG}" --color "#16E26B" \
		--description "Fixed in release ${END_TAG}"
	} 

# GitHub makes this easy..  Add the label then close the issue.
debug "Labelling issues"
for issue in ${issuelist} ; do
	${ECHO_CMD} gh --repo asterisk/$(basename "${SRC_REPO}") issue edit $issue --add-label Release/${END_TAG}
done
debug "Done"
