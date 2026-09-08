# Visual regression (Playwright screenshots)

Page-level checkpoints after the four Bug Tracker journeys. Driver is Playwright `toHaveScreenshot()` (pixelmatch). Not Chromatic, not Storybook.

Needs a running UI + API (`PLAYWRIGHT_TEST_BASE_URL`, `BUGTRACKER_API_URL`).

```bash
cd tests-visual
npm ci
npx playwright test
```

Update goldens **in the Jenkins agent image**, not on macOS:

```bash
docker run --rm -it --network host \
  -v "$PWD/..":/work -w /work/tests-visual \
  mcr.microsoft.com/playwright:v1.50.0-jammy \
  bash -lc 'npm ci && npx playwright test --update-snapshots'
```

Nightly / Release fail the build on a diff. PR / Master do not run this suite.
