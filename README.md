# common-infras

Kho chứa chung (monorepo) chứa cấu hình GitOps, Helm charts và script hỗ trợ triển khai hạ tầng nền tảng cho các dự án ecoma-io.

## Key contents

- Cung cấp manifests/kustomize/Helm chart chuẩn để cài đặt các thành phần nền tảng (Argo CD, Cilium, CoreDNS).
- Tự động hoá quy trình bootstrap cho môi trường `dev` và `prod` (script, k3d cho dev).
- Cung cấp test suite chi tiết nhằm kiểm thử triển khai thực tế để giảm thiểu rủi ro (Bats + thư viện hỗ trợ) và một Dev Container cho môi trường phát triển nhất quán.

## Prerequisites

- kubectl configured to target your cluster
- For production: k3s cluster and kubeconfig configured
- Dev container includes node, npm, kubectl, helm, docker CLI (see .devcontainer/). If devcontainer running on windows we need WSL2 and wsl2 kernel version 6.6 or higher. (Check with `wsl --version` and run `wsl --update` if needed)

## Quick start — Development

Development environment:

```sh
./install.sh dev
```

Production deployment

```sh
./install.sh prod
```

## Testing

- Bats test files are under tests/
- Run (requires bats):

```sh
bats tests
```

or run specific test file:

```sh
bats tests/test-filename.bats
```
