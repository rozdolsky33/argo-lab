# Argo learning lab on kind. Run `make help` for targets.
# All configuration lives in cluster/cluster.env; override any var inline: WORKERS=1 make up
SHELL := /bin/bash
S := ./scripts

.DEFAULT_GOAL := help

##@ Cluster
up: ## Create kind cluster + ingress-nginx
	@$(S)/cluster-up.sh
	@$(S)/install-ingress-nginx.sh

down: ## Delete the kind cluster
	@$(S)/cluster-down.sh

reset: down up ## Recreate the cluster from scratch

status: ## Show component health, URLs and credentials
	@$(S)/status.sh

##@ Components (install one at a time)
argocd: ## Vanilla Argo CD + ingress + CLI login
	@$(S)/install-argocd.sh

rollouts: ## Argo Rollouts controller + dashboard + kubectl plugin
	@$(S)/install-argo-rollouts.sh

workflows: ## Argo Workflows (quick-start: server, controller, MinIO)
	@$(S)/install-argo-workflows.sh

events: ## Argo Events controller + default JetStream EventBus
	@$(S)/install-argo-events.sh

image-updater: ## Argo CD Image Updater
	@$(S)/install-argocd-image-updater.sh

prometheus: ## kube-prometheus-stack (Prometheus + Grafana) via Helm
	@$(S)/install-prometheus.sh

cert-manager: ## cert-manager + self-signed ClusterIssuer
	@$(S)/install-cert-manager.sh

all: up ## Cluster + every component
	@$(S)/install-all.sh

##@ Uninstall a component (keeps the cluster)
uninstall-argocd: ## Remove Argo CD
	@$(S)/install-argocd.sh --uninstall
uninstall-rollouts: ## Remove Argo Rollouts
	@$(S)/install-argo-rollouts.sh --uninstall
uninstall-workflows: ## Remove Argo Workflows
	@$(S)/install-argo-workflows.sh --uninstall
uninstall-events: ## Remove Argo Events
	@$(S)/install-argo-events.sh --uninstall
uninstall-image-updater: ## Remove Argo CD Image Updater
	@$(S)/install-argocd-image-updater.sh --uninstall
uninstall-prometheus: ## Remove kube-prometheus-stack
	@$(S)/install-prometheus.sh --uninstall
uninstall-cert-manager: ## Remove cert-manager
	@$(S)/install-cert-manager.sh --uninstall
uninstall-ingress: ## Remove ingress-nginx
	@$(S)/install-ingress-nginx.sh --uninstall

##@ Labs
init-labs: ## Rewrite repoURL placeholders in labs/ to GIT_REPO_URL (one time, after pushing to GitHub)
	@$(S)/init-labs.sh

lint: ## shellcheck all scripts
	@shellcheck -x scripts/*.sh scripts/lib/*.sh

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage: make \033[36m<target>\033[0m\n"} \
	  /^[a-zA-Z_ -]+:.*?##/ { printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2 } \
	  /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)

.PHONY: up down reset status argocd rollouts workflows events image-updater prometheus cert-manager all init-labs lint help \
	uninstall-argocd uninstall-rollouts uninstall-workflows uninstall-events uninstall-image-updater uninstall-prometheus uninstall-cert-manager uninstall-ingress
