#!/usr/bin/env bash
# Install every component in dependency order.
#   install-all.sh                     everything
#   install-all.sh --only argocd,rollouts
#   install-all.sh --skip prometheus,cert-manager
source "$(dirname "$0")/lib/common.sh"
require_cluster

ALL=(ingress-nginx argocd argo-rollouts argo-workflows argo-events argocd-image-updater prometheus cert-manager)
only="" skip=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --only) only="$2"; shift 2 ;;
    --skip) skip="$2"; shift 2 ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

# Accept the short make-target names too.
normalize() {
  case "$1" in
    ingress) echo ingress-nginx ;;
    rollouts) echo argo-rollouts ;;
    workflows) echo argo-workflows ;;
    events) echo argo-events ;;
    image-updater) echo argocd-image-updater ;;
    *) echo "$1" ;;
  esac
}
selected=()
for c in "${ALL[@]}"; do
  if [[ -n "${only}" ]]; then
    match=0
    for o in ${only//,/ }; do [[ "$(normalize "$o")" == "$c" ]] && match=1; done
    [[ $match -eq 1 ]] || continue
  fi
  if [[ -n "${skip}" ]]; then
    match=0
    for o in ${skip//,/ }; do [[ "$(normalize "$o")" == "$c" ]] && match=1; done
    [[ $match -eq 1 ]] && continue
  fi
  selected+=("$c")
done

log "Installing: ${selected[*]}"
for c in "${selected[@]}"; do
  "${SCRIPT_DIR}/../install-${c}.sh"
done
ok "All selected components installed"
"${SCRIPT_DIR}/../status.sh"
