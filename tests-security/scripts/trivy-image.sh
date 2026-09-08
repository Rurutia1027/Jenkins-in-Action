#!/usr/bin/env bash
# Scan already-pushed images. Usage: trivy-image.sh <image[:tag]> [<image[:tag]> ...]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REPORTS="${ROOT}/tests-security/reports"
mkdir -p "${REPORTS}"
if [ "$#" -lt 1 ]; then
  echo "usage: $0 <image> [image...]" >&2
  exit 2
fi
EXIT=0
if [ "${SECURITY_CVE_GATE:-0}" = "1" ]; then
  EXIT=1
fi
failed=0
for image in "$@"; do
  safe="$(echo "${image}" | tr '/:' '__')"
  echo "trivy image ${image}"
  if ! trivy image \
    --config "${ROOT}/tests-security/trivy.yaml" \
    --insecure \
    --exit-code "${EXIT}" \
    --format table \
    --output "${REPORTS}/trivy-image-${safe}.txt" \
    "${image}"; then
    failed=1
  fi
  trivy image \
    --config "${ROOT}/tests-security/trivy.yaml" \
    --insecure \
    --exit-code 0 \
    --format json \
    --output "${REPORTS}/trivy-image-${safe}.json" \
    "${image}"
  cat "${REPORTS}/trivy-image-${safe}.txt"
done
exit "${failed}"
