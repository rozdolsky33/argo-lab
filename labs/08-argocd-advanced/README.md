# Lab 08 - Argo CD advanced patterns

**Prereqs:** `make up argocd` (+ `cert-manager` for section 5), repo pushed and `make init-labs` run.

## 1. AppProjects, RBAC and sync windows

```bash
kubectl apply -f labs/08-argocd-advanced/projects/appproject.yaml
kubectl apply -f labs/08-argocd-advanced/projects/app-in-project.yaml        # works
kubectl apply -f labs/08-argocd-advanced/projects/app-violating-project.yaml # rejected by the API
argocd proj get team-a
argocd proj windows list team-a
```

- Edit the deny window to cover *now* and watch `team-a-podinfo` stop auto-syncing (status shows
  the window). `manualSync: true` still lets you click Sync.
- Project-scoped token: `argocd proj role create-token team-a ci` then
  `argocd --auth-token <token> app sync team-a-podinfo` works, while `argocd --auth-token <token> app delete ...` is denied.
- Global RBAC lives in `argocd-rbac-cm` (`policy.csv`, `policy.default`). Try setting
  `policy.default: role:readonly` and log in as a Dex/local user.

## 2. Notifications

```bash
kubectl apply -f labs/08-argocd-advanced/notifications/echo-receiver.yaml
kubectl apply -f labs/08-argocd-advanced/notifications/argocd-notifications-cm.yaml
./labs/08-argocd-advanced/notifications/subscribe.sh team-a-podinfo
kubectl -n argocd logs deploy/echo -f
argocd app sync team-a-podinfo        # a JSON body arrives in the echo log
```

Break the app (`kubectl -n team-a-dev set image deploy/podinfo podinfo=ghcr.io/stefanprodan/podinfo:does-not-exist`
with selfHeal temporarily off) to see the degraded trigger. Swap the webhook service for Slack or
email: https://argocd-notifications.readthedocs.io/en/stable/services/overview/

## 3. Multi-source Applications

```bash
kubectl apply -f labs/08-argocd-advanced/multi-source/application.yaml
```

The chart comes from the podinfo Helm repo; values come from *this* repo through the `$values`
ref. Change `values.yaml`, push, refresh: only the values source changes. Open
http://podinfo-helm.localhost:8880.

## 4. Helm with inline values, ignoreDifferences, server-side apply

```bash
kubectl apply -f labs/08-argocd-advanced/helm-app/application.yaml
kubectl -n podinfo-helm-inline scale deploy/podinfo --replicas=3
argocd app get podinfo-helm            # still Synced: /spec/replicas is ignored and respected on sync
```

Remove `RespectIgnoreDifferences=true` and sync: the replicas are reset even though the diff was ignored.

## 5. TLS from cert-manager on an app ingress

```bash
make cert-manager
kubectl apply -f labs/08-argocd-advanced/tls/application.yaml
kubectl -n podinfo-tls get certificate,secret podinfo-tls
curl -vk https://podinfo-tls.localhost:8443/ 2>&1 | grep -E 'issuer|subject'
```

Trust the lab CA locally to lose the `-k`:
`kubectl -n cert-manager get secret lab-root-ca -o jsonpath='{.data.ca\.crt}' | base64 -d > lab-ca.crt`
and add it to your keychain.

## More to explore from here

- **Resource health**: custom Lua health checks in `argocd-cm` (`resource.customizations.health.<group>_<kind>`).
- **Config Management Plugins** (sidecar in repo-server) for tools Argo CD doesn't natively render.
- **Diffing customisation**: `managedFieldsManagers`, `jqPathExpressions`.
- **Sync options**: `ApplyOutOfSyncOnly`, `PruneLast`, `Replace=true`, `Validate=false`, `PrunePropagationPolicy`.
- **Managing Argo CD with Argo CD**: an Application whose source is `manifests/argocd/` in this repo.
- **Rollouts + Argo CD**: an Application pointing at lab 03; the UI shows Rollout health and
  the "Rollouts" extension (https://github.com/argoproj-labs/rollout-extension) adds the dashboard inside Argo CD.

## Cleanup

```bash
kubectl -n argocd delete application team-a-podinfo podinfo-helm-multisource podinfo-helm podinfo-tls --ignore-not-found
kubectl -n argocd delete appproject team-a
kubectl delete -f labs/08-argocd-advanced/notifications/echo-receiver.yaml
```
