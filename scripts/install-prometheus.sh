#!/usr/bin/env bash
# kube-prometheus-stack (Prometheus Operator, Prometheus, Grafana) via Helm.
# Used by the Rollouts AnalysisTemplate labs and for watching Argo metrics.
source "$(dirname "$0")/lib/common.sh"
parse_install_args "$@"
require_tools kubectl helm envsubst
require_cluster

RELEASE="prom"
export BASE_DOMAIN

if [[ "${ACTION}" == "uninstall" ]]; then
  log "Uninstalling kube-prometheus-stack"
  helm -n "${MONITORING_NS}" uninstall "${RELEASE}" --ignore-not-found 2>/dev/null || helm -n "${MONITORING_NS}" uninstall "${RELEASE}" || true
  kubectl delete ns "${MONITORING_NS}" --ignore-not-found
  # CRDs are not removed by helm uninstall
  kubectl get crd -o name | grep 'monitoring.coreos.com' | xargs -r kubectl delete
  ok "kube-prometheus-stack removed"
  exit 0
fi

log "Installing kube-prometheus-stack ${KUBE_PROMETHEUS_STACK_VERSION} into ${MONITORING_NS}"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update prometheus-community >/dev/null
render "${MANIFEST_DIR}/prometheus/values.yaml" | helm upgrade --install "${RELEASE}" prometheus-community/kube-prometheus-stack \
  --version "${KUBE_PROMETHEUS_STACK_VERSION}" \
  --namespace "${MONITORING_NS}" --create-namespace \
  --values - --wait --timeout 10m

wait_for_rollout "${MONITORING_NS}" deploy/prom-grafana deploy/prom-kube-prometheus-stack-operator 2>/dev/null \
  || wait_for_rollout "${MONITORING_NS}" deploy/prom-grafana deploy/prom-operator
ok "Prometheus stack ready"
printf '\n  Grafana:    %s  (admin/admin)\n  Prometheus: %s\n  In-cluster: http://prom-prometheus.%s.svc:9090\n\n' \
  "$(url_for grafana)" "$(url_for prometheus)" "${MONITORING_NS}"
