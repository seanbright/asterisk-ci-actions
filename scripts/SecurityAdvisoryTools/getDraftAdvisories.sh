#!/usr/bin/bash

SAT_DIR=$(dirname $(readlink -fn $0))
SCRIPT_DIR=$(dirname ${SAT_DIR})

set -e
QUIETER=true
HELP=false
BRIEF=false
ONELINE=false

print_help() {
	cat <<-EOF >/dev/stderr
	
	This script gets a list of draft security advisories for a repository.
	
	Usage: $0 --repo=<github_org>/<github_repo> [ --brief [ --oneline ] ]

	One row will be returned for each advisory in the format:
	<ghsa_id> : <summary>
	
	If --brief is specified, only the ghsa_ids will be printed.  If --oneline
	is also specified, the ids will be printed on one line separated by commas.
	
	The github cli tool is used to retrieve the advisories so you must have
	permission to read unpublished advisories for the repo specified.

	EOF
}

source "${SCRIPT_DIR}/ci.functions"
source "${SCRIPT_DIR}/tag.functions"

if [ -z "${REPO}" ] ; then
	echo -e "\nError: --repo=<github_org>/<github_repo> is required." >&2
	print_help
	exit 1
fi

fn="/tmp/sadraft.$$.json"
gh api --paginate "/repos/${REPO}/security-advisories?state=draft" >"${fn}"
trap '[ -f "${fn}" ] && rm "${fn}"' EXIT

if ${BRIEF} ; then
	if ${ONELINE} ; then
		exp='[ .[].ghsa_id ] | join(",")'
	else
		exp='.[].ghsa_id'
	fi
else
	exp='.[] | .ghsa_id + " : " + .summary'
fi

jq -r "${exp}" "${fn}"
