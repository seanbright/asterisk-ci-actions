#!/bin/bash

declare needs=( tag )

progdir="$(dirname $(realpath $0) )"
source "${progdir}/common.sh"

declare -A tag
tag_parser ${TAG} tag || bail "Unable to parse end tag '${TAG}'"
declare -p tag

