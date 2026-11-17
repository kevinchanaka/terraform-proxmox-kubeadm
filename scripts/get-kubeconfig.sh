#!/usr/bin/env bash
# get-kubeconfig.sh — fetch /etc/kubernetes/admin.conf from a VM guest
# Usage: ./get-kubeconfig.sh <vmid>
# Requires: PROXMOX_HOST env var, ssh, scp, jq
set -euo pipefail

PVE_HOST="${PROXMOX_HOST:?PROXMOX_HOST is not set}"
VMID="${1:?Usage: $0 <vmid>}"
OUTPUT="./${VMID}-kubeconfig.yaml"

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

# Step 4: check the guest command result and save the kubeconfig.
# Note: qm's CLI decodes out-data for us, so it is already plain text — do not
# run it through base64 -d.
EXITCODE=$(jq -r '.exitcode // "none"' "$LOCAL_TMPFILE")
if [[ "$EXITCODE" != "0" ]]; then
  jq -r '.["err-data"] // empty' "$LOCAL_TMPFILE" >&2
  rm -f "$LOCAL_TMPFILE"
  echo "Error: guest command failed (exitcode: ${EXITCODE})" >&2
  exit 1
fi

if ! jq -e 'has("out-data")' "$LOCAL_TMPFILE" > /dev/null; then
  rm -f "$LOCAL_TMPFILE"
  echo "Error: guest exec returned no out-data" >&2
  exit 1
fi

jq -r '.["out-data"]' "$LOCAL_TMPFILE" > "$OUTPUT"
rm -f "$LOCAL_TMPFILE"

if [[ ! -s "$OUTPUT" ]] || ! grep -q '^apiVersion:' "$OUTPUT"; then
  rm -f "$OUTPUT"
  echo "Error: fetched data does not look like a kubeconfig" >&2
  exit 1
fi

chmod 600 "$OUTPUT"
echo "kubeconfig saved to ${OUTPUT}"
