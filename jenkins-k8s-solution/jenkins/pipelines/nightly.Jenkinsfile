# Nightly — expensive regression. Does not rebuild images (uses last Master tag or this SHA if already pushed).
# Script Path = jenkins-k8s-solution/jenkins/pipelines/nightly.Jenkinsfile

pipeline {
    agent {
        kubernetes {
            yamlFile 'jenkins-k8s-solution/jenkins/agents/ci-pod.yaml'
            defaultContainer 'golang'
        }
    }

    options {
        timestamps()
        timeout(time: 90, unit: 'MINUTES')
    }

    triggers {
        cron('H 2 * * *')
    }

    stages {
        stage('Unit / component') {
            parallel {
                stage('Backend') {
                    steps {
                        container('golang') {
                            dir('bugtracker-backend') {
                                sh 'go test ./...'
                            }
                        }
                    }
                }
                stage('Frontend') {
                    steps {
                        container('node') {
                            dir('bugtracker-frontend') {
                                sh 'npm ci && npm test'
                            }
                        }
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

        stage('BDD (needs running API)') {
            steps {
                container('helm') {
                    sh '''
                    set -euo pipefail
                    if kubectl get svc -n bugtracker bugtracker-backend >/dev/null 2>&1; then
                      echo yes > .run-bdd
                    else
                      echo "Stable backend is not deployed; skip BDD."
                      echo no > .run-bdd
                    fi
                    '''
                }
                container('node') {
                    sh '''
                    set -euo pipefail
                    if [ "$(cat .run-bdd)" != "yes" ]; then
                      exit 0
                    fi
                    export BUGTRACKER_API_URL=http://bugtracker-backend.bugtracker.svc.cluster.local:8080
                    cd tests-bdd
                    npm ci
                    npm test
                    cd ../tests-security
                    npm ci
                    PLAYWRIGHT_TEST_BASE_URL="${BUGTRACKER_API_URL}/api/" npx playwright test
                    cd ../tests-integration
                    npm ci
                    PLAYWRIGHT_TEST_BASE_URL="${BUGTRACKER_API_URL}/api/" npx playwright test
                    '''
                }
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'tests-bdd/test-results/results.xml'
                    junit allowEmptyResults: true, testResults: 'tests-security/test-results/results.xml'
                    junit allowEmptyResults: true, testResults: 'tests-integration/test-results/results.xml'
                    archiveArtifacts artifacts: 'tests-bdd/test-results/**,tests-security/test-results/**,tests-security/playwright-report/**,tests-integration/test-results/**,tests-integration/playwright-report/**', allowEmptyArchive: true
                }
            }
        }

        stage('E2E / visual (needs running stack)') {
            steps {
                container('helm') {
                    sh '''
                    set -euo pipefail
                    if kubectl get svc -n bugtracker bugtracker-frontend >/dev/null 2>&1; then
                      echo yes > .run-live-ui-tests
                    else
                      echo "Stable Bug Tracker is not deployed; skip live E2E and visual."
                      echo no > .run-live-ui-tests
                    fi
                    '''
                }
                container('playwright') {
                    sh '''
                    set -euo pipefail
                    if [ "$(cat .run-live-ui-tests)" != "yes" ]; then
                      exit 0
                    fi
                    export PLAYWRIGHT_TEST_BASE_URL=http://bugtracker-frontend.bugtracker.svc.cluster.local:3000
                    export BUGTRACKER_API_URL=http://bugtracker-backend.bugtracker.svc.cluster.local:8080
                    export CI=1
                    cd tests-e2e
                    npm ci
                    npx playwright test integration.spec.ts
                    cd ../tests-visual
                    npm ci
                    npx playwright test
                    '''
                }
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'tests-e2e/test-results/results.xml'
                    junit allowEmptyResults: true, testResults: 'tests-visual/test-results/results.xml'
                    archiveArtifacts artifacts: 'tests-visual/test-results/**,tests-visual/playwright-report/**,tests-e2e/playwright-report/**', allowEmptyArchive: true
                }
            }
        }

        stage('Security — images') {
            steps {
                script {
                    env.IMAGE_TAG = env.GIT_COMMIT ? env.GIT_COMMIT.substring(0, 7) : 'unknown'
                }
                container('trivy') {
                    catchError(buildResult: 'UNSTABLE', stageResult: 'UNSTABLE') {
                        sh '''
                        SECURITY_CVE_GATE=1 bash tests-security/scripts/trivy-image.sh \
                          kind-registry:5000/bugtracker-backend:${IMAGE_TAG} \
                          kind-registry:5000/bugtracker-frontend:${IMAGE_TAG}
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
}
