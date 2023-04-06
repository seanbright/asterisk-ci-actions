#!/usr/bin/env bash
#
# Publish Asterisk documentation to the wiki
#
CIDIR=$(dirname $(readlink -fn $0))
source $CIDIR/ci.functions
ASTETCDIR=$DESTDIR/etc/asterisk

ASTERISK="$DESTDIR/usr/sbin/asterisk"
CONFFILE=$ASTETCDIR/asterisk.conf

if [ -z "${PUBLISH_DIR}" ] ; then
	echo "--publish-dir must be specified"
	exit 1
fi

if [ -z "${OUTPUT_DIR}" ] ; then
	echo "--output-dir must be specified"
	exit 1
fi

rm -rf $ASTETCDIR/extensions.{ael,lua} || :

: ${AWK:=awk}
: ${GREP:=grep}
: ${MAKE:=make}
: ${GIT:=git}

function fail()
{
    echo "${PROGNAME}: " "$@" >&2
    exit 1
}

function usage()
{
    echo "usage: ${PROGNAME} --branch-name=<branch> [ --user-group=<user>:<group> ] [ --output-dir=<output_dir> ]"
}

#
# Check settings from config file
#
if ! test ${INPUT_CONFLUENCE_URL}; then
    fail "INPUT_CONFLUENCE_URL not set"
fi

if ! test ${INPUT_CONFLUENCE_USERPASS}; then
    fail "INPUT_CONFLUENCE_USERPASS not set"
fi

if ! test ${CONFLUENCE_SPACE}; then
    fail "INPUT_CONFLUENCE_SPACE not set"
fi

#
# Check repository
#
if ! test -f main/asterisk.c; then
    fail "Must run from an Asterisk checkout"
fi

#
# Check current working copy
#
CHANGES=$(${GIT} status | grep 'modified:' | wc -l)
if test ${CHANGES} -ne 0; then
    fail "Asterisk checkout must be clean"
fi

# Verbose, and exit on any command failure
set -ex

AST_VER=$(export GREP; export AWK; ./build_tools/make_version .)

# Generate latest ARI documentation
make ari-stubs

# Ensure docs are consistent with the implementation
CHANGES=$(${GIT} status | grep 'modified:' | wc -l)
if test ${CHANGES} -ne 0; then
    fail "Asterisk code out of date compared to the model"
fi

# make ari-stubs may modify the $Revision$ tags in a file; revert the
# changes
${GIT} reset --hard

#
# Don't publish docs for non-main-release branches. We still want the above
# validation to ensure that REST API docs are kept up to date though.
#
if [ -n "$WIKI_DOC_BRANCH_REGEX" ] ; then
	if [[ ! ${BRANCH_NAME} =~ $WIKI_DOC_BRANCH_REGEX ]] ; then
    	exit 0;
	fi
fi

#
# Publish the REST API.
#
# needed by publishing scripts. pass via the environment so it doesn't show
# up in the logs.
export CONFLUENCE_PASSWORD=${INPUT_CONFLUENCE_USERPASS##*:}

python2 ${PUBLISH_DIR}/publish-rest-api.py --username="${INPUT_CONFLUENCE_USERPASS%%:*}" \
        --verbose \
        --ast-version="${AST_VER}" \
        ${CONFLUENCE_URL} \
        ${CONFLUENCE_SPACE} \
        "Asterisk ${BRANCH_NAME}"

rm -f ${OUTPUT_DIR}/full-en_US.xml

sudo $ASTERISK ${USER_GROUP:+-U ${USER_GROUP%%:*} -G ${USER_GROUP##*:}} -gn -C $CONFFILE
for n in {1..5} ; do
	sleep 3
	$ASTERISK -rx "core waitfullybooted" -C $CONFFILE && break
done
sleep 1
$ASTERISK -rx "xmldoc dump ${OUTPUT_DIR}/asterisk-docs.xml" -C $CONFFILE
$ASTERISK -rx "core stop now" -C $CONFFILE

#
# Set the prefix argument for publishing docs
#
PREFIX="Asterisk ${BRANCH_NAME}"

#
# Publish XML documentation.
#

# Script assumes that it's running from TOPDIR
pushd ${PUBLISH_DIR}

python2 ./astxml2wiki.py --username="${CONFLUENCE_USER}" \
    --server=${CONFLUENCE_URL} \
    --prefix="${PREFIX}" \
    --space="${CONFLUENCE_SPACE}" \
    --file=${OUTPUT_DIR}/asterisk-docs.xml \
    --ast-version="${AST_VER}" \
    -v

popd
