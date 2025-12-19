#!/bin/sh

parse_env_and_prompt() {
	ROLE="${ROLE:-}"
	TAILSCALE_AUTH_KEY="${TAILSCALE_AUTH_KEY:-}"
	K3S_TOKEN="${K3S_TOKEN:-}"
	K3S_URL="${K3S_URL:-}"
	REGION="${REGION:-}"

	if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
		usage
	fi

	# Prompt until a valid role is provided
	while :; do
		if [ -z "$ROLE" ]; then
			printf "Role to install (master/worker) [master]: "
			read ROLE || ROLE=
			ROLE=${ROLE:-master}
		fi
		ROLE=$(printf "%s" "$ROLE" | tr '[:upper:]' '[:lower:]')
		case "$ROLE" in
			master|worker) break ;;
			*) echo "Invalid role: $ROLE" >&2; ROLE="" ;;
		esac
	done

	if [ -z "$TAILSCALE_AUTH_KEY" ]; then
		printf "Tailscale auth key (leave empty to skip automatic join): "
		stty -echo 2>/dev/null || true
		read TAILSCALE_AUTH_KEY || TAILSCALE_AUTH_KEY=
		stty echo 2>/dev/null || true
		printf "\n"
	fi

	# k3s token is required — prompt until provided
	while [ -z "$K3S_TOKEN" ]; do
		printf "k3s token (will be used for cluster join) [required]: "
		stty -echo 2>/dev/null || true
		read K3S_TOKEN || K3S_TOKEN=
		stty echo 2>/dev/null || true
		printf "\n"
	done

	# region label for nodes (required)
	while [ -z "$REGION" ]; do
		printf "Region label (required, e.g. eu-west-1): "
		read REGION || REGION=
		REGION=$(printf "%s" "$REGION" | tr -d '[:space:]')
	done

	# If worker, require K3S_URL and validate format immediately
	if [ "$ROLE" = "worker" ]; then
		while :; do
			printf "k3s server URL (e.g. 1.2.3.4 or https://1.2.3.4:6443) [required]: "
			read K3S_URL || K3S_URL=
			K3S_URL=$(printf "%s" "$K3S_URL" | tr -d '[:space:]')
			if [ -z "$K3S_URL" ]; then
				echo "k3s server URL is required."
				continue
			fi
			# simple validation using grep -E
			if printf "%s" "$K3S_URL" | grep -E '^(https?://)?([0-9]{1,3}(\.[0-9]{1,3}){3}|[A-Za-z0-9.-]+)(:[0-9]+)?(/.*)?$' >/dev/null 2>&1; then
				break
			fi
			echo "Invalid k3s server URL format. Examples: 1.2.3.4  or  https://1.2.3.4:6443" >&2
		done
	fi
}


prepare_tmp() {
	TMP_DIR=$(mktemp -d)
}

ensure_sysctl_settings() {
	SYSCTL_CONF="/etc/sysctl.conf"
	BACKUP=""
	set_kv="net.core.rmem_max=8388608
net.core.wmem_max=8388608
net.ipv4.ip_local_port_range=11000 60999
net.ipv4.ip_forward=1
fs.file-max=524288
fs.inotify.max_user_instances=8192"

	# make a backup if possible
	if [ -w "$SYSCTL_CONF" ] || [ ! -e "$SYSCTL_CONF" ]; then
		BACKUP="${SYSCTL_CONF}.bak.$(date +%s)"
		cp -f "$SYSCTL_CONF" "$BACKUP" 2>/dev/null || true
	fi

	echo "$set_kv" | while IFS= read -r kv; do
		key=$(printf '%s' "$kv" | awk -F= '{print $1}')
		desired=$(printf '%s' "$kv" | awk -F= '{print substr($0, index($0,$2))}')
		current=$(sysctl -n "$key" 2>/dev/null || echo "")
		if [ "$current" = "$desired" ]; then
			continue
		fi

		# If a non-commented entry exists in the file, replace it; otherwise append
		if grep -E -q "^[[:space:]]*${key}[[:space:]]*=.*" "$SYSCTL_CONF" 2>/dev/null; then
			sed -i "s|^[[:space:]]*${key}[[:space:]]*=.*|${key} = ${desired}|" "$SYSCTL_CONF" 2>/dev/null || true
		else
			printf "%s = %s\n" "$key" "$desired" >> "$SYSCTL_CONF" 2>/dev/null || true
		fi

		# apply immediately (ignore failures)
		sysctl --system
	done

	if [ -n "${BACKUP:-}" ]; then
		echo "Sysctl: backed up $SYSCTL_CONF to $BACKUP"
	fi
}

ensure_limits_conf() {
	LIMITS_FILE="/etc/security/limits.conf"
	BACKUP=""

	# backup
	if [ -w "$LIMITS_FILE" ] || [ ! -e "$LIMITS_FILE" ]; then
		BACKUP="${LIMITS_FILE}.bak.$(date +%s)"
		cp -f "$LIMITS_FILE" "$BACKUP" 2>/dev/null || true
	fi

	for mode in soft hard; do
		if [ "$mode" = "soft" ]; then
			desired_val="524288"
		else
			desired_val="524288"
		fi

		# check for an existing non-commented '*' line for nofile
		if grep -E -q "^[[:space:]]*\*[[:space:]]+${mode}[[:space:]]+nofile" "$LIMITS_FILE" >/dev/null 2>&1; then
			# get current value (fourth field)
			current=$(awk '/^[[:space:]]*\*[[:space:]]+'"${mode}"'[[:space:]]+nofile/ {print $4; exit}' "$LIMITS_FILE" 2>/dev/null || echo "")
			if [ "$current" != "$desired_val" ]; then
				sed -i "s|^[[:space:]]*\*[[:space:]]*${mode}[[:space:]]*nofile.*|* ${mode} nofile ${desired_val}|" "$LIMITS_FILE" 2>/dev/null || true
				echo "Updated $mode nofile -> $desired_val in $LIMITS_FILE"
			fi
		else
			printf "* %s nofile %s\n" "$mode" "$desired_val" >> "$LIMITS_FILE" 2>/dev/null || true
			echo "Appended '* $mode nofile $desired_val' to $LIMITS_FILE"
		fi
	done

	if [ -n "${BACKUP:-}" ]; then
		echo "Limits: backed up $LIMITS_FILE to $BACKUP"
	fi
}

normalize_k3s_url() {
	if [ -z "$K3S_URL" ]; then
		echo "Error: K3S_URL is required for worker role" >&2
		exit 1
	fi
	if ! printf '%s' "$K3S_URL" | grep -E -q '^https?://'; then
		K3S_URL="https://$K3S_URL"
	fi
	if ! printf '%s' "$K3S_URL" | grep -E -q ':[0-9]+(/|$)'; then
		K3S_URL="${K3S_URL}:6443"
	fi
}

ensure_persistent_shared_mounts() {
	unit="/etc/systemd/system/ensure-shared-mounts.service"
	cat > "$unit" <<'UNIT'
[Unit]
Description=Ensure /sys and /run have shared mount propagation
RequiresMountsFor=/sys /run
Before=k3s.service

[Service]
Type=oneshot
ExecStart=/bin/mount --make-shared /sys
ExecStart=/bin/mount --make-shared /run
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT

	chmod 644 "$unit" || true
	systemctl daemon-reload || true
	systemctl enable --now ensure-shared-mounts.service || true
	echo "Created and enabled $unit"
}

install_tailscale() {
	echo "Installing Tailscale..."
	curl -fsSL https://tailscale.com/install.sh | sh -
    echo "Bringing up Tailscale with provided auth key..."    
    tailscale up --auth-key="$TAILSCALE_AUTH_KEY"
	if [ $ROLE = "master" ]; then
		tailscale serve --service=svc:kube-api --https=6443 127.0.0.1:6443
    fi
    systemctl enable --now tailscaled
    echo "Tailscale installation and setup completed."
	
}

install_k3s() {
	echo "Downloading k3s install script..."
    INSTALL_K3S_EXEC="--write-kubeconfig-mode=644 --disable=traefik --disable=servicelb --disable=local-storage --disable=coredns --disable=metrics-server --disable=kube-proxy --flannel-backend=none --disable-cloud-controller --disable-network-policy --disable-helm-controller"
	if [ "$ROLE" = "master" ]; then
        K3S_SERVER_BARE=$(printf '%s' "$K3S_SERVER" | sed -E 's|^https?://||' | sed -E 's|:[0-9]+(/.*)?$||')
		INSTALL_K3S_EXEC="$INSTALL_K3S_EXEC --cluster-init --embedded-registry --tls-san=$K3S_SERVER_BARE"
	fi
	INSTALL_K3S_EXEC="$INSTALL_K3S_EXEC --node-ip=$(tailscale ip -4)"
	INSTALL_K3S_EXEC="$INSTALL_K3S_EXEC --token=$K3S_TOKEN"
    INSTALL_K3S_EXEC="$INSTALL_K3S_EXEC --node-label=topology.kubernetes.io/region=${REGION}"

	echo "Running k3s installer (this may take a few minutes)..."
	if [ "$ROLE" = "worker" ]; then
		normalize_k3s_url
		echo "Using K3S_URL=$K3S_URL to join the server"
		curl -fsSL https://get.k3s.io | INSTALL_K3S_EXEC="$INSTALL_K3S_EXEC" K3S_TOKEN="$K3S_TOKEN" K3S_URL="$K3S_URL" sh -
	else
        curl -fsSL https://get.k3s.io |INSTALL_K3S_EXEC="$INSTALL_K3S_EXEC" K3S_TOKEN="$K3S_TOKEN" sh -
	fi
	echo "k3s installation finished."
	
}

verify_k3s_install() {
	echo "Verifying k3s by running: k3s kubectl get nodes"
	if k3s kubectl get nodes >/dev/null 2>&1; then
		echo "k3s command succeeded."
		return 0
	else
		echo "k3s command failed or cluster not reachable." >&2
		k3s kubectl get nodes || true
		return 1
	fi
}



main() {
	parse_env_and_prompt "$@"
	require_cmds curl sh mktemp mount findmnt systemctl
	prepare_tmp	
	ensure_sysctl_settings
	ensure_limits_conf
	ensure_persistent_shared_mounts
    install_tailscale
	install_k3s
	if ! verify_k3s_install; then
		echo "k3s verification failed; check logs or run 'k3s kubectl get nodes' for details." >&2
		exit 1
	fi
	echo "Done."
}

main "$@"