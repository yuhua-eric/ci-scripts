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

        sh "echo GIT_DESCRIBE=\\\"${GIT_DESCRIBE}\\\" >> env.properties"
        sh "echo BEBUG=\\\"${BEBUG}\\\" >> env.properties"
    }
    // load functions
    def functions = load "./local/ci-scripts/pipeline/functions.groovy"

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
    }
}

node('ci-compile') {
    stage('Upload Build Binary') {
        // unstash result
        dir('/fileserver/open-estuary'){
            unstash 'buildResult'
        }
    }

    clone2local(getGitUrl(), getGitBranchName(), './local/ci-scripts')
    // load functions
    def functions = load "./local/ci-scripts/pipeline/functions.groovy"
}
