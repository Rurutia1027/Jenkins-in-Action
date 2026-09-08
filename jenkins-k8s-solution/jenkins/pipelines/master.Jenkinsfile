# Master — tests + compile + image + push. This is the only pipeline that builds images.
# Later environments only pull IMAGE_TAG. Script Path = jenkins-k8s-solution/jenkins/pipelines/master.Jenkinsfile

pipeline {
    agent {
        kubernetes {
            yamlFile 'jenkins-k8s-solution/jenkins/agents/ci-pod.yaml'
            defaultContainer 'golang'
        }
    }

    environment {
        REGISTRY = 'kind-registry:5000'
    }

    options {
        timestamps()
        timeout(time: 45, unit: 'MINUTES')
    }

    stages {
        stage('Resolve tag') {
            steps {
                script {
                    env.IMAGE_TAG = env.GIT_COMMIT ? env.GIT_COMMIT.substring(0, 7) : 'unknown'
                }
            }
        }

        stage('Test — backend') {
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

        stage('Test — frontend') {
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

        stage('BDD') {
            steps {
                container('golang') {
                    dir('bugtracker-backend') {
                        sh '''
                        export DB_PATH=/tmp/bdd-bugs.db
                        go run ./cmd/bugtracker > "${WORKSPACE}/bdd-api.log" 2>&1 &
                        echo $! > /tmp/bdd-api.pid
                        '''
                    }
                }
                container('node') {
                    sh '''
                    set -euo pipefail
                    ok=0
                    for i in $(seq 1 40); do
                      if node -e 'fetch("http://127.0.0.1:8080/api/health").then((r)=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))'; then
                        ok=1
                        break
                      fi
                      sleep 1
                    done
                    if [ "${ok}" != "1" ]; then
                      echo "BDD API failed to start"
                      cat "${WORKSPACE}/bdd-api.log" || true
                      exit 1
                    fi
                    cd tests-bdd
                    npm ci
                    BUGTRACKER_API_URL=http://127.0.0.1:8080 npm test
                    '''
                }
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'tests-bdd/test-results/results.xml'
                    archiveArtifacts artifacts: 'tests-bdd/test-results/**,bdd-api.log', allowEmptyArchive: true
                }
            }
        }

        stage('Security — API abuse') {
            steps {
                container('node') {
                    sh '''
                    set -euo pipefail
                    cd tests-security
                    npm ci
                    PLAYWRIGHT_TEST_BASE_URL=http://127.0.0.1:8080/api/ npx playwright test
                    cd ../tests-integration
                    npm ci
                    PLAYWRIGHT_TEST_BASE_URL=http://127.0.0.1:8080/api/ npx playwright test
                    '''
                }
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'tests-security/test-results/results.xml'
                    junit allowEmptyResults: true, testResults: 'tests-integration/test-results/results.xml'
                    archiveArtifacts artifacts: 'tests-security/test-results/**,tests-security/playwright-report/**,tests-integration/test-results/**,tests-integration/playwright-report/**', allowEmptyArchive: true
                }
            }
        }

        stage('Compile') {
            parallel {
                stage('Go binary') {
                    steps {
                        container('golang') {
                            dir('bugtracker-backend') {
                                sh 'go build -o /tmp/bugtracker ./cmd/bugtracker'
                            }
                        }
                    }
                }
                stage('Next.js') {
                    steps {
                        container('node') {
                            dir('bugtracker-frontend') {
                                sh 'npm run build'
                            }
                        }
                    }
                }
            }
        }

        stage('Image — backend') {
            steps {
                container('kaniko') {
                    sh '''
                    /kaniko/executor \
                      --context="${WORKSPACE}/bugtracker-backend" \
                      --dockerfile=Dockerfile \
                      --destination="${REGISTRY}/bugtracker-backend:${IMAGE_TAG}" \
                      --insecure \
                      --skip-tls-verify
                    '''
                }
            }
        }

        stage('Image — frontend') {
            steps {
                container('kaniko') {
                    sh '''
                    /kaniko/executor \
                      --context="${WORKSPACE}/bugtracker-frontend" \
                      --dockerfile=Dockerfile \
                      --destination="${REGISTRY}/bugtracker-frontend:${IMAGE_TAG}" \
                      --insecure \
                      --skip-tls-verify
                    '''
                }
            }
        }

        stage('Security — images') {
            steps {
                container('trivy') {
                    catchError(buildResult: 'UNSTABLE', stageResult: 'UNSTABLE') {
                        sh '''
                        SECURITY_CVE_GATE=1 bash tests-security/scripts/trivy-image.sh \
                          "${REGISTRY}/bugtracker-backend:${IMAGE_TAG}" \
                          "${REGISTRY}/bugtracker-frontend:${IMAGE_TAG}"
                        '''
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

    post {
        success {
            echo "Pushed ${REGISTRY}/bugtracker-backend:${IMAGE_TAG}"
            echo "Pushed ${REGISTRY}/bugtracker-frontend:${IMAGE_TAG}"
            echo "Release/canary must deploy this tag; do not rebuild."
        }
    }
}
