# Fullstack Test Automation Platform

An SDET platform around [Bug Tracker](https://github.com/james-willett/bug-tracker): Go API + Next.js. Jenkins, kind, and Helm are the execution layer. They do not define the testing architecture.

The contract is: **the cheapest test at the earliest lifecycle stage that can reliably detect that failure.**

Primary design: [docs/testing-architecture.md](docs/testing-architecture.md).

## Architecture

<img width="866" height="801" alt="CI/CD Architecture" src="https://github.com/user-attachments/assets/d3fccdba-dee1-4d55-b3a2-c9ddf9c7a6ae" />

```
Test Type → Test Strategy → Suite → Engineering Scenario → Lifecycle / Environment → Pipeline
```

A pipeline is not a test suite. Smoke is not a test type. BDD is a specification style, not a layer.

## Documents

| Doc | What it is |
|---|---|
| [docs/testing-architecture.md](docs/testing-architecture.md) | Lifecycle, types vs strategies, pipelines, canary instrumentation |
| [docs/frontend-test-design.md](docs/frontend-test-design.md) | Frontend layers, journeys, profile flags |
| [docs/test-implementation-gaps.md](docs/test-implementation-gaps.md) | Designed suites not yet wired, and how to land them |
| [PLAN.md](PLAN.md) | Implementation blueprint and phases |

## What we validate (test types)

Types describe **what**. They live in this repo:

| Type | Where |
|---|---|
| Static | `next lint`; backend lint to add |
| Unit | `bugtracker-backend` `go test`; frontend Jest helpers / API client |
| Component | `bugtracker-frontend` Testing Library |
| API | `tests-api` |
| Integration | `tests-integration` + `bugtracker-backend/internal/integration` (handler → bbolt) |
| E2E | `tests-e2e` |
| BDD | `tests-bdd` (Cucumber + API fixtures) |
| Performance | `tests-perf` (k6) |
| Security | `tests-security` (`npm audit`, govulncheck, Trivy, API abuse) |
| Visual | Playwright `toHaveScreenshot` in `tests-visual/` |

Integration is **API → handler → bbolt**, not a browser path. Suite: [tests-integration](../tests-integration). Contract and chaos stay later.

**Not types:** smoke, sanity, regression, release validation, critical path. Those are **strategies** — they compose the types above.

## Strategies and suites

A suite has an objective. It is not named after a single tool.

| Suite | Objective | Composition |
|---|---|---|
| PR Validation | Merge protection, fast | Static, unit, component, API, audit |
| Master / Merge | Integrated tree still works | PR + BDD + E2E |
| Nightly | Expensive regression detection | Full regression, visual, extended E2E |
| Release | Artifact is promotable | Smoke after deploy + full regression + security |
| Production / Canary | Small blast radius, real conditions | Smoke, critical path, **instrumentation** |

Frontend assignment of these flags: [docs/frontend-test-design.md](docs/frontend-test-design.md).

Profiles stay data, not hard-coded stages:

```yaml
# example: PR
tests:
  unit: true
  component: true
  api: true
  bdd: false
  e2e: false
  visual: false
  security: true
  performance: false
```

## Engineering scenarios (pipelines)

Several pipelines, because the questions differ:

| Pipeline | Question |
|---|---|
| PR | Can this change enter the codebase? |
| Merge | Does the integrated codebase still behave? |
| Nightly | Did we miss slow or wide regressions? |
| Release | Can this **same** image be promoted? |
| Canary | Does the candidate hold under a small slice, by **tests and 埋点**? |

Build once, promote many. Staging and production do not rebuild.

```
PR → Merge → Artifact → TEST / Staging → Release → Canary → 100%
```

Upstream failure blocks downstream promotion. Canary failure stops the rollout and rolls back. Rollback is a pipeline **outcome**, not a side runbook.

## Canary and instrumentation (埋点)

No Istio. Canary is a Jenkins gate against a **second Helm release** (`bugtracker-canary`) while stable keeps the previous image.

1. Deploy candidate to `CANARY_URL`
2. Validation window (minutes): loop smoke + create/read + thin UI; record success ratio, latency; `kubectl logs` on canary pods
3. PASS → promote the **same image** to stable, uninstall canary
4. FAIL → uninstall canary, stable untouched, fail the pipeline

Details: [testing-architecture.md §9](docs/testing-architecture.md).

## Environments

```
Dev → TEST / Integration → Staging → Canary / Gray → Production
```

The same E2E may run in staging as release validation and against canary as critical path. The file is the same; purpose and risk are not.

## Quality gates

```
Suite result → Coverage → Lint / scan → Artifact → Deploy smoke → Canary instrumentation
```

Examples: coverage floor, no blocking vulns, mandatory regression green, canary error ratio and KPI within window.

Failures must name pipeline, commit, stage, suite, environment, duration, and report link.

## Production feedback

```
Incident → RCA → missing coverage → automated test → regression suite → gate
```

Production risk feeds the suite catalog. That is SDET work, not a new deploy tool.

## Application and tools

- App: Go, Next.js / React, bbolt (no extra Kafka/Postgres bolted on for the diagram)
- Tests: Go test, Jest, Playwright (API / E2E / visual), Cucumber BDD, k6
- Runner: Jenkins on Kubernetes (ephemeral agents). Local kind: [docs/jenkins-on-kind.md](docs/jenkins-on-kind.md)
- Observability **as test input**: metrics, logs, traces used in canary / production gates. Jenkins JVM dashboards are operational, not the testing architecture.

## Local Jenkins runner

Kind + Helm install notes live in [docs/jenkins-on-kind.md](docs/jenkins-on-kind.md). Compose + DinD under `jenkins/` remains the course-track fallback.

App chart: `helm/bugtracker` (backend + frontend). Images come from Master only (`kind-registry:5000/bugtracker-{backend,frontend}:<sha>`).

```bash
cd jenkins-k8s-solution
./scripts/kind-up.sh
./scripts/deploy-jenkins.sh

# After Master has pushed a tag:
IMAGE_TAG=<sha> ./scripts/build-and-push.sh   # local equivalent of Master image stages
IMAGE_TAG=<sha> ./scripts/deploy-bugtracker.sh
IMAGE_TAG=<sha> ./scripts/deploy-bugtracker.sh --canary
```

Jenkins jobs (Pipeline from SCM, **Script Path**):

| Job | Script Path | Builds images? |
|---|---|---|
| PR | `jenkins-k8s-solution/jenkins/pipelines/pr.Jenkinsfile` | No |
| Master | `.../master.Jenkinsfile` | Yes — compile, then Kaniko push |
| Nightly | `.../nightly.Jenkinsfile` | No |
| Release | `.../release.Jenkinsfile` | No — canary then promote the Master tag |

UI: <http://localhost:9000> (Jenkins). App stable: API `http://127.0.0.1:18080`, UI `http://127.0.0.1:13000`.

Existing kind cluster `jenkins` must be recreated once so NodePorts and the local registry patches apply (`./scripts/teardown.sh --cluster` then `kind-up.sh`).

## Project goal

Turn business and production risk into automated, observable, enforceable quality gates across the lifecycle.

```
Business risk → Test type / strategy → Suite → Pipeline scenario
    → Artifact promotion → Canary instrumentation → Rollback or 100%
```
