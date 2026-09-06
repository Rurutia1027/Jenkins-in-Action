#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

CLUSTER_NAME="${CLUSTER_NAME:-jenkins}"
KIND_CONFIG="${KIND_CONFIG:-${ROOT_DIR}/kind/cluster.yaml}"
KIND_HOST_PORT="${KIND_HOST_PORT:-9000}"

if ! command -v kind >/dev/null 2>&1; then
  echo "kind is required. Install: https://kind.sigs.k8s.io/docs/user/quick-start/#installation" >&2
  exit 1
fi

CONFIG_TO_USE="${KIND_CONFIG}"
TMP_CONFIG=""
cleanup() {
  if [[ -n "${TMP_CONFIG}" && -f "${TMP_CONFIG}" ]]; then
    rm -f "${TMP_CONFIG}"
  fi
}
trap cleanup EXIT

if [[ "${KIND_HOST_PORT}" != "9000" ]]; then
  TMP_CONFIG="$(mktemp)"
  sed "s/hostPort: 9000/hostPort: ${KIND_HOST_PORT}/" "${KIND_CONFIG}" > "${TMP_CONFIG}"
  CONFIG_TO_USE="${TMP_CONFIG}"
  echo "Using host port ${KIND_HOST_PORT} for Jenkins UI."
fi

if lsof -nP -iTCP:"${KIND_HOST_PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Host port ${KIND_HOST_PORT} is already in use." >&2
  echo "Stop the Compose Jenkins stack (jenkins/docker-compose.yml) or set KIND_HOST_PORT to a free port." >&2
  exit 1
fi

if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  echo "kind cluster '${CLUSTER_NAME}' already exists; reusing it."
else
  echo "Creating kind cluster '${CLUSTER_NAME}'..."
  kind create cluster --name "${CLUSTER_NAME}" --config "${CONFIG_TO_USE}"
fi

kubectl cluster-info --context "kind-${CLUSTER_NAME}"
echo "kind cluster '${CLUSTER_NAME}' is ready."
