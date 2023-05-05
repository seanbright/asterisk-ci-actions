#!/bin/bash
set -e

declare needs=( start_tag end_tag )
declare wants=( src_repo dst_dir )
declare tests=( start_tag src_repo dst_dir )

# Since creating the changelog doesn't make any
# changes, we're not bothering with dry-run.

progdir="$(dirname $(realpath $0) )"
source "${progdir}/common.sh"

declare -A end_tag_array
tag_parser ${END_TAG} end_tag_array

cd "${SRC_REPO}"
	
status=$(git status --porcelain)
if [ "x${status}" == "x" ] ; then
	bail "Nothing to commit!"
fi

debug "Committing ChangeLog and Alembic scripts"
if [ -f ChangeLog ] ; then
	$ECHO_CMD git rm -f ChangeLog
fi

if [ -f asterisk-*-summary.html ] ; then
	git rm -f asterisk-*-summary.html asterisk-*-summary.txt >/dev/null 2>&1 || :
fi

$ECHO_CMD cp ${DST_DIR}/.version .version

[ -L CHANGES ] && $ECHO_CMD git rm CHANGES

if [ -f CHANGES ] ; then
	$ECHO_CMD cp CHANGES /tmp/asterisk/last_changes
	$ECHO_CMD cp ${DST_DIR}/ChangeLog-${END_TAG}.md CHANGES.md
	$ECHO_CMD cat /tmp/asterisk/last_changes >> CHANGES.md
elif [ -f CHANGES.md ] ; then
	$ECHO_CMD cp CHANGES.md /tmp/asterisk/last_changes
	$ECHO_CMD cp ${DST_DIR}/ChangeLog-${END_TAG}.md CHANGES.md
	$ECHO_CMD cat /tmp/asterisk/last_changes >> CHANGES.md
else
	$ECHO_CMD cp ${DST_DIR}/ChangeLog-${END_TAG}.md CHANGES.md
fi
$ECHO_CMD ln -sf CHANGES.md CHANGES

if [ -f UPGRADE.txt ] ; then
	header=$(head -1 UPGRADE.txt)
	if [[ ! "$header" =~ OBSOLETE ]] ; then
		$ECHO_CMD cp UPGRADE.txt /tmp/asterisk/last_upgrade
		$ECHO_CMD cat <<-EOF >UPGRADE.txt
		===== WARNING, THIS FILE IS OBSOLETE AND WILL BE REMOVED IN A FUTURE VERSION =====
		See 'Upgrade Notes' in the CHANGES file
		
		EOF
		$ECHO_CMD cat /tmp/asterisk/last_upgrade >>UPGRADE.txt
	fi
fi

$ECHO_CMD git add contrib/realtime .version CHANGES CHANGES.md UPGRADE.txt
$ECHO_CMD git commit -a -m "Update for ${END_TAG}"

debug "Done"
