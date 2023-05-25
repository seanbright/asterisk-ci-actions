#!/bin/bash

declare needs=( end_tag )
declare wants=( src_repo dst_dir start_tag)
declare tests=( src_repo dst_dir )

progdir="$(dirname $(realpath $0) )"
source "${progdir}/common.sh"

declare -A end_tag
tag_parser ${END_TAG} end_tag || bail "Unable to parse end tag '${END_TAG}'"
${DEBUG} && declare -p end_tag

debug "Pushing Asterisk Release ${END_TAG} live"
cd "${SRC_REPO}"
RC=0
$ECHO_CMD gh release create ${END_TAG} \
	--verify-tag \
	$( [ "${end_tag[release_type]}" != "ga" ] && echo "--prerelease" ) \
	--notes-file ${DST_DIR}/email_announcement.md \
	--target ${end_tag[branch]} -t "Asterisk Release ${END_TAG}" \
	${DST_DIR}/asterisk-${END_TAG}.* \
	${DST_DIR}/ChangeLog-${END_TAG}.md \
	${DST_DIR}/README-${END_TAG}.md || RC=1
if [ $RC -eq 1 ] ; then
	$ECHO_CMD gh release create ${END_TAG} \
		--verify-tag \
		$( [ "${end_tag[release_type]}" != "ga" ] && echo "--prerelease" ) \
		--notes-file ${DST_DIR}/release_notes.md \
		--target ${end_tag[branch]} -t "Asterisk Release ${END_TAG}" \
		${DST_DIR}/asterisk-${END_TAG}.* \
		${DST_DIR}/ChangeLog-${END_TAG}.md \
		${DST_DIR}/README-${END_TAG}.md
fi

debug "Pushing Asterisk Release ${END_TAG} to downloads.asterisk.org"
