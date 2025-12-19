#!/usr/bin/env sh
CPU_COUNT=$(nproc --all || echo 4)
bats "$(dirname "$0")/src" -r --pretty --jobs "$CPU_COUNT"
