# Lab 00 - GitOps basics with Argo CD

**Prereqs:** `make up argocd`, this repo pushed to GitHub and `make init-labs` run.

**Concepts:** Application CRD, sync status vs health status, manual vs automated sync, prune,
self-heal, sync options, sync waves, resource hooks, app-of-apps.

Open the UI (`make status` prints the URL and password) and keep it visible during every step.

## 1. A manual Application

```bash
kubectl apply -f labs/00-gitops-basics/application.yaml
argocd app get podinfo-dev          # Sync Status: OutOfSync, Health: Missing
argocd app diff podinfo-dev         # what *would* change
argocd app sync podinfo-dev         # or click SYNC in the UI
curl -s http://podinfo-dev.localhost:8880/ | head -5
```

Things to try:
- `kubectl -n podinfo-dev scale deploy/podinfo --replicas=3` -> app turns **OutOfSync** but nothing
  happens. Argo CD only reports drift until you sync.
- Delete the Deployment with kubectl -> Health **Missing**, OutOfSync. Sync restores it.

## 2. Automated sync, prune and self-heal

```bash
kubectl apply -f labs/00-gitops-basics/application-automated.yaml
```

- Scale the deployment again: within seconds **selfHeal** reverts it. Watch the Events tab.
- Edit `labs/apps/podinfo/overlays/dev/kustomization.yaml`, change the UI message, push. Argo CD
  polls git every 3 minutes by default; click REFRESH to pick it up immediately.
- Remove `ingress.yaml` from the dev overlay's `resources`, push, refresh -> **prune** deletes the Ingress.
  Put it back afterwards.

## 3. Sync waves and hooks

```bash
kubectl apply -f labs/00-gitops-basics/application-waves.yaml
argocd app sync waves-demo
```

Watch the sync in the UI: the `db-migrate` Job (PreSync) runs first, then the ConfigMap (wave 0),
the Deployment (wave 1) must become Healthy before the Service (wave 2) is applied, and finally the
`smoke-test` Job (PostSync). Open `sync-waves-hooks/` to see the annotations that drive this.

- Change the PreSync job command to `exit 1`, push, sync -> the sync fails and nothing else is applied.
- Hook delete policies: `BeforeHookCreation` (default) vs `HookSucceeded` vs `HookFailed`.
- Other hook types: `Sync`, `SyncFail`, `PostDelete`.

## 4. App of Apps

```bash
kubectl delete -f labs/00-gitops-basics/application-automated.yaml   # avoid two apps owning podinfo-dev
kubectl apply -f labs/00-gitops-basics/app-of-apps/root.yaml
```

`root` syncs `app-of-apps/apps/`, which contains two more Applications. Deleting `root` cascades
(finalizer) and removes both children and their workloads. Add a third Application YAML to that
folder and push to see it appear automatically. Lab 01 shows ApplicationSets, the modern
alternative to this pattern.

## Cleanup

```bash
kubectl delete -f labs/00-gitops-basics/app-of-apps/root.yaml
kubectl delete application -n argocd waves-demo podinfo-dev --ignore-not-found
```
