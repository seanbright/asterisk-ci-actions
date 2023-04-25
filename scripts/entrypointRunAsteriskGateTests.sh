#!/usr/bin/bash
set -x
set -e

SCRIPT_DIR=${GITHUB_WORKSPACE}/$(basename ${GITHUB_ACTION_REPOSITORY})/scripts
ASTERISK_DIR=${GITHUB_WORKSPACE}/$(basename ${INPUT_ASTERISK_REPO})
OUTPUT_DIR=${GITHUB_WORKSPACE}/${INPUT_CACHE_DIR}/output

[ ! -d ${SCRIPT_DIR} ] && { echo "::error::SCRIPT_DIR ${SCRIPT_DIR} not found" ; exit 1 ; } 
[ ! -d ${ASTERISK_DIR} ] && { echo "::error::ASTERISK_DIR ${ASTERISK_DIR} not found" ; exit 1 ; } 
[ ! -d ${OUTPUT_DIR} ] && { echo "::error::OUTPUT_DIR ${OUTPUT_DIR} not found" ; exit 1 ; } 

TESTSUITE_DIR=${GITHUB_WORKSPACE}/$(basename ${INPUT_TESTSUITE_REPO})
mkdir -p ${TESTSUITE_DIR}
cd ${GITHUB_WORKSPACE}

git clone --depth 1 --no-tags -q -b ${INPUT_BASE_BRANCH} \
	${GITHUB_SERVER_URL}/${INPUT_TESTSUITE_REPO} ${TESTSUITE_DIR}
git config --global --add safe.directory ${TESTSUITE_DIR}

echo ${INPUT_GATETEST_COMMANDS} > /tmp/test_commands.json
TEST_NAME=$(jq -j '.'${INPUT_GATETEST_GROUP}'.name' /tmp/test_commands.json)
TEST_OPTIONS=$(jq -j '.'${INPUT_GATETEST_GROUP}'.options' /tmp/test_commands.json)
TEST_TIMEOUT=$(jq -j '.'${INPUT_GATETEST_GROUP}'.timeout' /tmp/test_commands.json)
TEST_CMD=$(jq -j '.'${INPUT_GATETEST_GROUP}'.testcmd' /tmp/test_commands.json)
TEST_DIR=$(jq -j '.'${INPUT_GATETEST_GROUP}'.dir' /tmp/test_commands.json)

if [ "${INPUT_GATETEST_GROUP}" == "all_pass" ] ; then
	cd ${TESTSUITE_DIR}
	cat >asterisk-test-suite-report.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<testsuites>
  <testsuite errors="0" tests="3" time="180.04" failures="0" name="AsteriskTestSuite" timestamp="2023-03-28T09:26:20 MDT" skipped="0">
    <testcase time="14.72" classname="channels.local" name="local_loop"/>
    <testcase time="5.96" classname="channels.local" name="local_optimize_away"/>
    <testcase time="4.77" classname="channels.local" name="local_removed_audio_stream_request"/>
  </testsuite>
</testsuites>
EOF
	cp asterisk-test-suite-report.xml logs/ || :
	echo "Exiting with RC 0 (forced)"
	echo "result=success" >> $GITHUB_OUTPUT
	exit 0
fi

if [ "${INPUT_GATETEST_GROUP}" == "pass_fail" ] ; then
	cd ${TESTSUITE_DIR}
	cat >asterisk-test-suite-report.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<testsuites>
  <testsuite errors="0" tests="3" time="180.04" failures="1" name="AsteriskTestSuite" timestamp="2023-03-28T09:26:20 MDT" skipped="0">
    <testcase time="133.07" classname="channels.iax2" name="acl_call">
      <failure>Running tests/channels/iax2/acl_call ...
[Mar 28 09:26:54] WARNING[1345365]: asterisk.test_case:547 _reactor_timeout: Reactor timeout: '30' seconds
[Mar 28 09:27:04] ERROR[1345365]: __main__:139 report_timeout: Phase 0 - Test reached timeout without achieving evaluation conditions for this phase.
[Mar 28 09:27:04] ERROR[1345365]: __main__:141 report_timeout: Phase 0 - Received the following manager events: [&lt;twisted.python.failure.Failure starpy.error.AMICommandFailure: {'response': 'Error', 'actionid': 'ernie.f5.int-140597921317840-2', 'message': 'Originate failed'}&gt;]
[Mar 28 09:27:04] ERROR[1345365]: __main__:144 report_timeout: Phase 0 - Two hangup events with cause-txt = 'Normal Clearing' were expected.
[Mar 28 09:27:04] ERROR[1345365]: __main__:146 report_timeout: Phase 0 - expected no error conditions and received originate error.
</failure>
    </testcase>
    <testcase time="5.96" classname="channels.local" name="local_optimize_away"/>
    <testcase time="4.77" classname="channels.local" name="local_removed_audio_stream_request"/>
  </testsuite>
</testsuites>
EOF
	cp asterisk-test-suite-report.xml logs/ || :
	echo "Exiting with RC 1 (forced)"
	echo "result=failure" >> $GITHUB_OUTPUT
	exit 1
fi

cd ${ASTERISK_DIR}

${SCRIPT_DIR}/installAsterisk.sh --github --uninstall-all \
  --branch-name=${INPUT_BASE_BRANCH} --user-group=asteriskci:users \
  --output-dir=${OUTPUT_DIR}


TESTRC=0
${SCRIPT_DIR}/runAsteriskGateTests.sh \
  --timeout=${TEST_TIMEOUT} \
  --testsuite-command="${TEST_OPTIONS} ${TEST_CMD}" || TESTRC=1
cp asterisk-test-suite-report.xml logs/ || :
echo "Exiting with RC $TESTRC"
exit $TESTRC
