# Integration

Proves the real collaborators for this app:

```
HTTP client → API handlers → bbolt
```

Not a browser. That is E2E (`tests-e2e`). Not mocked handlers. That is unit.

## In-process (PR+)

httptest + a real bbolt file. No long-lived server.

```bash
cd bugtracker-backend
go test -tags=integration ./internal/integration/ -count=1
```

Claims:

- Health, create, list, get, update, comment, delete go through the HTTP API into bbolt
- Closing and reopening the same DB file still returns the bug (process restart)

## Over the wire (Master / Nightly / Release)

Same lifecycle against a running API (`BUGTRACKER_API_URL` / Playwright `baseURL`).

```bash
cd tests-integration
npm ci
npx playwright test
```

Do not add Kafka, Redis, or Postgres here. The product storage is bbolt.
