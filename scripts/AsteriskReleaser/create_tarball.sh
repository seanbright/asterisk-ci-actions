#!/bin/bash
set -e

declare needs=( end_tag )
declare wants=( src_repo dst_dir sign dry_run )
declare tests=( end_tag src_repo dst_dir )

progdir="$(dirname $(realpath $0) )"
source "${progdir}/common.sh"

declare -A end_tag_array
tag_parser ${END_TAG} end_tag_array || bail "Unable to parse end tag '${END_TAG}'"
${DEBUG} && declare -p end_tag_array

debug "Creating tarball for ${END_TAG}"
# Before we create the tarball, we need to retrieve
# a few basic sounds files.
debug "Downloading sound files"
${ECHO_CMD} make -C "${SRC_REPO}/sounds" \
	MENUSELECT_CORE_SOUNDS=CORE-SOUNDS-EN-GSM \
	MENUSELECT_MOH=MOH-OPSOUND-WAV \
	WGET='wget -q' \
	DOWNLOAD='wget -q' all || bail "Unable to download sounds tarballs"

# Git creates the tarball for us but we need to tell it
# to include the unversioned sounds files just downloaded.
debug "Creating archive from git"
${ECHO_CMD} git -C "${SRC_REPO}" archive --format=tar \
	-o "${DST_DIR}/${end_tag_array[artifact_prefix]}-${END_TAG}.tar" \
	--prefix="${end_tag_array[artifact_prefix]}-${END_TAG}/sounds/" \
	$(find "${SRC_REPO}/sounds/" -name "asterisk*.tar.gz" -printf " --add-file=sounds/%P") \
	--prefix="${end_tag_array[artifact_prefix]}-${END_TAG}/" "${END_TAG}" || bail "Unable to create tarball"
${ECHO_CMD} tar --delete -f "${DST_DIR}/${end_tag_array[artifact_prefix]}-${END_TAG}.tar" ${end_tag_array[artifact_prefix]}-${END_TAG}/.github || :
${ECHO_CMD} gzip -f "${DST_DIR}/${end_tag_array[artifact_prefix]}-${END_TAG}.tar"

pushd "${DST_DIR}" &>/dev/null
debug "Creating checksums"
for alg in md5 sha1 sha256 ; do
	${ECHO_CMD} ${alg}sum ${end_tag_array[artifact_prefix]}-${END_TAG}.tar.gz > ${end_tag_array[artifact_prefix]}-${END_TAG}.${alg}
done 
# The gpg key is installed automatically by the GitHub action.
# If running standalone, your default gpg key will be used.
${SIGN} && {
	debug "Signing"
	${ECHO_CMD} gpg --detach-sign --armor ${end_tag_array[artifact_prefix]}-${END_TAG}.tar.gz
}
popd &>/dev/null
debug "Done"
