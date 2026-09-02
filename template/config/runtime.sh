#!/usr/bin/env bash
set -euo pipefail

PERSIST_DISK="/dev/sdb"
MOUNT_POINT="/var/lib/k8s-state"
KUBEADM_CONFIG="/root/kubeadm-config.yaml"

log() { echo "[node-runtime] $1"; }
err_exit() { echo "[node-runtime] ERROR: $1"; exit 1; }

if [[ "$UID" -ne 0 ]]; then
  err_exit "Must be run as root"
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

  # Format if the disk has no filesystem yet (first boot only)
  FS_TYPE=$(blkid -o value -s TYPE "$PERSIST_DISK" 2>/dev/null || true)
  if [[ -z "$FS_TYPE" ]]; then
    log "No filesystem on $PERSIST_DISK — formatting as ext4"
    mkfs.ext4 -F "$PERSIST_DISK"
  else
    log "$PERSIST_DISK already formatted ($FS_TYPE), skipping mkfs"
  fi

  log "Creating mount points"
  mkdir -p "$MOUNT_POINT"
  DISK_UUID=$(blkid -o value -s UUID "$PERSIST_DISK")
  if ! grep -q "$DISK_UUID" /etc/fstab; then
    echo "UUID=$DISK_UUID $MOUNT_POINT ext4 defaults 0 2" >> /etc/fstab
    systemctl daemon-reload
    mount "$MOUNT_POINT"
  fi
  # Create subdirectories ON the disk (must happen after mount)
  mkdir -p "$MOUNT_POINT/etcd"
  mkdir -p "$MOUNT_POINT/pki"
  if ! grep -q "/etc/kubernetes/pki" /etc/fstab; then
    echo "$MOUNT_POINT/pki /etc/kubernetes/pki none bind 0 0" >> /etc/fstab
  fi
  if ! grep -q "/var/lib/etcd" /etc/fstab; then
    echo "$MOUNT_POINT/etcd /var/lib/etcd none bind 0 0" >> /etc/fstab
  fi
  systemctl daemon-reload
  mount -a

  if [[ "$ROLE" == "primary-control" ]]; then
    log "Primary control-plane node detected"
    if [ "$(ls -A /etc/kubernetes/pki 2>/dev/null)" ]; then
      log "Existing certificates found — renewing with kubeadm"
      kubeadm certs renew all --config "$KUBEADM_CONFIG"
    fi
    log "Running kubeadm init to initialize the cluster"
    kubeadm init --config "$KUBEADM_CONFIG" --ignore-preflight-errors=all

  else
    log "Secondary control-plane node — joining cluster"
    kubeadm join "$CONTROL_PLANE_ENDPOINT:6443" --token "$BOOTSTRAP_TOKEN" --control-plane --ignore-preflight-errors=all --discovery-token-unsafe-skip-ca-verification
  fi

elif [[ "$ROLE" == "worker" ]]; then
  log "Worker node — joining cluster"
  kubeadm join "$CONTROL_PLANE_ENDPOINT:6443" --token "$BOOTSTRAP_TOKEN" --discovery-token-unsafe-skip-ca-verification

else
  err_exit "Unknown node role '$ROLE'"
fi

# Start qemu-guest-agent after bootstrapping, ensures node is considered ready at the right time
log "Installing qemu-guest-agent"
apt install -y qemu-guest-agent
systemctl enable qemu-guest-agent > /dev/null 2>&1
systemctl start qemu-guest-agent

log "Bootstrap complete"
