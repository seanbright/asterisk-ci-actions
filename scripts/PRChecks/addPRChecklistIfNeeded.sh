#!/usr/bin/bash
CHECKS_DIR=$(dirname $(realpath $0))
SCRIPT_DIR=$(dirname ${CHECKS_DIR})

DRY_RUN=false
DOWNLOAD_ONLY=false
DONT_DOWNLOAD=false
QUIET_CHECKS=false

source ${SCRIPT_DIR}/ci.functions
source ${CHECKS_DIR}/checks.functions

assert_env_variables --print REPO PR_NUMBER || exit 1

pr_path=/tmp/pr-${PR_NUMBER}.json
pr_diff_path=/tmp/pr-${PR_NUMBER}.diff
pr_commits_path=/tmp/pr-commits-${PR_NUMBER}.json
pr_comments_path=/tmp/pr-comments-${PR_NUMBER}.json

if ! $DONT_DOWNLOAD ; then
	debug_out "Downloading PR,  diff, commits, comments"

	curl -sL https://api.github.com/repos/${REPO}/pulls/${PR_NUMBER} > ${pr_path}

	curl -sL https://github.com/${REPO}/pull/${PR_NUMBER}.diff > ${pr_diff_path}

	curl -sL https://api.github.com/repos/${REPO}/pulls/${PR_NUMBER}/commits > ${pr_commits_path}

	curl -sL https://api.github.com/repos/${REPO}/issues/${PR_NUMBER}/comments > ${pr_comments_path}
fi

if $DOWNLOAD_ONLY ; then
	debug_out "Retrieval only.  Exiting."
	exit 0
fi

pr_checklist_path=/tmp/pr-checklist-${PR_NUMBER}.md
[ -f ${pr_checklist_path} ] && rm ${pr_checklist_path}

SCRIPT_ARGS="--repo=${REPO} --pr-number=${PR_NUMBER} \
--pr-path=${pr_path} \
--pr-diff-path=${pr_diff_path} \
--pr-commits-path=${pr_commits_path} \
--pr-comments-path=${pr_comments_path} \
--pr-checklist-path=${pr_checklist_path}"

debug_out "Running PR checks with arguments: ${SCRIPT_ARGS}"

checklist_added=false
for s in $(find ${CHECKS_DIR} -name '[0-9]*.sh' | sort) ; do
	check_name=$(basename $s)
	debug_out "Running check: ${check_name}"
	if $QUIET_CHECKS ; then
		bash $s ${SCRIPT_ARGS} &> /dev/null
	else
		bash $s ${SCRIPT_ARGS}
	fi
	RC=$?
	case $RC in
		$EXIT_OK)
			debug_out "    Check ${check_name} added no checklist items."
			;;
		$EXIT_ERROR)
			debug_out "    Check ${check_name} fatal error.  Exiting."
			exit 1
			;;
		$EXIT_CHECKLIST_ADDED)
			debug_out "    Check ${check_name} added checklist items."
			checklist_added=true
			;;
		$EXIT_SKIP_FURTHER_CHECKS)
			debug_out "    Check ${check_name} requested no more checks."
			break
			;;
		*)
			debug_out "    Check ${check_name} returned unknown exit code: $RC"
			exit 1
			;;
	esac
done

checklist_comment_id=$(jq -r '.[] | select(.body | startswith("<!--PRCL-->")) | .id' ${pr_comments_path})

if ! $checklist_added ; then
	debug_out "No PR checklist items found.  No reminder needed"
	if [ -n "$checklist_comment_id" ] ; then
		debug_out "Removing existing obsolete PR checklist comment"
		if $DRY_RUN ; then
			debug_out "DRY-RUN: gh api /repos/${REPO}/issues/comments/${checklist_comment_id} -X DELETE"
		else
			gh api /repos/${REPO}/issues/comments/${checklist_comment_id} -X DELETE
		fi
	fi
	exit 0
fi

pr_checklist_comment_path=/tmp/pr-checklist-comment-${PR_NUMBER}.md

# <!--PRCL--> needs to be the first line of the comment.
# This is how we'll find it later.
echo "<!--PRCL-->" > ${pr_checklist_comment_path}

# Append the checklist items
cat ${pr_checklist_path} >> ${pr_checklist_comment_path}

if $DRY_RUN ; then
	cat ${pr_checklist_comment_path} >&2
fi

if [ -n "$checklist_comment_id" ] ; then
	debug_out "Updating existing PR checklist comment"
	if $DRY_RUN ; then
		debug_out "DRY-RUN: gh api /repos/${REPO}/issues/comments/${checklist_comment_id} -X PATCH -F 'body=@${pr_checklist_comment_path}'"
	else
		gh api /repos/${REPO}/issues/comments/${checklist_comment_id} -X PATCH -F 'body=@${pr_checklist_comment_path}'
	fi
else
	debug_out "Creating new PR checklist comment"
	if $DRY_RUN ; then
		debug_out "DRY-RUN: gh api /repos/${REPO}/issues/${PR_NUMBER}/comments -F 'body=@${pr_checklist_comment_path}'"
	else
		gh api /repos/${REPO}/issues/${PR_NUMBER}/comments -F 'body=@${pr_checklist_comment_path}'
	fi
fi

exit 0
