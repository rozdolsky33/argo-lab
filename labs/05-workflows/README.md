# Lab 05 - Argo Workflows

**Prereqs:** `make up workflows` and the `argo` CLI (`brew install argo`). Open the UI from `make status`.
The quick-start install uses `--auth-mode=server`, so there is no login.

**Concepts:** Workflow / template types (container, script, steps, dag, suspend), parameters,
outputs, artifacts and the artifact repository, WorkflowTemplate vs ClusterWorkflowTemplate,
CronWorkflow, retries, exit handlers, `when` conditions, loops.

Run the numbered files in order. Every submit is `argo -n argo submit <file> --watch`; `--log`
streams pod logs as they run. Without the CLI, `kubectl create -f <file>` works too (not `apply`:
the files use `generateName`). `argo -n argo list` / `argo -n argo get @latest` afterwards.

| File | Watch for |
|---|---|
| `01-hello-world.yaml` | One pod. `kubectl -n argo get pods` during the run: note the `init`/`wait`/`main` containers. |
| `02-parameters.yaml` | `-p message="override"` changes the output. Parameters tab in the UI. |
| `03-steps.yaml` | Second group runs two pods at once; both print the same random number from step 1 (output parameters). |
| `04-dag.yaml` | Diamond graph in the UI. `-p run-optional=yes` adds a node. `withItems` fans out into 3 pods. |
| `05-artifacts.yaml` | Artifact passed via MinIO. Port-forward MinIO (see `make status`) and browse `my-bucket`. Try `archive: none`. |
| `06-workflowtemplate.yaml` | `kubectl apply -f` (templates are not run, only stored), then `argo -n argo submit --from workflowtemplate/build-and-test -p repo=foo`. Templates tab in the UI. |
| `06b-use-templates.yaml` | A Workflow composing both templates via `templateRef` (namespaced and `clusterScope: true`). |
| `07-cronworkflow.yaml` | `kubectl apply -f`, `argo -n argo cron list`, wait 2 minutes, `argo -n argo cron suspend every-two-minutes`. |
| `08-retries-and-exit-handler.yaml` | Retries appear as child nodes; `cleanup` always runs and prints the final status. |

## Things to try

- A `script:` template (inline Python) instead of `container:`; a `suspend:` template that waits
  for `argo resume`.
- `argo -n argo submit 03-steps.yaml --parameter-file params.yaml` and `argo -n argo logs @latest`.
- `activeDeadlineSeconds`, `ttlStrategy` (auto-delete finished workflows), `podGC`.
- Combine with Argo CD: commit a `WorkflowTemplate` and have Argo CD sync it (lab 08 pattern).
- Combine with Argo Events: lab 06 triggers a workflow from a webhook.

## Cleanup

```bash
argo -n argo delete --all
kubectl -n argo delete cronworkflow,workflowtemplate --all
kubectl delete clusterworkflowtemplate notify
```
