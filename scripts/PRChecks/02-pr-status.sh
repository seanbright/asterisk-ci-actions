#!/usr/bin/bash
CHECKS_DIR=$(dirname $(realpath $0))
SCRIPT_DIR=$(dirname ${CHECKS_DIR})

source ${SCRIPT_DIR}/ci.functions
source ${CHECKS_DIR}/checks.functions
set -e

assert_env_variables --print PR_STATUS_PATH || exit $EXIT_ERROR

: ${PR_CHECKLIST_PATH:=/dev/stderr}

status_count=$(jq -r '. | length' ${PR_STATUS_PATH})
if [ $status_count -eq 0 ] ; then
	debug_out "No status checks.  No checklist item needed."
	exit $EXIT_OK
fi

readarray -d "" -t states < <( jq --raw-output0 '.[].state ' ${PR_STATUS_PATH})
readarray -d "" -t descriptions < <( jq --raw-output0 '.[].description ' ${PR_STATUS_PATH})

checklist_added=false
for (( status=0 ; status < status_count ; status+=1 )) ; do
	if [ "${states[$status]}" != "success" ] ; then
		debug_out "Status check failed: ${descriptions[$status]}"
		cat <<-EOF | print_checklist_item --append-newline
		- [ ] ${descriptions[$status]}
		EOF
		checklist_added=true
	fi
done

$checklist_added && exit $EXIT_CHECKLIST_ADDED
debug_out "No issues found."
exit $EXIT_OK
