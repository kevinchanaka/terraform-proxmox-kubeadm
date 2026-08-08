#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Creates a persistent disk volume on a Proxmox host.
#
# The disk is allocated under a synthetic VMID (999) so that Proxmox won't
# auto-delete it when the real control-plane VM is destroyed.  Proxmox only
# purges disks whose volume name matches the destroyed VM's ID.
#
# Usage:
#   ./create-persistent-disk.sh <proxmox-host> <storage> <volume-name> <size-in-GB>
#
# Example:
#   ./create-persistent-disk.sh pve local-lvm vm-999-k8s-persist 10
#
# After running, add this to infra/infra.auto.tfvars:
#   persist_disk_volume_id = "<storage>:<volume-name>"
# ---------------------------------------------------------------------------

PROXMOX_HOST="${1:?Missing proxmox host}"
STORAGE="${2:?Missing storage name (e.g. local-lvm)}"
VOLUME_NAME="${3:?Missing volume name (e.g. vm-999-k8s-persist)}"
SIZE_GB="${4:?Missing size in GB}"

VOLUME_ID="${STORAGE}:${VOLUME_NAME}"

echo "==> Checking if ${VOLUME_ID} already exists on ${PROXMOX_HOST}..."

if ssh "${PROXMOX_HOST}" "pvesm list ${STORAGE} 2>/dev/null" | grep -qF "${VOLUME_NAME}"; then
  echo "    Volume ${VOLUME_ID} already exists — nothing to do."
else
  echo "    Allocating ${VOLUME_ID} (${SIZE_GB}G)..."
  ssh "${PROXMOX_HOST}" "pvesm alloc ${STORAGE} 999 ${VOLUME_NAME} ${SIZE_GB}G"
  echo "    Created ${VOLUME_ID}"
fi

echo ""
echo "──────────────────────────────────────────────────────────"
echo "  Persistent disk ready: ${VOLUME_ID}"
echo ""
echo "  Add this to infra/infra.auto.tfvars:"
echo "    persist_disk_volume_id = \"${VOLUME_ID}\""
echo "──────────────────────────────────────────────────────────"
