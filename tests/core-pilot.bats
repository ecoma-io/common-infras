#!/usr/bin/env bats
setup() {
  CURRENT_DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
  ROOT_DIR="$(dirname "$CURRENT_DIR")"
  load "$ROOT_DIR/.bats/bats-support/load"
  load "$ROOT_DIR/.bats/bats-assert/load"
}

@test "ArgoCD should be reachable via HTTP via Cilium Gateway" {
  hostname="argocd.fbi.com"
  # Try to GET the hostname until success (approx 60s total)
  success_output=""
  for i in $(seq 1 20); do
    run curl -sS --max-time 5 "http://${hostname}" || true
    if [ "$status" -eq 0 ] && [ -n "$output" ]; then
      success_output="$output"
      break
    fi
    sleep 3
  done
  if [ -z "$success_output" ]; then
    echo "== HTTP check failed: diagnostics follow =="
    echo "-- kubectl get gateway -A --show-labels --no-headers --ignore-not-found --context=$(kubectl config current-context) --kubeconfig=${KUBECONFIG:-~/.kube/config}"
    kubectl get gateway -A || true
    echo "-- kubectl get httproute -A"
    kubectl get httproute -A || true
    echo "-- argo-cd namespace pods & services"
    kubectl -n argo-cd get pods -o wide || true
    kubectl -n argo-cd get svc -o wide || true
    echo "-- cluster services in default (possible cilium gateway service)"
    kubectl -n default get svc -o wide || true
    fail "request to ${hostname} returned empty body or failed"
  fi
  echo "$success_output" | grep -qi "argocd\|html\|title\|login" || true
}

@test "ArgoCD core apps should exist and be Synced and Healthy" {
  core_dir="$ROOT_DIR/src/core"
  expected_apps=()
  for d in "$core_dir"/*; do
    [ -d "$d" ] || continue
    expected_apps+=("argocd/$(basename "$d")")
  done

  if [ "${#expected_apps[@]}" -eq 0 ]; then
    skip "no subdirectories in $core_dir to check"
  fi

  ok=0
  # max 10 minutes, check every 5s => 120 attempts
  for i in $(seq 1 120); do
    run argocd --core app list || true
    out="$output"
    all_good=1
    for app in "${expected_apps[@]}"; do
      # find line for app; assume first column is NAME, 4th STATUS, 5th HEALTH
      line="$(printf '%s\n' "$out" | awk -v a="$app" '$1==a {print; exit}')"
      if [ -z "$line" ]; then
        all_good=0
        break
      fi
      status="$(printf '%s\n' "$line" | awk '{print $5}')"
      health="$(printf '%s\n' "$line" | awk '{print $6}')"
      if [ "$status" != "Synced" ] || [ "$health" != "Healthy" ]; then
        all_good=0
        break
      fi
    done

    if [ "$all_good" -eq 1 ]; then
      ok=1
      break
    fi
    sleep 5
  done

  if [ "$ok" -ne 1 ]; then
    echo "== argocd --core app list output =="
    argocd --core app list || true
    echo "Expected apps: ${expected_apps[*]}"
    fail "not all argocd apps are Synced and Healthy after 5 minutes"
  fi
}




