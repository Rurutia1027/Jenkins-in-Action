# Release — promote an already-pushed IMAGE_TAG. Canary window, then stable. Never docker build.
# Script Path = jenkins-k8s-solution/jenkins/pipelines/release.Jenkinsfile

pipeline {
    agent {
        kubernetes {
            yamlFile 'jenkins-k8s-solution/jenkins/agents/ci-pod.yaml'
            defaultContainer 'helm'
        }
    }

    parameters {
        string(name: 'IMAGE_TAG', defaultValue: '', description: 'Git sha already pushed by Master. Empty = this commit short sha.')
        booleanParam(name: 'PROMOTE_ON_PASS', defaultValue: true, description: 'If canary gates pass, helm upgrade stable to the same tag.')
    }

    environment {
        CHART = 'jenkins-k8s-solution/helm/bugtracker'
        NS    = 'bugtracker'
    }

    options {
        timestamps()
        timeout(time: 40, unit: 'MINUTES')
    }

    stages {
        stage('Resolve tag') {
            steps {
                script {
                    env.DEPLOY_TAG = params.IMAGE_TAG?.trim() ? params.IMAGE_TAG.trim() : env.GIT_COMMIT.take(7)
                    echo "Deploying immutable tag ${env.DEPLOY_TAG}"
                }
            }
        }

        stage('Security — images') {
            steps {
                container('trivy') {
                    catchError(buildResult: 'UNSTABLE', stageResult: 'UNSTABLE') {
                        sh '''
                        SECURITY_CVE_GATE=1 bash tests-security/scripts/trivy-image.sh \
                          kind-registry:5000/bugtracker-backend:${DEPLOY_TAG} \
                          kind-registry:5000/bugtracker-frontend:${DEPLOY_TAG}
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

        stage('Deploy canary') {
            steps {
                container('helm') {
                    sh '''
                    helm upgrade --install bugtracker-canary "${CHART}" \
                      --namespace "${NS}" --create-namespace \
                      --values "${CHART}/values.yaml" \
                      --values "${CHART}/values-canary.yaml" \
                      --set backend.image.tag="${DEPLOY_TAG}" \
                      --set frontend.image.tag="${DEPLOY_TAG}" \
                      --wait --timeout 5m
                    '''
                }
            }
        }

        stage('BDD against canary') {
            steps {
                container('node') {
                    sh '''
                    set -euo pipefail
                    export BUGTRACKER_API_URL=http://bugtracker-canary-backend.${NS}.svc.cluster.local:8080
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

        stage('Canary window') {
            steps {
                container('helm') {
                    sh '''
                    set -euo pipefail
                    API="http://bugtracker-canary-backend.${NS}.svc.cluster.local:8080"
                    deadline=$((SECONDS + 120))
                    ok=0
                    fail=0
                    while [ "${SECONDS}" -lt "${deadline}" ]; do
                      if wget -qO- "${API}/api/health" | grep -q ok && \
                         wget -qO- --header='Content-Type: application/json' \
                           --post-data='{"title":"canary","description":"window","priority":"Low","status":"Open"}' \
                           "${API}/api/bugs" >/dev/null; then
                        ok=$((ok + 1))
                      else
                        fail=$((fail + 1))
                      fi
                      sleep 5
                    done
                    echo "canary window ok=${ok} fail=${fail}"
                    test "${ok}" -gt 0
                    test "${fail}" -eq 0
                    '''
                }
            }
        }

        stage('Canary logs') {
            steps {
                container('helm') {
                    sh 'kubectl -n "${NS}" logs -l app.kubernetes.io/instance=bugtracker-canary --tail=80 || true'
                }
            }
        }

        stage('Promote stable') {
            when { expression { return params.PROMOTE_ON_PASS } }
            steps {
                container('helm') {
                    sh '''
                    helm upgrade --install bugtracker "${CHART}" \
                      --namespace "${NS}" --create-namespace \
                      --values "${CHART}/values.yaml" \
                      --values "${CHART}/values-kind.yaml" \
                      --set backend.image.tag="${DEPLOY_TAG}" \
                      --set frontend.image.tag="${DEPLOY_TAG}" \
                      --wait --timeout 5m
                    '''
                }
            }
        }

        stage('Discard canary') {
            steps {
                container('helm') {
                    sh 'helm uninstall bugtracker-canary --namespace "${NS}" || true'
                }
            }
        }
    }

    post {
        failure {
            container('helm') {
                sh 'helm uninstall bugtracker-canary --namespace "${NS}" || true'
            }
        }
    }
}
