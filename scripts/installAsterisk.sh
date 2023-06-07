#!/usr/bin/env bash

CIDIR=$(dirname $(readlink -fn $0))
GITHUB=false
UNINSTALL=false
UNINSTALL_ALL=false
OUTPUT_DIR=/tmp/asterisk_ci/

source $CIDIR/ci.functions

if [ "${OUTPUT_DIR: -1}" != "/" ] ; then
	OUTPUT_DIR+=/
fi

set -e

mkdir -p "$OUTPUT_DIR" 2> /dev/null :: :

MAKE=`which make`

if [ x"$DESTDIR" != x ] ; then
	mkdir -p "$DESTDIR" || :
fi

if [[ "$BRANCH_NAME" =~ devel(opment)?/([0-9]+)/.+ ]] ; then
	export MAINLINE_BRANCH="${BASH_REMATCH[2]}"
fi
_version=$(./build_tools/make_version .)

destdir=${DESTDIR:+DESTDIR=$DESTDIR}

declare -p _version
declare -p destdir

echo "Uninstall existing"
$UNINSTALL && ${MAKE} ${destdir} uninstall || :
$UNINSTALL_ALL && ${MAKE} ${destdir} uninstall-all || :

echo "Installing"
${MAKE} ${destdir} install || ${MAKE} ${destdir} NOISY_BUILD=yes install || exit 1
${MAKE} ${destdir} samples install-headers 
if [ x"$DESTDIR" != x ] ; then
	sed -i -r -e "s@\[directories\]\(!\)@[directories]@g" $DESTDIR/etc/asterisk/asterisk.conf
	sed -i -r -e "s@ /(var|etc|usr)/@ $DESTDIR/\1/@g" $DESTDIR/etc/asterisk/asterisk.conf
fi

if [ x"$USER_GROUP" != x ] ; then
	echo "Setting permissions"
	set +e
	chown -R $USER_GROUP $DESTDIR/var/cache/asterisk
	chown -R $USER_GROUP $DESTDIR/var/lib/asterisk
	chown -R $USER_GROUP $DESTDIR/var/spool/asterisk
	chown -R $USER_GROUP $DESTDIR/var/log/asterisk
	chown -R $USER_GROUP $DESTDIR/var/run/asterisk
	chown -R $USER_GROUP $DESTDIR/etc/asterisk
	chown -R $USER_GROUP tests/keys
	chmod go-rw tests/keys/rsa_key1.key
fi
ldconfig
