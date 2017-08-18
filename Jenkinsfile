node ('compile'){
    stage('Preparation') { // for display purposes
        def exists = fileExists './local/ci-scripts'
        if (!exists){
            new File('./local/ci-scripts').mkdir()
        }
        dir ('./local/ci-scripts') {
            git url: 'https://github.com/qinshulei/ci-scripts.git'
        }
    }
    stage('Show env') {
        sh 'env'

        // save the properties
        sh "echo SKIP_BUILD=true > env.properties"
        sh "echo SHELL_PLATFORM=\"${SHELL_PLATFORM}\" >> env.properties"
        sh "echo ARCH_MAP=\"${ARCH_MAP}\" >> env.properties"
        sh "echo BOOT_PLAN=\"${BOOT_PLAN}\" >> env.properties"
        sh "echo APP_PLAN=\"${APP_PLAN}\" >> env.properties"
        sh "echo VERSION=\"${VERSION}\" >> env.properties"
        sh "echo GIT_DESCRIBE=\"${GIT_DESCRIBE}\" >> env.properties"
    }
    stage('Build') {
        sh "./local/ci-scripts/build-scripts/jenkins_build_start.sh -p env.properties 2>&1  | tee build.log"
    }
    stage('Test') {
        sh "./local/ci-scripts/boot-app-scripts/jenkins_boot_start.sh -p env.properties 2>&1  | tee test.log"
    }

    stage('Results') {
        echo "generate result"
    }
}
