#!/usr/bin/env bash
# One-time: replace the repoURL placeholder in all lab manifests with GIT_REPO_URL from cluster.env.
source "$(dirname "$0")/lib/common.sh"

PLACEHOLDER="https://github.com/CHANGE_ME/ArgoCD.git"
[[ "${GIT_REPO_URL}" != "${PLACEHOLDER}" ]] || die "Set GIT_REPO_URL in cluster/cluster.env (or env) to your GitHub repo first."

log "Pointing labs at ${GIT_REPO_URL} (branch ${GIT_BRANCH})"
count=0
while IFS= read -r -d '' f; do
  if grep -q "${PLACEHOLDER}" "$f"; then
    sed -i '' "s#${PLACEHOLDER}#${GIT_REPO_URL}#g" "$f"
    count=$((count + 1))
  fi
done < <(find "${ROOT_DIR}/labs" -type f \( -name '*.yaml' -o -name '*.yml' -o -name '*.md' \) -print0)
ok "Updated ${count} file(s). Commit and push, then Argo CD can sync the labs."
