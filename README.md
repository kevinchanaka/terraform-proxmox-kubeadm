# terraform-proxmox-kubeadm

Project to provision a Kubernetes homelab using the following tools:
- Packer to create worker node VM templates based on Ubuntu
- Terraform to provision infrastructure in Proxmox
- Kubeadm to initialise and manage Kubernetes cluster

## Packer

The Packer project creates Kubernetes worker node VM templates from an existing VM template. The initiall template needs to be manually created via `create-vm-template.sh` script run directly on a Proxmox node. This is done as the Packer Proxmox provisioner has better support for `proxmox_clone` action when compared to `proxmox_iso`, which does not support QCOW2 images.
