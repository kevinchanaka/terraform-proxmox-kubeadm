#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Creates a persistent disk volume on a Proxmox host.
# Runs on the Proxmox host — use pve-run.sh to invoke from elsewhere.
#
# The disk is allocated under a synthetic VMID (9999) so that Proxmox won't
# auto-delete it when the real control-plane VM is destroyed.  Proxmox only
# purges disks whose volume name matches the destroyed VM's ID.
#
# Usage:
#   ./pve-run.sh create-persistent-disk.sh <volume-name> <size-in-GB>
#
# The volume-name can be a short suffix (auto-prefixed to vm-9999-<name>),
# or a full name starting with vm-9999-.
#
# Example:
#   ./pve-run.sh create-persistent-disk.sh cp-data 10
#
# After running, add this to infra/infra.auto.tfvars:
#   persist_disk_volume_id = "<storage>:<volume-name>"
# ---------------------------------------------------------------------------

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <volume-name> <size-in-GB>"
    exit 1
fi

STORAGE="local-lvm"
VM_ID="9999"
VOLUME_NAME="$1"
SIZE_GB="$2"

PVE_VOLUME_NAME="vm-${VM_ID}-${VOLUME_NAME}"
PVE_VOLUME_ID="${STORAGE}:${PVE_VOLUME_NAME}"

echo "Checking if volume already exists..."

if pvesm list "${STORAGE}" 2>/dev/null | grep -qF "${PVE_VOLUME_NAME}"; then
  echo "Volume ${VOLUME_NAME} already exists, nothing to do."
else
  echo "Creating volume ${VOLUME_NAME} (${SIZE_GB}G)"
  pvesm alloc "${STORAGE}" ${VM_ID} "${PVE_VOLUME_NAME}" "${SIZE_GB}G"
  echo "Created ${VOLUME_NAME}, reference volume using ${PVE_VOLUME_NAME}"
fi
