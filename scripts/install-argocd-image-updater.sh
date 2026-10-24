#!/usr/bin/env bash
# Argo CD Image Updater (upstream pinned manifest) into the Argo CD namespace.
source "$(dirname "$0")/lib/common.sh"
parse_install_args "$@"
require_tools kubectl
require_cluster

URL="https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/${ARGOCD_IMAGE_UPDATER_VERSION}/config/install.yaml"
NAME="argocd-image-updater-${ARGOCD_IMAGE_UPDATER_VERSION}.yaml"

if [[ "${ACTION}" == "uninstall" ]]; then
  log "Uninstalling Argo CD Image Updater"
  delete_url "${URL}" "${NAME}" -n "${ARGOCD_NS}"
  ok "Argo CD Image Updater removed"
  exit 0
fi

kubectl get ns "${ARGOCD_NS}" >/dev/null 2>&1 || die "Argo CD namespace '${ARGOCD_NS}' missing. Run: make argocd"

log "Installing Argo CD Image Updater ${ARGOCD_IMAGE_UPDATER_VERSION} into ${ARGOCD_NS}"
apply_url "${URL}" "${NAME}" -n "${ARGOCD_NS}"
sed "s/namespace: argocd$/namespace: ${ARGOCD_NS}/; s/argocd.namespace: argocd$/argocd.namespace: ${ARGOCD_NS}/" \
  "${MANIFEST_DIR}/argocd/image-updater-config.yaml" | kubectl apply -f -
kubectl -n "${ARGOCD_NS}" rollout restart deploy/argocd-image-updater-controller >/dev/null
wait_for_rollout "${ARGOCD_NS}" deploy/argocd-image-updater-controller
ok "Argo CD Image Updater ready. Logs: kubectl -n ${ARGOCD_NS} logs deploy/argocd-image-updater-controller -f"
