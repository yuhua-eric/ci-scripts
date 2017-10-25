def functions = load "./local/pipeline/functions.groovy"

node ('compile'){
    stage('Preparation') { // for display purposes
        clone2local('https://github.com/qinshulei/ci-scripts.git', './local/ci-scripts')
        clone2local('https://github.com/qinshulei/ci-test-cases.git', './local/ci-test-cases')

        // prepare variables.
        sh 'env'

        BOOT_PLAN = "BOOT_ISO"

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
        sh "echo APP_PLAN=\\\"${APP_PLAN}\\\" >> env.properties"
        sh "echo VERSION=\\\"${VERSION}\\\" >> env.properties"
        sh "echo GIT_DESCRIBE=\\\"${GIT_DESCRIBE}\\\" >> env.properties"
    }

    stage('Test') {
        def test_result = sh "./local/ci-scripts/boot-app-scripts/jenkins_boot_start.sh -p env.properties 2>&1  | tee test.log"
        if (test_result) {
            echo "Test success"
        } else {
            echo "Test failed"
            functions.send_mail()
            exit -1
        }
    }

    stage('Result') {
        functions.send_mail()
    }
}
