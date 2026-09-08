# Testing Architecture Around the Software Lifecycle

Jenkins can run a pipeline. It should not define the testing architecture.

This document is the SDET contract for `jenkins-k8s-solution`. It turns the lifecycle model behind the public write-up *Design a Testing Architecture Around the Software Lifecycle* into something this repository can implement against Bug Tracker.

The CI/CD platform is the execution layer. Kind, Helm, and Jenkins agents exist so the strategy can run. They are not the architecture.

Related:

- Platform overview: [README.md](../README.md)
- Frontend layering: [frontend-test-design.md](./frontend-test-design.md)
- Not yet landed: [test-implementation-gaps.md](./test-implementation-gaps.md)
- Jenkins execution on kind: [jenkins-on-kind.md](./jenkins-on-kind.md)
- Implementation blueprint: [PLAN.md](../PLAN.md)

---

## 1. Why this document exists

A common CI/CD sketch starts with the tool:

```
Jenkins → Build → Deploy → Test → Production
```

That describes how software is delivered. It does not describe how confidence is established.

A stronger design starts from the software lifecycle. Different stages need different levels of confidence. Each level should use the **cheapest test that can detect that class of failure**.

The rule:

> Run the cheapest test at the earliest lifecycle stage that can reliably detect the failure.

A defect a unit test can catch should not survive until E2E. A contract break should not wait for production. A production-only latency or error-budget problem cannot be solved by adding more PR tests.

This project is an SDET platform around Bug Tracker. Deployment mechanics (traffic mesh, Ingress, Helm flags) stay out of this document. Where delivery appears, it appears as a **validation problem**: canary, instrumentation, promotion, rollback.

---

## 2. Six dimensions that must stay distinct

These are not synonyms.

| Dimension | Question | Examples in this project |
|---|---|---|
| **Test type** | What is being validated? | Unit, component, API, E2E, load, soak |
| **Test strategy** | Why and how is a set of tests selected? | Smoke, regression, sanity, release validation, critical path |
| **Specification style** | How is the behavior written? | BDD / Gherkin. Not a layer. A scenario may run as API, integration, or E2E. |
| **Engineering scenario** | What triggered validation? | PR, merge, nightly, release, hotfix, canary |
| **Lifecycle stage** | When is it affordable to run? | Local → PR → build → integration → staging → canary → production |
| **Environment** | Where does it run? | Dev, TEST / integration, staging, canary / gray, production |
| **Pipeline** | How is the strategy automated, promoted, observed, and rolled back? | Jenkins profiles, quality gates, canary windows |

A pipeline is not a test suite. A suite is not a test type. Smoke is not a competitor to E2E.

```
Test Type          what we validate
     │
Test Strategy      why we select those tests
     │
Test Suite         a named composition with an objective
     │
Engineering Scenario   PR / merge / nightly / release / canary
     │
Lifecycle + Environment   when and where
     │
Pipeline           orchestration, gates, promotion, rollback
```

---

## 3. Test types (what)

Test types describe technical scope. They do not describe why a pipeline fired.

### Functional types

| Type | Claim | Bug Tracker location |
|---|---|---|
| Static analysis | The change is writable and consistent | `golangci-lint` (to add), `next lint` |
| Unit | A function / class / helper is correct in isolation | `bugtracker-backend/**/*_test.go`, frontend helpers / `src/api/bugs.test.ts` |
| Component | A UI unit renders and reacts without a live backend | `bugtracker-frontend/**/*.test.tsx` |
| API | The HTTP boundary behaves | `tests-api/` |
| Integration | Real collaborators work together | `tests-integration/`; Go `internal/integration` (HTTP → bbolt) |
| Contract | A consumer/provider boundary stays compatible | Out of V1 until a second consumer exists |
| E2E | A user can complete a journey in a browser | `tests-e2e/` |
| Visual | A named screen still looks right | Playwright screenshots in `tests-visual/` |

### Non-functional types

| Type | Claim | Bug Tracker location |
|---|---|---|
| Security | Dependencies and images are not obviously unsafe | `tests-security/` (`govulncheck`, `npm audit`, Trivy, API abuse) |
| Load / stress / spike / soak | Capacity and degradation under traffic | `tests-perf/` (k6; extend later) |
| Resilience | Recovery from dependency failure | Later; not a PR suite |

Unit tests stay away from infrastructure. They should not need kind, Kafka, or a cluster to prove `validate()` is wrong.

BDD is not listed as a type. Gherkin states a business rule. The driver underneath may be API, integration, or E2E.

---

## 4. Test strategies (why)

Regression, smoke, sanity, release validation, and critical-path testing do **not** introduce a new driver. They select and compose types.

| Strategy | Objective | Typical composition |
|---|---|---|
| **Smoke** | Is the deployed version basically alive? | Health, one critical API, one critical UI control |
| **Sanity** | Did this local change still work? | Subset of component / API / E2E around the diff |
| **Regression** | Did previously proven behavior hold? | Unit + API + integration + BDD + E2E (+ visual when the bar is appearance) |
| **Release validation** | Can we promote this artifact? | Smoke after deploy + full regression + security + selected performance |
| **Critical path** | Do the journeys that lose the business still work? | Thin E2E / API against create / read / update / comment / delete |
| **Canary validation** | Does the new version hold under a small slice of real (or realistic) traffic? | Critical path + **instrumentation assertions** (metrics, logs, traces, business KPIs) |

A unit test can belong to regression. An API test can belong to smoke. An E2E test can be both regression and critical path. The type did not change. The strategy did.

---

## 5. Suites are composed by objective

Do not name suites only after a technology (`e2e-suite`) and then treat that name as a pipeline. A suite has a **testing objective** and composes types underneath.

| Suite | Objective | Composition |
|---|---|---|
| **PR Validation** | Keep obvious defects off main | Static, unit, component, API, security audit |
| **Merge / Master** | The integrated codebase still behaves | PR suites + BDD + E2E |
| **Regression** | Previously working behavior remains | Unit, API, integration, E2E, critical flows, visual on nightly/release |
| **Release Validation** | Production confidence for this artifact | Smoke + regression + E2E/BDD + security + optional performance |
| **Nightly** | Continuous, expensive detection | Full regression, visual, extended E2E, optional load |
| **Production / Canary** | Control blast radius while proving the new version | Smoke, critical path, instrumentation, rollback signal |

Ownership (SDET lens, not org-chart dogma):

- Developers: unit, component, fast API
- Service / API owners: API, integration, contracts
- SDET / QA: cross-layer E2E, BDD, visual, release suites, canary instrumentation, production synthetic checks

---

## 6. Lifecycle: when a test is allowed to exist

```
Local → PR / CI → Build (artifact) → Integration → Staging
      → Production canary → Progressive rollout → 100% production
```

Each step increases environmental realism, cost, and confidence.

### Local

Cheapest line of defense. `go test`, Jest, lint. No cluster. A developer changing bug priority handling should not wait for kind to learn the function is wrong.

### Pull request / CI

Protect the main branch. Fast and deterministic.

```
PR Validation = { Static, Unit, Component, API, Security audit }
```

No full production-like deploy. Fail as early as the cost is justified.

### Build

Produce the artifact that later environments will test.

```
Compile → unit / component / API → quality / security scan → image → publish
```

**Build once, promote many.** Later stages test the same image. If staging rebuilds, staging results do not describe what production will run.

### Integration environment

Real collaborators appear: Go API, bbolt, Next.js, the deployed URL. Assertions move past HTTP 200 when the product has business state. For Bug Tracker that means:

```
Bug created     → GET returns it
Bug updated     → status / priority persist
Comment added   → comment list contains it
Bug deleted     → GET is 404 / list no longer shows it
Health          → /api/health is live
```

That is the analogue of payment systems asserting `Order=CONFIRMED` rather than `200`. The domain is smaller; the rule is the same.

### Staging

Production-like enough for broader strategy:

```
Deploy → Smoke → PASS → Regression → E2E / BDD → Performance / Security
```

Smoke is intentionally small. It proves the version is alive before spending the expensive suites. BDD does not create a new lifecycle stage. The same business story may run as API or browser depending on which claim we need.

### Production changes the risk model

Pre-production asks: does it work?  
Production asks: does the **new version** work under real conditions while we control blast radius?

That is canary, synthetic checks, critical path, **instrumentation**, and rollback. Not a bigger Jenkinsfile.

---

## 7. Environment is a separate axis

Strategy does not only decide which tests and when. It decides **where**.

```
Dev → TEST / Integration → Staging → Canary / Gray → Production
```

| Environment | Why it exists | Typical validation |
|---|---|---|
| Dev | Fast feedback | Unit, component, API, lint |
| TEST / Integration | Shared or ephemeral stack | API, integration, contract, subset of regression |
| Staging | Production-like | Smoke, regression, E2E/BDD, security, performance |
| Canary / gray | Real characteristics, small blast radius | Critical path, synthetic, **instrumentation**, business KPIs |
| Production | Remaining risk + continuous proof | Smoke / synthetic, monitoring, tracing, automated rollback |

The same E2E can run in staging as release validation and against canary as a critical-path check. The test file did not change. Purpose, environment, and risk did.

---

## 8. Engineering scenarios and pipelines

The lifecycle says when. Types say what. Scenarios say **why this pipeline exists**. A mature platform is several pipelines, not one giant job.

### Commit / PR

Protect the codebase before merge.

```
Checkout → static → unit → component → API → security audit
```

Question: can this change enter the codebase?

### Merge / master

Validate the integrated tree, still against the same artifact recipe.

```
Build artifact → component / API → BDD / E2E → publish image
```

Question: does the combined codebase still behave?

### Nightly

Expensive suites that must not block every PR: full regression, visual, extended E2E, soak, optional resilience.

```
Deployment feedback  →  PR / merge pipelines
System-level feedback →  nightly pipeline
Release confidence    →  release pipeline
```

They complement each other.

### Release

Explicit production intent. Stronger validation and a promotion policy.

```
Release candidate → artifact verification → staging → smoke
  → full regression → E2E / BDD → performance / security
  → approval (Delivery) or auto-promote (Deployment)
  → production canary validation
```

Continuous Delivery and Continuous Deployment share this testing architecture. They differ only in whether a human is required before production.

### Canary / progressive delivery (validation pipeline)

**No Istio, no mesh, no 1% live user split.** V1 canary is a **Jenkins promotion gate** against an isolated candidate revision. Blast radius is “only the canary URL is hit,” not “1% of customers.”

```
Stable remains on the previous image
    → Helm install/upgrade a second release: bugtracker-canary (same chart, new image)
    → Validation window (pipeline sleeps / loops tests, e.g. 5–15 min)
         synthetic smoke + critical path against CANARY_URL
         instrumentation: success ratio, latency of those calls, canary pod logs
    → FAIL → helm uninstall canary (stable untouched) = rollback
    → PASS → helm upgrade bugtracker to the same image, then uninstall canary
```

Widening 1% → 5% → 100% is a traffic-mesh story. The pipeline analogue is **one candidate window, then all-or-nothing promote**. That is enough to prove fail-closed rollback without Istio.

### Shadow (optional later)

Users still hit the stable version. A copy of traffic hits the candidate into an isolated store. V1 does not require a shadow stack.


---

## 9. Pipeline canary: how the validation window is verified

Canary is not “the deploy job went green.” It is **instrumented evidence** that a candidate revision is safe to become stable.

Istio is out. The runner is Jenkins; the isolation is a **second Helm release** (or a second namespace) with its own URL. Stable keeps serving the previous image until the window passes.

### 9.1 Shape of the job

```
stage('Deploy canary')
    helm upgrade --install bugtracker-canary ./helm/bugtracker
        -f values.yaml -f values-canary.yaml
        --set image.tag=${GITSHA}
    wait for canary pods Ready

stage('Canary window')          // e.g. 5–15 minutes
    loop until deadline:
        GET  ${CANARY_URL}/api/health
        POST ${CANARY_URL}/api/bugs     (create)
        GET  ${CANARY_URL}/api/bugs/{id}
        optional: thin Playwright against canary UI
        record pass/fail, latency
    kubectl logs -l app=bugtracker-canary --since=${WINDOW}

stage('Canary gates')
    smoke pass == 100%
    critical-path success ratio >= threshold   // e.g. 99% of loop iterations
    p95 latency <= baseline * 1.5 (or a fixed budget)
    canary logs contain no panic / 5xx handler burst

stage('Promote or rollback')
    PASS → helm upgrade bugtracker (stable) to ${GITSHA}
         → helm uninstall bugtracker-canary
    FAIL → helm uninstall bugtracker-canary
         → leave bugtracker (stable) on the previous revision
         → fail the pipeline
```

Stable is never mutated until gates pass. That **is** rollback: the candidate is thrown away.

Do not `helm upgrade` stable first and then hope `helm rollback` saves you. That is deploy-and-pray, not a canary.

### 9.2 What “instrumentation” means without a mesh

The pipeline **generates** the traffic (synthetic loop or a short k6 script against `CANARY_URL`). The gates are assertions on that traffic plus canary pod logs.

| Signal | V1 (no Prometheus required) | Later |
|---|---|---|
| Alive | `/api/health` every iteration | same |
| Business KPI | create-then-read success ratio in the window | same, plus real traffic |
| Latency | p95 of the loop / k6 | Prometheus histogram |
| Errors | non-2xx count from the loop; `kubectl logs` for panic | RED metrics, Loki |
| Traces | skip | Tempo / OTel |

A canary that returns 200 but cannot persist a bug fails the KPI gate. HTTP 200 alone is not enough.

Reuse existing suites against the canary base URL:

- smoke: health + one create (from a thin slice of `tests-api`)
- critical UI: homepage + `Add New Bug` (frontend `fe-smoke`)
- optional: `k6` with a small VUs count for the length of the window

Do not run full Nightly E2E inside the window. The window is **cheap, repeated, time-bounded**.

### 9.3 Kind / this repo

Until Bug Tracker has a Helm chart, the same job shape can target two Compose/K8s services (`:8080` stable, `:8081` canary) or two namespaces. `values-canary.yaml` would only differ by release name, image tag, and service port — same overlay pattern as `values-kind.yaml`.

Jenkins already runs ephemeral agents. The canary stages are just more pipeline steps on those agents (`helm`, `kubectl`, Playwright/k6). No sidecar, no VirtualService.

### 9.4 Gates (targets, not claimed SLOs)

| Gate | Intent |
|---|---|
| Synthetic smoke pass | Candidate is alive |
| Critical-path success ratio | Core journeys work for the whole window |
| Latency budget | No sudden p95 blow-up vs last stable run (store baseline as a build artifact) |
| Log error burst | No panic / new 5xx signature in canary logs |

FAIL → uninstall canary, fail the job. PASS → promote the **same image** to stable.

### 9.5 What this is not

- Not 1% of real users (that needs a mesh or weighted Ingress)
- Not a rolling update observed “by eye”
- Not rebuilding the image between canary and stable

It is a **CI/CD quality gate with a clock**: isolate revision → observe → promote or discard.

---

## 10. Rollback is a pipeline outcome

```
Deploy → Validate → Observe
              ├── PASS → promote (widen or 100%)
              └── FAIL → rollback
```

A canary path is a sequence of windows, not a single deploy stage. Failure at 1% must not wait for a human to remember the old Helm revision. The SDET artifact is the **fail condition and the evidence**, not the kubectl command.

---

## 11. Pipelines form a quality graph

Pipelines consume each other's results. They are not isolated jobs.

```
PR Validation
    ↓
Merge
    ↓
Build & integration
    ↓
Artifact (immutable image)
    ↓
TEST / staging validation
    ↓
Release
    ↓
Production canary (synthetic + instrumentation)
    ↓
Progressive rollout
    ↓
100% production
```

Upstream failure blocks downstream promotion:

```
Unit fail     → PR blocked → no merge
Integration fail → artifact not promoted
Staging regression fail → release blocked
Canary instrumentation fail → rollout stopped → rollback
```

This is a quality dependency graph. Each node produces an artifact, a suite result, an environment state, or a promotion decision.

---

## 12. Performance and resilience follow the same rule

| Type | Question | Where it belongs |
|---|---|---|
| Load | Does expected traffic hold? | Staging / nightly, not every PR |
| Stress | What happens past capacity? | Nightly / release |
| Spike | Can we absorb a burst? | Nightly / release |
| Soak | Do we leak over hours? | Nightly. A 10-minute PR job cannot prove an 8-hour leak |
| Resilience | Do we recover from a dead dependency? | Staging / canary / dedicated chaos. Unit tests can prove retry *logic*; they cannot prove the live dependency recovered |

k6 in `tests-perf/` is the V1 performance seed. Expand profiles later. Do not dump soak onto PR.

---

## 13. Mapping this repository

| Article concept | This repo |
|---|---|
| System under test | Bug Tracker (Go API + Next.js), not a payment/Kafka stack |
| Unit / component | `go test`, Jest + Testing Library |
| API | `tests-api` |
| Integration | `tests-integration`, `bugtracker-backend/internal/integration` |
| E2E | `tests-e2e` |
| Visual | `tests-visual` |
| BDD | `tests-bdd` |
| Security | `tests-security` |
| Performance | `tests-perf` (k6) |
| Business state | Bug + comment CRUD, not ledger/saga |
| Artifact | Frontend and backend images, promoted unchanged |
| Execution | Jenkins on kind, ephemeral agents ([jenkins-on-kind.md](./jenkins-on-kind.md)) |
| Frontend assignment | [frontend-test-design.md](./frontend-test-design.md) |
| Canary | Validation windows + instrumentation; split mechanism later |
| Production feedback | Incident → missing test → regression suite → gate |

Do not add PostgreSQL, Kafka, or Redis to Bug Tracker to make the diagram look like a payments platform. The **model** transfers. The **product** stays this app.

---

## 14. Core design principle

```
Test type:            What is being validated?
Test strategy:        Why and how is it selected?
Engineering scenario: What triggered this run?
Lifecycle stage:      When is it affordable?
Environment:          Where does it run?
Pipeline:             How do we automate, promote, observe, and roll back?
```

The goal is not more tests. The goal is the **right validation**, in the **right environment**, at the **right point in the lifecycle**, with fast feedback and small production risk.

That is what turns CI/CD from a deploy mechanism into a quality architecture. Jenkins, GitHub Actions, or AWS CodePipeline can all walk the same graph. This repository happens to walk it with Jenkins.

---

## 15. Implementation notes (SDET first)

Already in the repo: backend unit, frontend unit/component, API, E2E, visual, BDD, security (`tests-security`), light k6, Jenkins on kind as the runner.

Still to add, in this order:

1. Profiles that bind suites to PR / master / nightly / release / smoke / canary
2. Wire `tests-api` and `fe-smoke` into Jenkins; sanity remains on-demand
3. Canary UI smoke + metric / log gates beyond the current wget loop
4. Incident → regression feedback as a documented loop

Helm for Bug Tracker, Ingress, and real traffic splitting wait until the validation contract is stable. Kind Jenkins is enough to execute the suites.
