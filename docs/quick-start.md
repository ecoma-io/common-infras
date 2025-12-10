# Quick start

## Development

1. Install required tools (local):

```sh
./install.sh dev
```

Application will be deployed to a local k3d cluster.

- You can access the cluster using `kubectl` (kubeconfig is set automatically).
- Argo CD UI is accessible at `https://argocd.fbi.com`
- You can you argo CLI to interact with Argo CD with --core options (e.g. `argocd --core app list`)
- Cilium cli is also available (e.g. `cilium status`)
- Helm and kustomize are also installed.
- After making change just commit and ArgoCD will sync to local cluster automatically (Need use squash/rebase to keep git history clean before push).
- You can run tests locally with `bats tests/` or `bats tests/<specific-test>.bats`

## Production

1. Ensure kubeconfig for the target production cluster is available and `kubectl` is configured
2. Bootstrap the production environment

```sh
./install.sh prod
```

Cluster will be bootstrapped with Argo CD, Cilium, CoreDNS and other platform components.
