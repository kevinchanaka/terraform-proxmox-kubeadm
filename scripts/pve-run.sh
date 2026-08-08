#!/usr/bin/env bash
# pve-run.sh — SSH and run a script on the Proxmox host
# Usage:  ./pve-run.sh <script> [args...]
# Set PVE_HOST to override the default target.
set -euo pipefail

PVE_HOST="root@${PROXMOX_HOST}"
SCRIPT="$1"

scp "$SCRIPT" "$PVE_HOST:/tmp/script.sh"
ssh -t "$PVE_HOST" "bash /tmp/script.sh ${*:2}"
exit
