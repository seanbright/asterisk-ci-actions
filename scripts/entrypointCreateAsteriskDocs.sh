#!/usr/bin/bash
set -x
set -e

export GITHUB_TOKEN=${INPUT_GITHUB_TOKEN}
export GH_TOKEN=${INPUT_GITHUB_TOKEN}

SCRIPT_DIR=${GITHUB_WORKSPACE}/$(basename ${GITHUB_ACTION_REPOSITORY})/scripts
ASTERISK_DIR=${GITHUB_WORKSPACE}/asterisk
OUTPUT_DIR=${GITHUB_WORKSPACE}/cache/output
DOCS_DIR=${GITHUB_WORKSPACE}/${INPUT_DOCS_DIR}
CONFFILE=/etc/asterisk/asterisk.conf

[ ! -d ${SCRIPT_DIR} ] && { echo "::error::SCRIPT_DIR ${SCRIPT_DIR} not found" ; exit 1 ; } 
[ ! -d ${ASTERISK_DIR} ] && { echo "::error::ASTERISK_DIR ${ASTERISK_DIR} not found" ; exit 1 ; } 
[ ! -d ${OUTPUT_DIR} ] && { echo "::error::OUTPUT_DIR ${OUTPUT_DIR} not found" ; exit 1 ; } 
mkdir -p ${DOCS_DIR}

cd ${ASTERISK_DIR}

${SCRIPT_DIR}/installAsterisk.sh --github --uninstall-all \
  --branch-name=${INPUT_BASE_BRANCH} --output-dir=${OUTPUT_DIR}
  
ASTERISK=/usr/sbin/asterisk

python rest-api-templates/make_ari_stubs.py \
	--resources rest-api/resources.json --source-dir . \
	--dest-dir ${DOCS_DIR} --docs-prefix ../


$ASTERISK -gn -C $CONFFILE
for n in {1..5} ; do
	sleep 3
	$ASTERISK -rx "core waitfullybooted" -C $CONFFILE && break
done
sleep 1
$ASTERISK -rx "xmldoc dump ${DOCS_DIR}/asterisk-docs.xml" -C $CONFFILE
$ASTERISK -rx "core stop now" -C $CONFFILE
killall -KILL asterisk || :

exit 0
