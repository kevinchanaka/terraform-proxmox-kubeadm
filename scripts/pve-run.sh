#!/usr/bin/env bash
# pve-run.sh — run a script on the Proxmox host from anywhere.
# Usage:  ./pve-run.sh <script> [args...]
# Set PVE_HOST to override the default target.
set -euo pipefail

PVE_HOST="${PVE_HOST:-root@pve.lab.kevinf.xyz}"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <script> [args...]"
  echo "  Set PVE_HOST env var to override the target (default: $PVE_HOST)"
  exit 1
fi

SCRIPT="$1"
shift

if [[ ! -f "$SCRIPT" ]]; then
  echo "Error: script not found: $SCRIPT"
  exit 1
fi

# Already on the Proxmox host — run directly.
if [[ "$(hostname -f 2>/dev/null)" == pve* || "$(hostname 2>/dev/null)" == pve* ]]; then
  exec bash "$SCRIPT" "$@"
fi

# Pipe the target script over SSH and execute it with forwarded args.
echo "==> Running $SCRIPT on $PVE_HOST..."
exec ssh -t "$PVE_HOST" "cat > /tmp/pve-run-target.sh && bash /tmp/pve-run-target.sh $*" < "$SCRIPT"
