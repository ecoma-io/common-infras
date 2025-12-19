#!/usr/bin/env bats
setup() {
  CURRENT_DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
  ROOT_DIR="$(dirname "$CURRENT_DIR")"
  load "$ROOT_DIR/.bats/bats-support/load"
  load "$ROOT_DIR/.bats/bats-assert/load"
}

prepare_fake_kubeseal() {
  fakebin="$($ROOT_DIR/bin/ctemp)"
  mkdir -p "$fakebin"
  cat > "$fakebin/kubeseal" <<'EOF'
#!/usr/bin/env bash
# simple fake kubeseal: parse --cert and --scope and echo them plus stdin
cert=""
scope=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cert)
      cert="$2"; shift 2 ;;
    --cert=*)
      cert="${1#*=}"; shift ;;
    --scope)
      scope="$2"; shift 2 ;;
    --format)
      shift 2 ;;
    *)
      shift ;;
  esac
done
echo "CERT:$cert"
echo "SCOPE:$scope"
cat -
EOF
  chmod +x "$fakebin/kubeseal"
  export PATH="$fakebin:$PATH"
}

@test "defaults to repo_root/.cert and uses dev.cert for namespace 'dev'" {
  tmpdir="$( $ROOT_DIR/bin/ctemp )"
  # create a temporary repo copy so default .certs can be created without mutating workspace
  tmprepo="$(mktemp -d)"
  cp -a "$ROOT_DIR/." "$tmprepo/"
  mkdir -p "$tmprepo/.certs"
  echo "DEVCERT" > "$tmprepo/.certs/dev.cert"
  echo "PRODCERT" > "$tmprepo/.certs/prod.cert"

  prepare_fake_kubeseal

  secret="$tmpdir/secret-dev.yaml"
  cat > "$secret" <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
  namespace: dev
data:
  key: dmFsdWU=
YAML

  run "$tmprepo/bin/sealup" "$secret"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "CERT:$tmprepo/.certs/dev.cert"
}

@test "--cert-dir override is respected (uses prod.cert for non-dev)" {
  tmpdir="$( $ROOT_DIR/bin/ctemp )"
  certdir="$tmpdir/certs"
  mkdir -p "$certdir"
  echo "OVERRIDE-DEV" > "$certdir/dev.cert"
  echo "OVERRIDE-PROD" > "$certdir/prod.cert"

  prepare_fake_kubeseal

  secret="$tmpdir/secret-prod.yaml"
  cat > "$secret" <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
  namespace: other
data:
  key: dmFsdWU=
YAML

  run "$ROOT_DIR/bin/sealup" --cert-dir "$certdir" "$secret"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "CERT:$certdir/prod.cert"
}

@test "reads from stdin when no files passed or '-' used" {
  tmpdir="$($ROOT_DIR/bin/ctemp)"
  certdir="$tmpdir/certs"
  mkdir -p "$certdir"
  echo "STDIN-DEV" > "$certdir/dev.cert"
  echo "STDIN-PROD" > "$certdir/prod.cert"

  prepare_fake_kubeseal

  secret_stdin=$(cat <<'YAML'
apiVersion: v1
kind: Secret
metadata:
  name: piped
  namespace: other
data:
  key: dmFsdWU=
YAML
)

  run bash -c "printf '%s' \"$secret_stdin\" | $ROOT_DIR/bin/sealup --cert-dir $certdir -"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "CERT:$certdir/prod.cert"
}

@test "relative --cert-dir is resolved relative to workspace root" {
  tmpdir="$($ROOT_DIR/bin/ctemp)"
  # create a temporary repo copy so we can create a relative certs dir there
  tmprepo="$(mktemp -d)"
  cp -a "$ROOT_DIR/." "$tmprepo/"
  mkdir -p "$tmprepo/.relcerts"
  echo "RELCERT-DEV" > "$tmprepo/.relcerts/dev.cert"
  echo "RELCERT-PROD" > "$tmprepo/.relcerts/prod.cert"

  prepare_fake_kubeseal

  secret="$tmpdir/secret-rel.yaml"
  cat > "$secret" <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
  namespace: other
data:
  key: dmFsdWU=
YAML

  # run sealup from the tmprepo; pass a relative cert-dir that should be
  # resolved against tmprepo (the repo root for that invocation)
  run "$tmprepo/bin/sealup" --cert-dir .relcerts "$secret"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "CERT:$tmprepo/.relcerts/prod.cert"
}
