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

node ('compile'){
    stage('Preparation') { // for display purposes
        clone2local(getGitUrl(), getGitBranchName(), './local/ci-scripts')

        // prepare variables.
        sh 'env'

        // save the properties
        sh 'echo "" > env.properties'

        // save jenkins enviroment properties.
        sh "echo BUILD_URL=\\\"${BUILD_URL}\\\" >> env.properties"

        // save jenkins parameters.
        sh "echo TREE_NAME=\\\"${TREE_NAME}\\\" >> env.properties"

        sh "echo SHELL_PLATFORM=\\\"${SHELL_PLATFORM}\\\" >> env.properties"
        sh "echo SHELL_DISTRO=\\\"${SHELL_DISTRO}\\\" >> env.properties"

        sh "echo VERSION=\\\"${VERSION}\\\" >> env.properties"

        sh "echo SUCCESS_MAIL_LIST=\\\"${SUCCESS_MAIL_LIST}\\\" >> env.properties"
        sh "echo FAILED_MAIL_LIST=\\\"${FAILED_MAIL_LIST}\\\" >> env.properties"
    }

    // load functions
    def functions = load "./local/ci-scripts/pipeline/functions.groovy"

    def build_result = 0
    stage('Build') {
        build_result = sh script: "./local/ci-scripts/build-scripts/jenkins_build_start.sh -p env.properties 2>&1 ", returnStatus: true
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

    stage('Result') {
        functions.send_mail()
    }
}
