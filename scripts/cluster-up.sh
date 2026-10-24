#!/usr/bin/env bash
# Create the kind cluster described by cluster/cluster.env (idempotent).
source "$(dirname "$0")/lib/common.sh"

require_tools kind kubectl docker envsubst
check_docker

if cluster_exists; then
  ok "kind cluster '${CLUSTER_NAME}' already exists"
  use_context
  exit 0
fi

for p in "${HTTP_PORT}" "${HTTPS_PORT}"; do
  port_free "${p}" || die "Host port ${p} is already in use (another kind cluster or local server?).
    Either stop it, or pick other ports:  HTTP_PORT=8080 HTTPS_PORT=8443 make up
    (persist by editing cluster/cluster.env; URLs will then include the port)"
done

# Build the worker node list for the template.
WORKER_NODES=""
for ((i = 0; i < WORKERS; i++)); do
  WORKER_NODES+=$'- role: worker\n'"  image: ${KIND_NODE_IMAGE}"$'\n'
done
export CLUSTER_NAME KIND_NODE_IMAGE HTTP_PORT HTTPS_PORT WORKER_NODES

RENDERED="${ROOT_DIR}/cluster/kind-config.yaml"
render "${ROOT_DIR}/cluster/kind-config.yaml.tpl" > "${RENDERED}"

log "Creating kind cluster '${CLUSTER_NAME}' (${WORKERS} worker(s), ${KIND_NODE_IMAGE%%@*})"
kind create cluster --config "${RENDERED}" --wait 120s
use_context
ok "Cluster ready. Context: kind-${CLUSTER_NAME}"
kubectl get nodes
