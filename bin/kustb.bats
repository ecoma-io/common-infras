#!/usr/bin/env bats
setup() {
  CURRENT_DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
  ROOT_DIR="$(dirname "$CURRENT_DIR")"
  load "$ROOT_DIR/.bats/bats-support/load"
  load "$ROOT_DIR/.bats/bats-assert/load"
}

prepare_fake_kustomize() {
  fakebin="$($ROOT_DIR/bin/ctemp)"
  mkdir -p "$fakebin"
  cat > "$fakebin/kustomize" <<'EOF'
#!/usr/bin/env bash
echo "KUSTOMIZE_ARGS:$*"
EOF
  chmod +x "$fakebin/kustomize"
  export PATH="$fakebin:$PATH"
}

prepare_fake_kubectl() {
  fakebin="$($ROOT_DIR/bin/ctemp)"
  mkdir -p "$fakebin"
  cat > "$fakebin/kubectl" <<'EOF'
#!/usr/bin/env bash
echo "KUBECTL_ARGS:$*"
# if '-' present, read stdin and echo marker
if [[ "$*" == *"-"* ]]; then
  cat -
fi
EOF
  chmod +x "$fakebin/kubectl"
  export PATH="$fakebin:$PATH"
}

@test "defaults to 'build --enable-helm --load-restrictor LoadRestrictionsNone'" {
  prepare_fake_kustomize

  run "$ROOT_DIR/bin/kustb" ./some-dir
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "KUSTOMIZE_ARGS:build --enable-helm --load-restrictor LoadRestrictionsNone ./some-dir"
}

@test "passthrough --help forwards to kustomize" {
  prepare_fake_kustomize

  run "$ROOT_DIR/bin/kustb" --help
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "KUSTOMIZE_ARGS:--help"
}

@test "explicit 'build' first arg is forwarded unchanged" {
  prepare_fake_kustomize

  tmpdir="$($ROOT_DIR/bin/ctemp)"
  out="$tmpdir/manifest.yaml"

  run "$ROOT_DIR/bin/kustb" build --output "$out" ./base
  [ "$status" -eq 0 ]
  [ -f "$out" ]
  cat "$out" | grep -F -- "KUSTOMIZE_ARGS:build ./base"
}

@test "short -o is normalized to --output and forwarded" {
  prepare_fake_kustomize

  tmpdir="$($ROOT_DIR/bin/ctemp)"
  out="$tmpdir/manifest.yaml"

  run "$ROOT_DIR/bin/kustb" ./some-dir -o "$out"
  [ "$status" -eq 0 ]
  [ -f "$out" ]
  cat "$out" | grep -F -- "KUSTOMIZE_ARGS:build --enable-helm --load-restrictor LoadRestrictionsNone ./some-dir"
}

@test "--apply with output writes file and calls kubectl apply -f <file>" {
  prepare_fake_kustomize
  prepare_fake_kubectl

  tmpdir="$($ROOT_DIR/bin/ctemp)"
  out="$tmpdir/manifest.yaml"

  run "$ROOT_DIR/bin/kustb" ./some-dir -o "$out" --apply
  [ "$status" -eq 0 ]
  [ -f "$out" ]
  # kubectl should have been invoked (we check PATH order by scanning output of fake kubectl)
  # The fake kubectl will have printed KUBECTL_ARGS to stdout when invoked; capture via run's output
  echo "$output" | grep -F -- "KUBECTL_ARGS:apply -f $out"
}

@test "--apply without output pipes to kubectl -f -" {
  prepare_fake_kustomize
  prepare_fake_kubectl

  run "$ROOT_DIR/bin/kustb" ./some-dir --apply
  [ "$status" -eq 0 ]
  # when applying from stdin, fake kubectl echoes kustomize stdout (from our fake kustomize)
  echo "$output" | grep -F -- "KUSTOMIZE_ARGS:build --enable-helm --load-restrictor LoadRestrictionsNone ./some-dir"
}
