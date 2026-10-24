#!/usr/bin/env bash
# Argo Workflows using the upstream quick-start-minimal manifest (controller, server, MinIO artifact
# store, httpbin). This is the install the official docs use for learning; not for production.
source "$(dirname "$0")/lib/common.sh"
parse_install_args "$@"
require_tools kubectl envsubst
require_cluster

URL="https://github.com/argoproj/argo-workflows/releases/download/${ARGO_WORKFLOWS_VERSION}/quick-start-minimal.yaml"
NAME="argo-workflows-${ARGO_WORKFLOWS_VERSION}-quick-start-minimal.yaml"
export ARGO_WORKFLOWS_NS BASE_DOMAIN

if [[ "${ACTION}" == "uninstall" ]]; then
  log "Uninstalling Argo Workflows"
  render "${MANIFEST_DIR}/argo-workflows/ingress.yaml.tpl" | kubectl delete --ignore-not-found -f - || true
  delete_url "${URL}" "${NAME}" -n "${ARGO_WORKFLOWS_NS}"
  kubectl delete ns "${ARGO_WORKFLOWS_NS}" --ignore-not-found
  ok "Argo Workflows removed"
  exit 0
fi

log "Installing Argo Workflows ${ARGO_WORKFLOWS_VERSION} (quick-start-minimal) into ${ARGO_WORKFLOWS_NS}"
ensure_ns "${ARGO_WORKFLOWS_NS}"
apply_url "${URL}" "${NAME}" -n "${ARGO_WORKFLOWS_NS}"

log "Patching argo-server for HTTP behind ingress"
kubectl -n "${ARGO_WORKFLOWS_NS}" patch deploy argo-server --type strategic \
  --patch-file "${MANIFEST_DIR}/argo-workflows/argo-server-patch.yaml" >/dev/null
render "${MANIFEST_DIR}/argo-workflows/ingress.yaml.tpl" | kubectl apply -f -

wait_for_rollout "${ARGO_WORKFLOWS_NS}" deploy/workflow-controller deploy/argo-server deploy/minio

if ! command -v argo >/dev/null 2>&1; then
  warn "argo CLI not found. Install with: brew install argo"
fi

ok "Argo Workflows ready"
printf '\n  UI:    %s\n  CLI:   argo -n %s list\n  MinIO: kubectl -n %s port-forward svc/minio 9000:9000 9001:9001  (admin/password)\n\n' \
  "$(url_for workflows)" "${ARGO_WORKFLOWS_NS}" "${ARGO_WORKFLOWS_NS}"
