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

REG_NAME="${REG_NAME:-kind-registry}"
REG_PORT="${REG_PORT:-5001}"

ensure_local_registry() {
  if [ "$(docker inspect -f '{{.State.Running}}' "${REG_NAME}" 2>/dev/null || true)" != "true" ]; then
    echo "Starting local registry ${REG_NAME} on localhost:${REG_PORT}..."
    docker run -d --restart=always -p "127.0.0.1:${REG_PORT}:5000" --network bridge --name "${REG_NAME}" registry:2
  else
    echo "Local registry ${REG_NAME} already running."
  fi

  if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${REG_NAME}" 2>/dev/null || true)" = "null" ]; then
    docker network connect "kind" "${REG_NAME}" || true
  fi

  # Point containerd on every kind node at the registry (kind local-registry docs).
  local hosts_toml
  hosts_toml="$(cat <<EOF
[host."http://${REG_NAME}:5000"]
EOF
)"
  for node in $(kind get nodes --name "${CLUSTER_NAME}"); do
    docker exec "${node}" mkdir -p /etc/containerd/certs.d/localhost:${REG_PORT}
    docker exec "${node}" mkdir -p /etc/containerd/certs.d/${REG_NAME}:5000
    echo "${hosts_toml}" | docker exec -i "${node}" cp /dev/stdin /etc/containerd/certs.d/localhost:${REG_PORT}/hosts.toml
    echo "${hosts_toml}" | docker exec -i "${node}" cp /dev/stdin /etc/containerd/certs.d/${REG_NAME}:5000/hosts.toml
  done

  kubectl --context "kind-${CLUSTER_NAME}" apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REG_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
}

if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  echo "kind cluster '${CLUSTER_NAME}' already exists; reusing it."
else
  echo "Creating kind cluster '${CLUSTER_NAME}'..."
  kind create cluster --name "${CLUSTER_NAME}" --config "${CONFIG_TO_USE}"
fi

kubectl cluster-info --context "kind-${CLUSTER_NAME}"
ensure_local_registry
echo "kind cluster '${CLUSTER_NAME}' is ready."
