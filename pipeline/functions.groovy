def send_mail() {
    //get mail info
    mailTo = readFile 'MAIL_LIST.txt'
    mailSubject = readFile 'MAIL_SUBJECT.txt'
    mailContent = readFile 'MAIL_CONTENT.txt'
    // send test result

    emailext mimeType: 'text/html', bcc: '', body: mailContent, cc: '', from: 'qinsl0106@thundersoft.com', replyTo: 'qinsl0106@thundersoft.com', subject: mailSubject, to: mailTo
    // don't upload the pdf
    //, attachmentsPattern: '**/*resultfile.pdf'
}

@NonCPS
def getAllFiles(rootPath) {
    def list = []
    for (subPath in rootPath.list()) {
        list << subPath.getName()
        // in case you don't want extension
        // list << FilenameUtils.removeExtension(subPath.getName())
    }
    return list
}

def publish_html() {
    html_files = getAllFiles("./html")
    for (int i = 0; i < html_files.size(); i++) {
        publishHTML([allowMissing: true, alwaysLinkToLastBuild: false, keepAll: true, reportDir: '', reportFiles: html_files[i], reportName: '', reportTitles: html_files[i]])
    }
}

def archive_result() {
    archiveArtifacts artifacts: '*result.txt', allowEmptyArchive: true
}

return this
