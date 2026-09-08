#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REPORTS="${ROOT}/tests-security/reports"
mkdir -p "${REPORTS}"
EXIT=0
if [ "${SECURITY_CVE_GATE:-0}" = "1" ]; then
  EXIT=1
fi
trivy fs \
  --config "${ROOT}/tests-security/trivy.yaml" \
  --exit-code "${EXIT}" \
  --scanners vuln \
  --format table \
  --output "${REPORTS}/trivy-fs.txt" \
  "${ROOT}/bugtracker-frontend" "${ROOT}/bugtracker-backend"
trivy fs \
  --config "${ROOT}/tests-security/trivy.yaml" \
  --exit-code 0 \
  --scanners vuln \
  --format json \
  --output "${REPORTS}/trivy-fs.json" \
  "${ROOT}/bugtracker-frontend" "${ROOT}/bugtracker-backend"
cat "${REPORTS}/trivy-fs.txt"
