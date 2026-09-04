pipeline {
    agent any

    stages {
        stage('Hello') {
            steps {
                echo 'Hello World'
                sh 'echo "hello world again from second pipeline job"'
                sh 'pwd'
            }
        }
    }
}