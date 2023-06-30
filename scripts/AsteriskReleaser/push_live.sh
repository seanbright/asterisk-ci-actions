#!/bin/bash

declare needs=( end_tag )
declare wants=( src_repo dst_dir start_tag push_tarballs )
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
	RC=0
	$ECHO_CMD gh release create ${END_TAG} \
		--verify-tag \
		$( [ "${end_tag[release_type]}" != "ga" ] && echo "--prerelease" ) \
		--notes-file ${DST_DIR}/release_notes.md \
		--target ${end_tag[branch]} -t "Asterisk Release ${END_TAG}" \
		${DST_DIR}/asterisk-${END_TAG}.* \
		${DST_DIR}/ChangeLog-${END_TAG}.md \
		${DST_DIR}/README-${END_TAG}.md || RC=1
fi

[ $RC -ne 0 ] && bail "Unable to create GitHub release!!"

$PUSH_TARBALLS || exit 0

debug "Pushing Asterisk Release ${END_TAG} live"

scp -p "${progdir}/common.sh" "${progdir}/downloads_host_publish.sh" \
	${DEPLOY_SSH_USERNAME}@${DEPLOY_HOST}:/home/${DEPLOY_SSH_USERNAME}/

ssh ${DEPLOY_SSH_USERNAME}@${DEPLOY_HOST} \
	/home/${DEPLOY_SSH_USERNAME}/downloads_host_publish.sh \
	--end-tag=${END_TAG} --dst-dir=${DEPLOY_DIR}
