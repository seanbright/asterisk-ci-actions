#!/usr/bin/bash
#set -x
set -e

export GITHUB_TOKEN=${INPUT_GITHUB_TOKEN}
export GH_TOKEN=${INPUT_GITHUB_TOKEN}

echo "ACTION_PATH: ${GITHUB_ACTION_PATH}"
[ -n "${GITHUB_ACTION_PATH}" ] && [ -d "${GITHUB_ACTION_PATH}" ] && ls -al ${GITHUB_ACTION_PATH}

SCRIPT_DIR=${GITHUB_WORKSPACE}/$(basename ${GITHUB_ACTION_REPOSITORY})/scripts/Releaser
REPO_DIR=${GITHUB_WORKSPACE}/$(basename ${INPUT_REPO})
STAGING_DIR=${GITHUB_WORKSPACE}/${INPUT_PRODUCT}-${INPUT_NEW_VERSION}

source ${SCRIPT_DIR}/common.sh
export PRODUCT=${INPUT_PRODUCT}

END_TAG="${INPUT_NEW_VERSION}"
START_TAG="${INPUT_START_VERSION}"
SECURITY=${INPUT_IS_SECURITY}
HOTFIX=${INPUT_IS_HOTFIX}
FORCE_CHERRY_PICK=${INPUT_FORCE_CHERRY_PICK}
PUSH_BRANCHES=${INPUT_PUSH_RELEASE_BRANCHES}
PUSH_TARBALLS=${INPUT_PUSH_TARBALLS}
ADVISORIES="${INPUT_ADVISORIES}"
ADV_URL_BASE=${INPUT_SEC_ADV_URL_BASE}
export DEPLOY_SSH_USERNAME=${INPUT_DEPLOY_SSH_USERNAME}
export DEPLOY_HOST=${INPUT_DEPLOY_HOST}
export DEPLOY_DIR=${INPUT_DEPLOY_DIR}

declare -A end_tag_array
tag_parser ${END_TAG} end_tag_array || bail "Unable to parse end tag '${END_TAG}'"

echo "Validating tags"
${SCRIPT_DIR}/version_validator.sh \
	--product=${PRODUCT} \
	$(booloption security) $(booloption hotfix) \
	$(stringoption start-tag) --end-tag=${END_TAG}

echo "Tags valid: ${START_TAG} -> ${END_TAG} Release Type: ${end_tag_array[release_type]}"

if [ -n "${ADVISORIES}" ] ; then
	IFS=$','
	echo "Checking security advisories"
	declare -i failed=0
	for a in ${ADVISORIES} ; do
		summary=$(gh api /repos/${INPUT_REPO}/security-advisories/$a --jq '.summary' 2>/dev/null || echo "FAILED")
		if [[ "$summary" =~ FAILED$ ]] ; then
			echo "Security advisory $a not found. Bad ID or maybe not published yet."
			failed=1
		else
			echo "Security advisory $a found."
		fi
	done
	[ $failed -gt 0 ] && { echo "One or more security advisories were not found" ; exit 1 ; }
	unset IFS
fi

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

if ${end_tag_array[certified]} && [ "${end_tag_array[release_type]}" == "ga" ] ; then
	NORC=true
	FORCE_CHERRY_PICK=true
fi

START_TAG=$(${SCRIPT_DIR}/get_start_tag.sh --src-repo=${REPO_DIR} \
	--product=${PRODUCT} --debug \
	$(booloption security) $(booloption hotfix) $(booloption norc) \
	$(stringoption start-tag) --end-tag=${END_TAG})

declare -A start_tag_array
tag_parser ${START_TAG} start_tag_array || bail "Unable to parse start tag '${START_TAG}'"

echo "Tags valid: ${START_TAG} Release Type: ${start_tag_array[release_type]} -> ${END_TAG} Release Type: ${end_tag_array[release_type]}"

gh auth setup-git -h github.com

echo $"${INPUT_GPG_PRIVATE_KEY}" > gpg.key
gpg --import gpg.key
rm gpg.key

eval $(ssh-agent -s)
echo $"${INPUT_DEPLOY_SSH_PRIV_KEY}" | ssh-add -

echo "Running create_release_artifacts.sh"
${SCRIPT_DIR}/create_release_artifacts.sh \
	--src-repo=${REPO_DIR} --dst-dir=${STAGING_DIR} \
	--gh-repo=${INPUT_REPO} --debug \
	$(booloption security) $(booloption hotfix) $(booloption norc) \
	$(stringoption advisories) $(stringoption adv-url-base) \
	$(booloption force-cherry-pick) \
	--product=${PRODUCT} \
	--start-tag=${START_TAG} --end-tag=${END_TAG} \
	--cherry-pick \
	$([ "${PRODUCT}" == "asterisk" ] && echo "--alembic" || echo "") \
	--changelog --commit --tag \
	--sign --tarball --patchfile $(booloption push-branches)

if ${INPUT_CREATE_GITHUB_RELEASE} ; then
	${SCRIPT_DIR}/push_live.sh \
		--product=${PRODUCT} \
		--src-repo=${REPO_DIR} --dst-dir=${STAGING_DIR} --debug \
		--start-tag=${START_TAG} --end-tag=${END_TAG} \
		$(booloption push-tarballs)
fi

eval $(ssh-agent -k)

echo "email_announcement=${PRODUCT}-${END_TAG}/email_announcement.md" >> ${GITHUB_OUTPUT}

# Determine the correct email list to send the announcement
# to (if any).
if ! ${INPUT_SEND_EMAIL} ; then
	echo "subject=none" >> ${GITHUB_OUTPUT}
	echo "mail_list=none" >> ${GITHUB_OUTPUT}
	exit 0
fi

echo "release_type=${end_tag_array[release_type]}" >> ${GITHUB_OUTPUT}

if ${INPUT_IS_SECURITY} ; then
	if ${end_tag_array[certified]} ; then
		echo "subject=Certified ${PRODUCT^} Security Release ${END_TAG}" >> ${GITHUB_OUTPUT}
	else
		echo "subject=${PRODUCT^} Security Release ${END_TAG}" >> ${GITHUB_OUTPUT}
	fi
	echo "mail_list=${INPUT_MAIL_LIST_SEC}" >> ${GITHUB_OUTPUT}
elif [ "${end_tag_array[release_type]}" == "rc" ] ; then
	if ${end_tag_array[certified]} ; then
		echo "subject=Certified ${PRODUCT^} Release Canditate ${END_TAG}" >> ${GITHUB_OUTPUT}
		echo "mail_list=${INPUT_MAIL_LIST_CERT_RC}" >> ${GITHUB_OUTPUT}
	else
		echo "subject=${PRODUCT^} Release Canditate ${END_TAG}" >> ${GITHUB_OUTPUT}
		echo "mail_list=${INPUT_MAIL_LIST_RC}" >> ${GITHUB_OUTPUT}
	fi
elif [ "${end_tag_array[release_type]}" == "ga" ] ; then
	if ${end_tag_array[certified]} ; then
		echo "subject=Certified ${PRODUCT^} Release ${END_TAG}" >> ${GITHUB_OUTPUT}
		echo "mail_list=${INPUT_MAIL_LIST_CERT_GA}" >> ${GITHUB_OUTPUT}
	else
		echo "subject=${PRODUCT^} Release ${END_TAG}" >> ${GITHUB_OUTPUT}
		echo "mail_list=${INPUT_MAIL_LIST_GA}" >> ${GITHUB_OUTPUT}
	fi
else
	echo "subject=none" >> ${GITHUB_OUTPUT}
	echo "mail_list=none" >> ${GITHUB_OUTPUT}
fi

