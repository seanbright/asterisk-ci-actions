
if [ "$0" == "${BASH_SOURCE[0]}" ] ; then
	echo "${BASH_SOURCE[0]} is meant to be 'sourced' not run directly" >&2
	exit 1
fi

progname=$(basename -s .sh $0)

# Scripts can use this common arg parsing like so...
# Create 3 arrays that describe the options being used:
#
# What options are required:
# declare needs=( version_type release_type branch )
# What options are wanted but not required:
# declare wants=( src_repo certified security )
# What options need to be tested if they exist:"
# declare tests=( version_type release_type branch src_repo )

# Find the script directory:
# progdir="$(dirname $(realpath $0) )"
# Source the common.sh file:
# source "${progdir}/common.sh"


# Not all the scripts use all the options
# but it'seasier to just define them all here.
[[ "$(declare -p options 2>/dev/null || : )" =~ "declare -A" ]] || declare -A options

options+=(
	[release_type]="--release-type=[ rc1 | rcn | ga | ganorc ]"
	   [start_tag]="--start-tag=<tag>"
	     [end_tag]="--end-tag=<tag>"
	    [src_repo]="--src-repo=<source repository>     # defaults to current directory"
	     [dst_dir]="--dest-dir=<destination directory> # defaults to ../staging"
	      [branch]="--branch=<branch> # Release branch"
	        [norc]="--norc            # There were no release candidates for this release"
	    [security]="--security        # This is a security release"
	 [cherry_pick]="--cherry-pick     # Cherry-pick commits for rc1 releases"
	     [alembic]="--alembic         # Create alembic sql scripts"
	   [changelog]="--changelog       # Create changelog"
	      [commit]="--commit          # Commit changelog/alembic scripts"
	         [tag]="--tag             # Tag the release"
	        [push]="--push            # Push ChangeLog commit and tag upstream"
	     [tarball]="--tarball         # Create tarball"
	   [patchfile]="--patchfile       # Create patchfile"
	        [sign]="--sign            # Sign the tarball and patchfile"
	[label_issues]="--label-issues    # Label related issues with release tag"
	   [push_live]="--push-live       # Create and publish GitHub release"
	  [full_monty]="--full-monty      # Do everything"
	        [help]="--help            # Print this help"
	     [dry_run]="--dry-run         # Don't do anything, just print commands"
	       [debug]="--debug           # Print debugging info"
)

wants+=( help debug )
needs+=( )
tests+=( )

bail() {
	# Join lines that start with whitespace.
	sed -E ':a ; $!N ; s/\n\s+/ / ; ta ; P ; D' <<<"${progname}: $@" >&2
	exit 1
}

debug() {
	# Join lines that start with whitespace.
	${DEBUG} && sed -E ':a ; $!N ; s/\n\s+/ / ; ta ; P ; D' <<<"${progname}: $@" >&2
	return 0
}

booloption() {
	declare -n option=${1^^}
	${option} && echo "--${1}"
}

print_help() {
	unset IFS
	echo "$@" >/dev/stdout
	echo "Usage: $0 " >/dev/stdout

	for x in "${needs[@]}" ; do
		echo -e "\t${options[$x]}" >/dev/stdout
	done

	for x in "${wants[@]}" ; do
		echo -e "\t[ ${options[$x]} ]" >/dev/stdout
	done

	exit 1
}

VERSION_TYPE=
RELEASE_TYPE=
START_TAG=
END_TAG=
SRC_REPO=
DST_DIR=
BRANCH=
NORC=false
SECURITY=false
CHERRY_PICK=false
ALEMBIC=false
CHANGELOG=false
COMMIT=false
TAG=false
PUSH=false
TARBALL=false
PATCHFILE=false
SIGN=false
LABEL_ISSUES=false
PUSH_LIVE=false
FULL_MONTY=false
HELP=false
DRY_RUN=false
DEBUG=false
ECHO_CMD=

declare -a args
for a in "$@" ; do
	if [[ $a =~ --no-([^=]+)$ ]] ; then
		var=${BASH_REMATCH[1]//-/_}
		eval "${var^^}"="false"
	elif [[ $a =~ --([^=]+)=(.+)$ ]] ; then
		var=${BASH_REMATCH[1]//-/_}
		eval "${var^^}"="\"${BASH_REMATCH[2]}\""
	elif [[ $a =~ --([^=]+)$ ]] ; then
		var=${BASH_REMATCH[1]//-/_}
		eval "${var^^}"="true"
		${FULL_MONTY} && {
			CHERRY_PICK=true
			ALEMBIC=true
			CHANGELOG=true
			COMMIT=true
			TAG=true
			PUSH=true
			TARBALL=true
			PATCHFILE=true
			SIGN=true
			LABEL_ISSUES=true
			PUSH_LIVE=true
		}
	else
		args+=( "$a" )
	fi
done

debug "$@"

$HELP && print_help

[ -n "${SRC_REPO}" ] && SRC_REPO=$(realpath "${SRC_REPO}")
[ -n "${DST_DIR}" ] && DST_DIR=$(realpath "${DST_DIR}")

for opt in "${needs[@]}" ; do
	declare -n var=${opt^^}
	if [ -z "${var}" ] ; then
		print_help "You must supply --${opt//_/-}"
	fi
done

for opt in "${tests[@]}" ; do
	declare -n var="${opt^^}"
	if [ -z "${var}" ] ; then
		continue
	fi
	case ${opt} in
		src_repo)
			if [ -n "$var" ] && [ ! -d "$var" ] ; then
				bail "${opt//_/-} '$var' doesn't exist"
			fi
			
			if [ -n "$var" ] && [ ! -d "$var/.git" ] ; then
				bail "${opt//_/-} '$var' isn't a git repo"
			fi
			;;
		dst_dir)
			if [ -n "$var" ] && [ ! -d "$var" ] ; then
				bail "${opt//_/-} '$var' doesn't exist"
			fi
			;;
		*_tag)
			if [ -n "$var" ] && [ -z "$(git -C ${SRC_REPO} tag -l ${var})" ] ; then
				bail "${opt//_/-} '${var}' doesn't exist"
			fi
			;;
		branch)
			if [ -n "$var" ] && [ -z "$(git -C ${SRC_REPO} branch --list ${var})" ] ; then
				bail "${opt//_/-} '${var}' doesn't exist"
			fi
			;;
		release_type)
			[ -n "$var" ] && [[ ${var} =~ (rc1|rcn|ga|ga-norc) ]] || bail "${opt//_/-} '${var}' is invalid"
			;;
		version_type)
			[ -n "$var" ] && [[ ${var} =~ (major|minor|patch) ]] || bail "${opt//_/-} '${var}' is invalid"
			;;
		*)
			bail "Option '--${opt//_/-}' doesn't have a test"
	esac
done

$DRY_RUN && ECHO_CMD="echo"

# tag_parser takes a tag and the _name_ of an existing
# associative array and parses the former into the latter
tag_parser() {
	{ [ -z "$1" ] || [ -z "$2" ] ; } && return 1 
	local tagin=$1
	local -n tagarray=$2
	tagarray[certified]=false
	
	if [[ "$tagin" =~  ^(certified/)?([0-9]+)[.]([0-9]+)(-cert|[.])([0-9]+)(-(rc|pre)([0-9]+))?$ ]]  ; then
		[ "${BASH_REMATCH[1]}" == "certified/" ] && tagarray[certified]=true
		tagarray[certprefix]=${BASH_REMATCH[1]}
		tagarray[major]=${BASH_REMATCH[2]}
		tagarray[minor]=${BASH_REMATCH[3]}
		tagarray[patchsep]=${BASH_REMATCH[4]}
		tagarray[patch]=${BASH_REMATCH[5]}
		tagarray[release]=${BASH_REMATCH[6]}
		tagarray[release_type]=${BASH_REMATCH[7]:-ga}
		tagarray[release_num]=${BASH_REMATCH[8]}
	else
		return 1
	fi
	tagarray[branch]="releases/${tagarray[certprefix]}${tagarray[major]}"
	tagarray[source_branch]="${tagarray[certprefix]}${tagarray[major]}"
	${tagarray[certified]} && tagarray[startpatch]=1 || tagarray[startpatch]=0
	tagarray[tag]=$tagin
	return 0
}
