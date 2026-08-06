#!/usr/bin/env bash
set -euo pipefail

PERSIST_DISK="/dev/sdb"
MOUNT_POINT="/var/lib/k8s-state"
BOOTSTRAP_TOKEN_FILE="/root/bootstrap-token"
KUBEADM_CONFIG="/root/kubeadm-config.yaml"

log() { echo "[node-runtime] $1"; }
err_exit() { echo "[node-runtime] ERROR: $1"; exit 1; }

if [[ "$UID" -ne 0 ]]; then
  err_exit "Must be run as root"
fi

NODE_CONFIG=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
log "Node config specified in /sys/class/dmi/id/product_name: $NODE_CONFIG"

read -r CONTROL_PLANE_ENDPOINT ROLE <<< "$NODE_CONFIG"
log "Parsed control plane endpoint: $CONTROL_PLANE_ENDPOINT"
log "Parsed node role: $ROLE"

if [[ ! -f "$BOOTSTRAP_TOKEN_FILE" ]]; then
  err_exit "Bootstrap token file $BOOTSTRAP_TOKEN_FILE not found"
fi
BOOTSTRAP_TOKEN=$(cat "$BOOTSTRAP_TOKEN_FILE")

log "Adding control plane endpoint and bootstrap token to kubeadm config"
sed -i "s|CONTROL_PLANE_ENDPOINT|$CONTROL_PLANE_ENDPOINT|" "$KUBEADM_CONFIG"
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
    log "Primary control-plane node — running kubeadm init"
    kubeadm init --config "$KUBEADM_CONFIG"

  else
    log "Secondary control-plane node — joining cluster"
    kubeadm join "$CONTROL_PLANE_ENDPOINT" --token "$TOKEN" --control-plane
  fi

elif [[ "$ROLE" == "worker" ]]; then
  log "Worker node — joining cluster"
  kubeadm join "$CONTROL_PLANE_ENDPOINT" --token "$TOKEN"

else
  err_exit "Unknown node role '$ROLE'"
fi

# Start qemu-guest-agent after bootstrapping
log "Starting qemu-guest-agent"
systemctl enable qemu-guest-agent
systemctl start qemu-guest-agent
log "Bootstrap complete"
