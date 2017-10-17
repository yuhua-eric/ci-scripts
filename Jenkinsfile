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

    // use TREE_NAME and BOOT_PLAN determine the CI steps.
    //            TREE_NAME       open-estuary       linaro
    // BOOT_PLAN
    // BOOT_NFS                  Build -> Test       NA
    // BOOT_PXE                  Deploy -> Test     Deploy -> Test

    if ( TREE_NAME == 'linaro' && BOOT_PLAN == 'BOOT_NFS') {
        error "ERROR: don't support linaro BOOT_NFS ."
    }

    if ( TREE_NAME == 'open-estuary' && BOOT_PLAN == "BOOT_NFS") {
        stage('Build') {
            sh "./local/ci-scripts/build-scripts/jenkins_build_start.sh -p env.properties 2>&1  | tee build.log"
        }
    }

    stage('Deploy') {
        def SKIP_DEPLOY = false
        def SKIP_UEFI = false
        sh "./local/ci-scripts/deploy-scripts/prepare_tools.sh 2>&1  | tee deploy.log"
        sh "./local/ci-scripts/deploy-scripts/config_dhcp.sh ${TREE_NAME} 2>&1  | tee -a deploy.log"
        sh "./local/ci-scripts/deploy-scripts/config_tftp.sh ${TREE_NAME} 2>&1  | tee -a deploy.log"
        if (! SKIP_UEFI) {
            sh "./local/ci-scripts/deploy-scripts/config_uefi.sh ${TREE_NAME} 2>&1  | tee -a deploy.log"
        }
        if (! SKIP_DEPLOY) {
            sh "./local/ci-scripts/deploy-scripts/do_deploy.sh 2>&1  | tee -a deploy.log"
        }
    }

    stage('Test') {
        sh "./local/ci-scripts/boot-app-scripts/jenkins_boot_start.sh -p env.properties 2>&1  | tee test.log"
    }

    stage('Result') {
        //get mail info
        mailTo = readFile 'MAIL_LIST.txt'
        mailSubject = readFile 'MAIL_SUBJECT.txt'
        mailContent = readFile 'MAIL_CONTENT.txt'
        // send test result
        mail bcc: '', body: mailContent, cc: '', from: 'qinsl0106@thundersoft.com', replyTo: 'qinsl0106@thundersoft.com', subject: mailSubject, to: mailTo
    }
}
