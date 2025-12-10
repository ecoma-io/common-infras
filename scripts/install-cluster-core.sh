#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENVIRONMENT=$1

printf '🚀 Installing cilium...\n'
kubectl create namespace cilium --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml
if [[ "$ENVIRONMENT" == "prod" ]]; then
    cilium install --wait --version 1.18.4 --namespace cilium \
        -f "$ROOT_DIR/src/core/cilium/base/cilium-chart.values.yaml" 
else
    cilium install --wait --version 1.18.4 --namespace cilium \
        --set gatewayAPI.enabled=true --set gatewayAPI.hostNetwork.enabled=true \
        --set k8sServiceHost=127.0.0.1 --set k8sServicePort=6443 \
        -f "$ROOT_DIR/src/core/cilium/base/cilium-chart.values.yaml" 
fi   
bash "$ROOT_DIR/scripts/verify-pod.sh" cilium "app.kubernetes.io/name=cilium-agent" 300
bash "$ROOT_DIR/scripts/verify-pod.sh" cilium "app.kubernetes.io/name=cilium-operator" 300
bash "$ROOT_DIR/scripts/verify-pod.sh" cilium "app.kubernetes.io/name=cilium-envoy" 300  
printf '✅ Cilium are installed.\n\n'

printf '🚀 Installing Core DNS components...\n'
kubectl create namespace coredns --dry-run=client -o yaml | kubectl apply -f -
bash "$ROOT_DIR/scripts/apply-kustomize.sh" core/coredns "$ENVIRONMENT"
bash "$ROOT_DIR/scripts/verify-pod.sh" coredns "app.kubernetes.io/name=coredns" 300
printf '✅ Core DNS components are installed.\n\n'

