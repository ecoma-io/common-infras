#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENVIRONMENT=$1
TMP_FILES=()
NEED_INSTALL_SYSTEM_PACKAGES=()
NEED_INSTALL_NPM_PACKAGES=()
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
  if ! command -v k3d > /dev/null 2>&1; then
    printf "⏱️ Installing k3d...\n"
    wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
  fi

  #Install BATS
  if ! command -v bats > /dev/null 2>&1; then
    printf "⏱️ Installing BATS...\n"
    git clone https://github.com/bats-core/bats-core.git /tmp/bats-core
    sudo /tmp/bats-core/install.sh /usr/local
    rm -rf /tmp/bats-core
  fi

  # Install ArgoCD CLI
  if ! command -v argocd > /dev/null 2>&1; then
    curl -sSL -o /tmp/argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    sudo install -m 555 /tmp/argocd-linux-amd64 /usr/local/bin/argocd
    sudo chmod +x /usr/local/bin/argocd
    rm /tmp/argocd-linux-amd64
  fi

  if [ ! -d "$ROOT_DIR/.bats/bats-support" ]; then
    echo "⏱️ Installing BATS support library..."
    git clone https://github.com/bats-core/bats-support.git "$ROOT_DIR/.bats/bats-support"
  fi

  if [ ! -d "$ROOT_DIR/.bats/bats-assert" ]; then
    echo "⏱️ Installing BATS assert library..."
    git clone https://github.com/bats-core/bats-assert.git "$ROOT_DIR/.bats/bats-assert"
  fi

  # Install GNU parallel
  if ! command -v parallel > /dev/null 2>&1; then
    NEED_INSTALL_SYSTEM_PACKAGES+=(parallel)
  fi

  if ! command -v shellcheck > /dev/null 2>&1; then
    NEED_INSTALL_SYSTEM_PACKAGES+=(shellcheck)
  fi

  if [ ${#NEED_INSTALL_SYSTEM_PACKAGES[@]} -ne 0 ]; then
    printf "⏱️ Installing required packages: %s\n" "${NEED_INSTALL_SYSTEM_PACKAGES[*]}"
    sudo apt-get update
    sudo apt-get install -y "${NEED_INSTALL_SYSTEM_PACKAGES[@]}"
  fi

  # Check for npm packages
  if ! npm list -g --depth=0 | grep -q markdownlint-cli > /dev/null 2>&1; then
    NEED_INSTALL_NPM_PACKAGES+=(markdownlint-cli)
  fi

  if [ ${#NEED_INSTALL_NPM_PACKAGES[@]} -ne 0 ]; then
    printf "⏱️ Installing required npm packages: %s\n" "${NEED_INSTALL_NPM_PACKAGES[*]}"
    sudo apt-get update
    sudo npm install -g "${NEED_INSTALL_NPM_PACKAGES[@]}"
  fi

fi

# Install kubectl
if ! command -v kubectl > /dev/null 2>&1; then
  printf "⏱️ Installing kubectl...\n"
  KUBECTL_URL="https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  tmp="$(mktemp)"
  TMP_FILES+=("$tmp")
  curl -fsSL -o "$tmp" "$KUBECTL_URL"
  sudo install -o root -g root -m 0755 "$tmp" /usr/local/bin/kubectl
fi

# Install Helm 3.x
if ! command -v helm > /dev/null 2>&1; then
  printf "⏱️ Installing Helm...\n"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Install kustomize
if ! command -v kustomize > /dev/null 2>&1; then
  curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
  sudo mv kustomize /usr/local/bin/kustomize
fi

# Install Cilium CLI
if ! command -v cilium > /dev/null 2>&1; then
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

# Install kubeseal
if ! command -v kubeseal > /dev/null 2>&1; then
  printf "⏱️ Installing kubeseal...\n"
  KUBESEAL_VERSION=$(curl -s https://api.github.com/repos/bitnami-labs/sealed-secrets/tags | jq -r '.[0].name' | cut -c 2-)
  KUBESEAL_TGZ="/tmp/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
  KUBESEAL_URL="https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"

  # Download to /tmp, follow redirects, and wtmprite to the specified file
  curl -L -o "$KUBESEAL_TGZ" "$KUBESEAL_URL"

  # Extract the kubeseal binary from the archive into /tmp, install and cleanup
  (cd /tmp && tar -xvzf "$KUBESEAL_TGZ" kubeseal && sudo install -m 755 kubeseal /usr/local/bin/kubeseal)
  rm -f "$KUBESEAL_TGZ" /tmp/kubeseal || true
fi
