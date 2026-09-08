pipeline {
    agent { label 'jenkins-agent' }

    stages {
        stage('Smoke') {
            steps {
                sh 'echo ok && uname -a'
            }
        }
    }
}
