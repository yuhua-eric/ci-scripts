def clone2local(giturl, localdir) {
    def exists = fileExists localdir
    if (!exists){
        new File(localdir).mkdir()
    }
    dir (localdir) {
        git url: giturl
    }
}

node ('compile'){
    stage('Preparation') { // for display purposes
        clone2local('https://github.com/qinshulei/ci-scripts.git', './local/ci-scripts')
        clone2local('https://github.com/qinshulei/ci-test-cases.git', './local/ci-test-cases')

        // prepare variables.
        sh 'env'

        BOOT_PLAN = "BOOT_NFS"

        // save the properties
        //sh "echo SKIP_BUILD=true > env.properties"
        sh 'echo "" > env.properties'

        // save jenkins enviroment properties.
        sh "echo BUILD_URL=\\\"${BUILD_URL}\\\" >> env.properties"

        // save jenkins parameters.
        sh "echo TREE_NAME=\\\"${TREE_NAME}\\\" >> env.properties"
        sh "echo BOOT_PLAN=\\\"${BOOT_PLAN}\\\" >> env.properties"

        sh "echo SHELL_PLATFORM=\\\"${SHELL_PLATFORM}\\\" >> env.properties"
        sh "echo SHELL_DISTRO=\\\"${SHELL_DISTRO}\\\" >> env.properties"
        sh "echo TEST_PLAN=\\\"${TEST_PLAN}\\\" >> env.properties"
        sh "echo TEST_LEVEL=\\\"${TEST_LEVEL}\\\" >> env.properties"
        sh "echo VERSION=\\\"${VERSION}\\\" >> env.properties"
        sh "echo GIT_DESCRIBE=\\\"${GIT_DESCRIBE}\\\" >> env.properties"

    }

    // load functions
    def functions = load "./local/ci-scripts/pipeline/functions.groovy"

    def build_result = false
    stage('Build') {
        build_result = sh "./local/ci-scripts/build-scripts/jenkins_build_start.sh -p env.properties 2>&1  | tee build.log"
    }
    if (build_result) {
        echo "build success"
    } else {
        echo "build failed"
        functions.send_mail()
        currentBuild.result = 'SUCCESS'
        return
    }


    def test_result = false
    stage('Test') {
        def test_result = sh "./local/ci-scripts/boot-app-scripts/jenkins_boot_start.sh -p env.properties 2>&1  | tee test.log"
    }
    if (test_result) {
        echo "Test success"
    } else {
        echo "Test failed"
        functions.send_mail()
        currentBuild.result = 'SUCCESS'
        return
    }


    stage('Result') {
        functions.send_mail()
    }
}
