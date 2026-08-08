#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Creates a persistent disk volume on a Proxmox host.
# Runs on the Proxmox host — use pve-run.sh to invoke from elsewhere.
#
# The disk is allocated under a synthetic VMID (999) so that Proxmox won't
# auto-delete it when the real control-plane VM is destroyed.  Proxmox only
# purges disks whose volume name matches the destroyed VM's ID.
#
# Usage:
#   ./pve-run.sh create-persistent-disk.sh <storage> <volume-name> <size-in-GB>
#
# Example:
#   ./pve-run.sh create-persistent-disk.sh local-lvm vm-999-k8s-persist 10
#
# After running, add this to infra/infra.auto.tfvars:
#   persist_disk_volume_id = "<storage>:<volume-name>"
# ---------------------------------------------------------------------------

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <storage> <volume-name> <size-in-GB>"
    exit 1
fi

STORAGE="$1"
VOLUME_NAME="$2"
SIZE_GB="$3"

VOLUME_ID="${STORAGE}:${VOLUME_NAME}"

echo "==> Checking if ${VOLUME_ID} already exists..."

if pvesm list "${STORAGE}" 2>/dev/null | grep -qF "${VOLUME_NAME}"; then
  echo "    Volume ${VOLUME_ID} already exists — nothing to do."
else
  echo "    Allocating ${VOLUME_ID} (${SIZE_GB}G)..."
  pvesm alloc "${STORAGE}" 999 "${VOLUME_NAME}" "${SIZE_GB}G"
  echo "    Created ${VOLUME_ID}"
fi

echo ""
echo "──────────────────────────────────────────────────────────"
echo "  Persistent disk ready: ${VOLUME_ID}"
echo ""
echo "  Add this to infra/infra.auto.tfvars:"
echo "    persist_disk_volume_id = \"${VOLUME_ID}\""
echo "──────────────────────────────────────────────────────────"
