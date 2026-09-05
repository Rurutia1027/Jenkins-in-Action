# Fullstack CI/CD & Test Automation Platform

A production-oriented CI/CD and automated testing platform built with Jenkins, GitHub, Kubernetes, and the Bug Tracker fullstack application in this repository.

This document is the solution blueprint. Implementation follows the phases at the end. A public README can be derived from this plan later.

---

## 1. Project Overview

This project demonstrates how to design and implement a production-oriented automated testing and CI/CD platform for a modern fullstack application.

The goal is not simply to run tests in Jenkins.

The project establishes a complete engineering workflow:

```
Business Scenarios
        ↓
Test Strategy
        ↓
Automated Test Suites
        ↓
Jenkins Pipeline
        ↓
Docker Image
        ↓
Kubernetes Deployment
        ↓
Quality Gates
        ↓
Observability
        ↓
Release / Rollback
```

The same Bug Tracker application is used throughout to validate:

- Automated testing architecture
- CI pipeline design
- CD pipeline design
- Jenkins scalability and reliability
- Kubernetes deployment
- Test result reporting
- Code quality and coverage analysis
- Frontend and backend automation
- API, integration, E2E, BDD, and visual regression testing
- Performance and security testing
- Production smoke testing
- Failure notification
- Observability
- Release governance and rollback

The platform shows how different testing strategies can be dynamically combined and executed according to development and release scenarios.

---

## 2. Current State vs Target

This plan is grounded in the existing repository. It does not invent a Java / Spring / PostgreSQL / Redis / Vite stack.

### What already exists

| Layer | Actual project | Location |
|---|---|---|
| Backend | Go 1.21, gorilla/mux, bbolt | `bugtracker-backend/` |
| Frontend | Next.js 15, React 19, TypeScript, Tailwind | `bugtracker-frontend/` |
| Backend unit tests | `go test`, testify | `*_test.go` under backend |
| Frontend unit / component tests | Jest + React Testing Library | `*.test.tsx` under frontend |
| API tests | Playwright request API | `tests-api/api.spec.ts` |
| E2E tests | Playwright browser | `tests-e2e/integration.spec.ts` |
| Performance tests | k6 | `tests-perf/script.js` |
| Current CI | Single Jenkinsfile, unit tests only | `jenkins/Jenkinsfile` |
| Current Jenkins runtime | Docker Compose + DinD | `jenkins/docker-compose.yml` |
| App runtime | Docker Compose frontend + backend | `docker-compose.yml` |

### Domain already covered by tests

- Health check
- Create / read / update / delete bugs
- Comments on bugs
- Priority and status
- Frontend components: `BugList`, `AddBugModal`, `EditBugModal`, `CommentSection`, `DeleteConfirmationModal`, `Notification`

### Gaps this solution fills

- Test type vs test scenario model
- Configurable test profiles bound to CI / CD
- Smoke, sanity, BDD, visual regression, and security suites
- Multiple pipelines instead of one UT-only Jenkinsfile
- Immutable image promotion through TEST / STAGING / PROD
- Helm-based Kubernetes deployment
- Jenkins on Kubernetes with ephemeral agents
- Quality gates, reporting aggregation, and notifications
- Observability for both Jenkins and the deployed application

### Explicitly out of scope for the application itself

Do not add Kafka, RabbitMQ, PostgreSQL, or Redis to Bug Tracker just to match a generic enterprise diagram. Contract tests, chaos tests, and multi-tenant Jenkins folders are optional later phases.

---

## 3. Architecture

```
                           GitHub
                              │
                 ┌────────────┴────────────┐
                 │                         │
              Pull Request             Merge / Tag
                 │                         │
                 ▼                         ▼
          ┌─────────────┐          ┌─────────────┐
          │ PR Pipeline │          │ Master CI   │
          └──────┬──────┘          └──────┬──────┘
                 │                         │
                 └────────────┬────────────┘
                              │
                              ▼
                    Jenkins CI Platform
                              │
                 ┌────────────┼────────────┐
                 │            │            │
              Build        Test         Quality
                 │            │            │
                 ▼            ▼            ▼
              Docker      Test Suites   Coverage
              Images         │          Lint / Scan
                 │            │
                 │     ┌──────┼───────────────┐
                 │     │      │       │       │
                 │    API    UI      BDD   Visual
                 │     │      │       │       │
                 │     └──────┴───────┴───────┘
                 │
                 ▼
            Container Registry
                 │
                 ▼
             Kubernetes / Helm
                 │
          ┌──────┼───────┐
          │      │       │
         TEST  STAGING   PROD
          │      │       │
          └──────┼───────┘
                 │
                 ▼
           Smoke / Health Check
                 │
                 ▼
          Observability Stack
       ┌─────────┼──────────┐
       │         │          │
    Metrics     Logs      Traces
       │         │          │
   Prometheus   Loki    OpenTelemetry
       │         │          │
       └─────────┼──────────┘
                 │
              Grafana
```

---

## 4. Technology Stack

### Application (already in this repo)

**Frontend**

- Next.js 15
- React 19
- TypeScript
- Tailwind CSS
- Jest
- React Testing Library
- Playwright (in-app `test:integration` plus the dedicated `tests-e2e` suite)

**Backend**

- Go 1.21
- gorilla/mux
- REST API (`/api/health`, `/api/bugs`, `/api/bugs/{id}/comments`)
- testify
- bbolt

**Data**

- Embedded bbolt database (`DB_PATH`)
- Optional seed data via `SEED_DATA=true`

### CI/CD platform (to build)

- Jenkins Multibranch / multi-pipeline
- Jenkins Shared Library
- Jenkins Configuration as Code
- GitHub (GitHub Enterprise compatible)
- Docker
- Container Registry
- Kubernetes
- Helm

### Quality and testing (reuse + extend)

| Concern | Tool | Status |
|---|---|---|
| Backend unit / coverage | `go test`, `go tool cover` | Exists |
| Frontend unit / component / coverage | Jest, RTL, jest-junit | Exists |
| API | Playwright (`tests-api`) | Exists |
| E2E | Playwright (`tests-e2e`) | Exists |
| Performance | k6 (`tests-perf`) | Exists, light script |
| Frontend lint | ESLint / `next lint` | Exists |
| BDD | Cucumber + Gherkin on bug lifecycle | To add |
| Visual regression | Playwright screenshots | To add |
| Smoke / sanity | Thin API + E2E slices | To add |
| Backend lint | golangci-lint | To add |
| Dependency / image security | govulncheck, Trivy | To add |
| Quality gate | Coverage + lint + scan thresholds | To add |
| Optional quality server | SonarQube | Optional if local cost is acceptable |

### Observability (to add)

- Prometheus
- Grafana
- Loki
- OpenTelemetry (later)
- Jaeger / Tempo (later)

Observability covers both the Jenkins platform and the deployed Bug Tracker application.

---

## 5. Test Strategy

The project uses a layered and scenario-driven testing strategy.

Instead of one giant regression job, tests are organized into reusable suites.

```
Test Types
     │
     ▼
Test Suites
     │
     ▼
Test Scenarios
     │
     ▼
Pipeline Policies
     │
     ▼
Execution
```

The same suite can be reused by different pipelines.

This distinction is critical:

- **Test type** describes *how* the system is tested (unit, API, E2E, visual, performance).
- **Test scenario** describes *why* the tests run (PR validation, nightly regression, release validation, production smoke).

A regression scenario is a business validation objective composed of multiple suites. It is not a single test type.

---

## 6. Test Types

### 6.1 Static analysis

Validates source before functional tests.

- Frontend: `next lint` / ESLint
- Backend: `gofmt` / golangci-lint
- Dependency analysis: npm audit / govulncheck

Purpose: fast feedback.

Typical execution: every PR.

### 6.2 Unit testing

Tests individual components in isolation.

**Backend**

- Handlers (`bugs`, `comments`, `health`)
- DB layer
- Models
- Main wiring

**Frontend**

- React component tests
- API client tests (`src/api/bugs.test.ts`)
- Hook / utility tests as they appear

Purpose: fast verification of local business logic.

### 6.3 API testing

Validates REST APIs independently from the browser.

Existing coverage in `tests-api`:

- `GET /api/health`
- `POST /api/bugs`
- `GET /api/bugs/{id}`
- `PUT /api/bugs/{id}`
- Comments endpoints as the suite grows

Validation includes HTTP status, response schema, business rules, and error handling.

Purpose: validate service contracts and business APIs.

### 6.4 Integration testing

Tests interactions across components with real dependencies.

Current realistic path for this app:

```
API
 ↓
Handler
 ↓
bbolt
```

Purpose: validate real storage and service integration. Do not introduce Kafka or Redis unless the application actually uses them.

### 6.5 Component testing

Frontend components are tested independently with Jest + RTL.

Existing examples:

- `BugList`
- `AddBugModal`
- `EditBugModal`
- `CommentSection`
- `DeleteConfirmationModal`
- `Notification`

Validates rendering, interaction, state, error / loading states, and input validation.

### 6.6 BDD testing

Business behavior expressed in Gherkin, executed through Cucumber.

Example:

```gherkin
Feature: Bug lifecycle

  Scenario: User creates a bug successfully
    Given the API is healthy
    When the user creates a bug with title "Login button broken"
    Then the bug should be created successfully
    And the bug status should be "Open"
    And the bug priority should be "Medium"
```

Execution:

```
Gherkin → Cucumber → Step definitions → Bug Tracker API / UI → Report
```

Purpose: bridge business requirements and executable acceptance tests.

Domain must stay Bug Tracker (bugs, comments, priority, status). Do not use Order / Payment examples.

### 6.7 End-to-end testing

E2E tests validate complete user workflows.

Existing flow in `tests-e2e`:

```
Open homepage
 ↓
Add New Bug
 ↓
Fill title / description / priority
 ↓
Verify bug on list and detail page
 ↓
Delete bug
 ↓
Verify it is gone
```

Technology: Playwright.

E2E is a higher-cost layer. It should not necessarily run for every commit.

### 6.8 Visual regression testing

Validates UI appearance.

```
Browser
   ↓
Render bug list / bug detail
   ↓
Screenshot
   ↓
Baseline comparison
   ↓
Visual difference
```

Useful for the dashboard list, detail page, modals, and responsive layout.

Technology: Playwright screenshots.

### 6.9 Regression testing

Regression verifies that previously working functionality has not been broken.

A regression scenario is a composition:

```
Regression Scenario: Bug Lifecycle
    ├── Backend unit tests
    ├── API tests
    ├── Integration tests
    ├── Frontend component tests
    ├── Playwright E2E
    ├── BDD
    └── Visual regression
```

### 6.10 Smoke testing

Fast validation that a deployed application is basically functional.

```
GET /api/health
        ↓
Create one bug via API
        ↓
Open homepage
        ↓
Critical UI control ("Add New Bug")
```

Smoke tests must be small, fast, stable, and high-value.

Typical execution: after deployment.

### 6.11 Sanity testing

Focuses on the area affected by a recent change.

Example: comment API changed

```
Comment Sanity Suite
  ├── Add comment
  ├── List comments
  └── CommentSection component test
```

Faster feedback than full regression.

### 6.12 Contract testing

Optional later. The current app is a single backend plus one frontend, so Pact is not required in P1.

If a second consumer appears, contract tests can verify that the frontend and backend still agree on `/api/bugs` and `/api/bugs/{id}/comments`.

### 6.13 Security testing

Integrated into CI where cost is acceptable.

- Dependency / CVE scan: govulncheck, npm audit
- Container scan: Trivy on backend and frontend images
- API security: invalid input, missing fields, basic access assumptions

Optional later: OWASP ZAP against TEST.

### 6.14 Performance testing

Intentionally separated from normal CI.

Existing k6 script covers health + create-bug with thresholds:

- `http_req_failed` rate < 1%
- p95 < 500ms

Extend later into:

- Load
- Stress
- Spike
- Soak
- Capacity

Metrics: throughput, latency (p50 / p95 / p99), error rate, CPU, memory.

Run against TEST or a production-like environment, not production, and not on every PR.

### 6.15 Chaos / resilience testing

Optional advanced phase.

Examples:

- Kill the backend pod and observe recovery
- Make the bbolt volume unavailable and observe application behavior

Purpose: validate resilience, not functional correctness.

---

## 7. Test Scenario Model

| Test type (how) | Test scenario (why) |
|---|---|
| Unit, API, Integration, BDD, E2E, Visual, Performance, Security | PR Validation, Smoke, Sanity, Regression, Release, Nightly, Performance, Production Verification |

Example:

```
Regression Scenario
        │
        ├── Unit
        ├── API
        ├── Integration
        ├── Component
        ├── BDD
        ├── E2E
        └── Visual Regression
```

---

## 8. Test Scenario Matrix

| Scenario | Unit | API | Integration | Component | BDD | E2E | Visual | Security | Performance |
|---|---|---|---|---|---|---|---|---|---|
| PR Validation | Yes | Yes | Yes | Yes | Optional | No | No | Yes | No |
| Sanity | Yes | Yes | Yes | Yes | Optional | Yes | No | No | No |
| Master Validation | Yes | Yes | Yes | Yes | Yes | Yes | Optional | Yes | No |
| Nightly Regression | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | No |
| Release Validation | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Optional |
| Performance | No | No | No | No | No | No | No | No | Yes |
| Production Smoke | No | Yes | Optional | No | No | Yes | No | No | No |

Pipeline policy defines the minimum quality bar. Developers may add extra suites. They must not disable mandatory gates.

---

## 9. Pipeline Architecture

Use multiple pipelines rather than one giant Jenkinsfile.

```
Jenkins
│
├── CI
│   ├── PR Validation
│   └── Master Validation
│
├── Scheduled
│   └── Nightly Regression
│
├── CD
│   ├── Deploy TEST
│   ├── Deploy STAGING
│   └── Deploy PROD
│
├── Performance
│   └── Load / Stress Testing
│
└── Operations
    ├── Health Check
    └── Smoke Test
```

### 9.1 PR pipeline

Objective: fast developer feedback. Target: under 10 minutes.

```
Checkout
   ↓
Static Analysis
   ↓
Backend + Frontend Unit Tests
   ↓
Frontend Component Tests
   ↓
API Tests
   ↓
Small Integration Suite
   ↓
Coverage
   ↓
Quality Gate
   ↓
PR Status
```

Avoid full E2E, full regression, and performance testing on every PR.

### 9.2 Master pipeline

Triggered after merge to the default branch.

```
Checkout
   ↓
Build
   ↓
Unit + Integration + API
   ↓
BDD
   ↓
E2E
   ↓
Coverage + Quality Gate
   ↓
Docker Build
   ↓
Image Scan
   ↓
Push Image
```

### 9.3 Nightly pipeline

Continuous regression detection at a sustainable cost.

```
Nightly Trigger
      ↓
Environment Preparation
      ↓
Extended Regression
      ↓
BDD + E2E + Visual
      ↓
Security Regression
      ↓
Report Aggregation
      ↓
Notification
```

Nightly does not need to be identical to release validation.

### 9.4 Release pipeline

Focused on production confidence.

```
Release Candidate
       ↓
Full Regression
       ↓
BDD + E2E + Visual + Security
       ↓
Select Immutable Images
       ↓
Deploy TEST → Smoke
       ↓
Deploy STAGING → Extended Validation
       ↓
Manual Approval
       ↓
Deploy PROD → Production Smoke
       ↓
Observe
```

### 9.5 Performance pipeline

Isolated from normal CI.

```
Performance Trigger
       ↓
Prepare Environment
       ↓
Load / Stress / Spike / Soak
       ↓
Collect Metrics
       ↓
Performance Report
       ↓
Threshold Evaluation
```

### 9.6 Test profiles

Suites are configured, not hardcoded into every Jenkinsfile.

PR profile:

```yaml
profile: PR
tests:
  static: true
  unit: true
  component: true
  api: true
  integration: true
  bdd: false
  e2e: false
  visual: false
  security: true
  performance: false
```

Nightly profile:

```yaml
profile: NIGHTLY
tests:
  static: true
  unit: true
  component: true
  api: true
  integration: true
  bdd: true
  e2e: true
  visual: true
  security: true
  performance: false
```

Release profile:

```yaml
profile: RELEASE
tests:
  static: true
  unit: true
  component: true
  api: true
  integration: true
  bdd: true
  e2e: true
  visual: true
  security: true
  performance: false
```

Performance profile:

```yaml
profile: PERFORMANCE
tests:
  performance: true
```

---

## 10. Docker Image Strategy

Build once. Promote the same immutable images.

```
Source Code
     ↓
Build
     ↓
Test
     ↓
Docker Build
     ↓
Registry
```

Example tags:

```
bugtracker-backend:<gitsha>
bugtracker-frontend:<gitsha>
```

Promotion:

```
bugtracker-*:abc1234
        │
        ├── TEST
        ├── STAGING
        └── PROD
```

The CD pipeline does not rebuild the application.

Existing Dockerfiles:

- `bugtracker-backend/Dockerfile`
- `bugtracker-frontend/Dockerfile`

---

## 11. Kubernetes Deployment

Deploy with Helm.

```
helm/bugtracker/
├── Chart.yaml
├── values.yaml
├── values-test.yaml
├── values-staging.yaml
├── values-prod.yaml
└── templates/
```

Environment differences:

- Replica count
- CPU / memory
- HPA
- Environment variables (`DB_PATH`, `SEED_DATA`, `NEXT_PUBLIC_API_URL`)
- Service endpoints
- Ingress
- Persistence for bbolt

Production flow:

```
Staging Validation
       ↓
Manual Approval
       ↓
Helm Deployment
       ↓
Rolling Update
       ↓
Readiness Check
       ↓
Smoke Test
       ↓
Observability
```

Rollback:

```bash
helm rollback bugtracker <REVISION>
```

---

## 12. Jenkins on Kubernetes

Jenkins runs with Kubernetes-based dynamic agents.

```
Jenkins Controller
        │
        ▼
Pipeline Queue
        │
        ▼
Kubernetes
        │
 ┌──────┼──────┐
 │      │      │
Agent  Agent  Agent
```

```
Pipeline Start
      ↓
Create Agent
      ↓
Execute
      ↓
Publish Results
      ↓
Destroy Agent
```

Benefits: isolation, horizontal scale, better utilization, reduced controller workload, reproducible environments.

The current Compose + DinD setup in `jenkins/` remains a local bootstrap path. The solution path replaces it with Jenkins-on-Kubernetes for real pipeline execution.

### Reliability

Treat Jenkins as a production platform.

Monitor:

- Controller: CPU, memory, JVM heap, GC, disk, queue, executor utilization
- Agents: provisioning time, availability, pod failures, startup failures
- Pipelines: success rate, queue time, execution time, test duration, deploy duration

Fault tolerance:

- Persistent Jenkins configuration
- JCasC
- Automated backup
- External artifact storage
- External container registry
- Ephemeral Kubernetes agents
- Agent and controller recovery
- Plugin version management

Do not treat Jenkins as a stateless app with naive active-active replicas.

```
Jenkins Controller
       │
       ├── Persistent Configuration
       ├── Backup / Recovery
       └── Dynamic Kubernetes Agents
```

### Multi-tenancy (optional later)

Logical isolation for multiple teams:

```
Jenkins
│
├── Bug Tracker
│   ├── PR
│   ├── Master
│   ├── Nightly
│   └── Release
│
└── Future Tenant
    ├── PR
    ├── Master
    └── Release
```

Shared platform pieces: controller, shared libraries, Kubernetes cluster, observability, registry.

### SLA targets (engineering targets, not claimed results)

| Metric | Target |
|---|---|
| Jenkins availability | 99.9% |
| PR feedback | < 10 min |
| Pipeline success rate | > 95% |
| Agent provisioning | < 60 sec |
| Rollback | < 5 min |
| Nightly completion | < 90 min |

Validate these through benchmarking before presenting them as achieved.

---

## 13. Test Reporting

Every stage should produce machine-readable and human-readable reports.

| Layer | Reports |
|---|---|
| Backend | JUnit XML, Go coverage HTML (`coverage.html`) |
| Frontend | jest-junit XML, Jest coverage HTML |
| API / E2E | Playwright HTML + JUnit |
| BDD | Cucumber / Serenity-style report |
| Visual | Screenshot baseline + diff |
| Performance | k6 HTML (`perf-results.html`), p50 / p95 / p99, error rate |
| Security | Trivy / govulncheck output |

The current Jenkinsfile already publishes backend and frontend coverage HTML. The solution should keep that pattern and extend it to the other suites.

---

## 14. Code Quality

```
Build
 ↓
Test
 ↓
Coverage
 ↓
Lint / Scan / Optional SonarQube
 ↓
Quality Gate
```

Suggested gates (tune to the project):

- Coverage >= 80% on new or overall code where practical
- Critical bugs = 0
- Blocker vulnerabilities = 0
- Lint must pass

Prefer golangci-lint + ESLint + coverage thresholds for a local-first solution. Add SonarQube if the environment can host it.

---

## 15. Failure Handling

Classify failures:

```
Pipeline Failure
       │
       ├── Test Failure
       ├── Application Failure
       ├── Infrastructure Failure
       ├── Environment Failure
       └── Pipeline Failure
```

Notification example:

```
Bug Tracker Pipeline FAILED

PR: #42
Commit: abc1234
Stage: API Test

Failed Suite:
Bug API Regression

Failed Test:
Update a bug

Environment:
TEST

Duration:
8m 32s

Report:
Jenkins / Test Report
```

Channels: Slack, email, GitHub checks.

### Production incident feedback loop

```
Production Incident
        ↓
Root Cause Analysis
        ↓
Identify Missing Coverage
        ↓
Create Automated Test
        ↓
Classify Test Type
        ↓
Add to the relevant Regression Scenario
        ↓
Bind to Pipeline Profile
        ↓
Execute Automatically
        ↓
Prevent Regression
```

P0/P1 incidents should become permanent automated protection.

---

## 16. Observability

Observe CI infrastructure and application runtime.

```
                 Observability
                      │
          ┌───────────┼───────────┐
          │           │           │
       Metrics       Logs       Traces
          │           │           │
     Prometheus      Loki    OpenTelemetry
          │           │           │
          └───────────┼───────────┘
                      │
                   Grafana
```

Application signals to start with:

- Backend `/api/health`
- Request rate and latency for `/api/bugs`
- Pod CPU / memory
- Container logs

Jenkins signals to start with:

- Queue depth
- Agent provision time
- Pipeline duration and result
- Controller resource usage

---

## 17. Engineering Principles

1. **Build once, promote many.** Build → Test → Image → Registry → TEST → STAGING → PROD. The same immutable artifact is promoted.
2. **Test according to risk.** PR is fast feedback. Master is integration confidence. Nightly is continuous regression detection. Release is production confidence. Performance is capacity validation.
3. **Automate quality gates.** Tests must produce release decisions, not only logs.
4. **Separate test types from test scenarios.** How vs why.
5. **Production incidents improve coverage.** Missing tests become regression suites.
6. **CI infrastructure is a production platform.** Jenkins needs scalability, reliability, observability, security, backup, recovery, and SLA.

---

## 18. Success Criteria

The project is complete when this workflow can be demonstrated end to end:

```
Developer
   ↓
GitHub
   ↓
Pull Request
   ↓
Jenkins PR Pipeline
   ↓
Automated Tests
   ↓
Coverage + Code Quality
   ↓
PR Status
   ↓
Merge
   ↓
Master Pipeline
   ↓
Docker Images
   ↓
Container Registry
   ↓
Kubernetes TEST
   ↓
Smoke Test
   ↓
STAGING
   ↓
Extended Validation
   ↓
Manual Approval
   ↓
PRODUCTION
   ↓
Production Smoke Test
   ↓
Prometheus / Grafana / Loki
   ↓
Release Result
```

In parallel:

```
Nightly → Regression → BDD → E2E → Visual → Report → Notification
```

Independently:

```
Performance Pipeline → Load / Stress / Spike / Soak → Report
```

---

## 19. Solution Project Layout

Existing application and `tests-*` directories stay in the repository root. `jenkins-k8s-solution/` orchestrates them.

```
jenkins-k8s-solution/
  PLAN.md
  README.md                 # later, derived from this plan
  jenkins/
    casc/                   # JCasC
    shared-library/
    pipelines/              # pr / master / nightly / release / perf / deploy
    agents/                 # pod templates
    profiles/               # pr.yaml, master.yaml, nightly.yaml, ...
  helm/bugtracker/
  observability/
  tests/                    # bdd, visual, smoke wrappers, or pointers to repo suites
```

---

## 20. Implementation Phases

### P0 — Design (this document)

Write this PLAN.md. No application code changes.

### P1 — Test engine

- Define profiles: `pr`, `master`, `nightly`, `release`, `performance`, `prod-smoke`
- Split smoke and sanity from the existing API / E2E suites
- Add BDD on bug create / update / comment
- Add Playwright visual snapshots for list and detail pages
- Aggregate reports
- Bind suites to PR vs master vs nightly

### P2 — Jenkins on Kubernetes

- Controller + JCasC
- Shared library that reads profiles and runs suites
- Ephemeral agents / pod templates
- Keep `jenkins/` Compose + DinD as a local fallback only

### P3 — CD

- Helm chart and env values
- Registry
- Promote immutable images TEST → STAGING → PROD
- Post-deploy smoke
- Helm rollback

### P4 — Quality and security

- Coverage and lint gates
- Trivy image scan
- govulncheck / npm audit
- Failure notifications and GitHub checks

### P5 — Observability

- Prometheus / Grafana / Loki for Jenkins and Bug Tracker
- Dashboards
- Treat SLA numbers as targets until measured

### P6 — Optional

- Multi-tenant Jenkins folders
- Chaos / pod-kill experiments
- Pact if a second consumer appears
- Heavier k6 soak / capacity profiles
- Incident-to-regression runbook

---

## 21. Resume-Oriented Summary

This project demonstrates the ability to design and implement a production-oriented automated testing and CI/CD platform, rather than only configuring Jenkins jobs.

Capabilities to demonstrate:

- Enterprise-style Jenkins architecture
- GitHub integration
- Kubernetes-based Jenkins agents
- CI/CD orchestration
- Scenario-driven test strategy
- Playwright API / E2E / visual automation
- Jest component testing
- Go unit / integration testing
- BDD
- k6 performance testing
- Security scanning
- Test reporting
- Coverage and quality gates
- Docker image lifecycle
- Helm-based Kubernetes deployment
- Release governance
- Production smoke testing
- Jenkins observability
- Fault tolerance and scalability
- Incident-driven test improvement

The objective is to transform business and production risks into automated, observable, scalable, and enforceable quality gates throughout the software delivery lifecycle.
