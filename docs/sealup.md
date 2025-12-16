**Sealup — quick guide**

- **What it does:** small helper script to produce SealedSecrets using `kubeseal`, picking the certificate by environment and setting the correct scope automatically.

- **Prerequisites:**

  - `kubeseal` installed and on `PATH`.
  - Repo-level cert files named `dev.cert` and `prod.cert` at the repository root (or pass `--cert-dir`).
  - `bin/sealup` executable (run `chmod +x bin/sealup`).

- **Basic usage:**

  - Seal a file (uses `ENV` positional arg):
    ```bash
    sealup dev path/to/secret.yaml > sealed-secret.yaml
    ```
  - Seal from stdin:
    ```bash
    cat secret.yaml | sealup prod - > sealed-secret.yaml
    ```

- **Options:**

  - `ENV` (positional, required): `dev` or `prod` — selects `<repo-root>/ENV.cert`.
  - `--cert-dir DIR` (optional): override directory for cert files.
  - `-` as input file reads from stdin.

- **Behavior details:**

  - The script only seals resources whose `kind` is `Secret` (error otherwise).
  - If the Secret manifest has no `metadata.namespace`, the script runs `kubeseal --scope cluster-wide`.
  - If the manifest has `metadata.namespace`, the script runs `kubeseal --scope namespace-wide` (and the SealedSecret receives the matching annotation).
  - Selected cert is always `DEV.cert` or `PROD.cert` in repo root unless overridden by `--cert-dir`.

- **Example: Argo CD GitHub App (dev):**

  1. Edit `src/core/argocd/dev/resources/argocd-github-secret.yaml` and fill `clientID` and `clientSecret`.
  2. Seal it:
     ```bash
     sealup dev src/core/argocd/dev/resources/argocd-github-secret.yaml > src/core/argocd/dev/resources/sealed-argocd-github-secret.yaml
     ```
  3. Replace / commit the sealed file into the overlay (or include as additional resource in kustomization).

- **Security notes:**

  - Keep `dev.cert`/`prod.cert` private and do not commit private keys.
  - Prefer keeping unsealed secrets out of version control; the script is intended for managing sealed artifacts.

- **Troubleshooting:**

  - Error `kubeseal not found`: install `kubeseal` and ensure it is on `PATH`.
  - Error `cert file not found`: ensure `dev.cert` or `prod.cert` exist at repo root or pass `--cert-dir`.
  - If `kubeseal` complains about `--scope` values, ensure you are using the updated `sealup` which sends `namespace-wide` or `cluster-wide`.

- **Next steps / suggestions:**
  - Add a `--namespace` override if you want to force namespace scope independent of the manifest.
