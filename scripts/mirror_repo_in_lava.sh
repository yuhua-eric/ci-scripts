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

# remove old gitconfig
rm -rf /etc/gitconfig

# save last gitconfig
mv -f ~/.gitconfig ~/.gitconfig.edit

cd ${SUBDIR}
if [ -d "${DIR_NAME}" ];then
    git fetch --all
else
    git clone ${TEST_REPO} --mirror
    echo "[url \"${MIRROR_ROOT}/${SUBDIR}/${DIR_NAME}\"]" >> ~/.gitconfig.edit
    echo "    insteadOf = ${TEST_REPO}" >> ~/.gitconfig.edit
fi

mv -f ~/.gitconfig.edit ~/.gitconfig

# overwrite system gitconfig
cp -f ~/.gitconfig /etc/gitconfig
