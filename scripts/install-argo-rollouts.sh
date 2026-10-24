#!/usr/bin/env bash
# Argo Rollouts controller + dashboard (upstream pinned manifests), dashboard Ingress,
# and the kubectl-argo-rollouts plugin for the local machine.
source "$(dirname "$0")/lib/common.sh"
parse_install_args "$@"
require_tools kubectl envsubst curl
require_cluster

BASE="https://github.com/argoproj/argo-rollouts/releases/download/${ARGO_ROLLOUTS_VERSION}"
CTRL_NAME="argo-rollouts-${ARGO_ROLLOUTS_VERSION}.yaml"
DASH_NAME="argo-rollouts-${ARGO_ROLLOUTS_VERSION}-dashboard.yaml"
export ARGO_ROLLOUTS_NS BASE_DOMAIN

if [[ "${ACTION}" == "uninstall" ]]; then
  log "Uninstalling Argo Rollouts"
  render "${MANIFEST_DIR}/argo-rollouts/ingress.yaml.tpl" | kubectl delete --ignore-not-found -f - || true
  delete_url "${BASE}/dashboard-install.yaml" "${DASH_NAME}" -n "${ARGO_ROLLOUTS_NS}"
  delete_url "${BASE}/install.yaml" "${CTRL_NAME}" -n "${ARGO_ROLLOUTS_NS}"
  kubectl delete ns "${ARGO_ROLLOUTS_NS}" --ignore-not-found
  ok "Argo Rollouts removed (kubectl plugin left in ${PLUGIN_DIR})"
  exit 0
fi

log "Installing Argo Rollouts ${ARGO_ROLLOUTS_VERSION} into ${ARGO_ROLLOUTS_NS}"
ensure_ns "${ARGO_ROLLOUTS_NS}"
apply_url "${BASE}/install.yaml" "${CTRL_NAME}" -n "${ARGO_ROLLOUTS_NS}"
apply_url "${BASE}/dashboard-install.yaml" "${DASH_NAME}" -n "${ARGO_ROLLOUTS_NS}"
render "${MANIFEST_DIR}/argo-rollouts/ingress.yaml.tpl" | kubectl apply -f -
wait_for_rollout "${ARGO_ROLLOUTS_NS}" deploy/argo-rollouts deploy/argo-rollouts-dashboard

# --- kubectl plugin ----------------------------------------------------------
os="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch="$(uname -m)"; case "${arch}" in x86_64) arch=amd64 ;; aarch64|arm64) arch=arm64 ;; esac
PLUGIN="${PLUGIN_DIR}/kubectl-argo-rollouts"
if [[ -x "${PLUGIN}" ]] && "${PLUGIN}" version --short 2>/dev/null | grep -q "${ARGO_ROLLOUTS_VERSION}"; then
  ok "kubectl-argo-rollouts ${ARGO_ROLLOUTS_VERSION} already installed"
else
  log "Installing kubectl-argo-rollouts plugin to ${PLUGIN}"
  mkdir -p "${PLUGIN_DIR}"
  bin="$(fetch "${BASE}/kubectl-argo-rollouts-${os}-${arch}" "kubectl-argo-rollouts-${ARGO_ROLLOUTS_VERSION}-${os}-${arch}")"
  install -m 0755 "${bin}" "${PLUGIN}"
fi
case ":${PATH}:" in *":${PLUGIN_DIR}:"*) ;; *) warn "${PLUGIN_DIR} is not on your PATH. Add: export PATH=\"${PLUGIN_DIR}:\$PATH\"" ;; esac

ok "Argo Rollouts ready"
printf '\n  Dashboard: %s\n  Plugin:    kubectl argo rollouts version\n\n' "$(url_for rollouts)"
