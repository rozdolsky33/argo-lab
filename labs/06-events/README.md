# Lab 06 - Argo Events

**Prereqs:** `make up argocd workflows events` (03 also needs an Argo CD app named `podinfo-dev`, from lab 00).

**Concepts:** EventBus (JetStream), EventSource, Sensor, dependencies, triggers (k8s, log, argo-workflow,
http, ...), parameterisation from the event payload, data filters, RBAC for triggers.

```bash
kubectl -n argo-events get eventbus,pods          # 3 eventbus-default-js pods from `make events`
```

## 1. Webhook -> Workflow

```bash
kubectl apply -f labs/06-events/01-webhook-to-workflow.yaml
kubectl -n argo-events get eventsource,sensor,pods     # one pod per EventSource and Sensor
kubectl -n argo-events port-forward svc/webhook-eventsource-svc 12000:12000 &
curl -d '{"message":"hello events"}' -H 'Content-Type: application/json' http://localhost:12000/example
argo -n argo list                                   # a from-webhook-xxxxx Workflow appeared
argo -n argo logs @latest                           # prints the JSON body
```

Follow the chain in logs:
`kubectl -n argo-events logs -l eventsource-name=webhook` and `... -l sensor-name=webhook`.

## 2. Calendar -> log trigger

```bash
kubectl apply -f labs/06-events/02-calendar-to-log.yaml
kubectl -n argo-events logs -l sensor-name=calendar -f    # a line every minute with the event payload
```

## 3. Webhook -> Argo CD refresh with a data filter

```bash
kubectl apply -f labs/06-events/03-webhook-to-argocd-sync.yaml
kubectl -n argo-events port-forward svc/argocd-hook-eventsource-svc 12001:12001 &
curl -d '{"app":"other"}'       -H 'Content-Type: application/json' http://localhost:12001/refresh   # filtered out
curl -d '{"app":"podinfo-dev"}' -H 'Content-Type: application/json' http://localhost:12001/refresh   # fires
kubectl -n argocd get application podinfo-dev -o jsonpath='{.metadata.annotations}'
```

Argo CD consumes the `refresh` annotation (removes it) and re-evaluates the app. Check the Events
tab of the app in the UI.

## Things to try

- Expose the webhook through ingress-nginx instead of port-forward (add an Ingress for the
  `webhook-eventsource-svc`), then point a GitHub webhook at it via a tunnel.
- Replace the `k8s` trigger with the `argoWorkflow` trigger (`operation: submit`) which understands
  WorkflowTemplates: `source.resource` can be a `WorkflowTemplate` reference.
- Add a second dependency and a `conditions: "a && b"` expression on the trigger.
- Other EventSources worth a look: `github`, `sns`, `kafka`, `resource` (watch any k8s object),
  `minio` (bucket notifications from the Workflows quick-start MinIO).

## Cleanup

```bash
kubectl delete -f labs/06-events/01-webhook-to-workflow.yaml -f labs/06-events/02-calendar-to-log.yaml -f labs/06-events/03-webhook-to-argocd-sync.yaml
```
