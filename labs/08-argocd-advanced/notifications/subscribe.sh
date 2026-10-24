#!/usr/bin/env bash
# Subscribe an Application to the echo webhook for both triggers.
app="${1:?usage: subscribe.sh <application-name>}"
kubectl -n argocd annotate application "$app" --overwrite \
  notifications.argoproj.io/subscribe.on-sync-succeeded.echo="" \
  notifications.argoproj.io/subscribe.on-health-degraded.echo=""
