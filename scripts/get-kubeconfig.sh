#!/usr/bin/env bash
# get-kubeconfig.sh — fetch /etc/kubernetes/admin.conf from a VM guest
# Usage:  ./get-kubeconfig.sh <vmid> [output-path]
# Requires: PROXMOX_HOST env var, ssh, scp, jq, base64
set -euo pipefail

PVE_HOST="${PROXMOX_HOST:?PROXMOX_HOST is not set}"
VMID="${1:?Usage: $0 <vmid> [output-path]}"
OUTPUT="${2:-./${VMID}-kubeconfig.yaml}"

# Step 1: run qm guest exec on Proxmox, save raw JSON to a remote temp file
REMOTE_TMPFILE=$(ssh "root@${PVE_HOST}" "
  TMPFILE=\$(mktemp)
  qm guest exec ${VMID} -- cat /etc/kubernetes/admin.conf > \"\$TMPFILE\"
  echo \"\$TMPFILE\"
" | tail -1)

# Step 2: pull the temp file back locally
LOCAL_TMPFILE=$(mktemp)
scp "root@${PVE_HOST}:${REMOTE_TMPFILE}" "$LOCAL_TMPFILE"

# Step 3: clean up the remote temp file
ssh "root@${PVE_HOST}" "rm -f ${REMOTE_TMPFILE}"

# Step 4: parse with jq and save the kubeconfig
jq -r '.["out-data"]' "$LOCAL_TMPFILE" | base64 -d > "$OUTPUT"
rm -f "$LOCAL_TMPFILE"
chmod 600 "$OUTPUT"
echo "kubeconfig saved to ${OUTPUT}"
