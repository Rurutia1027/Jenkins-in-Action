#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${ROOT_DIR}/.." && pwd)"

CLUSTER_NAME="${CLUSTER_NAME:-jenkins}"
KUBE_CONTEXT="${KUBE_CONTEXT:-kind-${CLUSTER_NAME}}"
NAMESPACE="${NAMESPACE:-bugtracker}"
CHART_DIR="${CHART_DIR:-${ROOT_DIR}/helm/bugtracker}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
CANARY=false

for arg in "$@"; do
  case "${arg}" in
    --canary) CANARY=true ;;
    -h|--help)
      echo "Usage: IMAGE_TAG=<sha> $0 [--canary]"
      exit 0
      ;;
    *)
      echo "Unknown argument: ${arg}" >&2
      exit 1
      ;;
  esac
done

if [[ "${CANARY}" == true ]]; then
  RELEASE="${RELEASE:-bugtracker-canary}"
  EXTRA_VALUES=("${CHART_DIR}/values-canary.yaml")
else
  RELEASE="${RELEASE:-bugtracker}"
  EXTRA_VALUES=("${CHART_DIR}/values-kind.yaml")
fi

helm upgrade --install "${RELEASE}" "${CHART_DIR}" \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --kube-context "${KUBE_CONTEXT}" \
  --values "${CHART_DIR}/values.yaml" \
  --values "${EXTRA_VALUES[0]}" \
  --set backend.image.tag="${IMAGE_TAG}" \
  --set frontend.image.tag="${IMAGE_TAG}" \
  --wait \
  --timeout 5m

echo
if [[ "${CANARY}" == true ]]; then
  echo "Canary:"
  echo "  API  http://127.0.0.1:18081"
  echo "  UI   http://127.0.0.1:13001"
else
  echo "Stable:"
  echo "  API  http://127.0.0.1:18080"
  echo "  UI   http://127.0.0.1:13000"
fi
echo "  images ${IMAGE_TAG}  (kind-registry:5000/bugtracker-{backend,frontend})"
