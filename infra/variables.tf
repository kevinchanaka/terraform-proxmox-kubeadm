
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

variable "persist_disk_device" {
  type        = string
  default     = "/dev/sdb"
  description = "Guest device path for the persistent etcd/PKI disk"
}

variable "persist_disk_size" {
  type        = string
  default     = "10G"
  description = "Size of the persistent etcd/PKI disk"
}