# Lab 04 - AnalysisTemplates, AnalysisRuns and Experiments

**Prereqs:** `make up argocd rollouts prometheus`.

**Concepts:** AnalysisTemplate vs ClusterAnalysisTemplate, AnalysisRun lifecycle, providers (job,
web, prometheus, plus datadog/newrelic/wavefront/kayenta/plugin), inline vs background analysis,
`successCondition` / `failureCondition` expressions, `failureLimit`, `count` / `interval`,
Experiments.

## 1. Make ingress-nginx metrics visible to Prometheus

```bash
kubectl apply -f labs/04-rollouts-analysis/templates/ingress-nginx-servicemonitor.yaml
# After ~30 s, http://prometheus.localhost:8880 -> Status > Targets shows ingress-nginx UP
```

## 2. Deploy the rollout and keep traffic flowing

```bash
kubectl apply -k labs/04-rollouts-analysis/canary-with-analysis
./labs/04-rollouts-analysis/traffic.sh      # leave running in a second terminal
kubectl argo rollouts -n analysis get rollout analysis-demo --watch
```

## 3. A good canary

```bash
kubectl argo rollouts -n analysis set image analysis-demo demo=argoproj/rollouts-demo:yellow
kubectl -n analysis get analysisrun -w
```

- Step 2 creates an AnalysisRun from `smoke-test` (job provider): three Jobs, 10 s apart.
  `kubectl -n analysis get jobs` shows them. When it passes, weight goes to 50.
- From step 3 (`startingStep: 2`) a **background** AnalysisRun from `success-rate` runs the
  Prometheus query every 20 s. `kubectl argo rollouts -n analysis get rollout analysis-demo` lists
  both runs under the revision.
- Open the run: `kubectl -n analysis describe analysisrun <name>` shows each measurement's value.

## 4. A bad canary

```bash
kubectl argo rollouts -n analysis set image analysis-demo demo=argoproj/rollouts-demo:bad-red
```

`bad-red` answers 500 to some requests. The smoke-test job (`curl -f`) fails, the run is **Failed**,
the Rollout **aborts** and traffic snaps back to stable. If the smoke test happens to pass, the
background success-rate analysis catches it a step later. Check the dashboard: the revision is
marked with the failed analysis.

```bash
kubectl argo rollouts -n analysis retry rollout analysis-demo     # try again
kubectl argo rollouts -n analysis undo analysis-demo              # or roll back
```

## 5. Experiments

```bash
kubectl apply -f labs/04-rollouts-analysis/experiment/experiment.yaml
kubectl -n analysis get experiment,rs,analysisrun -w
```

Two ReplicaSets run for 2 minutes with an analysis attached to one. Experiments never receive
production traffic unless you wire them into a canary step (`- experiment:` step with weights).

## Things to try

- Change `successCondition` to `result[0] >= 0.999` and watch a *good* canary fail; then add
  `inconclusiveLimit` and see the **Inconclusive** state that pauses instead of aborting.
- Move `smoke-test` to a `ClusterAnalysisTemplate` and reference it with `clusterScope: true`.
- Read `templates/web-template.yaml` and point it at a JSON endpoint you control.
- Use `measurementRetention` to keep more than the default 10 measurements for debugging.

## Cleanup

```bash
kubectl delete -f labs/04-rollouts-analysis/experiment/experiment.yaml --ignore-not-found
kubectl delete -k labs/04-rollouts-analysis/canary-with-analysis
kubectl delete -f labs/04-rollouts-analysis/templates/ingress-nginx-servicemonitor.yaml
```
