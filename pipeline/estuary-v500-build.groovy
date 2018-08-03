def clone2local(giturl, branchname, localdir) {
    def exists = fileExists localdir
    if (!exists){
        new File(localdir).mkdir()
    }
    dir (localdir) {
        checkout([$class: 'GitSCM', branches: [[name: branchname]],
                extensions: [[$class: 'CloneOption', timeout: 120]], gitTool: 'Default',
                userRemoteConfigs: [[url: giturl]]
            ])
    }
}

def getGitBranchName() {
    return scm.branches[0].name
}

def getGitUrl() {
    return scm.getUserRemoteConfigs()[0].getUrl()
}

node ('ci-v500-compile'){
    stage('Preparation') { // for display purposes
        clone2local(getGitUrl(), getGitBranchName(), './local/ci-scripts')

        // prepare variables.
        sh 'env'

        // save the properties
        sh 'echo "" > env.properties'

        // save jenkins enviroment properties.
        sh "echo BUILD_URL=\\\"${BUILD_URL}\\\" >> env.properties"

        // save jenkins parameters.
        if (env.TREE_NAME) {
            sh "echo TREE_NAME=\\\"${TREE_NAME}\\\" >> env.properties"
        }

        if (env.SHELL_PLATFORM) {
            sh "echo SHELL_PLATFORM=\\\"${SHELL_PLATFORM}\\\" >> env.properties"
        }
        if (env.SHELL_DISTRO) {
            sh "echo SHELL_DISTRO=\\\"${SHELL_DISTRO}\\\" >> env.properties"
        }

		if (env.SOURCE_CODE) {
            sh "echo SOURCE_CODE=\\\"${SOURCE_CODE}\\\" >> env.properties"
        }
		
		if (env.BRANCH) {
            sh "echo BRANCH=\\\"${BRANCH}\\\" >> env.properties"
        }
		
        if (env.VERSION) {
            sh "echo VERSION=\\\"${VERSION}\\\" >> env.properties"
        }
        if (env.SAVE_ISO) {
            sh "echo SAVE_ISO=\\\"${SAVE_ISO}\\\" >> env.properties"
        }

        if (env.DEBUG) {
            sh "echo DEBUG=\\\"${DEBUG}\\\" >> env.properties"
        }
    }

    // load functions
    def functions = load "./local/ci-scripts/pipeline/functions.groovy"


    def build_result = 0
    stage('Build') {
        // build_result = sh script: "./local/ci-scripts/build-scripts/estuary_build_v500_start.sh -p env.properties 2>&1 ", returnStatus: true
		// modify by liucaili for developer testing build by themselves
		build_result = sh script: "./local/ci-scripts/build-scripts/jenkins_build_v500_start.sh -p env.properties 2>&1 ", returnStatus: true
    }
    echo "build_result : ${build_result}"
    if (build_result == 0) {
        echo "build success"
    } else {
        echo "build failed"
        functions.send_mail()
        currentBuild.result = 'FAILURE'
        return
    }


    def iso_result = 0
    dir('./local/ci-scripts/build-iso-scripts') {
        iso_result = sh script: "./buildiso_v500.sh -p env.properties 2>&1 ", returnStatus: true
    }
    echo "iso_result : ${iso_result}"
    if (iso_result == 0) {
        echo "iso success"
    } else {
        echo "iso failed"
        functions.send_mail()
        currentBuild.result = 'FAILURE'
        return
    }


    stage('stash') {
        // stash result
        dir('/home/fileserver/open-estuary') {
            stash includes: '**/*', name: 'buildResult'
        }

        stash includes: '*.txt', name: 'mailResult'
        stash includes: '*.properties', name: 'paramsResult'

    }
}

node('ci-compile') {
    stage('Unstash Build Result') {
        unstash 'mailResult'
        unstash 'paramsResult'
    }

    def props = readProperties  file: 'env.properties'
    def GIT_DESCRIBE = props['GIT_DESCRIBE']

    clone2local(getGitUrl(), getGitBranchName(), './local/ci-scripts')
    // load functions
    def functions = load "./local/ci-scripts/pipeline/functions.groovy"

    stage('upload') {
        // unstash result
        dir('/fileserver/open-estuary'){
            unstash 'buildResult'

            // TODO : if git_describe exist, clean fileserver pxe_install iso_install
        }
    }
    stage('Result') {
        unstash 'mailResult'
        functions.send_mail()
    }
}
