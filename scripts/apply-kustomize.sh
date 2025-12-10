#!/usr/bin/env bash
set -euo pipefail

COMPONENT="${1:-}"
ENVIROMENT="${2:-}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KUSTOMIZE_DIR="$ROOT_DIR/src/$COMPONENT/$ENVIROMENT"

# check args
if [[ -z "$COMPONENT" || -z "$ENVIROMENT" || ( "$ENVIROMENT" != "dev" && "$ENVIROMENT" != "prod" ) ]]; then
  echo "Usage: $0 <component> <dev|prod>"
  exit 1
fi

# check kustomize dir exists
if [[ ! -d "$KUSTOMIZE_DIR" ]]; then
  echo "Error: Kustomize directory '$KUSTOMIZE_DIR' does not exist"
  exit 1
fi

kustomize build --helm-debug --enable-helm --load-restrictor LoadRestrictionsNone "$KUSTOMIZE_DIR" | kubectl apply --wait -f -