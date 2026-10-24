#!/usr/bin/env bash
# Show what is installed, pod health, URLs and credentials.
source "$(dirname "$0")/lib/common.sh"
require_tools kubectl

if ! cluster_exists; then
  warn "kind cluster '${CLUSTER_NAME}' does not exist. Run: make up"
  exit 0
fi
use_context

row() { printf '  %-22s %-12s %s\n' "$1" "$2" "$3"; }
component() {
  local name="$1" ns="$2" url="$3"
  if kubectl get ns "${ns}" >/dev/null 2>&1; then
    local total ready
    total="$(kubectl -n "${ns}" get pods --no-headers 2>/dev/null | wc -l | tr -d ' ')"
    ready="$(kubectl -n "${ns}" get pods --no-headers 2>/dev/null | awk '$3=="Running" || $3=="Completed"' | wc -l | tr -d ' ')"
    row "${name}" "${ready}/${total} pods" "${url}"
  else
    row "${name}" "-" "(not installed)"
  fi
}

printf '\nCluster: kind-%s   nodes: %s   ingress ports: %s/%s\n\n' "${CLUSTER_NAME}" \
  "$(kubectl get nodes --no-headers | wc -l | tr -d ' ')" "${HTTP_PORT}" "${HTTPS_PORT}"
component "ingress-nginx"        "${INGRESS_NS}"        "http://localhost:${HTTP_PORT}"
component "Argo CD"              "${ARGOCD_NS}"         "$(url_for argocd)"
component "Argo Rollouts"        "${ARGO_ROLLOUTS_NS}"  "$(url_for rollouts)"
component "Argo Workflows"       "${ARGO_WORKFLOWS_NS}" "$(url_for workflows)"
component "Argo Events"          "${ARGO_EVENTS_NS}"    "-"
component "Prometheus / Grafana" "${MONITORING_NS}"     "$(url_for prometheus)  $(url_for grafana)"
component "cert-manager"         "${CERT_MANAGER_NS}"   "-"
if kubectl -n "${ARGOCD_NS}" get deploy argocd-image-updater-controller >/dev/null 2>&1; then
  row "Argo CD Image Updater" "installed" "-"
fi

echo
pw="$(kubectl -n "${ARGOCD_NS}" get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || true)"
[[ -n "${pw}" ]] && printf '  Argo CD login:  admin / %s\n' "${pw}"
kubectl get ns "${MONITORING_NS}" >/dev/null 2>&1 && printf '  Grafana login:  admin / admin\n'
kubectl get ns "${ARGO_WORKFLOWS_NS}" >/dev/null 2>&1 && printf '  MinIO:          kubectl -n %s port-forward svc/minio 9001:9001  -> admin / password\n' "${ARGO_WORKFLOWS_NS}"
echo
