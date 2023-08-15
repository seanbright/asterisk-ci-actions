#!/bin/bash
progname=$(realpath "$0")
progdir=$(dirname "$progname")
SRC_REPO=$1

runner() {
	start_tag=$1
	shift
	end_tags="$*"
	expected_rc=0
	declare -i rc=0
	for e in $end_tags ; do
		if [ "$e" == "success" ] ; then
			expected_rc=0
			continue
		fi
		if [ "$e" == "fail" ] ; then
			expected_rc=1
			continue
		fi
		echo "-----Testing $start_tag -> $e " 
		$progdir/get_start_tag.sh --start-tag=$start_tag --end-tag=${e%+*} \
			--src-repo=$SRC_REPO ${e#*+}
		if [ $? != $expected_rc ] ; then
			echo "********** test failed"
			rc=$(( rc + 1 ))
		else
			echo "Success"
		fi
	done
	return $rc
}

declare -i RC=0
runner 21.0.0 success 21.0.1+--security 21.1.0-rc1 fail 21.1.0-rc2 || RC=$(( RC + $? ))
runner 21.0.1 success 21.0.2+--security 21.1.0-rc1 fail 21.1.0-rc2 || RC=$(( RC + $? ))

runner 21.1.0-rc1 success 21.1.0 21.1.0-rc2 fail 21.1.0-rc3 21.2.0 21.0.0 || RC=$(( RC + $? ))
runner 21.1.0-rc2 success 21.1.0 21.1.0-rc3 fail 21.1.0-rc1 21.2.0 21.0.0 || RC=$(( RC + $? ))

runner certified/20.0-cert1 success certified/20.0-cert2+--security \
	certified/20.0-cert2-rc1 \
	fail certified/20.0-cert2 \
	certified/20.0-cert2-rc3 \
	certified/20.0-cert3 \
	certified/20.0-cert3-rc1 \
	certified/20.0-cert3+--security || RC=$(( RC + $? ))

runner certified/20.0-cert3 \
	success \
	certified/20.0-cert4-rc1 \
	certified/20.0-cert4+--security \
	certified/20.5-cert1-rc1 \
	fail \
	certified/20.5-cert1 \
	certified/20.5-cert1+--security \
	certified/20.5-cert3 || RC=$(( RC + $? ))

runner certified/20.0-cert5-rc1 \
	success \
	certified/20.0-cert5-rc2 \
	certified/20.0-cert5 \
	fail \
	certified/20.0-cert5-rc3
	certified/20.0-cert6
	certified/20.5-cert1
	certified/20.5-cert5-rc2


if [ $RC != 0 ] ; then
	echo "At least $RC test(s) failed"
	exit 1
fi
exit 0