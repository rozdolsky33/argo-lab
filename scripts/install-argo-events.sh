#!/usr/bin/env bash
# Argo Events controller (upstream pinned manifest) + a default JetStream EventBus.
source "$(dirname "$0")/lib/common.sh"
parse_install_args "$@"
require_tools kubectl
require_cluster

URL="https://raw.githubusercontent.com/argoproj/argo-events/${ARGO_EVENTS_VERSION}/manifests/install.yaml"
NAME="argo-events-${ARGO_EVENTS_VERSION}.yaml"

if [[ "${ACTION}" == "uninstall" ]]; then
  log "Uninstalling Argo Events"
  kubectl delete -f "${MANIFEST_DIR}/argo-events/eventbus.yaml" --ignore-not-found || true
  delete_url "${URL}" "${NAME}" -n "${ARGO_EVENTS_NS}"
  kubectl delete ns "${ARGO_EVENTS_NS}" --ignore-not-found
  ok "Argo Events removed"
  exit 0
fi

log "Installing Argo Events ${ARGO_EVENTS_VERSION} into ${ARGO_EVENTS_NS}"
ensure_ns "${ARGO_EVENTS_NS}"
apply_url "${URL}" "${NAME}" -n "${ARGO_EVENTS_NS}"
wait_for_rollout "${ARGO_EVENTS_NS}" deploy/controller-manager
wait_for_crd eventbus.argoproj.io eventsources.argoproj.io sensors.argoproj.io

log "Creating default JetStream EventBus"
kubectl apply -f "${MANIFEST_DIR}/argo-events/eventbus.yaml"
# The controller creates the StatefulSet asynchronously; wait for it to appear before watching it.
for _ in $(seq 1 30); do
  kubectl -n "${ARGO_EVENTS_NS}" get statefulset eventbus-default-js >/dev/null 2>&1 && break
  sleep 2
done
wait_for_rollout "${ARGO_EVENTS_NS}" statefulset/eventbus-default-js

ok "Argo Events ready (EventBus 'default' in ${ARGO_EVENTS_NS})"
