#!/bin/bash -ex

MIRROR_ROOT=/root/github_mirror
mkdir -p ${MIRROR_ROOT}

cd ${MIRROR_ROOT}

if [[ ! "${TEST_REPO}" =~ .git$ ]];then
    TEST_REPO=${TEST_REPO}".git"
fi

DIR_NAME=${TEST_REPO##*/}
touch ~/.gitconfig

mv -f ~/.gitconfig ~/.gitconfig.edit
if [ -d "${DIR_NAME}" ];then
    rm -rf ${DIR_NAME}
fi

git clone ${TEST_REPO} --mirror
echo "[url \"${MIRROR_ROOT}/${DIR_NAME}\"]" >> ~/.gitconfig.edit
echo "    insteadOf = ${TEST_REPO}" >> ~/.gitconfig.edit

mv -f ~/.gitconfig.edit ~/.gitconfig

# overwrite system gitconfig
cp -f ~/.gitconfig /etc/gitconfig
