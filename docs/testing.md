# Testing

- Goal: Thoroughly validate real deployment steps to reduce risk when promoting to a cluster (sanity checks, readiness, CRD/manifest validation, network/connectivity, and smoke tests for main deployment flows).
- Framework: `bats` together with `bats-support` and `bats-assert`. Tests are located in the `tests/` directory and are designed to run both locally (on k3d) and in CI.

Run locally:

```sh
bats tests
```

Tips:

- Ensure `kubectl` is pointed at the target cluster before running (for `prod`, make sure the correct kubeconfig is available).
- For the `dev` environment, create the cluster with:

```sh
./install.sh dev
```
