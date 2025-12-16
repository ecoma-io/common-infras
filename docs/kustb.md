**kustb — kustomize build helper**

- **What it does:** a small wrapper around `kustomize build` that enables Helm support and relaxes file load restrictions by default for convenience in development and CI.

- **Command name:** `kustb` (the repo `bin` is expected to be on `PATH` in the devcontainer, so call `kustb` directly).

- **Default behavior:**

  - Runs `kustomize build --enable-helm --load-restrictor LoadRestrictionsNone` plus any arguments you pass through.
  - Uses the system `kustomize` binary, or the one set in the `KUSTOMIZE_BIN` environment variable.

- **Prerequisites:**

  - `kustomize` installed and on `PATH`, or set `KUSTOMIZE_BIN` to a full path to the binary.
  - `bin` added to `PATH` by your devcontainer (so `kustb` is callable without `./`).

- **Usage examples:**

  - Build an overlay directory:
    ```bash
    kustb ./overlays/dev
    ```
  - Write manifest to a file:
    ```bash
    kustb ./base > manifest.yaml
    ```
  - Pass through arbitrary `kustomize` flags:
    ```bash
    kustb --load-restrictor LoadRestrictionsNone ./some/dir
    ```

- **Environment variables:**

  - `KUSTOMIZE_BIN` — optional override path to a `kustomize` executable.
  - `KUSTB_DEBUG=1` — print the exact command being executed to stderr before running it.

- **Behavior details / safety:**

  - The wrapper `exec`s the real `kustomize` binary so exit codes and signals are preserved.
  - Default `LoadRestrictionsNone` simplifies local development but may widen file access; consider explicitly setting `--load-restrictor` when running in security-sensitive CI.

- **Troubleshooting:**

  - If you see `kustomize not found`, install it or set `KUSTOMIZE_BIN`.
  - If you get unexpected loading errors, try running `kustomize` directly with the same args to compare.

- **Suggestions / next improvements:**
  - Add a Docker fallback to run `kustomize` in a container when the binary is not available.
  - Add a `--no-helm`/`--no-relax` opt-out to explicitly disable the defaults in sensitive environments.
