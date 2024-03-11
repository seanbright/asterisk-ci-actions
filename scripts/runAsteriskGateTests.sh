#!/usr/bin/env bash
SCRIPT_DIR=$(dirname $(readlink -fn $0))
REALTIME=false
TEST_TIMEOUT=600
source $SCRIPT_DIR/ci.functions
ASTETCDIR="$DESTDIR/etc/asterisk"
ASTERISK="$DESTDIR/usr/sbin/asterisk"
CONFFILE="$ASTETCDIR/asterisk.conf"

[ ! -x "$ASTERISK" ] && { echo "Asterisk isn't installed." ; exit 1 ; }
[ ! -f "$CONFFILE" ] && { echo "Asterisk samples aren't installed." ; exit 1 ; }

if [ x"$WORK_DIR" != x ] ; then
	export AST_WORK_DIR="$(readlink -f $WORK_DIR)"
	mkdir -p "$AST_WORK_DIR"
fi

if [ -n "$TESTSUITE_DIR" ] ; then
	pushd $TESTSUITE_DIR
fi

./cleanup-test-remnants.sh
coreglob=$(asterisk_corefile_glob)
corefiles=$(find $(dirname $coreglob) -name $(basename $coreglob))
if [ -n "$corefiles" ] ; then
	echo "*** Found one or more core files before running tests ***"
	echo "Search glob: ${coreglob}"
	echo "Corefiles: ${corefiles}"
	if [[ "$coreglob" =~ asterisk ]] ; then
		echo "Removing matching corefiles: $corefiles"
		rm -rf $corefiles || :
	fi
fi

if $REALTIME ; then
	$SCRIPT_DIR/setupRealtime.sh --initialize-db=${INITIALIZE_DB:?0} || exit 1
fi

# check to see if venv scripts exist so we can use them
if [ -f ./setupVenv.sh ] ; then
	echo "Running in Virtual Environment"
	# explicitly invoking setupVenv to capture output in case of failure
	./setupVenv.sh &>/tmp/setupVenv.out || { cat /tmp/setupVenv.out ; exit 1 ; }
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
	for f in $failures ; do
		[ $f -gt 0 ] && TESTRC=1
	done
fi

if $REALTIME ; then
	$SCRIPT_DIR/teardownRealtime.sh --cleanup-db=${CLEANUP_DB:?0}
fi

coreglob=$(asterisk_corefile_glob)
corefiles=$(find $(dirname $coreglob) -name $(basename $coreglob))
if [ -n "$corefiles" ] ; then
	echo "*** Found one or more core files after running tests ***"
	echo "Search glob: ${coreglob}"
	echo "Matching corefiles: ${corefiles}"
	TESTRC=1
	$SCRIPT_DIR/ast_coredumper.sh --no-conf-file --outputdir=./logs/ \
		--tarball-coredumps --delete-coredumps-after $coreglob
	# If the return code was 2, none of the coredumps actually came from asterisk.
	[ $? -eq 2 ] && TESTRC=0
fi

if [ -n "$TESTSUITE_DIR" ] ; then
	popd
fi
exit $TESTRC
