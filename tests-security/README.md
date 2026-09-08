# Security suite

Dependency, image, and API-abuse checks for Bug Tracker. Not ZAP. Not a frontend component suite.

| Check | What it proves | When |
|---|---|---|
| `npm audit` | Frontend lockfile has no *new* high/critical story to hide | PR+ |
| `govulncheck` | Go code does not call a known-vulnerable symbol (same Go as the build) | PR+ |
| `trivy fs` | HIGH/CRITICAL in `go.mod` / npm tree (ignore unfixed) | PR+ |
| `trivy image` | The **pushed** backend/frontend images | Master after Kaniko; Release before canary |
| `api-abuse` | Invalid / missing input is rejected (400/404), not 500 | Master, Nightly, Release |

## Local

API abuse needs the backend on `:8080`.

```bash
cd tests-security
npm ci
npx playwright test          # api-abuse

# from repo root
./tests-security/scripts/npm-audit.sh
./tests-security/scripts/govulncheck.sh
# Trivy (optional locally):
./tests-security/scripts/trivy-fs.sh
./tests-security/scripts/trivy-image.sh kind-registry:5000/bugtracker-backend:<tag>
```

`npm audit` uses `https://registry.npmjs.org` (mirrors often stub the audit API).

## Gates

- **api-abuse** and **govulncheck** fail the stage.
- **npm audit** and **Trivy** always publish reports. On this app, Next 15.1.x currently reports critical CVEs; those stages are `UNSTABLE` until the dependency is upgraded, so Master can still push an image. Set `SECURITY_CVE_GATE=1` to fail closed.

No OWASP ZAP in V1.
