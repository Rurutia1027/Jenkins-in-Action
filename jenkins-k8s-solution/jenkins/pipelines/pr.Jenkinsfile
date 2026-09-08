# PR — fast merge protection. No image build. No deploy.
# Jenkins job: Pipeline from SCM, Script Path = jenkins-k8s-solution/jenkins/pipelines/pr.Jenkinsfile

pipeline {
    agent {
        kubernetes {
            yamlFile 'jenkins-k8s-solution/jenkins/agents/ci-pod.yaml'
            defaultContainer 'golang'
        }
    }

    options {
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
    }

    stages {
        stage('Compile — backend') {
            steps {
                container('golang') {
                    dir('bugtracker-backend') {
                        sh 'go test ./...'
                    }
                }
            }
        }

        stage('Integration') {
            steps {
                container('golang') {
                    dir('bugtracker-backend') {
                        sh 'go test -tags=integration ./internal/integration/ -count=1'
                    }
                }
            }
        }

        stage('Compile — frontend') {
            steps {
                container('node') {
                    dir('bugtracker-frontend') {
                        sh '''
                        npm ci
                        npm run lint
                        npm test
                        '''
                    }
                }
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'bugtracker-frontend/test-results.xml'
                }
            }
        }

        stage('Security — dependencies') {
            parallel {
                stage('npm audit') {
                    steps {
                        container('node') {
                            catchError(buildResult: 'UNSTABLE', stageResult: 'UNSTABLE') {
                                sh 'SECURITY_CVE_GATE=1 bash tests-security/scripts/npm-audit.sh'
                            }
                        }
                    }
                }
                stage('govulncheck') {
                    steps {
                        container('golang') {
                            dir('bugtracker-backend') {
                                sh 'go run golang.org/x/vuln/cmd/govulncheck@v1.1.3 ./...'
                            }
                        }
                    }
                }
                stage('trivy fs') {
                    steps {
                        container('trivy') {
                            catchError(buildResult: 'UNSTABLE', stageResult: 'UNSTABLE') {
                                sh 'SECURITY_CVE_GATE=1 bash tests-security/scripts/trivy-fs.sh'
                            }
                        }
                    }
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'tests-security/reports/**', allowEmptyArchive: true
                }
            }
        }
    }
}
