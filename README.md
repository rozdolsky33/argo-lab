# Argo ecosystem learning lab on kind

Spin up a local Kubernetes cluster with **kind**, install a vanilla **Argo CD**, then add
**Argo Rollouts**, **Argo Workflows**, **Argo Events**, **Argo CD Image Updater** and supporting
tools (ingress-nginx, Prometheus + Grafana, cert-manager) one at a time or all at once.
`labs/` contains guided exercises for each component.

Everything is installed from the upstream manifests at versions pinned in **one file**:
[`cluster/cluster.env`](cluster/cluster.env).

## Quick start

```bash
make up            # kind cluster "argo-lab" + ingress-nginx  (~2 min)
make argocd        # vanilla Argo CD, prints the admin password, logs the CLI in
make status        # URLs, pod health, credentials
```

Then open http://argocd.localhost:8880 (user `admin`, password from `make status`).

Add components as you need them:

```bash
make rollouts      # controller + dashboard + kubectl-argo-rollouts plugin
make workflows     # quick-start install: controller, server (no login), MinIO artifact store
make events        # controller + JetStream EventBus
make image-updater
make prometheus    # kube-prometheus-stack (Grafana admin/admin)
make cert-manager  # + self-signed "lab-ca" ClusterIssuer
make all           # cluster + everything above
make down          # delete the cluster
make help          # every target
```

Every component also has `make uninstall-<name>`, and every script is idempotent (re-run to repair).
`scripts/install-all.sh --only argocd,rollouts` / `--skip prometheus` for subsets.

## URLs

Hosts use `*.localhost`, a public wildcard DNS that resolves to 127.0.0.1, so nothing to edit in
`/etc/hosts`. The port comes from `HTTP_PORT` in `cluster.env`.

| UI | URL |
|---|---|
| Argo CD | http://argocd.localhost:8880 |
| Argo Rollouts dashboard | http://rollouts.localhost:8880 |
| Argo Workflows | http://workflows.localhost:8880 |
| Grafana | http://grafana.localhost:8880 |
| Prometheus | http://prometheus.localhost:8880 |

Port 80/443 give URLs without a port but on this machine they are used by another kind cluster,
hence 8880/8443. Change `HTTP_PORT`/`HTTPS_PORT` in `cluster.env` *before* `make up` (the ports are
baked into the kind node); `make reset` recreates the cluster.

## Configuration

`cluster/cluster.env` is sourced by every script. Override anything inline:

```bash
WORKERS=1 make up                     # smaller cluster
ARGOCD_VERSION=v3.4.0 make argocd     # try another version (then `make argocd` again to go back)
```

Downloaded manifests are cached in `.cache/` so reinstalling works offline.

## Layout

```
cluster/     cluster.env (all config) and the kind config template
scripts/     one install-<component>.sh per component (+ --uninstall), cluster-up/down, status, install-all
manifests/   small local overlays applied after each upstream install (ingresses, config patches, Helm values)
labs/        guided exercises, see labs/README.md
```

## Using the labs with Argo CD

Argo CD needs a git repo to sync from. Push this folder to GitHub, then:

```bash
# in cluster/cluster.env
GIT_REPO_URL="https://github.com/<you>/<repo>.git"

make init-labs     # rewrites the repoURL placeholder in labs/
git commit -am "point labs at my repo" && git push
```

Start with [labs/README.md](labs/README.md).

## Versions

| Component | Version |
|---|---|
| Kubernetes (kind node) | v1.35.0 |
| ingress-nginx | controller-v1.15.1 |
| Argo CD | v3.5.6 |
| Argo Rollouts | v1.10.1 |
| Argo Workflows | v4.1.6 |
| Argo Events | v1.9.11 |
| Argo CD Image Updater | v1.4.0 |
| kube-prometheus-stack | 92.13.1 |
| cert-manager | v1.21.3 |

## Troubleshooting

- **`Host port 8880 is already in use`**: another process or kind cluster has it. `docker ps` shows
  which; pick other ports in `cluster.env`.
- **Argo CD UI shows a blank page / CLI login fails**: `kubectl -n argocd rollout status deploy/argocd-server`;
  the server restarts once after the `server.insecure` patch.
- **Ingress created but 404**: the ingress-nginx admission webhook may still be starting; re-run the install script.
- **Everything is slow**: Docker Desktop CPU/memory. 4 CPUs / 8 GB is comfortable for the full stack.
- **Start over**: `make reset` (cluster) or `make uninstall-<x> && make <x>` (one component).
