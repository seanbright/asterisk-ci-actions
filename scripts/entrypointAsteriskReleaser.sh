#!/usr/bin/bash
#set -x
set -e

export GITHUB_TOKEN=${INPUT_GITHUB_TOKEN}
export GH_TOKEN=${INPUT_GITHUB_TOKEN}

echo "ACTION_PATH: ${GITHUB_ACTION_PATH}"
[ -n "${GITHUB_ACTION_PATH}" ] && [ -d "${GITHUB_ACTION_PATH}" ] && ls -al ${GITHUB_ACTION_PATH}

SCRIPT_DIR=${GITHUB_WORKSPACE}/$(basename ${GITHUB_ACTION_REPOSITORY})/scripts/AsteriskReleaser
REPO_DIR=${GITHUB_WORKSPACE}/$(basename ${INPUT_REPO})
STAGING_DIR=${GITHUB_WORKSPACE}/asterisk-${INPUT_NEW_VERSION}

source ${SCRIPT_DIR}/common.sh

end_tag="${INPUT_NEW_VERSION}"
declare -A end_tag_array
tag_parser ${INPUT_NEW_VERSION} end_tag_array || bail "Unable to parse end tag '${END_TAG}'"
start_tag="${INPUT_START_VERSION}"

echo "Validating tags"
${SCRIPT_DIR}/version_validator.sh \
	$( ${INPUT_IS_SECURITY} && echo "--security") \
	${start_tag:+--start-tag=${start_tag}} --end-tag=${INPUT_NEW_VERSION}

echo "Tags valid: ${start_tag} -> ${end_tag} Release Type: ${end_tag_array[release_type]}"
cd ${GITHUB_WORKSPACE}
mkdir -p ${REPO_DIR}
mkdir -p ${STAGING_DIR}

git clone ${GITHUB_SERVER_URL}/${INPUT_REPO} ${REPO_DIR}
git config --global --add safe.directory $(realpath ${REPO_DIR})

git -C ${REPO_DIR} checkout ${end_tag_array[source_branch]} >/dev/null 2>&1
git -C ${REPO_DIR} pull >/dev/null 2>&1 
git -C ${REPO_DIR} checkout ${end_tag_array[branch]} >/dev/null 2>&1
git -C ${REPO_DIR} pull >/dev/null 2>&1

git config --global user.email "asteriskteam@digium.com"
git config --global user.name "Asterisk Development Team"

start_tag=$(${SCRIPT_DIR}/get_start_tag.sh --src-repo=${REPO_DIR} \
$( $INPUT_IS_SECURITY && echo "--security") \
${start_tag:+--start-tag=${start_tag}} --end-tag=${end_tag})

declare -A start_tag_array
tag_parser ${start_tag} start_tag_array || bail "Unable to parse start tag '${start_tag}'"

echo "Tags valid: ${start_tag} Release Type: ${start_tag_array[release_type]} -> ${end_tag} Release Type: ${end_tag_array[release_type]}"

gh auth setup-git -h github.com

set +x
echo $"${INPUT_GPG_PRIVATE_KEY}" > gpg.key
#set -x
gpg --import gpg.key
rm gpg.key

echo "Running create_release_artifacts.sh"
${SCRIPT_DIR}/create_release_artifacts.sh \
	--src-repo=${REPO_DIR} --dst-dir=${STAGING_DIR} --debug \
	$(${INPUT_IS_SECURITY} && echo "--security") \
	--start-tag=${start_tag} --end-tag=${end_tag} \
	--cherry-pick --alembic --changelog --commit --tag \
	--sign --tarball --patchfile \
	$(${INPUT_PUSH_LIVE} && echo " --push")

if ${INPUT_PUSH_LIVE} ; then
	${SCRIPT_DIR}/push_live.sh \
		--src-repo=${REPO_DIR} --dst-dir=${STAGING_DIR} --debug \
		--start-tag=${start_tag} --end-tag=${end_tag}
fi

echo "email_announcement=asterisk-${end_tag}/email_announcement.md" >> ${GITHUB_OUTPUT}

# Determine the correct email list to send the announcement
# to (if any).
if ! ${INPUT_SEND_EMAIL} ; then
	echo "mail_list=none" >> ${GITHUB_OUTPUT}
	exit 0
fi
	
if ${INPUT_IS_SECURITY} ; then
	echo "mail_list=${INPUT_ASTERISK_MAIL_LIST_SEC}" >> ${GITHUB_OUTPUT}
elif [ "${end_tag_array[release_type]}" == "rc" ] ; then
	if ${end_tag_array[certified]} ; then
		echo "mail_list=${INPUT_ASTERISK_MAIL_LIST_CERT_RC}" >> ${GITHUB_OUTPUT}
	else
		echo "mail_list=${INPUT_ASTERISK_MAIL_LIST_RC}" >> ${GITHUB_OUTPUT}
	fi
elif [ "${end_tag_array[release_type]}" == "ga" ] ; then
	if ${end_tag_array[certified]} ; then
		echo "mail_list=${INPUT_ASTERISK_MAIL_LIST_CERT_GA}" >> ${GITHUB_OUTPUT}
	else
		echo "mail_list=${INPUT_ASTERISK_MAIL_LIST_GA}" >> ${GITHUB_OUTPUT}
	fi
else
	echo "mail_list=none" >> ${GITHUB_OUTPUT}
fi

