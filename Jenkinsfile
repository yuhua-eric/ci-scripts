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
        sh 'env > env.txt'
        for (String i : readFile('env.txt').split("\r?\n")) {
            println i
        }
    }
    stage('Build') {
        sh "./local/ci-scripts/build-scripts/jenkins_build_start.sh 2>&1  | tee build.log"
    }
    stage('Test') {
        sh "./local/ci-scripts/boot-app-scripts/jenkins_boot_start.sh -p env.properties 2>&1  | tee test.log"
    }

    stage('Results') {
        echo "generate result"
    }
}
