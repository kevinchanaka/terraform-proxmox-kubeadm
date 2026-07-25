#!/usr/bin/env bash
set -euo pipefail

# Mounts a persistent disk for etcd + PKI data and creates bind mounts
# with systemd ordering so kubeadm/etcd only start after storage is ready.
#
# Usage: setup-persistent-storage.sh <disk-device> [mount-point]
# Example: setup-persistent-storage.sh /dev/sdb

log() { echo "[persistent-storage] $1"; }

if [[ "$UID" -ne 0 ]]; then
  echo "Must be run as root"
  exit 1
fi

DISK="${1:-}"
PERSIST_DIR="${2:-/var/lib/k8s-state}"

if [[ -z "$DISK" ]]; then
  echo "Usage: $0 <disk-device> [mount-point]"
  echo "Example: $0 /dev/sdb"
  exit 1
fi

if [[ ! -b "$DISK" ]]; then
  log "ERROR: $DISK is not a block device"
  exit 1
fi

# ---------------------------------------------------------------------------
# 1. Format the disk if it has no filesystem
# ---------------------------------------------------------------------------
FS_TYPE=$(blkid -o value -s TYPE "$DISK" 2>/dev/null || true)

if [[ -z "$FS_TYPE" ]]; then
  log "No filesystem detected on $DISK — formatting as ext4"
  mkfs.ext4 -F "$DISK"
else
  log "$DISK already formatted ($FS_TYPE), skipping mkfs"
fi

# ---------------------------------------------------------------------------
# 2. Create mount point and subdirectories
# ---------------------------------------------------------------------------
log "Creating mount tree under $PERSIST_DIR"
mkdir -p "$PERSIST_DIR"
mkdir -p "$PERSIST_DIR/etcd"
mkdir -p "$PERSIST_DIR/pki"

# ---------------------------------------------------------------------------
# 3. Mount the persistent disk (fstab-driven for boot ordering)
# ---------------------------------------------------------------------------
DISK_UUID=$(blkid -o value -s UUID "$DISK")

# Remove any existing fstab entry for this mount point
sed -i "\|$PERSIST_DIR|d" /etc/fstab

# Add fstab entry — systemd-fstab-generator turns this into a .mount unit
echo "UUID=$DISK_UUID $PERSIST_DIR ext4 defaults 0 2" >> /etc/fstab

log "Mounting $DISK → $PERSIST_DIR"
systemctl daemon-reload
mount "$PERSIST_DIR"

# ---------------------------------------------------------------------------
# 4. Create systemd mount units for bind mounts
#    These depend on the persistent disk being mounted first.
#    systemd will not start kubelet/etcd until these mounts succeed.
# ---------------------------------------------------------------------------

# Derive the escaped disk-mount unit name (e.g. var-lib-k8s\x2dstate.mount)
DISK_MOUNT_UNIT="$(systemd-escape --path "$PERSIST_DIR").mount"

# --- /var/lib/etcd bind mount ---
cat > /etc/systemd/system/var-lib-etcd.mount <<UNIT
[Unit]
Description=Bind mount persistent etcd data
Documentation=https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/
Requires=$DISK_MOUNT_UNIT
After=$DISK_MOUNT_UNIT
Before=kubelet.service

[Mount]
What=$PERSIST_DIR/etcd
Where=/var/lib/etcd
Type=none
Options=bind

[Install]
WantedBy=local-fs.target
UNIT

# --- /etc/kubernetes/pki bind mount ---
cat > /etc/systemd/system/etc-kubernetes-pki.mount <<UNIT
[Unit]
Description=Bind mount persistent Kubernetes PKI
Documentation=https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/
Requires=$DISK_MOUNT_UNIT
After=$DISK_MOUNT_UNIT
Before=kubelet.service

[Mount]
What=$PERSIST_DIR/pki
Where=/etc/kubernetes/pki
Type=none
Options=bind

[Install]
WantedBy=local-fs.target
UNIT

# ---------------------------------------------------------------------------
# 5. Create target directories, enable and start bind mounts
# ---------------------------------------------------------------------------
mkdir -p /var/lib/etcd
mkdir -p /etc/kubernetes/pki

systemctl daemon-reload
systemctl enable var-lib-etcd.mount
systemctl enable etc-kubernetes-pki.mount


# TODO: do this at runtime!!!
systemctl start var-lib-etcd.mount
systemctl start etc-kubernetes-pki.mount

# ---------------------------------------------------------------------------
# 6. Verify everything
# ---------------------------------------------------------------------------
log "Verifying mounts..."

check_mount() {
  if mountpoint -q "$1"; then
    log "  OK: $1 is mounted"
  else
    log "  FAIL: $1 is NOT mounted"
    exit 1
  fi
}

check_mount "$PERSIST_DIR"
check_mount /var/lib/etcd
check_mount /etc/kubernetes/pki

log "Persistent storage setup complete"
log "  Persistent disk : $DISK → $PERSIST_DIR"
log "  etcd data        : $PERSIST_DIR/etcd → /var/lib/etcd"
log "  PKI certs        : $PERSIST_DIR/pki → /etc/kubernetes/pki"
