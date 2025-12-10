#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENVIRONMENT="${1:-}"

if [[ -z "$ENVIRONMENT" ]]; then
  printf '❌ Environment not specified. Usage: %s <dev|prod>\n' "$0"
  exit 1
fi

if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "prod" ]]; then
  printf '❌ Invalid environment "%s". Usage: %s <dev|prod>\n' "$ENVIRONMENT" "$0"
  exit 1
fi


if [[ "$ENVIRONMENT" == "prod" ]]; then
  printf '🔍 Verifying kubectl connectivity to the cluster...\n'
  kubectl cluster-info > /dev/null 2>&1
  if [ $? -eq 0 ]; then
      printf "✅ SUCCESS: Kubectl is successfully connected to the cluster.\n"      
  else
      printf "❌ FAILURE: Kubectl failed to connect to the cluster.\n"
      exit 1       
  fi
fi
printf '🚀 Bootstrapping the %s environment...\n' "$ENVIRONMENT"

printf "🔧 Installing required tools\n"
bash "$ROOT_DIR/scripts/install-tools.sh" "$ENVIRONMENT"
printf "✅ All required tools are installed\n\n"

if [[ "$ENVIRONMENT" == "dev" ]]; then    
  bash "$ROOT_DIR/scripts/create-k3d-cluster.sh"
fi

bash "$ROOT_DIR/scripts/install-cluster-core.sh" "$ENVIRONMENT"
bash "$ROOT_DIR/scripts/gitops-pilot.sh" "$ENVIRONMENT"


printf "\n\n"
printf "✅ Cluster is bootstrapped.\n\n" 

