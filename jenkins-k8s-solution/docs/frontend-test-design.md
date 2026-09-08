# Frontend Test Design Doc 

This document is the frontend test design for Bug Tracker. It follows the platform model in [README.md](../README.md): 

```
Test Type -> Test Suite -> Test Scenario -> Pipeline Policy -> Quality Gat 
```

A **test type** describes **how** the UI is tested. 
A **test scenario** describes **why** and **when** those tests run. 

They are not the same thing, and they must not be collapsed into one suite. 

This file is the design contract. Implementation should follow it rather than invent a second model. 

---

## 1. Why this document exists 

The frontend is small (list page, detail page, a handful of components), but it sits on the user-visible path. The risk is not "we lack Storybook." The risk is that behavior, interaction, and appearance get stacked into one brittle flow. 

The design below does three things: 
- Split frontend verification into layers that prove different claims. 
- Map every README test type to a frontend ownership decision. 
- Assign those types to the README test scenarios so pipeline profiles stay honest. 

---

## 2. Vocabulary 

These words must stay distinct. 

- **Test type**: How we test: unit, component, BDD, E2E, visual, and so on. 
- **Test suite**: A runnable package of one type, for example `bugtracker-frontend` Jest, `tests-e2e`, future `test-visual`.
- **Test scenario**: Why the pipeline runs: PR Validation, Master Validation, Nightly Regression, Release Validation, Performance, Production Smoke. 
- **Journey**: A product path on the Bug Tracker UI: create, edit, comment, delete. 
- **Fixture**: API-seeded data that puts app into a known state before a test. 
- **Visual checkpoint**: A named screen that is snapshotted after fixtures are applied. 

A journey is a product catalot entry. It is not a pipeline scenario, and it is not a Cucumber file. 

`Regression`, `Smoke`, and `Sanity` appear in the README test-type list. For the frontend they are **composite wrappers**: they select other types, they do not inroduce a new driver. 

---

## 3. Frontend surface 

The UI under test: 

| Area | What it is |
|---|---|
| `/` | Bug list, add / edit / delete entry points, notifications |
| `/bugs/[id]` | Bug detail and comments |
| Components | `BugList`, `AddBugModal`, `EditBugModal`, `DeleteConfirmationModal`, `DeleteBugButton`, `CommentSection`, `Notification` |
| Client | `src/api/bugs.ts` talking to the Go API |

Existing coverage to reuse: 

- Jest + Testing Library component tests in `bugtracker-frontend/src/components/*.test.tsx`
- API client unit tests in `bugtracker-frontend/src/api/bugs.test.ts` 
- Playwright journeys in `tests-e2e/integration.spec.ts` 
- ESLint / `next lint`

Not in scope as a frontend platform: 

- Storybook
- Chromatic
- Component-isolation visual reviews 

For now, page-level Playwright screenshots are enough for this UI. 

---

## 4. Design principles 

- **Shared state, not shared execution.** BDD, E2E, and visual tests reuse the same fixtures. They do not drive each other. 
- **Seed through the API.** Clicking through the UI to reach a screenshot state is an E2E concern, not a visual-regression setup path. 
- **BDD states business rules.** Gherkin says what a bug, status, or comment must mean. It does not narrate clicks, and it does not take screenshots. 
- **E2E proves the path is clickable.** A small number of real browser journeys is enough. 
- **Visual proves the fronzen screen.** After fixtures are applied, open the page and compare a named checkpoint. 
- **Few checkpoints.** Four journeys, about 8-12 baselines. Not one snapshot per Gherkin step. 
- **Cost follows risk.** PR stays fast. Visual and full E2E belong to Nightly and Release. 

What this is not:

```
BDD step -> click component -> screenshot -> next step -> screenshot
```

That stack makes Gherkin unreadable, E2E slower, and visual baselines flaky. 

---

## 5. Layering 

```
                    Production Smoke (critical UI only)
                                    ▲
                         Visual checkpoints
                                    ▲
                        E2E journeys (click-through)
                                    ▲
                     BDD acceptance (business rules)
                                    ▲
              Component tests (Jest + Testing Library)
                                    ▲
           Unit tests (API client, helpers) + Static analysis
                                    ▲
                         Fixture / API seed layer
```

The fixture layer sits under BDD, E2E, and visual. Component and unit tests mock the network and do not use it. 

### 5.1 What each layer proves 

| Layer | Claim | Driver | State setup | Assertion style |
|---|---|---|---|---|
| Static | The frontend is writable and consistent | ESLint / `next lint` | None | Lint rules |
| Unit | The API client and helpers behave | Jest | Mocks | Return values, errors |
| Component | A component renders and reacts | Jest + Testing Library | Props / mocked API | DOM, events, validation |
| BDD | A business rule holds | Cucumber + Gherkin | API fixtures | Status, priority, counts, messages |
| E2E | A user can click a journey | Playwright | Prefer API seed, then UI | Visibility, navigation, persistence |
| Visual | A named screen still looks right | Playwright screenshots | API fixtures only | `toHaveScreenshot()` |
| Smoke | The deployed UI is basically up | Thin Playwright | None or one API create | Critical control visible |
| Sanity | The changed area still works | Subset of component / E2E | Minimal | Local assertions |
| Regression | Previously proven behavior still holds | Composition of the above | Shared fixtures | Suite results |

### 5.2 Fixture contract 

Fixtures are the only shared implementation between BDD, E2E, and visual. 

```
seed via API
   ├── BDD: Given the following bugs exist
   ├── E2E: start from a known list, then click
   └── Visual: open the screen, snapshot the checkpoint
```

Rules: 
- Given / seed uses `POST /api/bugs` and comment APIs, not the add-bug modal. 
- Titles, priorities, and statuses are deterministic. No `Date.now()` in visual fixtures. 
- Dynamic regions (timestamp, notifcations that auto-dismiss) are masked or avoided in checkpoints. 
- One fixture recipe can feed several test types. A failed visual test does not return the BDD story to rebuild the page. 


### 5.3 Journeys and visual checkpoints 
Journeys are the frontend product catalog. Pipeline scenarios *select* which type run agains this catalog. 

| Journey | Fixture | Visual checkpoints |
|---|---|---|
| Create | Empty list, or one existing bug | Empty list, Add Bug modal, list after create |
| Edit | One Open / Medium bug | Detail page, Edit Bug modal |
| Comment | One bug with two comments | Detail page comment section |
| Delete | One deletable bug | Delete confirmation, list after delete |

That is the full visual set for V1: **8-12 named baselines**. Add a checkpoint only when a production defect shows a missing screen. 

E2E already covers the same four journeys in `tests-e2e/integration.spec.ts`. BDD should cover the same business outcomes without duplicating every click. 

---

## 6. README test types, assigned for the frontend

Every type from the README is classified here. 

**Own** = the frontend suite is the source of truth. 
**Participate** = the frontend contributes a slice, but the type is platform-wide. 
**Not owned** = do not build a frontend-shaped version of this type. 

| README test type | Frontend role | What we run | What we do not do |
|---|---|---|---|
| **Static Analysis** | Own | `next lint` / ESLint on `bugtracker-frontend` | Custom frontend static rules beyond the Next config |
| **Unit Testing** | Own | Jest for `src/api/bugs.ts` and any future helpers | Calling the live backend from unit tests |
| **API Testing** | Not owned | Nothing in the frontend tree | Do not move `tests-api` into the UI repo |
| **Integration Testing** | Not owned | Nothing | Jest-with-real-backend is not an integration suite here; that path is E2E |
| **Frontend Component Testing** | Own | Existing `*.test.tsx` component specs | Snapshotting CSS in Jest; Storybook |
| **BDD/Acceptance Testing** | Participate | Gherkin on create / edit / comment / delete. Given = API fixture. Then = business outcome | Step text that says “click Add New Bug”; screenshot steps |
| **E2E Testing** | Own | Playwright journeys in `tests-e2e` | Using E2E as the visual baseline generator |
| **Visual Regression** | Own | Playwright page screenshots on the checkpoints above | Storybook, Chromatic, per-step screenshots |
| **Smoke Testing** | Participate | Critical UI: homepage loads, `Add New Bug` is visible | Full create / delete on every deploy |
| **Sanity Testing** | Participate | Only the changed journey or component, for example comments | Nightly-sized visual on a sanity run |
| **Regression Testing** | Participate | Composition: unit + component + BDD + E2E + visual | A fifth driver named “regression” |
| **Contract Testing** | Not owned (V1) | None until a second consumer appears | Pact just to fill the matrix |
| **Security Testing** | Participate | `npm audit` on the frontend image / lockfile; Trivy on the frontend image | ZAP-from-the-component-tests |
| **Performance Testing** | Not owned | None on the UI | k6 stays against the API; no Lighthouse gate in V1 |
| **Resilience / Chaos Testing** | Not owned | None | Killing pods is an ops / backend exercise |


API, integration, performance, contract, and chaos still run in the platform. They are not frontend layers. 

---

## 7. Suites the frontend actually ships

These are the suites a pipeline profile can turn on. 

| Suite id | Test type | Location | Mandatory when enabled |
|---|---|---|---|
| `fe-static` | Static Analysis | `bugtracker-frontend` lint | PR and above |
| `fe-unit` | Unit Testing | `bugtracker-frontend` Jest, non-component | PR and above |
| `fe-component` | Frontend Component Testing | `bugtracker-frontend` component tests | PR and above |
| `fe-bdd` | BDD/Acceptance Testing | Future Gherkin + steps, Bug Tracker domain only | Master, Nightly, Release |
| `fe-e2e` | E2E Testing | `tests-e2e` | Master, Nightly, Release |
| `fe-visual` | Visual Regression | Playwright screenshots on seeded pages | Nightly, Release |
| `fe-smoke` | Smoke Testing | Thin Playwright against a deployed URL | After deploy, Production Smoke |
| `fe-sanity` | Sanity Testing | Selected `fe-component` and/or `fe-e2e` | On-demand / change-scoped |
| `fe-security` | Security Testing | `npm audit`, frontend image scan | PR (audit), Master / Nightly / Release (image) |

`fe-regression` is not a suite. Nightly and Release enable the composition:

```
fe-unit + fe-component + fe-bdd + fe-e2e + fe-visual
```
---

## 8. Test scenarios: what the frontend contributes

Scenario definitions stay exactly those in the README. This section only assigns frontend types. 

### 8.1 Assignment matrix 

`Yes` = frontend suite is in the default profile. 
`No` = must stay off. 
`Optional` = allowed by policy, never required. 

| Frontend type | PR Validation | Master Validation | Nightly Regression | Release Validation | Performance | Production Smoke |
|---|---|---|---|---|---|---|
| Static Analysis | Yes | Yes | Yes | Yes | No | No |
| Unit Testing | Yes | Yes | Yes | Yes | No | No |
| Frontend Component Testing | Yes | Yes | Yes | Yes | No | No |
| BDD/Acceptance Testing | No | Yes | Yes | Yes | No | No |
| E2E Testing | No | Yes | Yes | Yes | No | Critical UI only, via Smoke |
| Visual Regression | No | No | Yes | Yes | No | No |
| Smoke Testing | No | No | No | Yes, after TEST deploy | No | Yes |
| Sanity Testing | Optional | Optional | No | No | No | No |
| Regression Testing | No | Partial (no visual) | Yes | Yes | No | No |
| Security Testing | Yes (`npm audit`) | Yes (audit + image) | Yes | Yes | No | No |
| API Testing | — | — | — | — | — | — |
| Integration Testing | — | — | — | — | — | — |
| Contract Testing | — | — | — | — | — | — |
| Performance Testing | — | — | — | — | No frontend suite | — |
| Resilience / Chaos Testing | — | — | — | — | — | — |

Dashes mean the type is not a frontend suite. The platform may still run backend API / integration / k6 in that scenario.

This matches the README intent:

| README scenario | README typical tests | Frontend reading |
|---|---|---|
| **PR Validation** | Static, Unit, API, Component, Integration | Lint, unit, component, npm audit. No BDD, E2E, or visual. |
| **Master Validation** | Unit, API, Integration, BDD, E2E | Same fast suites, plus BDD and full E2E. Visual stays off. |
| **Nightly Regression** | Regression, BDD, E2E, Visual | Full frontend composition including checkpoints. |
| **Release Validation** | Full Regression, E2E, Visual, Security | Same as Nightly, plus deploy smoke and image security. |
| **Performance** | Load, Stress, Spike, Soak | Frontend does not add a suite. |
| **Production Smoke** | Health, Critical API, Critical UI | Homepage + `Add New Bug` only. |

Nightly optimizes for continuous regression detection. Release adds deploy-time smoke and a harder security bar. They are not copies of each other. 

### 8.2 Scenario narratives 

**PR Validation - fast developer feedback** 

Prove the change did not break isolated frontend logic. 

```
fe-static -> fe-unit -> fe-component -> fe-security (npm audit)
```

Keep this under the PR time budget. A broker modal test belongs here. A full create-and-delete browser path does not. 

**Master Validation - integration confidence** 

Prove the merged UI still satisfies business rules and can be clicked through. 

```
fe-static → fe-unit → fe-component → fe-bdd → fe-e2e → fe-security
```

Visual is optinal in the platform PLAN and **off** for the frontend default. Pixel noise on every merge is not worth the signal. 

**Nightly Regression - continus regression detection** 

Prove the four journeys still behave, still click, and still look right. 

```
fe-unit + fe-component + fe-bdd + fe-e2e + fe-visual + fe-security
```

This is the first scenario that is allowed to fail the build on a screenshot diff. 

**Release Validation - production confidence**

Same functional and visual bar as Nightly, then prove the promoted image actually serves UI. 

```
frontend regression (including visual)
        → image security
        → deploy TEST
        → fe-smoke
```

**Performance** 

No frontend type is assigned. Capacity is an API / k6 concern. 

**Production Smoke - deployment safety** 

```
open homepage -> Add New Bug is visible 
```

No fixture catalog, no visual compare, no comment journey. 

**Sanity (on-demand, not a README pipeline).** 

Used when a change is local. Example: comment API or `CommentSection` changed. 

```
CommentSection component tests + comment E2E
```

No visual, no full regression. 


---

## 9. Profile flags 

These flags are the frontend rows of the README configurable profiles 

```yaml 
# PR
tests:
  static: true
  unit: true
  component: true
  bdd: false
  e2e: false
  visual: false
  security: true
  performance: false

# MASTER
tests:
  static: true
  unit: true
  component: true
  bdd: true
  e2e: true
  visual: false
  security: true
  performance: false

# NIGHTLY
tests:
  static: true
  unit: true
  component: true
  bdd: true
  e2e: true
  visual: true
  security: true
  performance: false

# RELEASE
tests:
  static: true
  unit: true
  component: true
  bdd: true
  e2e: true
  visual: true
  security: true
  performance: false
  # fe-smoke runs after deploy, not as a compile-time suite

# PERFORMANCE
tests:
  performance: true
  # no frontend suites

# SMOKE / Production Smoke
tests:
  # fe-smoke only
```

Pipeline policy may add optional suites. It must not let a PR disable `fe-static`, `fe-unit`, or `fe-component`.


---

## 10. Quality gates that belong to the frontend 

| Gate | Applies to | Rule |
|---|---|---|
| Lint clean | PR and above | `next lint` fails the build |
| Unit / component pass | PR and above | Jest failures fail the build |
| Coverage floor | PR and Master | Use the existing Jest coverage reporters; do not invent a second frontend coverage tool |
| BDD pass | Master, Nightly, Release | Failed business scenarios fail the build |
| E2E pass | Master, Nightly, Release | Failed journeys fail the build |
| Visual pass | Nightly, Release | Diff beyond threshold fails the build |
| Smoke pass | Release TEST, Production | Missing critical control fails the deploy |
| npm audit / image scan | Per security column above | Blocking severity fails the build |

Visual failures must publish the image diff. A red pixel without a report is not an actionable gate. 

---

## 11. Implementation status 

| Piece | Status |
|---|---|
| Component tests | Exists |
| API client unit tests | Exists |
| Frontend lint | Exists |
| E2E journeys (create, comment, edit, delete) | Exists in `tests-e2e` |
| Shared API fixture module | To add |
| BDD on the four journeys | To add |
| Visual checkpoints | To add |
| `fe-smoke` slice | To add (homepage + Add New Bug) |
| Profile wiring in Jenkins | To add with the test-engine work |


When implementing, add fixtures first. BDD and visual both depend on them. Do not start by wrapping the current E2E file in Gherkin. 

---

## 12. Decision record 

| Decision | Choice | Reason |
|---|---|---|
| Visual tool | Playwright screenshots | Already in the repo; the UI has two pages |
| Storybook visual | Out | Setup cost exceeds the component surface |
| BDD driver | Business steps + API Given | Keeps Gherkin readable |
| Visual setup | API fixtures, then navigate | Stable baselines |
| Journey catalog | Create, edit, comment, delete | Matches the current product and E2E |
| Visual on PR / Master | Off | Pixel flakiness is the wrong PR signal |
| Visual on Nightly / Release | On | This is the regression bar for appearance |
| Performance on the UI | Off in V1 | README performance is k6 against the API |

If a later design system is extracted, revisit Storybook then. Do not revisit it to get visual regression for this app.