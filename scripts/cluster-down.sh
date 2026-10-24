#!/usr/bin/env bash
# Delete the kind cluster.
source "$(dirname "$0")/lib/common.sh"
require_tools kind

if cluster_exists; then
  log "Deleting kind cluster '${CLUSTER_NAME}'"
  kind delete cluster --name "${CLUSTER_NAME}"
  ok "Deleted"
else
  ok "kind cluster '${CLUSTER_NAME}' does not exist"
fi
