#!/usr/bin/env bats
setup() {
  CURRENT_DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
  ROOT_DIR="$(dirname "$CURRENT_DIR")"
  load "$ROOT_DIR/.bats/bats-support/load"
  load "$ROOT_DIR/.bats/bats-assert/load"

  uid=$(tr -dc 'a-z0-9' </dev/urandom | head -c 5 || echo "uid$(date +%s | tr -dc 'a-z0-9' | head -c5)")

  # Create a single netshoot pod that all tests will reuse
  kubectl run netshoot-${uid} --image=nicolaka/netshoot:latest --restart=Never -n default --command -- sleep 1d
  kubectl wait --for=condition=Ready pod/netshoot-${uid} -n default --timeout=120s
}

teardown() {
  # If uid is set in the test, attempt to remove the test pods from default
  if [ -n "${uid:-}" ]; then
    kubectl delete pod netshoot-${uid} -n default --ignore-not-found --wait --timeout=60s || true
  fi
}

@test "DNS internal cluster resolution works" {
  run kubectl exec -n default netshoot-${uid} -- nslookup kubernetes.default.svc.cluster.local
  assert_success
  # ensure output is non-empty
  if [ -z "$output" ]; then
    echo "== kubectl describe pod dns-internal-${uid} =="
    kubectl  describe pod/netshoot-${uid} -n default || true
    echo "== kubectl logs netshoot-${uid} =="
    kubectl  logs pod/netshoot-${uid} -n default --all-containers || true
    fail "internal DNS resolution returned empty output"
  fi
}

@test "DNS external cluster resolution works" {
  run kubectl exec -n default netshoot-${uid} -- nslookup example.com
  assert_success
  if [ -z "$output" ]; then
    echo "== kubectl describe pod dns-external-${uid} =="
    kubectl  describe pod/netshoot-${uid} -n default || true
    echo "== kubectl logs netshoot-${uid} =="
    kubectl  logs pod/netshoot-${uid} -n default --all-containers || true
    fail "external DNS resolution returned empty output"
  fi
}

@test "Egress reach outside world" {
  run kubectl exec -n default netshoot-${uid} -- curl -sS -I -f --max-time 15 https://www.wikipedia.org/
  assert_success
}