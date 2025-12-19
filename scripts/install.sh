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
  if kubectl cluster-info > /dev/null 2>&1; then
    printf "✅ SUCCESS: Kubectl is successfully connected to the cluster.\n"
  else
    printf "❌ FAILURE: Kubectl failed to connect to the cluster.\n"
    exit 1
  fi

  # Need user input private key for setup in prod
  printf '🔐 Path to your kubeseal key for production setup \033[0;32m[prod.key]\033[0m: '
  read -r KUBESEAL_KEY_PATH
  if [[ -z "$KUBESEAL_KEY_PATH" ]]; then
    KUBESEAL_KEY_PATH="$ROOT_DIR/prod.key"
  fi
  if [[ ! -f "$KUBESEAL_KEY_PATH" ]]; then
    printf '❌ The file "%s" does not exist. Please provide a valid kubeseal key path.\n' "$KUBESEAL_KEY_PATH"
    exit 1
  fi

  # try to ensure the key works
  printf '🔍 Validating the provided kubeseal key...\n'
  # create tmp area and test encrypt/decrypt with the repo public key
  if ! command -v openssl > /dev/null 2>&1; then
    printf '❌ openssl is required to validate the key. Please install openssl and retry.\n'
    exit 1
  fi

  cleanup() {
    if [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]]; then
      rm -rf "$TMP_DIR"
    fi
  }
  trap cleanup EXIT

  TMP_DIR="$(mktemp -d)"
  PUB_FROM_CERT="$TMP_DIR/pub_from_cert.pem"
  PUB_FROM_PRIV="$TMP_DIR/pub_from_priv.pem"

  PUBLIC_KEY_PATH="$ROOT_DIR/keys/prod.cert"
  if [[ ! -f "$PUBLIC_KEY_PATH" ]]; then
    printf '❌ Public key (certificate) %s not found.\n' "$PUBLIC_KEY_PATH"
    exit 1
  fi

  # extract public key from certificate
  if ! openssl x509 -in "$PUBLIC_KEY_PATH" -pubkey -noout > "$PUB_FROM_CERT" 2> /dev/null; then
    printf '❌ Failed to extract public key from certificate %s\n' "$PUBLIC_KEY_PATH"
    exit 1
  fi

  # extract public key from provided private key
  if ! openssl pkey -in "$KUBESEAL_KEY_PATH" -pubout > "$PUB_FROM_PRIV" 2> /dev/null; then
    if ! openssl rsa -in "$KUBESEAL_KEY_PATH" -pubout > "$PUB_FROM_PRIV" 2> /dev/null; then
      printf '❌ Provided private key is not a valid RSA/ECDSA private key or is passphrase-protected.\n'
      printf '   Provide an unencrypted private key file or decrypt it first.\n'
      exit 1
    fi
  fi

  # normalize to DER and compare SHA256 fingerprints
  CERT_FP=$(openssl pkey -pubin -in "$PUB_FROM_CERT" -outform der 2> /dev/null | sha256sum | awk '{print $1}') || true
  PRIV_FP=$(openssl pkey -pubin -in "$PUB_FROM_PRIV" -outform der 2> /dev/null | sha256sum | awk '{print $1}') || true

  if [[ -n "$CERT_FP" && -n "$PRIV_FP" && "$CERT_FP" == "$PRIV_FP" ]]; then
    printf '✅ Private key matches public certificate (fingerprint: %s).\n' "$CERT_FP"
    # Ask user to conform to proceed
    printf '⚠️  WARNING: You are about to bootstrap the PRODUCTION environment.
This operation may modify live systems and should be performed with caution.
Are you sure you want to proceed? (yes/no): '
    read -r CONFIRMATION
    if [[ "$CONFIRMATION" != "yes" ]]; then
      printf '❌ Operation aborted by user.\n'
      exit 1
    else
      ## create kubeseal namespace if not exists
      if ! kubectl get namespace kubeseal > /dev/null 2>&1; then
        kubectl create namespace kubeseal
      fi

      # apply the public cert to the cluster
      kubectl -n kubeseal create secret generic sealed-secrets-key --from-file=tls.key="$KUBESEAL_KEY_PATH" --from-file=tls.crt="$PUBLIC_KEY_PATH" --dry-run=client -o yaml | kubectl apply -f -
    fi
  else
    printf '❌ Private key does not match certificate %s (cert fp: %s, priv fp: %s)\n' "$PUBLIC_KEY_PATH" "$CERT_FP" "$PRIV_FP"
    exit 1
  fi

  printf '🚀 Bootstrapping the production environment...\n'

else

  printf '🚀 Bootstrapping the development environment...\n'

fi

printf "🔧 Installing required tools\n"
bash "$ROOT_DIR/scripts/install-tools.sh" "$ENVIRONMENT"
printf "✅ All required tools are installed\n\n"

if [[ "$ENVIRONMENT" == "dev" ]]; then
  bash "$ROOT_DIR/scripts/create-k3d-cluster.sh"
fi

bash "$ROOT_DIR/scripts/install-cluster-core.sh" "$ENVIRONMENT"

# create kubeseal namespace and apply dev key/cert on development
if [[ "$ENVIRONMENT" == "dev" ]]; then
  if ! kubectl get namespace kubeseal > /dev/null 2>&1; then
    kubectl create namespace kubeseal
  fi
  kubectl -n kubeseal create secret generic sealed-secrets-key --from-file=tls.key="$ROOT_DIR/keys/dev.key" --from-file=tls.crt="$ROOT_DIR/keys/dev.cert" --dry-run=client -o yaml | kubectl apply -f -
fi
bash "$ROOT_DIR/scripts/gitops-pilot.sh" "$ENVIRONMENT"

printf "\n\n"
printf "✅ Cluster is bootstrapped.\n\n"
