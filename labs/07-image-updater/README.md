# Lab 07 - Argo CD Image Updater

**Prereqs:** `make up argocd image-updater`, repo pushed and `make init-labs` run.

**Concepts:** image-list and aliases, update strategies (`semver`, `newest-build`, `alphabetical`,
`digest`), tag filters (`allow-tags`, `ignore-tags`), write-back methods (`argocd` vs `git`),
registry configuration, how the updater discovers images in an Application.

The updater only watches Applications **it can see images for**: Argo CD must have synced the app
at least once so `status.summary.images` is populated.

## 1. argocd write-back (no git credentials)

```bash
kubectl apply -f labs/07-image-updater/application-argocd-writeback.yaml
kubectl -n argocd logs deploy/argocd-image-updater-controller -f
```

Within one interval (2 min, set in `manifests/argocd/image-updater-config.yaml`) the log shows
`Setting new image to ghcr.io/stefanprodan/podinfo:6.7.1` (or whatever the newest 6.7.x is).
Then:

```bash
argocd app get image-updater-demo          # Images: ...podinfo:6.7.1 ; app is Synced because the
                                           # override is part of the Application spec, not git
kubectl -n argocd get application image-updater-demo -o yaml | grep -A4 kustomize
```

Run `argocd app diff image-updater-demo` and note there is no diff: the override lives in
`spec.source.kustomize.images`. Delete the Application and recreate it and the override is gone.
That is the weakness of this method.

## 2. git write-back

Create a token with write access to your repo and store it:

```bash
kubectl -n argocd create secret generic git-creds \
  --from-literal=username=<github-user> --from-literal=password=<token>
kubectl apply -f labs/07-image-updater/application-git-writeback.yaml
```

After the next interval, `git pull` and look at
`labs/07-image-updater/app/.argocd-source-image-updater-demo.yaml`: the updater committed a
kustomize image override there, and Argo CD synced from git. Change `allow-tags` to allow 6.8.x /
6.9.x and watch another commit land.

## Things to try

- `update-strategy: digest` with `allow-tags` pinned to one tag: redeploys when the tag is re-pushed.
- `update-strategy: newest-build` (needs registries that expose tag timestamps; Docker Hub does).
- Pull-request flow: set `git-branch` to the templated form in the manifest, so each update lands on a
  new branch for review.
- Add a private registry with credentials in `registries.conf` (see
  `manifests/argocd/image-updater-config.yaml`).
- Check metrics: `kubectl -n argocd port-forward svc/argocd-image-updater-controller-metrics-service 8443` .

## Cleanup

```bash
kubectl -n argocd delete application image-updater-demo
kubectl -n argocd delete secret git-creds --ignore-not-found
```
