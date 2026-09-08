#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-jenkins}"
NAMESPACE="${NAMESPACE:-jenkins}"
RELEASE="${RELEASE:-jenkins}"
KUBE_CONTEXT="${KUBE_CONTEXT:-kind-${CLUSTER_NAME}}"

DELETE_CLUSTER=false
for arg in "$@"; do
  case "${arg}" in
    --cluster) DELETE_CLUSTER=true ;;
    -h|--help)
      echo "Usage: $0 [--cluster]"
      echo "  default     helm uninstall ${RELEASE} from namespace ${NAMESPACE}"
      echo "  --cluster   also delete the kind cluster '${CLUSTER_NAME}'"
      exit 0
      ;;
    *)
      echo "Unknown argument: ${arg}" >&2
      echo "Usage: $0 [--cluster]" >&2
      exit 1
      ;;
  esac
done

if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  if helm status "${RELEASE}" --namespace "${NAMESPACE}" --kube-context "${KUBE_CONTEXT}" >/dev/null 2>&1; then
    echo "Uninstalling Helm release '${RELEASE}' from namespace '${NAMESPACE}'..."
    helm uninstall "${RELEASE}" --namespace "${NAMESPACE}" --kube-context "${KUBE_CONTEXT}" --wait
  else
    echo "Helm release '${RELEASE}' not found in namespace '${NAMESPACE}'; skipping uninstall."
  fi
else
  echo "kind cluster '${CLUSTER_NAME}' does not exist; nothing to uninstall."
fi

if [[ "${DELETE_CLUSTER}" == true ]]; then
  if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
    echo "Deleting kind cluster '${CLUSTER_NAME}'..."
    kind delete cluster --name "${CLUSTER_NAME}"
  else
    echo "kind cluster '${CLUSTER_NAME}' already gone."
  fi
else
  echo "Left kind cluster '${CLUSTER_NAME}' running. Pass --cluster to delete it."
fi
