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

def publish_html() {
    publishHTML([allowMissing: true, alwaysLinkToLastBuild: false, keepAll: true, reportDir: '', reportFiles: 'daily.html', reportName: 'DailyReport', reportTitles: 'Estuary CI Auto-test Daily Report '])
    publishHTML([allowMissing: true, alwaysLinkToLastBuild: false, keepAll: true, reportDir: '', reportFiles: 'build.html', reportName: 'BuildReport', reportTitles: '编译结果'])
    publishHTML([allowMissing: true, alwaysLinkToLastBuild: false, keepAll: true, reportDir: '', reportFiles: 'test.html', reportName: 'TestReport', reportTitles: '详细测试结果'])
}

def archive_result() {
    archiveArtifacts artifacts: '*result.txt', allowEmptyArchive: true
}

return this
