#!/usr/bin/env bats
setup() {
  CURRENT_DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
  ROOT_DIR="$(dirname "$CURRENT_DIR")"
  load "$ROOT_DIR/.bats/bats-support/load"
  load "$ROOT_DIR/.bats/bats-assert/load"
}

@test "ctemp prints a path and creates directory under repo tmp" {
  run "$ROOT_DIR/bin/ctemp"
  [ "$status" -eq 0 ]
  # output is the path
  out="$output"
  [ -n "$out" ]
  # directory exists
  [ -d "$out" ]
  # directory is under repo tmp
  echo "$out" | grep -F -- "$ROOT_DIR/tmp/"
}

@test "ctemp creates unique directories on multiple invocations and they are writable" {
  p1="$($ROOT_DIR/bin/ctemp)"
  p2="$($ROOT_DIR/bin/ctemp)"
  [ -d "$p1" ]
  [ -d "$p2" ]
  [ "$p1" != "$p2" ]
  # writable: create a file inside each
  touch "$p1/ok1" && test -f "$p1/ok1"
  touch "$p2/ok2" && test -f "$p2/ok2"
}
