# Lab 01 - ApplicationSets

**Prereqs:** `make up argocd`, repo pushed and `make init-labs` run.

**Concepts:** generators (list, git directory, git file, matrix, cluster), Go templating,
`goTemplateOptions`, how an ApplicationSet owns its generated Applications.

Each manifest here is a standalone ApplicationSet. Apply one at a time, inspect the generated
Applications, then delete it before the next so names don't collide.

```bash
kubectl apply -f labs/01-applicationsets/list-generator.yaml
kubectl -n argocd get applicationset,application
kubectl -n argocd describe applicationset podinfo-envs   # look at Events on template errors
```

| File | What to observe |
|---|---|
| `list-generator.yaml` | Two Applications from two list elements. Edit the list, re-apply, an app is added/removed. |
| `git-directory-generator.yaml` | One app per folder under `apps/`. Create `apps/nginx/` with a Deployment, push, refresh -> new Application. |
| `git-file-generator.yaml` | Parameters come from `config/*/config.json`. Teams own config files, platform owns the template. |
| `matrix-generator.yaml` | directories x clusters. Both "clusters" are the in-cluster endpoint, so you get `guestbook-east`, `guestbook-west`, ... |
| `cluster-generator.yaml` | Needs a cluster Secret labelled `lab=true`. Register the in-cluster endpoint as a named cluster first (below). |

### Registering the local cluster for the cluster generator

Argo CD's implicit `in-cluster` has no Secret, so the cluster generator sees nothing. Create one:

```bash
argocd cluster add kind-argo-lab --name argo-lab --in-cluster --label lab=true -y
kubectl apply -f labs/01-applicationsets/cluster-generator.yaml
kubectl -n argocd get secret -l argocd.argoproj.io/secret-type=cluster --show-labels
```

### Things to try

- Change `goTemplateOptions` to `["missingkey=zero"]` and reference a missing key; compare behaviour.
- Add `syncPolicy: {preserveResourcesOnDeletion: true}` to the ApplicationSet spec, delete it, and
  note the Applications stay.
- Pull-request and SCM-provider generators need a GitHub token; see
  https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Pull-Request/

## Cleanup

```bash
kubectl -n argocd delete applicationset --all
```
