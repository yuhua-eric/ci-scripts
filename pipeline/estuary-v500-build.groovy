def clone2local(giturl, localdir) {
    def exists = fileExists localdir
    if (!exists){
        new File(localdir).mkdir()
    }
    dir (localdir) {
        checkout([$class: 'GitSCM', branches: [[name: '*/master']],
                extensions: [[$class: 'CloneOption', timeout: 120]], gitTool: 'Default',
                userRemoteConfigs: [[url: giturl]]
            ])
    }
}

node ('ci-v500-compile'){
    stage('Preparation') { // for display purposes
        clone2local('https://github.com/qinshulei/ci-scripts.git', './local/ci-scripts')

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
    }

    // load functions
    def functions = load "./local/ci-scripts/pipeline/functions.groovy"

    def build_result = 0
    stage('Build') {
        //build_result = sh script: "./local/ci-scripts/build-scripts/jenkins_build_v500_start.sh -p env.properties 2>&1 ", returnStatus: true

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

    stage('stash') {
        // stash result
        dir('/fileserver/open-estuary') {
            stash includes: '**/*', name: 'buildResult'
        }
    }
}

node('ci-compile') {
    stage('upload') {
        // unstash result
        dir('/fileserver/open-estuary'){
            unstash 'buildResult'
        }
    }
    stage('Result') {
        functions.send_mail()
    }
}
