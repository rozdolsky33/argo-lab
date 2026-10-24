# Labs

Hands-on exercises for the Argo ecosystem. Each folder has a README with goals, step-by-step
commands, what to watch in the UI, and cleanup. Suggested order:

| Lab | Topic | Needs (`make ...`) | Git required |
|---|---|---|---|
| [00-gitops-basics](00-gitops-basics/) | Application CRD, auto-sync, prune, self-heal, sync waves, hooks, app-of-apps | `up argocd` | yes |
| [01-applicationsets](01-applicationsets/) | list / git directory / git file / matrix / cluster generators | `up argocd` | yes |
| [02-rollouts-bluegreen](02-rollouts-bluegreen/) | Blue-green: preview service, manual promotion, instant rollback | `up argocd rollouts` | no |
| [03-rollouts-canary](03-rollouts-canary/) | Canary steps + ingress-nginx traffic splitting, abort / retry | `up argocd rollouts` | no |
| [04-rollouts-analysis](04-rollouts-analysis/) | AnalysisTemplates (job, web, prometheus), background analysis, Experiments | `up argocd rollouts prometheus` | no |
| [05-workflows](05-workflows/) | Steps, DAGs, parameters, artifacts, templates, cron, retries | `up workflows` | no |
| [06-events](06-events/) | EventSource -> Sensor -> Workflow / Argo CD refresh, filters, RBAC | `up argocd workflows events` | no |
| [07-image-updater](07-image-updater/) | Update strategies, argocd vs git write-back | `up argocd image-updater` | yes |
| [08-argocd-advanced](08-argocd-advanced/) | AppProjects, RBAC, sync windows, notifications, multi-source, Helm, TLS | `up argocd cert-manager` | yes |

**"Git required"** labs are synced by Argo CD from your fork of this repo. Push the repo, set
`GIT_REPO_URL` in `cluster/cluster.env`, run `make init-labs`, commit and push again. Labs marked
"no" can be applied straight with `kubectl apply -k` and also ship an `application.yaml` for the
GitOps route.

`labs/apps/` holds the shared sample apps (a podinfo kustomize base with dev/prod overlays and
notes on the `argoproj/rollouts-demo` image).

All hostnames end in `.localhost`, which resolves to 127.0.0.1. The port is `HTTP_PORT` from
`cluster/cluster.env` (8880 by default here; drop the `:8880` if you run on port 80).
