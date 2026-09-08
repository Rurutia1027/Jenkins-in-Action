#!/usr/bin/env bash
# Frontend lockfile audit. Official registry — many mirrors stub /-/npm/v1/security/*.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REPORTS="${ROOT}/tests-security/reports"
mkdir -p "${REPORTS}"
cd "${ROOT}/bugtracker-frontend"
npm audit \
  --audit-level="${NPM_AUDIT_LEVEL:-high}" \
  --registry="${NPM_AUDIT_REGISTRY:-https://registry.npmjs.org}" \
  --json > "${REPORTS}/npm-audit.json" || status=$?
npm audit \
  --audit-level="${NPM_AUDIT_LEVEL:-high}" \
  --registry="${NPM_AUDIT_REGISTRY:-https://registry.npmjs.org}" \
  | tee "${REPORTS}/npm-audit.txt" || true
if [ "${SECURITY_CVE_GATE:-0}" = "1" ]; then
  exit "${status:-0}"
fi
exit 0
