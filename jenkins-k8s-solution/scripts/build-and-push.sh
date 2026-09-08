#!/usr/bin/env bash
# Build both app images and push to the kind local registry (localhost:5001).
# Used by humans locally; Master Jenkinsfile does the same with Kaniko.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REGISTRY="${REGISTRY:-localhost:5001}"
IMAGE_TAG="${IMAGE_TAG:-$(git -C "${REPO_ROOT}" rev-parse --short HEAD)}"
case "$(uname -m)" in
  arm64|aarch64) PLATFORM="${PLATFORM:-linux/arm64}" ;;
  *) PLATFORM="${PLATFORM:-linux/amd64}" ;;
esac

docker build --platform "${PLATFORM}" \
  -t "${REGISTRY}/bugtracker-backend:${IMAGE_TAG}" \
  "${REPO_ROOT}/bugtracker-backend"
docker build --platform "${PLATFORM}" \
  -t "${REGISTRY}/bugtracker-frontend:${IMAGE_TAG}" \
  "${REPO_ROOT}/bugtracker-frontend"

docker push "${REGISTRY}/bugtracker-backend:${IMAGE_TAG}"
docker push "${REGISTRY}/bugtracker-frontend:${IMAGE_TAG}"

echo "Pushed:"
echo "  ${REGISTRY}/bugtracker-backend:${IMAGE_TAG}"
echo "  ${REGISTRY}/bugtracker-frontend:${IMAGE_TAG}"
echo "Deploy with: IMAGE_TAG=${IMAGE_TAG} ${SCRIPT_DIR}/deploy-bugtracker.sh"
