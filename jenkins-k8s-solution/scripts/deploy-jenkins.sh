#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

CLUSTER_NAME="${CLUSTER_NAME:-jenkins}"
NAMESPACE="${NAMESPACE:-jenkins}"
RELEASE="${RELEASE:-jenkins}"
KUBE_CONTEXT="${KUBE_CONTEXT:-kind-${CLUSTER_NAME}}"
CHART_DIR="${CHART_DIR:-${ROOT_DIR}/helm/jenkins}"
CONTROLLER_DIR="${CONTROLLER_DIR:-${ROOT_DIR}/jenkins/controller}"
CONTROLLER_IMAGE="${CONTROLLER_IMAGE:-docker.io/jenkins-kind/controller:1.0.0}"
AGENT_IMAGE="${AGENT_IMAGE:-docker.io/jenkins/inbound-agent:3385.vf1123fb_515da_-1}"
HELM_TIMEOUT="${HELM_TIMEOUT:-10m}"
KIND_HOST_PORT="${KIND_HOST_PORT:-9000}"

ensure_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

kind_node_platform() {
  local machine
  machine="$(docker exec "${CLUSTER_NAME}-control-plane" uname -m)"
  case "${machine}" in
    aarch64|arm64) echo "linux/arm64" ;;
    x86_64|amd64) echo "linux/amd64" ;;
    *) echo "linux/${machine}" ;;
  esac
}

# Flatten to a single-platform image so kind's ctr --all-platforms import works
# on Docker Desktop (multi-arch + attestation manifests otherwise fail).
ensure_image() {
  local img="$1"
  local platform
  platform="${IMAGE_PLATFORM:-$(kind_node_platform)}"

  echo "Ensuring ${img} (${platform}) is in kind cluster '${CLUSTER_NAME}'..."
  if ! docker image inspect "${img}" >/dev/null 2>&1; then
    echo "Pulling ${img}..."
    docker pull --platform "${platform}" "${img}"
  fi

  echo "Flattening ${img} to ${platform}..."
  printf 'FROM %s\n' "${img}" | docker build --platform "${platform}" -t "${img}" -

  if ! kind load docker-image "${img}" --name "${CLUSTER_NAME}"; then
    local archive
    archive="$(mktemp -t kind-image.XXXXXX.tar)"
    echo "kind load docker-image failed; falling back to image-archive for ${img}"
    docker save "${img}" -o "${archive}"
    kind load image-archive "${archive}" --name "${CLUSTER_NAME}"
    rm -f "${archive}"
  fi
}

ensure_cmd docker
ensure_cmd kind
ensure_cmd kubectl
ensure_cmd helm

if ! kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  echo "kind cluster '${CLUSTER_NAME}' is missing; creating it first..."
  "${SCRIPT_DIR}/kind-up.sh"
fi

echo "Building controller image ${CONTROLLER_IMAGE}..."
docker build -t "${CONTROLLER_IMAGE}" "${CONTROLLER_DIR}"

ensure_image "${CONTROLLER_IMAGE}"
ensure_image "${AGENT_IMAGE}"

echo "Resolving Helm chart dependencies..."
helm repo add jenkins https://charts.jenkins.io >/dev/null 2>&1 || true
helm repo update jenkins
helm dependency update "${CHART_DIR}"

echo "Installing / upgrading Jenkins release '${RELEASE}' in namespace '${NAMESPACE}'..."
helm upgrade --install "${RELEASE}" "${CHART_DIR}" \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --kube-context "${KUBE_CONTEXT}" \
  --values "${CHART_DIR}/values.yaml" \
  --values "${CHART_DIR}/values-kind.yaml" \
  --wait \
  --timeout "${HELM_TIMEOUT}"

echo
echo "Jenkins is up."
echo "  URL:      http://localhost:${KIND_HOST_PORT}"
echo "  user:     admin"
echo "  password: $(kubectl --context "${KUBE_CONTEXT}" -n "${NAMESPACE}" get secret jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 --decode)"
echo
echo "To read the password again:"
echo "  kubectl --context ${KUBE_CONTEXT} -n ${NAMESPACE} get secret jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 --decode"
echo
echo "Smoke an ephemeral agent with a Pipeline job using:"
echo "  agent { label 'jenkins-agent' }"
