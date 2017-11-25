#!/bin/bash -ex

MIRROR_ROOT=/root/github_mirror
mkdir -p ${MIRROR_ROOT}

cd ${MIRROR_ROOT}

if [[ ! "${TEST_REPO}" =~ .git ]];then
    TEST_REPO=${TEST_REPO}".git"
fi

dir_NAME=${TEST_REPO##*/}
touch ~/.gitconfig

mv -f ~/.gitconfig ~/.gitconfig.edit
if [ -d "${DIR_NAME}" ];then
    cd ${DIR_NAME}
    git fetch
    cd -
else
    git clone ${TEST_REPO} --mirror
    echo "[url \"${MIRROR_ROOT}/${DIR_NAME}\"]" >> ~/.gitconfig.edit
    echo "    insteadOf = ${TEST_REPO}" >> ~/.gitconfig.edit
fi
mv ~/.gitconfig.edit ~/.gitconfig
