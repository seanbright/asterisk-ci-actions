#!/usr/bin/bash
set -x
set -e

SCRIPT_DIR=${GITHUB_WORKSPACE}/$(basename ${GITHUB_ACTION_REPOSITORY})/scripts
ASTERISK_DIR=${GITHUB_WORKSPACE}/asterisk
OUTPUT_DIR=${GITHUB_WORKSPACE}/cache/output

[ ! -d ${SCRIPT_DIR} ] && { echo "::error::SCRIPT_DIR ${SCRIPT_DIR} not found" ; exit 1 ; } 
[ ! -d ${ASTERISK_DIR} ] && { echo "::error::ASTERISK_DIR ${ASTERISK_DIR} not found" ; exit 1 ; } 
[ ! -d ${OUTPUT_DIR} ] && { echo "::error::OUTPUT_DIR ${OUTPUT_DIR} not found" ; exit 1 ; } 

PUBLISH_DIR=${GITHUB_WORKSPACE}/publish-docs

cd ${ASTERISK_DIR}

${SCRIPT_DIR}/installAsterisk.sh --github --uninstall-all \
  --branch-name=${INPUT_BASE_BRANCH} --user-group=asteriskci:users \
  --output-dir=${OUTPUT_DIR}

cd ${GITHUB_WORKSPACE}

mkdir -p ${PUBLISH_DIR}
git clone --depth 1 --no-tags -q -b ${INPUT_PUBLISH_DOCS_BRANCH} \
	${GITHUB_SERVER_URL}/${INPUT_PUBLISH_DOCS_REPO} ${PUBLISH_DIR}
git config --global --add safe.directory ${TESTSUITE_DIR}

cd ${ASTERISK_DIR}

export INPUT_CONFLUENCE_URL
export INPUT_CONFLUENCE_USERPASS
export INPUT_CONFLUENCE_SPACE

${SCRIPT_DIR}/publishAsteriskDocs.sh --user-group=asteriskci:users \
	--publish-dir=${PUBLISH_DIR} \
	--output-dir=${OUTPUT_DIR} \
	--branch-name=${INPUT_BASE_BRANCH} \
	--wiki-doc-branch-regex="${INPUT_BRANCH_REGEX}"
