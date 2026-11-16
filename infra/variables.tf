variable "bootstrap_token" {
  type        = string
  sensitive   = true
  description = "Bootstrap token for kubeadm (set via TF_VAR_bootstrap_token)"

  validation {
    condition     = can(regex("^[a-z0-9]{6}[.][a-z0-9]{16}$", var.bootstrap_token))
    error_message = "Bootstrap token must look like abcdef.0123456789abcdef."
  }
}

variable "proxmox_endpoint" {
  type        = string
  description = "Proxmox VE API endpoint, e.g. https://pve.example.com:8006/"
}

variable "pve_node" {
  type        = string
  default     = "pve"
  description = "Proxmox node to create the VMs on."
}

variable "datastore_id" {
  type        = string
  default     = "local-lvm"
  description = "Datastore used for VM disks and the cloud-init drive."
}

variable "control_plane_endpoint" {
  type        = string
  default     = null
  description = "DNS name (or IP) that can be used to access all the control plane nodes. Required for high-availability."
}

variable "control_plane_template_id" {
  type        = number
  description = "Default VM template ID for control plane. Used when a node does not specify its own template_id."
}

variable "worker_template_id" {
  type        = number
  description = "Default VM template ID for worker nodes. Used when a node does not specify its own template_id."
}

variable "control_plane_data_vm" {
  type = object({
    name = string
    id   = number
  })
  description = "Data VM that owns the control plane persistent disks (etcd + PKI)."
}

variable "control_plane_nodes" {
  type = list(object({
    name                 = string
    id                   = number
    ip_address           = string
    memory               = number
    cpu_cores            = number
    disk_size            = number
    persistent_disk_size = optional(number, 10)
    template_id          = optional(number)
    gateway              = optional(string)
  }))
  description = "Control plane node definitions. The first entry runs kubeadm init (primary-control); the rest join as secondary control-plane nodes."

  validation {
    condition     = length(var.control_plane_nodes) >= 1
    error_message = "At least one control plane node is required."
  }

  validation {
    condition     = alltrue([for n in var.control_plane_nodes : can(cidrhost(n.ip_address, 1))])
    error_message = "Each control plane node ip_address must be valid CIDR notation, e.g. 192.168.50.27/24."
  }
}

variable "worker_nodes" {
  type = list(object({
    name        = string
    id          = number
    ip_address  = string
    memory      = number
    cpu_cores   = number
    disk_size   = number
    template_id = optional(number)
    gateway     = optional(string)
  }))
  default     = []
  description = "Worker node definitions"

  validation {
    condition     = alltrue([for n in var.worker_nodes : can(cidrhost(n.ip_address, 1))])
    error_message = "Each worker node ip_address must be valid CIDR notation, e.g. 192.168.50.28/24."
  }
}
