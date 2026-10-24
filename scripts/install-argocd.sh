#!/usr/bin/env bash
# Vanilla Argo CD from the upstream pinned install.yaml, plus a minimal overlay:
#   - server.insecure=true so ingress-nginx can terminate HTTP
#   - an Ingress at argocd.$BASE_DOMAIN
# Then prints the initial admin password and logs the argocd CLI in.
source "$(dirname "$0")/lib/common.sh"
parse_install_args "$@"
require_tools kubectl envsubst
require_cluster

URL="https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
NAME="argocd-${ARGOCD_VERSION}.yaml"
export ARGOCD_NS BASE_DOMAIN

if [[ "${ACTION}" == "uninstall" ]]; then
  log "Uninstalling Argo CD"
  render "${MANIFEST_DIR}/argocd/ingress.yaml.tpl" | kubectl delete --ignore-not-found -f - || true
  delete_url "${URL}" "${NAME}" -n "${ARGOCD_NS}"
  kubectl delete ns "${ARGOCD_NS}" --ignore-not-found
  ok "Argo CD removed"
  exit 0
fi

log "Installing Argo CD ${ARGOCD_VERSION} into namespace ${ARGOCD_NS}"
ensure_ns "${ARGOCD_NS}"
apply_url "${URL}" "${NAME}" -n "${ARGOCD_NS}"

log "Applying local overlay (server.insecure, ingress)"
sed "s/namespace: argocd$/namespace: ${ARGOCD_NS}/" "${MANIFEST_DIR}/argocd/argocd-cmd-params-cm.yaml" | kubectl apply -f -
kubectl -n "${ARGOCD_NS}" rollout restart deploy/argocd-server >/dev/null
render "${MANIFEST_DIR}/argocd/ingress.yaml.tpl" | kubectl apply -f -

wait_for_rollout "${ARGOCD_NS}" deploy/argocd-server deploy/argocd-repo-server deploy/argocd-redis \
  deploy/argocd-applicationset-controller deploy/argocd-dex-server deploy/argocd-notifications-controller
kubectl -n "${ARGOCD_NS}" rollout status statefulset/argocd-application-controller --timeout="${WAIT_TIMEOUT}"

PASSWORD="$(kubectl -n "${ARGOCD_NS}" get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || true)"
HOST="argocd.${BASE_DOMAIN}"

if command -v argocd >/dev/null 2>&1 && [[ -n "${PASSWORD}" ]]; then
  log "Logging in the argocd CLI"
  # The ingress answers on the host port; use it so the CLI works without port-forwarding.
  for _ in 1 2 3 4 5 6; do
    if argocd login "${HOST}:${HTTP_PORT}" --username admin --password "${PASSWORD}" --grpc-web --plaintext >/dev/null 2>&1; then
      ok "argocd CLI logged in to ${HOST}"; break
    fi
    sleep 5
  done
fi

ok "Argo CD ready"
printf '\n  UI:       %s\n  user:     admin\n  password: %s\n\n' "$(url_for argocd)" "${PASSWORD:-<already rotated: argocd-initial-admin-secret missing>}"
