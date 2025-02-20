#!/usr/bin/bash
CHECKS_DIR=$(dirname $(realpath $0))
SCRIPT_DIR=$(dirname ${CHECKS_DIR})

source ${SCRIPT_DIR}/ci.functions
source ${CHECKS_DIR}/checks.functions
set -e

assert_env_variables --print PR_PATH PR_COMMITS_PATH || exit 1

: ${PR_CHECKLIST_PATH:=/dev/stderr}

pr_title=$(jq -j -r '.title' ${PR_PATH})
# We need to strip out any carriage returns('\r') so we can do
# more accurate comparisons.
pr_body=$(jq -j -r '.body | sub("\r";"";"g")' ${PR_PATH})

commit_msg=$(jq -j -r '.[0].commit.message | sub("\r";"";"g")' ${PR_COMMITS_PATH})
# The commit title isn't split out for us like the PR title
# so we need to get the first line ourselves.
commit_title=$(jq -j -r '.[0].commit.message  | sub("\r";"";"g") | split("\n")[0] ' ${PR_COMMITS_PATH})
# The second line of the commit message should be a blank line.
commit_blank=$(jq -j -r '.[0].commit.message | sub("\r";"";"g") | split("\n")[1:2].[] ' ${PR_COMMITS_PATH})
# The rest of the commit message is the body.
commit_body=$(jq -r '.[0].commit.message | sub("\r";"";"g") | split("\n")[2:] | join("\n")' ${PR_COMMITS_PATH})

debug_out "Checking for PR description/Commit msg mismatches"
checklist_added=false

if [ "$pr_title" != "$commit_title" ] ; then
	debug_out "PR title and commit title mismatch"
	cat <<-EOF | print_checklist_item --append-newline
	- [ ] The PR title does not match the commit title.
	EOF
	checklist_added=true
fi

if [ "$pr_body" != "$commit_body" ] ; then
	debug_out "PR description and commit message body mismatch."
	cat <<-EOF | print_checklist_item --append-newline
	- [ ] The PR description does not match the commit message body.
	EOF
	checklist_added=true
fi

if [ -n "${commit_blank}" ] ; then
	debug_out "Commit message doesn't contain a blank line after the title."
	cat <<-EOF | print_checklist_item --append-newline
	- [ ] The commit message doesn't contain a blank line after the title.
	EOF
	checklist_added=true
fi

print_bad_fixes() {
	cat <<-EOF | print_checklist_item --append-newline
	- [ ] The ${1:-<mmsg_body>} has a malformed \`Fixes\` or \`Resolves\` trailer. 
	The \`Fixes\` or \`Resolves\` keywords MUST be preceeded by a blank line 
	and followed immediately by a colon, a space, a hash sign, and the issue number. 
	A malformed trailer will prevent the issue from being automatically closed when 
	the PR merges and from being listed in the release change logs.<br> 
	  Regular expression: \`^(Fixes|Resolves): #[0-9]+\`.<br> 
	  Example: \`Fixes: #9999\`. 
	EOF
	checklist_added=true
}

print_no_blank_line() {
	cat <<-EOF | print_checklist_item --append-newline
	- [ ] The \`${1:-<keyword>}\` trailer in the ${2:-<msg_body>} must be 
	predeeded by a blank line and the \`${1:-<keyword>}\` keyword itself must be followed 
	by a colon and a space before the actual note text.  This is to ensure that 
	the note is properly formatted and displayed in the release change logs.
	EOF
	checklist_added=true
}

print_mismatched_fixes() {
	cat <<-EOF | print_checklist_item --append-newline
	- [ ] The ${1:-<first_body>} has a \`Fixes\` or \`Resolves\` special trailer 
	but the ${2:-<second_body>} has neither.  A properly formatted \`Fixes\` or \`Resolves\` 
	trailer is required in the PR description to allow the issue and the PR 
	to be cross-linked and for the issue to be automatically closed when the 
	PR merges. It's also required in the commit message to allow the issue 
	to be listed in the release change logs.
	EOF
	checklist_added=true
}

debug_out "Checking commit message for Resolves/Fixes, UpgradeNote and UserNote trailers."

declare -a keywords=( Fixes Resolves UpgradeNote UserNote )
declare -A bodies=( ["commit"]="${commit_body}" ["pr"]="${pr_body}" )
declare -A body_names=( ["commit"]="commit message" ["pr"]="PR description" )

declare -A has_fixes=( ["commit"]=false ["pr"]=false )
declare -A has_usernote=( ["commit"]=false ["pr"]=false )
declare -A has_upgradenote=( ["commit"]=false ["pr"]=false )
declare -A commit_trailers=( ["fixes"]=false ["usernote"]=false ["upgradenote"]=false )
declare -A pr_trailers=( ["fixes"]=false ["usernote"]=false ["upgradenote"]=false )

for body in ${!bodies[@]} ; do
	for keyword in Fixes Resolves UpgradeNote UserNote ; do
		if [[ "${bodies[$body]}" =~ (^|[[:cntrl:]])(${keyword})([^[:cntrl:]]+) ]] ; then
#			debug_out "${body} has a ${keyword} trailer."
			eval has_${keyword,,}[$body]=true
			eval ${body}_trailers[${keyword,,}]=true
		fi
	done
done

declare -A has_bad_fixes=( ["commit"]=false ["pr"]=false )
declare -A has_no_blank_line=( ["commit"]=false ["pr"]=false )

for body in ${!bodies[@]} ; do
	if ${has_fixes[$body]} ; then
		[[ "${bodies[$body]}" =~ (^|[[:cntrl:]])(Fixes|Resolves)([^[:cntrl:]]+) ]] || continue
		keyword=${BASH_REMATCH[2]}
		value=${BASH_REMATCH[3]}
		debug_out "${body} has a '${keyword}' trailer.  Checking value '${value}'."
		if [[ ! "${value}" =~ ^[:][[:blank:]][#][0-9]+$ ]] || [[ ! "${bodies[$body]}" =~ (^|[[:cntrl:]][[:cntrl:]])${keyword} ]] ; then
			debug_out "${body} '${keyword}' trailer doesn't have a preceeding blank line."
			print_bad_fixes "${body_names[$body]}"
		fi
	fi
	for keyword in UserNote UpgradeNote ; do
		if eval "\${has_${keyword,,}[$body]}" ; then
			debug_out "${body} has a '${keyword}' trailer.  Checking for ':' and predeeding blank line."
			if [[ ! "${bodies[$body]}" =~ (^|[[:cntrl:]][[:cntrl:]])${keyword}[:][[:blank:]] ]] ; then
				debug_out "${body} '${keyword}' trailer either doesn't have a ':' after the keyword or doesn't have a preceeding blank line."
				print_no_blank_line "${keyword}" "${body_names[$body]}"
			fi
		fi
	done
done

if ${has_fixes[commit]} && ! ${has_fixes[pr]} ; then
	debug_out "Commit has fixes but PR doesn't."
	print_mismatched_fixes "${body_names[commit]}" "${body_names[pr]}"
fi

if ! ${has_fixes[commit]} && ${has_fixes[pr]} ; then
	debug_out "PR has fixes but commit doesn't."
	print_mismatched_fixes "${body_names[pr]}" "${body_names[commit]}"
fi

$checklist_added && exit $EXIT_CHECKLIST_ADDED
debug_out "No issues found."
exit EXIT_OK

