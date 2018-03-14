#!/bin/bash -ex

MIRROR_ROOT=/root/github_mirror
mkdir -p ${MIRROR_ROOT}

cd ${MIRROR_ROOT}

# get sub dir from url
temp=${TEST_REPO:8}
temp=${temp%/*}
temp=${temp#*/}
SUBDIR=${temp}

if [[ ! "${TEST_REPO}" =~ .git$ ]];then
    TEST_REPO=${TEST_REPO}".git"
fi

DIR_NAME=${TEST_REPO##*/}
touch ~/.gitconfig

mkdir -p ${SUBDIR}
cd ${SUBDIR}
if [ -d "${DIR_NAME}" ];then
    cd ${DIR_NAME}
    HOME=/dev/null GIT_CONFIG_NOSYSTEM=1 git fetch --all
else
    HOME=/dev/null GIT_CONFIG_NOSYSTEM=1 git clone ${TEST_REPO} --mirror
    echo "[url \"${MIRROR_ROOT}/${SUBDIR}/${DIR_NAME}\"]" >> ~/.gitconfig
    echo "    insteadOf = ${TEST_REPO}" >> ~/.gitconfig
fi

# overwrite system gitconfig
cp -f ~/.gitconfig /etc/gitconfig
