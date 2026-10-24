# Lab 03 - Canary with ingress-nginx traffic routing

**Prereqs:** `make up argocd rollouts` (ingress-nginx comes with `make up`).

**Concepts:** canary steps (`setWeight`, `pause`), stable vs canary Services, `trafficRouting`
with ingress-nginx, header-based canary, abort / retry / promote-full, dynamic stable scale.

Open **http://canary.localhost:8880** and keep refreshing, or run `./traffic.sh` to count
responses per colour.

## 1. Deploy and start a canary

```bash
kubectl apply -k labs/03-rollouts-canary/manifests
kubectl argo rollouts -n canary get rollout canary-demo --watch
kubectl argo rollouts -n canary set image canary-demo demo=argoproj/rollouts-demo:yellow
```

- Status becomes **Paused** at step 2 with `SetWeight: 20`.
- `kubectl -n canary get ingress` -> a second ingress `canary-demo-canary-demo-canary` exists.
  Look at its annotations: `nginx.ingress.kubernetes.io/canary: "true"`, `canary-weight: "20"`.
- `./traffic.sh 100` shows roughly 80 blue / 20 yellow. Note there is still only **one** yellow pod
  among four: with traffic routing, weight is enforced at the proxy, not by pod ratio.
- Force the canary: `curl -H 'X-Canary: always' http://canary.localhost:8880/color`.

## 2. Promote step by step

```bash
kubectl argo rollouts -n canary promote canary-demo        # continue past the indefinite pause
```

Weight goes 50 -> 80 -> 100 with 30 s pauses. Watch pods: canary ReplicaSet scales up, stable
scales down, and at the end the canary becomes the new stable and the canary ingress weight returns to 0.

## 3. Abort and retry

```bash
kubectl argo rollouts -n canary set image canary-demo demo=argoproj/rollouts-demo:red
kubectl argo rollouts -n canary abort canary-demo           # traffic back to stable immediately
kubectl argo rollouts -n canary get rollout canary-demo     # Status: Degraded (aborted)
kubectl argo rollouts -n canary retry rollout canary-demo   # start the same revision again
kubectl argo rollouts -n canary promote canary-demo --full  # skip all remaining steps
```

## Things to try

- Set `dynamicStableScale: true` under `canary:` so stable pods scale down as canary weight grows.
- Replace `pause: {}` with `pause: {duration: 1m}` for a fully automated canary.
- Add `setCanaryScale: {replicas: 2}` before a `setWeight` to decouple pod count from weight.
- Use the Argo CD route (`application.yaml`): the rollout starts when you change the image in git.
  Argo CD reports the Rollout as **Progressing / Suspended** during pauses.

## Cleanup

```bash
kubectl delete -k labs/03-rollouts-canary/manifests
```
