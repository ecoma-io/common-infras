# Tools — quick reference

This document describes helper tools included in this repository and how to use them.

Included tools

- `sealup`: helper to seal Kubernetes Secrets with `kubeseal` using environment-specific certs.
- `kustb`: (brief) helper for kustomize operations. See the script header for details.

Usage convention

- These helper scripts live under `bin/` and are available in the environment used by this repository. In this workspace `sealup` is installed on `$PATH` so you can call it directly as `sealup`.
- Most scripts accept `--help` or include usage at the top of the file. Check the binary header if you need details.

## sealup

### What's

`sealup` is a small repo-specific wrapper around `kubeseal` that seals Kubernetes `Secret` resources using certificates stored in the repository. It automates per-environment cert selection and handles multi-document YAML inputs.

### Why

- Replaces repetitive `kubeseal` invocations in this project by applying sensible defaults tuned for the repo.
- Automatically selects the correct cert (`dev.cert` vs `prod.cert`) based on `metadata.namespace`, so operators and CI don't need to track which cert to pass.
- Handles multi-doc YAML and concatenates sealed outputs with `---`, making batch operations and pipelines simpler.
- Resolves `--cert-dir` relative to the repository root and defaults to `REPO_ROOT/.certs`, which works well in CI and local clones without extra flags.

### How

Basic invocation:

```
sealup [--cert-dir DIR] [files...]
```

- If no files are provided (or `-` is used) `sealup` reads from stdin.
- Default cert location: `REPO_ROOT/.certs` (expected files: `dev.cert`, `prod.cert`).
- `--cert-dir DIR` overrides the cert directory. If `DIR` is relative it is resolved relative to the repository root (the parent of `bin/`).
- For each `Secret` document, `sealup` calls `kubeseal --cert <chosen-cert> --format yaml` and emits the sealed result; namespace-scoped Secrets use `--scope namespace-wide`, cluster-scoped use `--scope cluster-wide`.

Examples

```bash
# Seal a file and write sealed output
sealup path/to/secret.yaml > sealed.yaml

# Seal multiple files
sealup a.yaml b.yaml c.yaml > sealed-all.yaml

# Read from stdin
cat secret.yaml | sealup > sealed.yaml

# Use a different cert directory (relative to repo root)
sealup --cert-dir .other-certs secret.yaml
```

For `kustb` you can use `-o` or `--output` to specify the output file; `-o` is supported as a shorthand and will be forwarded to `kustomize` as `--output`.

Requirements & troubleshooting

- `kubeseal` must be available in `PATH`.
- Ensure `REPO_ROOT/.certs` (or `--cert-dir`) contains `dev.cert` and `prod.cert`.
- If cert dir or cert files are missing, `sealup` will exit with an error stating the missing path.

## kustb

### What's

`kustb` is a lightweight wrapper for `kustomize build` used in this repository. It provides project-default flags to enable Helm chart processing and to relax load restrictions.

### Why

- Ensures `kustomize build` is invoked with consistent flags across developers and CI.
- Enables Helm chart rendering inside kustomize (`--enable-helm`) without repeating flags.
- Disables kustomize load restrictions (`--load-restrictor LoadRestrictionsNone`) so repository layouts that reference files outside of the immediate directory work as intended.

### How

Basic usage:

```
kustb [kustomize-build-options] [directory]
```

Behavior:

- `kustb` will detect a `kustomize` binary in `PATH` (or respect the `KUSTOMIZE_BIN` env var).
- If the first argument is `build` or the user asks for `--help`/`-h`/`--version`, `kustb` forwards the invocation directly to `kustomize`.
- Otherwise it runs `kustomize build --enable-helm --load-restrictor LoadRestrictionsNone` plus any arguments you provided.

Examples

```bash
# Build an overlay directory with default flags
kustb ./overlays/production

# Forward help directly to kustomize
kustb --help

# Run build explicitly with additional flags
kustb build --output manifest.yaml ./base
```

## ctemp

`ctemp` is a tiny helper that creates temporary directories under the repository root's `tmp/` and prints the created path. Tests in this repo use `ctemp` so temporary directories are colocated inside the workspace (e.g. `REPO_ROOT/tmp/tmp.XXXXXX`).

Usage:

```bash
# prints something like /path/to/repo/tmp/tmp.abc123
ctemp
```
