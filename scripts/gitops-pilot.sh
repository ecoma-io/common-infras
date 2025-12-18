#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENVIRONMENT=$1

printf "🚀 Installing Argo CD...\n"
kubectl apply -k https://github.com/argoproj/argo-cd/manifests/crds\?ref\=stable
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f $ROOT_DIR/src/cilium/base/resources/http.gateway.yaml
bash "$ROOT_DIR/scripts/apply-kustomize.sh" argocd "$ENVIRONMENT"
sleep 3
bash "$ROOT_DIR/scripts/verify-pod.sh" argocd  app.kubernetes.io/name=argocd-redis 600
# rollout argocd-server and argocd-repo-server to pick up any config changes
kubectl -n argocd rollout restart deployment argocd-repo-server
bash "$ROOT_DIR/scripts/verify-pod.sh" argocd "app.kubernetes.io/name=argocd-server" 600
bash "$ROOT_DIR/scripts/verify-pod.sh" argocd "app.kubernetes.io/name=argocd-repo-server" 600
kubectl config set-context --current --namespace=argocd
printf "✅ Argo CD is installed.\n\n" 