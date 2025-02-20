#!/usr/bin/bash
CHECKS_DIR=$(dirname $(realpath $0))
SCRIPT_DIR=$(dirname ${CHECKS_DIR})

source ${SCRIPT_DIR}/ci.functions
source ${CHECKS_DIR}/checks.functions
set -e

assert_env_variables --print PR_COMMENTS_PATH || exit $EXIT_ERROR

: ${PR_CHECKLIST_PATH:=/dev/stderr}

debug_out "    Looking for 'cherry-pick-to' headers."
value=$(jq -c -r "[ .[].body | match(\"(^|\r?\n)cherry-pick-to:[[:blank:]]*(([0-9.]+)|(certified/[0-9.]+)|(master|none))\"; \"g\") | .captures[1].string ][]" ${PR_COMMENTS_PATH})
if [ -n "$value" ] ; then
	debug_out "    cherry-pick-to: ${value//[[:space:]]/,} found.  No checklist item needed."
	exit $EXIT_OK
fi
debug_out "    No 'cherry-pick-to' headers found."

debug_out "Adding cherry-pick reminder."
cat <<-EOF | print_checklist_item --append-newline
- [ ] The are no \`cherry-pick-to\` headers in any comment in this PR. 
If the PR applies to more than just the branch it was submitted against, 
please add a comment with one or more \`cherry-pick-to: <branch>\` headers or a 
comment with \`cherry-pick-to: none\` to indicate that this PR shouldn't
be cherry-picked to any other branch. See the 
[Code Contribution](https://docs.asterisk.org/Development/Policies-and-Procedures/Code-Contribution/) 
documentation for more information.
EOF

exit $EXIT_CHECKLIST_ADDED
