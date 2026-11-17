#!/usr/bin/env bash
set -euo pipefail

PERSIST_DISK="/dev/sdb"
MOUNT_POINT="/var/lib/k8s-state"
KUBEADM_CONFIG="/root/kubeadm-config.yaml"
KUBEADM_MARKER="/root/node-kubeadm.done"
KUBECONFIG_ADMIN="/etc/kubernetes/admin.conf"
CONTROL_PLANE_TIMEOUT="${CONTROL_PLANE_TIMEOUT:-600}" # seconds

log() { echo "[node-bootstrap] $1"; }
err_exit() { echo "[node-bootstrap] ERROR: $1"; exit 1; }

kubectl_admin() {
  kubectl --kubeconfig="$KUBECONFIG_ADMIN" --request-timeout=5s "$@"
}

# Non-blocking: did kubeadm init complete? kubeadm-config proves the API is
# reachable; CoreDNS and kube-proxy are the last things init applies.
cluster_initialized() {
  kubectl_admin -n kube-system get cm kubeadm-config >/dev/null 2>&1 &&
    kubectl_admin -n kube-system get deploy coredns >/dev/null 2>&1 &&
    kubectl_admin -n kube-system get ds kube-proxy >/dev/null 2>&1
}

# Wait until the local API server reports ready. admin.conf is written during
# bootstrap; if it is briefly absent, kubectl fails and the loop retries.
wait_control_plane() {
  local deadline=$((SECONDS + CONTROL_PLANE_TIMEOUT))
  log "Waiting for control plane to be reachable (timeout: ${CONTROL_PLANE_TIMEOUT}s)"
  until kubectl_admin get --raw=/readyz >/dev/null 2>&1; do
    if (( SECONDS >= deadline )); then
      err_exit "Control plane not reachable after ${CONTROL_PLANE_TIMEOUT}s"
    fi
    sleep 5
  done
  log "Control plane is reachable"
}

if [[ "$UID" -ne 0 ]]; then
  err_exit "Must be run as root"
fi

if [[ -f /root/node-bootstrap.done ]]; then
  log "Bootstrap already completed (marker present), exiting"
  exit 0
fi

# SMBIOS fields (set by Terraform via the Proxmox provider):
#   product_name  = node role: primary-control | control | worker
#   product_family = "<endpoint> <mode> <bootstrap-token>"
#     endpoint: IP or hostname (blank for single mode)
#     mode:     high-availability | single
#     token:    kubeadm bootstrap token (abcdef.0123456789abcdef)
ROLE=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
FAMILY=$(cat /sys/class/dmi/id/product_family 2>/dev/null)
read -r CONTROL_PLANE_ENDPOINT CLUSTER_MODE BOOTSTRAP_TOKEN <<< "$FAMILY"
log "SMBIOS — role: $ROLE, endpoint: $CONTROL_PLANE_ENDPOINT, mode: $CLUSTER_MODE"

if [[ -z "$BOOTSTRAP_TOKEN" ]]; then
  err_exit "Bootstrap token missing from SMBIOS product_family"
fi

# Apply kubeadm config substitutions
if [[ "$CLUSTER_MODE" == "high-availability" ]]; then
  if [[ -z "$CONTROL_PLANE_ENDPOINT" ]]; then
    err_exit "Control plane endpoint required for high-availability mode"
  fi
  log "HA mode — writing control plane endpoint to kubeadm config"
  sed -i "s|CONTROL_PLANE_ENDPOINT|$CONTROL_PLANE_ENDPOINT|" "$KUBEADM_CONFIG"
elif [[ "$CLUSTER_MODE" == "single" ]]; then
  log "Single mode — clearing controlPlaneEndpoint"
  sed -i "s|CONTROL_PLANE_ENDPOINT||" "$KUBEADM_CONFIG"
else
  err_exit "Invalid cluster mode '$CLUSTER_MODE' (expected: high-availability or single)"
fi
sed -i "s|BOOTSTRAP_TOKEN|$BOOTSTRAP_TOKEN|" "$KUBEADM_CONFIG"

# Setup control plane
if [[ "$ROLE" == "control" || "$ROLE" == "primary-control" ]]; then

  log "Control-plane node detected"

  if [[ ! -b "$PERSIST_DISK" ]]; then
    err_exit "Persistent disk $PERSIST_DISK not found (expected on control-plane nodes)"
  fi

  log "Persistent disk $PERSIST_DISK detected"

  # Only format a disk with no signatures at all. Never use mkfs -F: a probe
  # error must not be mistaken for "empty disk" (that would wipe etcd/PKI data).
  if ! SIGS=$(wipefs -n "$PERSIST_DISK" 2>/dev/null); then
    err_exit "Failed to probe $PERSIST_DISK for existing signatures"
  fi
  if [[ -n "$SIGS" ]]; then
    FS_TYPE=$(blkid -o value -s TYPE "$PERSIST_DISK" 2>/dev/null || echo "non-ext4")
    log "$PERSIST_DISK already has a signature ($FS_TYPE), skipping mkfs"
  else
    log "No filesystem signature on $PERSIST_DISK — formatting as ext4"
    mkfs.ext4 "$PERSIST_DISK"
  fi

  log "Creating mount points"
  mkdir -p "$MOUNT_POINT"
  if ! DISK_UUID=$(blkid -o value -s UUID "$PERSIST_DISK" 2>/dev/null); then
    err_exit "Persistent disk $PERSIST_DISK has no ext4 UUID (existing signature is not a mountable ext4 filesystem)"
  fi
  if ! grep -q "$DISK_UUID" /etc/fstab; then
    echo "UUID=$DISK_UUID $MOUNT_POINT ext4 defaults 0 2" >> /etc/fstab
    systemctl daemon-reload
  fi
  findmnt -n "$MOUNT_POINT" > /dev/null || mount "$MOUNT_POINT"

  # Create subdirectories ON the disk (must happen after mount)
  mkdir -p "$MOUNT_POINT/etcd"
  mkdir -p "$MOUNT_POINT/pki"
  # requires-mounts-for makes systemd order each bind mount after (and require)
  # the state disk mount at boot, instead of relying on fstab order / mount -a.
  if ! grep -q "/etc/kubernetes/pki" /etc/fstab; then
    echo "$MOUNT_POINT/pki /etc/kubernetes/pki none bind,x-systemd.requires-mounts-for=$MOUNT_POINT 0 0" >> /etc/fstab
  fi
  if ! grep -q "/var/lib/etcd" /etc/fstab; then
    echo "$MOUNT_POINT/etcd /var/lib/etcd none bind,x-systemd.requires-mounts-for=$MOUNT_POINT 0 0" >> /etc/fstab
  fi
  systemctl daemon-reload
  findmnt -n /etc/kubernetes/pki > /dev/null || mount /etc/kubernetes/pki
  findmnt -n /var/lib/etcd > /dev/null || mount /var/lib/etcd

  # KUBEADM_MARKER is written right after this block (i.e. once init/join has
  # exited 0), so a later failure (e.g. the agent install below) retries
  # without re-running kubeadm.
  if [[ -f "$KUBEADM_MARKER" ]]; then
    log "kubeadm already completed (marker present) — skipping init/join"
  elif [[ "$ROLE" == "primary-control" ]]; then
    log "Primary control-plane node detected"
    if cluster_initialized; then
      log "Cluster already initialized — skipping kubeadm init"
    else
      log "Running kubeadm init to initialize the cluster"
      kubeadm init --config "$KUBEADM_CONFIG" --ignore-preflight-errors=all
    fi

  else
    # kubelet.conf is written by kubeadm join at the end of a successful join.
    if [[ -f /etc/kubernetes/kubelet.conf ]]; then
      log "Node already joined (kubelet.conf present) — skipping join"
    else
      log "Secondary control-plane node — joining cluster"
      kubeadm join "$CONTROL_PLANE_ENDPOINT:6443" --token "$BOOTSTRAP_TOKEN" --control-plane --ignore-preflight-errors=all --discovery-token-unsafe-skip-ca-verification
    fi
  fi

elif [[ "$ROLE" == "worker" ]]; then
  if [[ -f "$KUBEADM_MARKER" ]]; then
    log "kubeadm already completed (marker present) — skipping join"
  elif [[ -f /etc/kubernetes/kubelet.conf ]]; then
    log "Node already joined (kubelet.conf present) — skipping join"
  else
    log "Worker node — joining cluster"
    kubeadm join "$CONTROL_PLANE_ENDPOINT:6443" --token "$BOOTSTRAP_TOKEN" --discovery-token-unsafe-skip-ca-verification
  fi

else
  err_exit "Unknown node role '$ROLE'"
fi

# Only reached when init/join exited 0 (set -e aborts otherwise), or when the
# node was already marked/joined.
touch "$KUBEADM_MARKER"

# Gate the agent (and therefore Terraform's readiness signal) on a reachable
# control plane. On failure the retry skips init/join thanks to the marker.
if [[ "$ROLE" == "control" || "$ROLE" == "primary-control" ]]; then
  wait_control_plane
fi

# Start qemu-guest-agent after bootstrapping, ensures node is considered ready at the right time.
log "Installing qemu-guest-agent"
apt install -y qemu-guest-agent
systemctl enable qemu-guest-agent > /dev/null 2>&1
systemctl start qemu-guest-agent

log "Bootstrap complete"
touch /root/node-bootstrap.done
