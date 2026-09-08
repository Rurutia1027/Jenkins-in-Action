#!/usr/bin/env bash
# Scan with the same Go toolchain the pipeline compiles (Jenkins agent is 1.21).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${ROOT}/bugtracker-backend"
ver="$(go env GOVERSION)"
case "${ver}" in
  go1.21*) pkg="golang.org/x/vuln/cmd/govulncheck@v1.1.3" ;;
  *)       pkg="golang.org/x/vuln/cmd/govulncheck@latest" ;;
esac
echo "govulncheck toolchain=${ver} pkg=${pkg}"
go run "${pkg}" ./...
