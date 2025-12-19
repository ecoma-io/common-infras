#!/usr/bin/env sh
# Lint tracked Markdown and shell scripts in parallel.
# - Uses `git ls-files` to only include tracked files (respecting .gitignore)
# - Runs `npx markdownlint` on `**/*.md`
# - Runs `shellcheck` on `**/*.sh`
# - Executes both linters in parallel and reports a concise summary

set -eu

md_count=$(git ls-files -- '*.md' | wc -l | tr -d '[:space:]' || true)
sh_count=$(git ls-files -- '*.sh' | wc -l | tr -d '[:space:]' || true)

echo "Found ${md_count:-0} Markdown files and ${sh_count:-0} shell scripts (tracked)."

run_md() {
  if [ "${md_count:-0}" -eq 0 ]; then
    echo "No Markdown files to lint."
    return 0
  fi
  echo "Running npx markdownlint on tracked .md files..."
  # Use null-separated list to safely handle filenames
  git ls-files -z -- '*.md' | xargs -0 npx markdownlint
}

run_sh() {
  if [ "${sh_count:-0}" -eq 0 ]; then
    echo "No shell scripts to lint."
    return 0
  fi
  echo "Running shellcheck on tracked .sh files..."
  git ls-files -z -- '*.sh' | xargs -0 shellcheck
}

# Run both linters in background (parallel)
run_md &
md_pid=$!
run_sh &
sh_pid=$!

md_status=0
sh_status=0

wait "$md_pid" || md_status=$?
wait "$sh_pid" || sh_status=$?

echo "---- Lint Summary ----"
if [ "${md_count:-0}" -gt 0 ]; then
  if [ "$md_status" -eq 0 ]; then
    echo "Markdownlint: OK"
  else
    echo "Markdownlint: FAILED (exit $md_status)"
  fi
else
  echo "Markdownlint: SKIPPED"
fi

if [ "${sh_count:-0}" -gt 0 ]; then
  if [ "$sh_status" -eq 0 ]; then
    echo "Shellcheck: OK"
  else
    echo "Shellcheck: FAILED (exit $sh_status)"
  fi
else
  echo "Shellcheck: SKIPPED"
fi

# Exit non-zero if any linter failed
if [ "$md_status" -ne 0 ] || [ "$sh_status" -ne 0 ]; then
  exit 1
fi

exit 0
