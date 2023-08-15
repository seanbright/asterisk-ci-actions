#!/bin/bash

set -e

declare -A options=(
	[save_github_env]="--save-github-env                 # Saves start tag to 'start_tag' in the github environment"
)
SAVE_GITHUB_ENV=false
TAG_OUTPUT_PREFIX=

declare needs=( end_tag )
declare wants=( start_tag src_repo security norc hotfix save_github_env)
declare tests=( src_repo )

progdir="$(dirname $(realpath $0) )"
source "${progdir}/common.sh"

print_tag() {
	echo $1
	if $SAVE_GITHUB_ENV && [ -n "$GITHUB_ENV" ] && [ -f "$GITHUB_ENV" ] ; then
		echo "start_tag=$1" >> "$GITHUB_ENV"
	fi
}

declare -A last
declare -A new

tag_parser ${END_TAG} new || bail "Unable to parse end tag '${END_TAG}'"
${DEBUG} && declare -p new
debug "Checking out ${new[branch]}"
cd "${SRC_REPO}"

git checkout ${new[branch]}  >/dev/null 2>&1

if [ -z "${START_TAG}" ] ; then
	START_TAG=$(git -C "${SRC_REPO}" describe --abbrev=0 "${new[branch]}")
fi

debug "Parsing start tag ${START_TAG}"
tag_parser ${START_TAG} last || bail "Unable to parse start tag '${START_TAG}'"
${DEBUG} && declare -p last

if [ "${new[tag]}" == "${last[tag]}" ] ; then
	bail "(${last[tag]} -> ${new[tag]}): The end tag you specified
		is the same as the last tag in the repo."
fi
debug "good: Tags aren't the same"

if [ "${last[branch]}" != "${new[branch]}" ] ; then
	bail "(${last[tag]} -> ${new[tag]}): The last tag in branch '${new[branch]}'
			isn't correct.  If this is a new major release,
			perhaps you forgot to add the initial
			'${new[branch]}.${new[minor]}${new[patchsep]}${new[startpatch]}-pre1'
			tag."
fi
debug "good: Branches are the same: ${new[branch]}"

if [ "${new[minor]}" != "${last[minor]}" ] ; then
	debug "good: A new minor: ${last[minor]} -> ${new[minor]}"

	if [ "${new[release_type]}" != "rc" ] &&
		[ "${new[release_num]}" != "1" ] ; then
		bail "(${last[tag]} -> ${new[tag]}): You can't go to a new minor
			version without going to rc1."
	fi

	if [ "${new[patch]}" != "${new[startpatch]}" ] ; then
		bail "(${last[tag]} -> ${new[tag]}): This seems to be a new minor
			version but the new patch level doesn't seem to be correct.
			Should be (${new[patchsep]}${new[startpatch]})."
	fi
	if [ "${last[release_type]}" != "ga" ] ; then
		bail "(${last[tag]} -> ${new[tag]}): This seems to be a new minor
			version but the last release type can only be 'GA'
			( not 'rc' or 'pre', etc)."
		fi
	if [ "${new[release_type]}" != "rc" ] ; then
		if ! { ${NORC} || ${SECURITY} || ${HOTFIX} ; } ; then
			bail "(${last[tag]} -> ${new[tag]}): This seems to be a new minor
				version but the new release type isn't 'rc' and neither the
				'--hotfix' nor the '--security' options were specified."
		fi
	elif [ "${new[release_num]}" != "1" ] ; then 
		bail "(${last[tag]} -> ${new[tag]}): This seems to be a new minor
			version but the new release type/num isn't 'rc1'."
	fi
	print_tag "${last[tag]}"
	exit 0
fi

debug "good: Possibly rc->ga, rcn->rcn+1, patch, -pre1 -> rc1"

# At this point, major and minor are the same
# so this can only be a transition from...
#   1.  A release candidate to either another
#       release candidate or to GA.
#   2.  A patch/security release
#	3.  A -pre1 to -rc1 
 

if [ "${new[patch]}" != "${last[patch]}" ] ; then
	debug "good: New patch: ${last[patch]} -> ${new[patch]}"

	if [ "${new[patch]}" != "$(( last[patch] + 1))" ] ; then 
		bail "(${last[tag]} -> ${new[tag]}): The new patch version is
			${new[patch]} but the last patch version was ${last[patch]}.
			You can't skip or go back."
	fi

	if [ "${last[release_type]}" != "ga" ] ; then
		bail "(${last[tag]} -> ${new[tag]}): This seems to be a new patch
			version but the last release type can only be 'GA'
			( not 'rc' or 'pre', etc)."
	fi
	if [ "${new[release_type]}" != "rc" ] ; then
		if ! { ${NORC} || ${SECURITY} || ${HOTFIX} ; } ; then
			bail "(${last[tag]} -> ${new[tag]}): This seems to be a new patch
				version but the new release type isn't 'rc' and neither the
				'--hotfix' nor the '--security' options were specified."
		fi
	elif [ "${new[release_num]}" != "1" ] ; then 
		bail "(${last[tag]} -> ${new[tag]}): This seems to be a new patch
			version but the new release type/num isn't 'rc1'."
	fi
	print_tag "${last[tag]}"
	exit 0
fi

debug "good: Possibly rc->ga, rcn->rcn+1, -pre1 -> rc1"

# At this point, major, minor and patch are the same
# so we can only be...
# 1. Going from -pre1 to -rc1
# 2. Incrementing rc
# 3. Going from rc to ga.	

if [ "${last[release_type]}" == "ga" ] ; then
	bail "(${last[tag]} -> ${new[tag]}): You can't go from a GA release back to
		${last[release_type]}". 
fi

if [ "${new[release_type]}" == "rc" ] ; then
	debug "good: Possibly rcn->rcn+1, -pre1 -> rc1"
	if [ "${last[release_type]}" == "pre" ] ; then
		debug "good: -pre1 -> rc1"
		if [ "${new[release]}" != "-rc1" ] ; then 
			bail "(${last[tag]} -> ${new[tag]}): The last release type was
				'${last[release_type]}' so the new release must be '-rc1'."
		fi
		# We need to get the last branch.  In the case of certified,
		# it's brobably NOT branch_num - 1.
		last_branch=$(git -C "${SRC_REPO}" for-each-ref --sort="v:refname" --format="%(refname:lstrip=3)" refs/heads/releases/${new[certprefix]} | tail -2 | head -1)
		lastga=$(git -C "${SRC_REPO}" tag --sort="v:refname" -l "${last_branch}.[0-9]*${new[patchsep]}[0-9]" | tail -1)
		print_tag "${lastga}"
		exit 0
	fi
	debug "good: rcn->rcn+1"
	if [ "${new[release_num]}" != "$(( last[release_num] + 1))" ] ; then 
		bail "(${last[tag]} -> ${new[tag]}): The new rc version is
			${new[release_num]} but the last rc version was
			${last[release_num]}. You can't skip or go back."
	fi

	print_tag "${last[tag]}"
	exit 0
fi

# It's RC to GA
# We need to find the previous GA release tag
debug "good: rcn->ga"

lastga=$(git -C "${SRC_REPO}" tag --sort="v:refname" -l "${new[major]}.[0-9]*${new[patchsep]}[0-9]" | tail -1)
print_tag "${lastga}"
debug "Done"
exit 0
