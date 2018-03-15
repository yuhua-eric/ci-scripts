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
    stage('Build Preparation') { // for display purposes
        clone2local(getGitUrl(), getGitBranchName(), './local/ci-scripts')

        // prepare variables.
        sh 'env'

        // save the properties
        sh 'echo "" > env.properties'

        // save jenkins enviroment properties.
        sh "echo BUILD_URL=\\\"${BUILD_URL}\\\" >> env.properties"

        // save jenkins parameters.
        sh "echo TREE_NAME=\\\"${TREE_NAME}\\\" >> env.properties"
        sh "echo BOOT_PLAN=\\\"${BOOT_PLAN}\\\" >> env.properties"

        sh "echo SHELL_PLATFORM=\\\"${SHELL_PLATFORM}\\\" >> env.properties"
        sh "echo SHELL_DISTRO=\\\"${SHELL_DISTRO}\\\" >> env.properties"

        sh "echo TEST_REPO=\\\"${TEST_REPO}\\\" >> env.properties"
        sh "echo TEST_PLAN=\\\"${TEST_PLAN}\\\" >> env.properties"
        sh "echo TEST_SCOPE=\\\"${TEST_SCOPE}\\\" >> env.properties"
        sh "echo TEST_LEVEL=\\\"${TEST_LEVEL}\\\" >> env.properties"

        sh "echo SUCCESS_MAIL_LIST=\\\"${SUCCESS_MAIL_LIST}\\\" >> env.properties"
        sh "echo FAILED_MAIL_LIST=\\\"${FAILED_MAIL_LIST}\\\" >> env.properties"
    }
    // load functions
    def functions = load "./local/ci-scripts/pipeline/functions.groovy"

    def build_result = 0
    stage('Build') {
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
    stage('Build Auto ISO') {
        dir('./local/ci-scripts/build-iso-scripts') {
            iso_result = sh script: "./buildiso.sh 2>&1 ", returnStatus: true
        }
    }
    echo "iso_result : ${iso_result}"
    if (iso_result == 0) {
        echo "iso success"
    } else {
        echo "iso failed"
        currentBuild.result = 'FAILURE'
        return
    }

    stage('Stash Build Result') {
        // stash result
        dir('/fileserver/open-estuary') {
            stash includes: '**/*', name: 'buildResult'
        }

        stash includes: '*.txt', name: 'mailResult'
        stash includes: '*.properties', name: 'paramsResult'
    }
}

node('ci-compile') {
    stage('Upload Build Binary') {
        // unstash result
        dir('/fileserver/open-estuary'){
            unstash 'buildResult'
        }
    }

    stage('Unstash Build Result') {
        unstash 'mailResult'
        unstash 'paramsResult'
    }

    def props = readProperties  file: 'env.properties'
    def GIT_DESCRIBE = props['GIT_DESCRIBE']

    clone2local(getGitUrl(), getGitBranchName(), './local/ci-scripts')
    // load functions
    def functions = load "./local/ci-scripts/pipeline/functions.groovy"

    stage('Test Preparation') { // for display purposes
        clone2local(getGitUrl(), getGitBranchName(), './local/ci-scripts')

        dir('./local/ci-test-cases') {
            deleteDir()
        }
        if (TEST_REPO == "" || TEST_REPO == null) {
            TEST_REPO = "https://github.com/qinshulei/ci-test-cases.git"
        }
        clone2local(TEST_REPO, '*/master', './local/ci-test-cases')
    }

    stage ('Mirror Test Repo') {
        build job: 'step_mirror_test_repo_in_lava', parameters: [[$class: 'StringParameterValue', name: 'TEST_REPO', value: TEST_REPO]]
    }

    def test_result = 0
    stage('Testing') {
        try {
            build job: 'remote-erp-test-liuchunfeng', parameters: [[$class: 'StringParameterValue', name: 'TREE_NAME', value:  "$TREE_NAME"], [$class: 'StringParameterValue', name: 'GIT_DESCRIBE', value: "$GIT_DESCRIBE"]], wait: false
        } catch (Exception err) {
        } finally {
        }

        test_result = sh script: "./local/ci-scripts/test-scripts/jenkins_boot_start.sh -p env.properties 2>&1 " , returnStatus: true
    }
    echo "test_result : ${test_result}"
    if (test_result == 0) {
        echo "Test success"
    } else {
        echo "Test failed"
        functions.send_mail()
        currentBuild.result = 'FAILURE'
        return
    }

    stage('Mail & Report') {
        functions.send_mail()
        functions.publish_html()
    }
}
