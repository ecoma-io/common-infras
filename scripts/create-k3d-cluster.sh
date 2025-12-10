#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CLUSTER_NAME=$(basename "$ROOT_DIR")
AGENTS=0 # Number of worker nodes

## Setup network
echo "============================================="
echo "🚀 Setting up Docker network..."
if [ -z "$(docker network ls -q -f name="$CLUSTER_NAME")" ]; then
  docker network create "$CLUSTER_NAME" \
    --driver bridge \
    --subnet "10.0.0.0/8" \
    --gateway "10.0.0.1"
  echo "✅ Docker network '$CLUSTER_NAME' created."
else
  echo "ℹ️  Docker network '$CLUSTER_NAME' already exists."
fi



## Setup local registry for proxy
echo "============================================="
echo "🚀 Setting up local Docker registry..."
if [ -z "$(docker ps -q -f name=registry)" ]; then
  docker run -d \
    --name registry \
    --restart always \
    --network "$CLUSTER_NAME" \
    --ip "10.0.0.2" \
    --health-cmd "wget --quiet --tries=1 --spider http://localhost:5000/v2/ || exit 1" \
    --health-interval 5s \
    --health-timeout 3s \
    --health-retries 3 \
    registry:3
else
  echo "ℹ️  Local Docker registry already running."
fi



## wait for registry to be ready
echo "⏱️  Waiting for local Docker registry to be ready..."
REGISTRY_HEALTH_STATUS=""
REGISTRY_HEALTH_CHECK_ATTEMPT=0
REGISTRY_HEALTH_CHECK_MAX_ATTEMPTS=10
while [ "$REGISTRY_HEALTH_STATUS" != "healthy" ] && [ "$REGISTRY_HEALTH_CHECK_ATTEMPT" -lt "$REGISTRY_HEALTH_CHECK_MAX_ATTEMPTS" ]; do
  REGISTRY_HEALTH_CHECK_ATTEMPT=$((REGISTRY_HEALTH_CHECK_ATTEMPT + 1))
  if [ "$REGISTRY_HEALTH_CHECK_ATTEMPT" -ne 1 ]; then
    sleep 5 ## sleep before next check after first attempt
  fi
  HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' registry 2>/dev/null || true)
  if [ -z "$HEALTH_STATUS" ]; then
    echo "❌ Can't get health status of local Docker registry."
    exit 1
  fi
  REGISTRY_HEALTH_STATUS=$HEALTH_STATUS
  echo "ℹ️  Local registry health status: $REGISTRY_HEALTH_STATUS (attempt: $REGISTRY_HEALTH_CHECK_ATTEMPT/$REGISTRY_HEALTH_CHECK_MAX_ATTEMPTS)"
done
if [ "$REGISTRY_HEALTH_STATUS" = "healthy" ]; then
  echo "✅ Setup local registry successfully."
else
  echo "❌ Local registry did not reach HEALTHY status after $REGISTRY_HEALTH_CHECK_MAX_ATTEMPTS attempts."
  exit 1
fi



echo "🗑️  Deleting existing cluster '$CLUSTER_NAME' if exist..."
if k3d cluster delete "$CLUSTER_NAME" 2>/dev/null; then
  echo "✅ Existing cluster '$CLUSTER_NAME' deleted."
else
  echo "ℹ️  No existing cluster '$CLUSTER_NAME' found."
fi


echo "🚀 Setting up k3d cluster '$CLUSTER_NAME'..."
k3d cluster create "$CLUSTER_NAME" \
  --image "rancher/k3s:v1.32.10-k3s1" \
  --servers 1 \
  --agents "$AGENTS" \
  --network "$CLUSTER_NAME" \
  --api-port "127.0.0.1:6443" \
  --no-lb \
  -p "80:80@server:0:direct" \
  -p "443:443@server:0:direct" \
  --registry-config "$SCRIPT_DIR/registry-proxy.yaml" \
  --volume "$ROOT_DIR":/mnt/local-repo.git@server:* \
  --volume /sys/fs/bpf:/sys/fs/bpf@server:* \
  --k3s-arg "--tls-san=127.0.0.1@server:*" \
  --k3s-arg "--disable=traefik@server:*" \
  --k3s-arg "--disable=servicelb@server:*" \
  --k3s-arg "--disable=local-storage@server:*" \
  --k3s-arg "--disable=coredns@server:*" \
  --k3s-arg "--disable=metrics-server@server:*" \
  --k3s-arg "--disable-network-policy@server:*" \
  --k3s-arg "--flannel-backend=none@server:*" \
  --k3s-arg "--disable=kube-proxy@server:*" \
  --k3s-arg "--cluster-cidr=10.42.0.0/16@server:0" \
  --k3s-arg "--service-cidr=10.43.0.0/16@server:0" \
  --wait



printf "✅ Cluster '%s' is set up.\n\n" "$CLUSTER_NAME"
