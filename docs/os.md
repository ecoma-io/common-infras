# Cách chạy script để cài đặt trên server

## Master

```
curl -fsSL https://github.com/ecoma-io/common-infras/raw/refs/heads/main/setup.sh | ROLE=master REGION=vn-hn-1  K3S_TOKEN="<paste-your-token-here>"  TAILSCALE_AUTH_KEY="<TAILSCALE_AUTH_KEY>" sh -
```

Sau khi chạy xong nhớ vào tailscale admin console để Accept Service Node

## Worker

```
curl -fsSL https://github.com/ecoma-io/common-infras/raw/refs/heads/main/setup.sh | ROLE=worker K3S_URL=https://kube-api:6443 REGION=vn-hn-1  K3S_TOKEN="<K3S_TOKEN>"  TAILSCALE_AUTH_KEY="<TAILSCALE_AUTH_KEY>" sh -
```
