#!/usr/bin/bash
SCRIPT_DIR=$(dirname $(realpath $0))

source ${SCRIPT_DIR}/ci.functions
set -e

for v in REPO PR_NUMBER CHERRY_PICK_REGEX ; do
	assert_env_variable $v || exit 1
done

print_output() {
	output="{ \"forced_none\": $1, \"branch_count\": $2, \"branches\": $3 }"
	debug_out "Output: $output"
	echo "$output"
	if [ -n "$GITHUB_ENV" ] ; then
		echo "FORCED_NONE=$1" >> ${GITHUB_ENV}
		echo "BRANCH_COUNT=$2" >> ${GITHUB_ENV}
		echo "BRANCHES=$3" >> ${GITHUB_ENV}
	fi
	if [ -n "$GITHUB_OUTPUT" ] ; then
		echo "FORCED_NONE=$1" >> ${GITHUB_OUTPUT}
		echo "BRANCH_COUNT=$2" >> ${GITHUB_OUTPUT}
		echo "BRANCHES=$3" >> ${GITHUB_OUTPUT}
	fi
}

jqexp=".[].body | match(\"${CHERRY_PICK_REGEX}\"; \"g\") | .captures[0].string"
branchlist=$(gh api /repos/${REPO}/issues/${PR_NUMBER}/comments \
	--jq "${jqexp}" | tr '\n' ' ')

debug_out "Branch list: $branchlist"

if [[ "$branchlist" =~ none ]] ; then
	print_output true 0 '[]'
	exit 0
fi

eval declare -a BRANCHES=( ${branchlist/none/} ${INCLUDE_BRANCHES//,/ } )
declare -i branch_count=0

json='['
for branch in ${BRANCHES[@]} ; do
	[ $branch_count -ne 0 ] && json+=','
	json+="\"$branch\""
	branch_count+=1
done
json+=']'

print_output false $branch_count "$json"

exit 0
