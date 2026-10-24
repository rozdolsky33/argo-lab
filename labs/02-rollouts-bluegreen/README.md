# Lab 02 - Blue-Green with Argo Rollouts

**Prereqs:** `make up argocd rollouts`. Works with or without git: either apply the manifests
directly with kustomize, or (after `make init-labs`) let Argo CD manage them via `application.yaml`.

**Concepts:** Rollout CRD vs Deployment, active/preview Services, manual promotion, preview
replica count, scale-down delay, rollback, the Rollouts dashboard and kubectl plugin.

Two browser tabs: **http://bluegreen.localhost:8880** (active) and
**http://bluegreen-preview.localhost:8880** (preview). The page fills with coloured squares that
show which image is answering. Also open the dashboard: `make status` lists it.

## 1. Deploy blue

```bash
kubectl apply -k labs/02-rollouts-bluegreen/manifests        # or: kubectl apply -f labs/02-rollouts-bluegreen/application.yaml
kubectl argo rollouts -n bluegreen get rollout bluegreen-demo --watch
```

Both hosts show **blue**. In the watch output note `revision:1`, `stable`, `active`.

## 2. Roll out green

```bash
kubectl argo rollouts -n bluegreen set image bluegreen-demo demo=argoproj/rollouts-demo:green
```

(With the Argo CD route, instead edit the image in `rollout.yaml`, push, refresh.)

- A second ReplicaSet appears with 1 pod (`previewReplicaCount`). Rollout status is **Paused**.
- Preview host shows **green**, active host still **blue**. This is your window for testing.
  (A 503 on the preview host for the first few seconds just means the single preview pod is not Ready yet.)
- `kubectl -n bluegreen get svc bluegreen-demo-preview -o yaml | grep hash` shows the selector
  the controller injected.

## 3. Promote (or abort)

```bash
kubectl argo rollouts -n bluegreen promote bluegreen-demo
# or: kubectl argo rollouts -n bluegreen abort bluegreen-demo
```

On promote: preview scales to 2, active Service flips to green (ingress-nginx picks up the new
endpoints within a second or two), blue ReplicaSet stays
for `scaleDownDelaySeconds` then scales to 0. Run `undo` within that window and the switch back is
instant because the pods are still there:

```bash
kubectl argo rollouts -n bluegreen undo bluegreen-demo
```

## Things to try

- Set `autoPromotionEnabled: true` and `autoPromotionSeconds: 30` and watch an unattended promotion.
- Add `prePromotionAnalysis` / `postPromotionAnalysis` after Lab 04.
- Compare with a plain Deployment's `RollingUpdate`: `kubectl argo rollouts` has no equivalent of
  "preview", and the switchover is gradual rather than atomic.
- Argo CD shows Rollout health natively (it ships a health check for the Rollout CRD). A paused
  rollout is **Suspended**, not Degraded.

## Cleanup

```bash
kubectl delete -k labs/02-rollouts-bluegreen/manifests
# or: kubectl -n argocd delete application bluegreen-demo
```
