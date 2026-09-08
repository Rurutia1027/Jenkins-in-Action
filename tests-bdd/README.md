# BDD / acceptance

Gherkin for Bug Tracker create / edit / comment / delete. Driver is the HTTP API via `tests/fixtures`. Steps do not click the UI and do not take screenshots.

Needs a running API (`BUGTRACKER_API_URL`, default `http://localhost:8080`).

```bash
cd tests-bdd
npm ci
npm test
```

Master / Nightly / Release. Not on PR.
