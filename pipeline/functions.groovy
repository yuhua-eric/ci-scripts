def send_mail() {
    //get mail info
    mailTo = readFile 'MAIL_LIST.txt'
    mailCC = readFile 'MAIL_CC_LIST.txt'
    mailSubject = readFile 'MAIL_SUBJECT.txt'
    mailContent = readFile 'MAIL_CONTENT.txt'
    // send test result

    emailext mimeType: 'text/html', bcc: '', body: mailContent, cc: mailCC, from: 'qinsl0106@thundersoft.com', replyTo: 'qinsl0106@thundersoft.com', subject: mailSubject, to: mailTo
    // don't upload the pdf
    //, attachmentsPattern: '**/*resultfile.pdf'
}

def archive_result() {
    archiveArtifacts artifacts: '*result.txt', allowEmptyArchive: true
}


@NonCPS
def getAllFiles(rootPath) {
    def list = []
    for (subPath in rootPath.list()) {
        list << subPath.getName()
        // in case you don't want extension
        // list << FilenameUtils.removeExtension(subPath.getName())
    }
    return list.sort()
}

// Helps if slave servers are in picture
def createFilePath(def path) {
    if (env['NODE_NAME'].equals("master")) {
        File localPath = new File(path)
        return new hudson.FilePath(localPath);
    } else {
        return new hudson.FilePath(Jenkins.getInstance().getComputer(env['NODE_NAME']).getChannel(), path);
    }
}

def publish_html() {
    html_files = getAllFiles(createFilePath("${workspace}/html"))
    for (int i = 0; i < html_files.size(); i++) {
        def name = html_files[i].split("\\.")[0]
        publishHTML([allowMissing: true, alwaysLinkToLastBuild: false, keepAll: true, reportDir: 'html', reportFiles: html_files[i], reportName:  name, reportTitles:name])
    }
}

return this
