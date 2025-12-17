# Sau khi cài đặt os xong cần chạy các lệnh sau:

### Tối ưu cho cloudflared & Tailscale

**/etc/sysctl.conf**

```
net.core.rmem_max = 8388608
net.core.wmem_max = 8388608
fs.file-max =524288
fs.inotify.max_user_instances
net.ipv4.ip_local_port_range = 11000 60999
net.ipv4.ip_forward = 1
```

**/etc/security/limits.conf**

```
*   soft   nofile   524288
*   hard   nofile   524288
``

```
