# Designed tests that are not landed yet

This is the implementation backlog against [testing-architecture.md](./testing-architecture.md) and [frontend-test-design.md](./frontend-test-design.md).

**Landed today** (code exists *and* a Jenkins-k8s pipeline runs it): backend `go test`, frontend `next lint` + Jest unit/component.

**Exists in the repo but not wired** into `jenkins-k8s-solution` pipelines: `tests-api`, `tests-e2e`, `tests-perf`.

**Designed, no suite yet:** golangci-lint. Security is in `tests-security/`; BDD in `tests-bdd/`; visual in `tests-visual/`.

Visual regression is implemented in this pass. Everything else below is the remaining how-to.

---

## 1. Gap matrix

| Suite / type | Design | Code today | Jenkins-k8s today | Folder to own it |
|---|---|---|---|---|
| Static (frontend) | PR+ | `next lint` | PR, Master | `bugtracker-frontend` |
| Static (backend) | PR+ | Missing | Missing | `bugtracker-backend` + `golangci-lint` |
| Unit backend | PR+ | `go test ./...` | PR, Master, Nightly | `bugtracker-backend` |
| Unit + component frontend | PR+ | Jest + RTL | PR, Master, Nightly | `bugtracker-frontend/src/**/*.test.*` |
| API | PR+ | `tests-api/api.spec.ts` | **Not in new Jenkinsfiles** (only course Compose Jenkins) | `tests-api/` |
| Shared API fixtures | Under BDD / E2E / visual | `tests/fixtures/` | used by visual + BDD | `tests/fixtures/` |
| Integration | PR+ | **`internal/integration` + `tests-integration/`** | PR (Go httptest); Master/Nightly/Release (HTTP chain) | `tests-integration/` |
| E2E journeys | Master / Nightly / Release | `tests-e2e/integration.spec.ts` | Nightly is an echo placeholder | `tests-e2e/` |
| BDD / Gherkin | Master / Nightly / Release | **`tests-bdd/`** | Master (in-pod API), Nightly (stable API), Release (canary API) | `tests-bdd/` |
| Visual checkpoints | Nightly / Release | **`tests-visual/` (this pass)** | Wire Nightly | `tests-visual/` |
| fe-smoke | After deploy, production smoke | Missing | Missing | `tests-e2e/smoke.spec.ts` |
| Canary synthetic | Release window | Health + POST `/api/bugs` loop | Partial in `release.Jenkinsfile` | keep in Jenkinsfile; optional thin `tests-api` slice |
| npm audit | PR+ | **`tests-security/scripts/npm-audit.sh`** | PR/Master/Nightly (UNSTABLE while Next CVEs remain) | `tests-security/` |
| Image scan (Trivy) | Master / Nightly / Release | **`tests-security/scripts/trivy-*.sh`** | Master after Kaniko; Release before canary | `tests-security/` |
| govulncheck | PR / Master | **`tests-security/scripts/govulncheck.sh`** | PR, Master, Nightly | `tests-security/` |
| Performance (k6) | Nightly / Performance job | `tests-perf/script.js` (light) | Missing | `tests-perf/` + profiles later |

PR/Master still do **not** run API or E2E. That is a wiring gap, not a missing product test.

---

## 2. Visual regression (landed in this pass)

### Tool choice

Use **Playwright's built-in `toHaveScreenshot()`** (pixelmatch). That is the default Playwright visual path in US/EU teams, already matches [frontend-test-design.md](./frontend-test-design.md) §12, and needs no extra SaaS token.

Do **not** add Chromatic / Storybook for this UI (two pages). Hosted services (Percy, Argos CI) are optional later if baselines should live in the cloud instead of git.

### How it is supposed to run

```
API seed (precondition)
    → click the remaining UI of the journey
    → named checkpoint screenshot
    → compare to committed baseline
```

Not: Gherkin step → click → screenshot → next step.

| Journey | Precondition | UI, then checkpoint |
|---|---|---|
| Create | Empty list (GET stub or cleaned store) | Empty list; Add Bug modal; fill + submit → list after create |
| Edit | One Open / Medium bug via API | Detail page; Edit Bug modal |
| Comment | One bug + two comments via API | Comment section (timestamps masked) |
| Delete | One deletable bug via API | Delete confirmation; list after delete |

About **8 named baselines**. Dynamic pixels (auto-ids, `toLocaleString` timestamps, toast notifications) are **masked**, not asserted.

Baselines are committed under `tests-visual/__screenshots__/`. Generate them **inside the same Linux image Jenkins uses** (`mcr.microsoft.com/playwright:v1.50.0-jammy`), otherwise Darwin vs Jammy fonts fail the gate.

```bash
# local app at :3000 / :8080, then update goldens in CI-shaped Linux:
docker run --rm -it --network host \
  -v "$PWD":/work -w /work/tests-visual \
  mcr.microsoft.com/playwright:v1.50.0-jammy \
  bash -lc 'npm ci && npx playwright test --update-snapshots'
```

Nightly / Release: `npx playwright test` (no `--update-snapshots`). Diff beyond `maxDiffPixelRatio` fails the build. HTML report + `test-results` diffs must be archived.

### Isolation

bbolt is persistent and the backend seeds sample bugs. Full-page list screenshots would be noisy. Visual tests therefore:

- Seed or stub a **deterministic** list for list checkpoints.
- Screenshot **named locators** (`bug-list`, modals, `bug-detail`, `comment-section`), not the entire OS window.
- Clean `Visual ` title prefix after the spec.

Off on PR and Master. On Nightly and Release.

---

## 3. Remaining suites — folders and how to implement

### 3.1 Shared fixtures — `tests/fixtures/`

Used by visual now; BDD and E2E should import the same helpers later.

| File | Responsibility |
|---|---|
| `tests/fixtures/api.ts` | `createBug`, `addComment`, `deleteBug`, `listBugs`, `deleteByTitlePrefix` against `BUGTRACKER_API_URL` (default `http://localhost:8080`) |
| `tests/fixtures/recipes.ts` | Frozen titles / priorities / comments. No `Date.now()` |

Rule: Given / seed = HTTP. Clicking the add-bug modal is an E2E or visual *journey*, not a fixture.

### 3.2 API in Jenkins — `tests-api/`

Already Playwright request tests. PR design includes API.

**How:** In `pr.Jenkinsfile` / `master.Jenkinsfile`, start the Go API in the `golang` container (`go run ./cmd/bugtracker` with a temp db path), wait for `/api/health`, then in `playwright` container:

```text
cd tests-api && npm ci && PLAYWRIGHT_TEST_BASE_URL=http://127.0.0.1:8080/api/ npx playwright test
```

Do not wait for a cluster deploy on PR. Do not move these files into `bugtracker-frontend`.

### 3.3 E2E wiring — `tests-e2e/`

Journeys already exist (`create`, `comment`, `edit`, `delete`). They still create data by clicking; later they should `createBug()` then click.

**How:** Nightly / Release against the **stable** in-cluster UI:

```text
PLAYWRIGHT_TEST_BASE_URL=http://bugtracker-frontend.bugtracker.svc.cluster.local:3000
```

Master may run the same after an ephemeral Helm install of the just-pushed tag, or wait until Release. Do not run full E2E on PR.

Prefer `headless: true` in CI (already `CI` env). Drop `slowMo` in CI (already).

### 3.4 fe-smoke — `tests-e2e/smoke.spec.ts`

Not a copy of integration.spec.ts.

```text
goto /
expect Add New Bug visible
```

**How:** Release after canary (and production smoke) with `PLAYWRIGHT_TEST_BASE_URL` pointing at that environment. One test, no fixtures, no screenshots.

### 3.5 BDD — `tests-bdd/` (landed)

Cucumber.js + Gherkin. Driver is `tests/fixtures` against the HTTP API. Four features: create, edit, comment, delete. Steps do not click and do not screenshot.

```text
cd tests-bdd && npm ci && npm test
```

`BUGTRACKER_API_URL` defaults to `http://localhost:8080`. Master starts the Go API in-pod; Nightly/Release hit the cluster Service.

### 3.6 Security — `tests-security/` (landed)

| Check | Where | How |
|---|---|---|
| `npm audit --audit-level=high` | PR+, `bugtracker-frontend` | `tests-security/scripts/npm-audit.sh` (official npm registry) |
| `govulncheck ./...` | PR / Master / Nightly | Jenkins `golang:1.21` + `govulncheck@v1.1.3` |
| Trivy fs | PR+ | `trivy fs` on frontend + backend trees |
| Trivy image | Master after push, Nightly, Release before canary | `kind-registry:5000/bugtracker-*:tag` |
| API abuse | Master / Nightly / Release | `tests-security/api-abuse.spec.ts` |

CVE stages archive reports. Known Next 15.1.x criticals make npm/Trivy **UNSTABLE** until upgraded (`SECURITY_CVE_GATE=1` inside `catchError`). govulncheck and API abuse fail the build.

No ZAP-from-component-tests.

### 3.7 Performance — `tests-perf/`

Keep k6 against the **API**, not Lighthouse.

V1 script is health + create, 1 VU, 30s. Nightly can run it against stable:

```text
k6 run -e API_URL=http://bugtracker-backend.bugtracker.svc.cluster.local:8080 tests-perf/script.js
```

Add later, as separate files, not flags on PR: `load.js`, `stress.js`, `spike.js`, `soak.js`. Parameterize `localhost:8080` via env (the current script is hard-coded).

### 3.8 Backend lint

Add `.golangci.yml` at `bugtracker-backend/` and `golangci-lint run` on PR. Optional until the first noise is cleaned.

---

## 4. Pipeline assignment (when the remaining suites exist)

| Pipeline | Should run |
|---|---|
| PR | lint, unit, component, **integration (Go)**, security deps. No BDD / E2E / visual |
| Master | PR + BDD + API abuse. Visual **off**. Then compile + Kaniko + Trivy image |
| Nightly | unit/component + security + BDD + API abuse + E2E + visual against **stable** |
| Release | Trivy image of the tag, canary + BDD + API abuse + synthetic window; promote the **same** git-sha tag |

Canary stays Helm + wget (or a thin API slice). It is not Istio and not a 1% mesh split.

---

## 5. Quality gates for visual

- Screenshot mismatch → fail Nightly / Release.
- Archive Playwright HTML report and the `test-results` diff images.
- Updating goldens is a deliberate commit (`--update-snapshots` in the Jammy image), not a silent CI rewrite.
