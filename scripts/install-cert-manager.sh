#!/usr/bin/env bash
# cert-manager (upstream pinned manifest) + self-signed root CA ClusterIssuer "lab-ca".
source "$(dirname "$0")/lib/common.sh"
parse_install_args "$@"
require_tools kubectl
require_cluster

URL="https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml"
NAME="cert-manager-${CERT_MANAGER_VERSION}.yaml"

if [[ "${ACTION}" == "uninstall" ]]; then
  log "Uninstalling cert-manager"
  kubectl delete -f "${MANIFEST_DIR}/cert-manager/selfsigned-clusterissuer.yaml" --ignore-not-found || true
  delete_url "${URL}" "${NAME}"
  ok "cert-manager removed"
  exit 0
fi

log "Installing cert-manager ${CERT_MANAGER_VERSION}"
apply_url "${URL}" "${NAME}"
wait_for_rollout "${CERT_MANAGER_NS}" deploy/cert-manager deploy/cert-manager-webhook deploy/cert-manager-cainjector

log "Creating self-signed root CA and ClusterIssuers (selfsigned, lab-ca)"
# The webhook needs a moment after "Ready" before it accepts CRs.
for _ in 1 2 3 4 5 6 7 8 9 10; do
  kubectl apply -f "${MANIFEST_DIR}/cert-manager/selfsigned-clusterissuer.yaml" >/dev/null 2>&1 && break
  sleep 5
done
kubectl apply -f "${MANIFEST_DIR}/cert-manager/selfsigned-clusterissuer.yaml"
kubectl -n "${CERT_MANAGER_NS}" wait --for=condition=Ready certificate/lab-root-ca --timeout=120s
ok "cert-manager ready. ClusterIssuers: selfsigned, lab-ca"
