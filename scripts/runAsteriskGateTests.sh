#!/usr/bin/env bash
CIDIR=$(dirname $(readlink -fn $0))
REALTIME=false
TEST_TIMEOUT=600
source $CIDIR/ci.functions
ASTETCDIR=$DESTDIR/etc/asterisk

if [ x"$WORK_DIR" != x ] ; then
	export AST_WORK_DIR="$(readlink -f $WORK_DIR)"
	mkdir -p "$AST_WORK_DIR"
fi

if [ -n "$TESTSUITE_DIR" ] ; then
	pushd $TESTSUITE_DIR
fi
./cleanup-test-remnants.sh
[ -f /tmp/core* ] && rm -rf /tmp/core*

if $REALTIME ; then
	$CIDIR/setupRealtime.sh --initialize-db=${INITIALIZE_DB:?0}
fi

# check to see if venv scripts exist so we can use them
if [ -f ./setupVenv.sh ] ; then
	echo "Running in Virtual Environment"
	# explicitly invoking setupVenv to capture output in case of failure
	./setupVenv.sh >/dev/null
	VENVPREFIX="runInVenv.sh python "
else
	echo "Running in Legacy Mode"
	export PYTHONPATH=./lib/python/
fi

TESTRC=0
echo "Running tests ${TESTSUITE_COMMAND} ${AST_WORK_DIR:+with work directory ${AST_WORK_DIR}}"
./${VENVPREFIX}runtests.py --cleanup --timeout=${TEST_TIMEOUT} \
	${TESTSUITE_COMMAND} \
	| contrib/scripts/pretty_print --no-color --no-timer \
		--term-width=100 --show-errors || :
	
if [ ! -f ./asterisk-test-suite-report.xml ] ; then
	echo "./asterisk-test-suite-report.xml not found"
	TESTRC=1
else
	cp asterisk-test-suite-report.xml logs/ || :
	failures=$(xmlstarlet sel -t -v "//testsuite/@failures" ./asterisk-test-suite-report.xml)
	[ $failures -gt 0 ] && TESTRC=1
fi

if $REALTIME ; then
	$CIDIR/teardownRealtime.sh --cleanup-db=${CLEANUP_DB:?0}
fi

if [ -f /tmp/core* ] ; then
	echo "*** Found a core file after running unit tests ***"
	/var/lib/asterisk/scripts/ast_coredumper --tarball-coredumps /tmp/core*
	cp /tmp/core*.tar.gz ./logs/
	TESTRC=1
fi

if [ -n "$TESTSUITE_DIR" ] ; then
	popd
fi
exit $TESTRC
