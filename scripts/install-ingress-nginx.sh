#!/usr/bin/env bash
# ingress-nginx using the kind-specific provider manifest (hostPort 80/443 on the ingress-ready node).
source "$(dirname "$0")/lib/common.sh"
parse_install_args "$@"
require_tools kubectl
require_cluster

URL="https://raw.githubusercontent.com/kubernetes/ingress-nginx/${INGRESS_NGINX_VERSION}/deploy/static/provider/kind/deploy.yaml"
NAME="ingress-nginx-${INGRESS_NGINX_VERSION}.yaml"

if [[ "${ACTION}" == "uninstall" ]]; then
  log "Uninstalling ingress-nginx"
  delete_url "${URL}" "${NAME}"
  ok "ingress-nginx removed"
  exit 0
fi

log "Installing ingress-nginx ${INGRESS_NGINX_VERSION}"
apply_url "${URL}" "${NAME}"
# Pin the controller to the node that carries kind's extraPortMappings (labelled in kind-config.yaml.tpl).
# Newer upstream kind manifests no longer set this selector themselves.
kubectl -n "${INGRESS_NS}" patch deploy ingress-nginx-controller --type strategic \
  -p '{"spec":{"template":{"spec":{"nodeSelector":{"ingress-ready":"true","kubernetes.io/os":"linux"}}}}}' >/dev/null
wait_for_rollout "${INGRESS_NS}" deploy/ingress-nginx-controller
# The admission webhook must be ready before any Ingress can be created.
kubectl -n "${INGRESS_NS}" wait --for=condition=complete job --all --timeout=120s >/dev/null 2>&1 || true
ok "ingress-nginx ready on http://localhost:${HTTP_PORT} (hosts: *.${BASE_DOMAIN})"
