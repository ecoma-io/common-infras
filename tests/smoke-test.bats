#!/usr/bin/env bats
setup() {
  CURRENT_DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
  ROOT_DIR="$(dirname "$CURRENT_DIR")"
  load "$ROOT_DIR/.bats/bats-support/load"
  load "$ROOT_DIR/.bats/bats-assert/load"
}

@test "Smoke test build core app with kustomize configurations" {
  for d in "$ROOT_DIR/src"/*; do
    [ -d "$d" ] || continue
    run kustomize build --enable-helm --load-restrictor LoadRestrictionsNone "$d/base"
    assert_success
    run kustomize build --enable-helm --load-restrictor LoadRestrictionsNone "$d/dev"
    assert_success
    run kustomize build --enable-helm --load-restrictor LoadRestrictionsNone "$d/prod"
    assert_success
  done
}