variable "bootstrap_token" {
  type        = string
  sensitive   = true
  description = "Bootstrap token for kubeadm (set via TF_VAR_bootstrap_token)"
}

variable "proxmox_endpoint" {
  type        = string
  description = "Proxmox VE API endpoint, e.g. https://pve.example.com:8006/"
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


variable "control_plane_nodes" {
  type = list(object({
    name       = string
    id         = number
    ip_address = string
    memory     = number
    cpu_cores  = number
    disk_size  = number
    template_id = optional(number)
    additional_disks = optional(list(object({
      interface    = string
      size         = optional(number)
      datastore_id = optional(string, "local-lvm")
      path_in_datastore = optional(string)
    })), [])
  }))
  description = "Control plane node definitions. The first entry runs kubeadm init (primary-control); the rest join as secondary control-plane nodes."

  validation {
    condition     = length(var.control_plane_nodes) >= 1
    error_message = "At least one control plane node is required."
  }
}

variable "worker_nodes" {
  type = list(object({
    name       = string
    id         = number
    ip_address = string
    memory     = number
    cpu_cores  = number
    disk_size  = number
    template_id = optional(number)
  }))
  default     = []
  description = "Worker node definitions"
}
