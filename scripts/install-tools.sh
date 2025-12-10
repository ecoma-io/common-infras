#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENVIRONMENT=$1
TMP_FILES=()
cleanup() {
    for f in "${TMP_FILES[@]}"; do
        [[ -e "$f" ]] && rm -f "$f"
    done
}
trap cleanup EXIT


if [ "$ENVIRONMENT" != "dev" ] && [ "$ENVIRONMENT" != "prod" ]; then
  echo "Invalid environment: $ENVIRONMENT"
  echo "Usage: $0 {dev|prod}"
  exit 1
fi

# Only dev environment tools
if [[ "$ENVIRONMENT" == "dev" ]]; then
   # Install k3d
   if ! command -v k3d >/dev/null 2>&1; then
        printf "⏱️ Installing k3d...\n"
        wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
   fi
   # Install ArgoCD CLI
   if ! command -v argocd >/dev/null 2>&1; then
      curl -sSL -o /tmp/argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
      sudo install -m 555 /tmp/argocd-linux-amd64 /usr/local/bin/argocd
      sudo chmod +x /usr/local/bin/argocd
      rm /tmp/argocd-linux-amd64
   fi

    #Install BATS
    if ! command -v bats >/dev/null 2>&1; then
        printf "⏱️ Installing BATS...\n"
        git clone https://github.com/bats-core/bats-core.git /tmp/bats-core
        sudo /tmp/bats-core/install.sh /usr/local
        rm -rf /tmp/bats-core
    fi

    if [ ! -d "$ROOT_DIR/.bats/bats-support" ]; then
        echo "⏱️ Installing BATS support library..."
        git clone https://github.com/bats-core/bats-support.git "$ROOT_DIR/.bats/bats-support"
    fi

    if [ ! -d "$ROOT_DIR/.bats/bats-assert" ]; then
        echo "⏱️ Installing BATS assert library..."
        git clone https://github.com/bats-core/bats-assert.git "$ROOT_DIR/.bats/bats-assert"
    fi


fi

# Install kubectl
if ! command -v kubectl >/dev/null 2>&1; then
    printf "⏱️ Installing kubectl...\n"
    KUBECTL_URL="https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    tmp="$(mktemp)"
    TMP_FILES+=("$tmp")
    curl -fsSL -o "$tmp" "$KUBECTL_URL"
    sudo install -o root -g root -m 0755 "$tmp" /usr/local/bin/kubectl
fi

# Install Helm 3.x
if ! command -v helm >/dev/null 2>&1; then
    printf "⏱️ Installing Helm...\n"
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Install kustomize
if ! command -v kustomize >/dev/null 2>&1; then
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
    sudo mv kustomize /usr/local/bin/kustomize
fi

# Install Cilium CLI
if ! command -v cilium >/dev/null 2>&1; then
    printf "⏱️ Installing Cilium CLI...\n"
    CILIUM_CLI_VERSION="$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)"
    CLI_ARCH="amd64"
    if [[ "$(uname -m)" == "aarch64" ]]; then
        CLI_ARCH="arm64"
    fi
    CILIUM_TGZ="cilium-linux-${CLI_ARCH}.tar.gz"
    CILIUM_URL="https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/${CILIUM_TGZ}"
    tmp="$(mktemp)"
    TMP_FILES+=("$tmp")
    curl -fL -o "$tmp" "$CILIUM_URL"
    sudo tar xzvf "$tmp" -C /usr/local/bin
fi

# Install ArgoCD CLI
if ! command -v argocd >/dev/null 2>&1; then
    curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
fi
