# Jenkins on kind 

This is the first platform slice of the final project: a production-shaped Jenkins controller on a local Kubernetes cluster. 

The Bug Tracker fullstack app stays the system under test. This document only covers how Jenkins itself is deployed. The Compose + DinD stack under `jenkins` remains the fallback for the course track. 

## Why this exists 

PLAN.md P2 treats Jenkins as a platform, not a long-lived Docker container: 

- configuration is code (JCasC), not click-ops 
- the controller is persistent; agents are not 
- pipelines run on ephemeral Kubernetes pods 
- install and teardown are scripts, so the environment is repeatable

kind is enough to prove that shape on a laptop. Helm is the install path, not a custom Deployment we woud have maintain. 

## What you get 

One kind cluster and one Helm release: 

| Piece | Role |
|---|---|
| kind cluster `jenkins` | Single control-plane, local-path StorageClass |
| Jenkins controller | StatefulSet + 8Gi PVC + health probes |
| JCasC | Kubernetes cloud and system message applied on start |
| Ephemeral agents | Pods with label `jenkins-agent`, deleted after the build |
| UI | `http://localhost:9000` (same port as Compose) |

Controller executors are set to `0`. Bulids do not run on the controller. 

## How it is installed 

We wrap the official chart [`jenkins/jenkins` 5.9.56](https://github.com/jenkinsci/helm-charts). The wrapper only owns values, a controller image, the kind cluster, and scripts. 

```
kind-up.sh
    │
    ▼
kind cluster (NodePort 30080 ← host 9000)
    │
deploy-jenkins.sh
    │
    ├── docker build  jenkins-kind/controller:1.0.0
    ├── kind load     controller + inbound-agent
    └── helm upgrade --install jenkins
              │
              ▼
     official jenkins/jenkins
              │
      ┌───────┴────────┐
      ▼                ▼
 controller + PVC   agent pods
```

Production-like settings live in `helm/jenkins/values.yaml`. Laptop overrides (NodePort, smaller memory, no config-reload sidecar) live in `values-kind.yaml`. 

Plugins are baked into the controller image so Jenkins does not download them from the update center at startup: 

- kubernetes 
- workflow-aggregator
- git 
- configuration-as-code 
- job-dsl 
- junit 
- htmlpublisher 
- github-branch-source 


## Layout 

```
jenkins-k8s-solution/ 
  kind/cluster.yaml
  helm/jenkins/
    Chart.yaml              # dependency: jenkins/jenkins@5.9.56
    values.yaml
    values-kind.yaml
  jenkins/
    controller/             # Dockerfile + plugins.txt
    pipelines/agent-smoke.Jenkinsfile
  scripts/
    kind-up.sh
    deploy-jenkins.sh
    teardown.sh
```

## Run it 

Prerequisites: Docker, kind, kubectl, Heml 3. 

```bash 
cd jenkins-k8s-solution
./scripts/kind-up.sh 
./scripts/deploy-jenkins.sh 
```

- URL: <http://localhost:9000>
- User: `admin`
- Password: printed by the deploy script, or 

```bash 
kubectl --context kind-jenkins -n jenkins get secret jenkins \
    -o jsonpath='{.data.jenkins-admin-password}' | base64 --decode 
```

Smoke the agent pool with `jenkins/pipelines/agent-smoke.Jenkinsfile`: 

```groovy
agent { label 'jenkins-agent' }
```

Then after the above commands, a pod should appear in namespace `jenkins` and disappear when build finished. 

```bash 
./scripts/teardown.sh               # uninstall Helm, keep the cluster 
./scripts/teardown.sh --cluster     # also delete the kind cluster 
```

If Compose Jenkins already holds port 9000: 

```bash 
KIND_HOST_PORT=9001 ./scripts/kind-up.sj 
KIND_HOST_PORT=9001 ./scripts/deploy-jenkins.sh 
```

## What this slice does not include 

These stay later phases: 

- Bug Tracker Helm chart 
- shared library and scenario pipelines (PR / master / nightly / release)
- Ingress + TLS 
- Prometheus / Grafana / Loki
- backup and an external registry 


## Troubleshotting 

**Init container: `echo: I/O error`.** kind uses the Docker Desktop disk. If that disk is full, the controller cannot write its PVC. Free space (`docker builder prune`) and delete pod `jenkins-0`.

**`kind load` fails on a multi-arch image.** `deploy-jenkins.sh` flattens images to the kind node platform (`linux/arm64` or `linux/amd64`) before loading. That avoids Docker Desktop manifest-list import errors.

