variable "bootstrap_token" {
  type        = string
  sensitive   = true
  description = "Bootstrap token for kubeadm (set via TF_VAR_bootstrap_token)"
}

variable "proxmox_endpoint" {
  type        = string
  description = "Proxmox VE API endpoint, e.g. https://pve.example.com:8006/"
}

variable "pve_node" {
  type    = string
  default = "pve"
}

variable "ssh_public_key_file" {
  type    = string
  default = "~/.ssh/id_rsa.pub"
}

variable "control_plane_vm_id" {
  type    = number
  default = 100
}

variable "control_plane_name" {
  type    = string
  default = "k8s-cp-1"
}

variable "control_plane_ip" {
  type        = string
  description = "Static IP in CIDR notation, e.g. 192.168.50.30/24"
}

variable "control_plane_memory" {
  type    = number
  default = 4096
}

variable "control_plane_cores" {
  type    = number
  default = 2
}

variable "clone_template_id" {
  type        = number
  default     = 902
  description = "VM template ID created by Packer"
}

variable "node_role" {
  type        = string
  default     = "control-plane-primary"
  description = "Node role set in SMBIOS product field. 'control-plane-primary' runs kubeadm init, 'control-plane' runs kubeadm join --control-plane, 'worker' runs kubeadm join."

  validation {
    condition     = contains(["control-plane-primary", "control-plane", "worker"], var.node_role)
    error_message = "node_role must be one of: control-plane-primary, control-plane, worker"
  }
}

variable "persist_disk_device" {
  type        = string
  default     = "/dev/sdb"
  description = "Guest device path for the persistent etcd/PKI disk (maps to scsi1)"
}

variable "persist_disk_volume_id" {
  type        = string
  description = "Proxmox volume ID for the persistent etcd/PKI disk (e.g. 'local-lvm:vm-999-k8s-persist'). Create once with scripts/create-persistent-disk.sh, then set here. The disk lives independently of the VM — it survives terraform destroy and re-attaches on the next apply. Use a VMID in the volume name that differs from the actual control-plane VM to prevent Proxmox from auto-deleting it."
}
