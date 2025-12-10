#!/usr/bin/env bash
set -euo pipefail
kubectl wait --for=condition=ready pod -n "$1" -l "$2" --timeout="${3:-600}s"