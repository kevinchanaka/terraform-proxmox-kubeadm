#!/bin/bash
# Run this script on a proxmox node to create a VM template from a cloud-init image
# Docs: pve.proxmox.com/wiki/Cloud-Init_Support
# Ubuntu ISOs: https://cloud-images.ubuntu.com/

set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <download_url> <vmid> <template_name>"
    exit 1
fi

URL="$1"
VMID="$2"
TEMPLATE_NAME="$3"
IMG_FILE="$(basename "$URL")"

if qm status $VMID &>/dev/null; then
    echo "Error: VM $VMID already exists. Exiting."
    exit 1
fi

if [[ ! -f "$IMG_FILE" ]]; then
    echo "Downloading image: $URL"
    wget -O "$IMG_FILE" "$URL"
else
    echo "Using existing image: $IMG_FILE"
fi

qm create $VMID \
    --cores 2 \
    --memory 2048 \
    --net0 virtio,bridge=vmbr0 \
    --scsihw virtio-scsi-pci \
    --ostype l26

qm set $VMID --scsi0 local-lvm:0,import-from=$PWD/$IMG_FILE

qm disk resize $VMID scsi0 10G

qm set $VMID \
    --ide2 local-lvm:cloudinit \
    --boot order=scsi0 \
    --serial0 socket \
    --vga serial0 \
    --ciupgrade 0

qm template $VMID

rm $IMG_FILE
