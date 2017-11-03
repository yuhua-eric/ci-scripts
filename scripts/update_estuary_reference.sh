#!/bin/bash -ex
trap "exit 1" SIGINT SIGTERM

# set default workspace , if don't run in jenkins
WORKSPACE=${WORKSPACE:-$(pwd)}
REFERENCE_PATH=${REFERENCE_PATH:-~/estuary_reference}

cd ${WORKSPACE}
###################### prepare repo tool ######################
mkdir -p bin;
curl https://mirrors.tuna.tsinghua.edu.cn/git/git-repo -o bin/repo || true
chmod a+x bin/repo || true

export REPO_URL='https://mirrors.tuna.tsinghua.edu.cn/git/git-repo/'
export PATH=${WORKSPACE}/bin:$PATH;

# sync
mkdir -p ${REFERENCE_PATH}
cd ${REFERENCE_PATH}

if [ ! -d '.repo' ];then
    repo init -u "https://github.com/open-estuary/estuary.git" --mirror --no-repo-verify --repo-url=git://android.git.linaro.org/tools/repo
fi

set +e
false; while [ $? -ne 0 ]; do repo sync; done
set -e
repo list
