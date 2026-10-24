#!/usr/bin/env bash
# Shared helpers for all scripts. Source this file; do not execute it.
# shellcheck disable=SC2034

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CACHE_DIR="${ROOT_DIR}/.cache"
MANIFEST_DIR="${ROOT_DIR}/manifests"

# shellcheck source=../../cluster/cluster.env
source "${ROOT_DIR}/cluster/cluster.env"

# --- output -----------------------------------------------------------------
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'; C_INFO=$'\033[1;34m'; C_OK=$'\033[1;32m'; C_WARN=$'\033[1;33m'; C_ERR=$'\033[1;31m'
else
  C_RESET=""; C_INFO=""; C_OK=""; C_WARN=""; C_ERR=""
fi
log()  { printf '%s==> %s%s\n' "$C_INFO" "$*" "$C_RESET"; }
ok()   { printf '%s  ✔ %s%s\n' "$C_OK" "$*" "$C_RESET"; }
warn() { printf '%s  ! %s%s\n' "$C_WARN" "$*" "$C_RESET" >&2; }
die()  { printf '%s  ✖ %s%s\n' "$C_ERR" "$*" "$C_RESET" >&2; exit 1; }

# --- preconditions ----------------------------------------------------------
require_tools() {
  local missing=()
  for t in "$@"; do command -v "$t" >/dev/null 2>&1 || missing+=("$t"); done
  [[ ${#missing[@]} -eq 0 ]] || die "Missing required tools: ${missing[*]}"
}

check_docker() {
  docker info >/dev/null 2>&1 || die "Docker daemon is not reachable. Start Docker Desktop and retry."
}

cluster_exists() { kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; }

# use_context: switch kubectl to the lab cluster only when needed (writing kubeconfig takes a
# lock, so unconditional switching breaks scripts that run in parallel).
use_context() {
  local want="kind-${CLUSTER_NAME}"
  [[ "$(kubectl config current-context 2>/dev/null || true)" == "${want}" ]] && return 0
  for _ in 1 2 3 4 5; do
    kubectl config use-context "${want}" >/dev/null 2>&1 && return 0
    sleep 1
  done
  die "Could not switch kubectl context to ${want}"
}

require_cluster() {
  cluster_exists || die "kind cluster '${CLUSTER_NAME}' not found. Run: make up"
  use_context
}

# --- manifests --------------------------------------------------------------
# fetch <url> <cache-file-name>  -> prints local path; downloads once into .cache/
fetch() {
  local url="$1" name="$2"
  local dest="${CACHE_DIR}/${name}"
  mkdir -p "${CACHE_DIR}"
  if [[ ! -s "${dest}" ]]; then
    log "Downloading ${name}" >&2
    curl -fsSL --retry 3 -o "${dest}.tmp" "${url}" || die "Download failed: ${url}"
    mv "${dest}.tmp" "${dest}"
  fi
  printf '%s\n' "${dest}"
}

# apply_url <url> <cache-name> [kubectl apply args...]
# Server-side apply: upstream CRDs (Argo CD, Workflows, cert-manager) exceed the 256KiB
# last-applied-configuration annotation limit that client-side apply needs.
apply_url() {
  local url="$1" name="$2"; shift 2
  local file; file="$(fetch "${url}" "${name}")"
  kubectl apply --server-side --force-conflicts "$@" -f "${file}"
}

# delete_url <url> <cache-name> [kubectl delete args...]
delete_url() {
  local url="$1" name="$2"; shift 2
  local file; file="$(fetch "${url}" "${name}")"
  kubectl delete "$@" --ignore-not-found -f "${file}"
}

# render <template> -> stdout, substituting only exported variables we define
render() {
  envsubst < "$1"
}

ensure_ns() {
  kubectl get ns "$1" >/dev/null 2>&1 || kubectl create ns "$1" >/dev/null
}

# --- waiting ----------------------------------------------------------------
# wait_for_rollout <namespace> <deploy|statefulset|daemonset>/<name> ...
wait_for_rollout() {
  local ns="$1"; shift
  for res in "$@"; do
    log "Waiting for ${res} in ${ns}"
    kubectl -n "${ns}" rollout status "${res}" --timeout="${WAIT_TIMEOUT}"
  done
}

# wait_for_crd <crd-name> ...
wait_for_crd() {
  for crd in "$@"; do
    kubectl wait --for=condition=Established "crd/${crd}" --timeout=120s >/dev/null
  done
}

# wait_for_pods_ready <namespace> <label-selector>
wait_for_pods_ready() {
  local ns="$1" sel="$2"
  kubectl -n "${ns}" wait --for=condition=Ready pod -l "${sel}" --timeout="${WAIT_TIMEOUT}"
}

# --- argument parsing shared by install-*.sh --------------------------------
ACTION="install"
parse_install_args() {
  for a in "$@"; do
    case "$a" in
      --uninstall|-u) ACTION="uninstall" ;;
      -h|--help) printf 'Usage: %s [--uninstall]\n' "$(basename "$0")"; exit 0 ;;
      *) die "Unknown argument: $a" ;;
    esac
  done
}

# url_for <subdomain> -> http://sub.domain[:port]
url_for() {
  if [[ "${HTTP_PORT}" == "80" ]]; then printf 'http://%s.%s\n' "$1" "${BASE_DOMAIN}"
  else printf 'http://%s.%s:%s\n' "$1" "${BASE_DOMAIN}" "${HTTP_PORT}"; fi
}

# port_free <port> -> 0 if nothing listens on the host port (checks docker and local listeners)
port_free() {
  local port="$1"
  if docker ps --format '{{.Ports}}' 2>/dev/null | grep -qE "(^|[ ,]):${port}->"; then return 1; fi
  if lsof -nP -iTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1; then return 1; fi
  return 0
}
