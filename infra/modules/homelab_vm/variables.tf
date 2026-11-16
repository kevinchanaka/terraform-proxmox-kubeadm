variable "name" {
  type        = string
  description = "Name of the VM to create"
}

variable "id" {
  type        = number
  description = "VM ID of the new VM to create"
}

variable "template_id" {
  type        = number
  description = "VM ID of the template to clone from"
}

variable "cpu_cores" {
  type        = number
  description = "Number of CPU cores to assign to the VM"
}

variable "memory" {
  type        = number
  description = "Memory in MiB to assign to the VM"
}

variable "disk_size" {
  type        = number
  description = "Size of the primary disk (scsi0) in GiB"
}

variable "datastore_id" {
  type        = string
  default     = "local-lvm"
  description = "Datastore for the root disk (scsi0) and the cloud-init drive."
}

variable "attached_disks" {
  # A subset of the provider's computed disk object (e.g. module.data_vm.disks
  # elements). Extra attributes are discarded by type conversion.
  type = list(object({
    datastore_id      = optional(string)
    path_in_datastore = optional(string)
    file_format       = optional(string)
    size              = optional(number)
  }))
  default     = []
  description = "Existing disks to attach, e.g. the disk objects from the data VM module. Attached as scsi1, scsi2 onwards in list order."
}

variable "smbios" {
  type = object({
    family       = optional(string)
    manufacturer = optional(string)
    product      = optional(string)
    serial       = optional(string)
    sku          = optional(string)
    uuid         = optional(string)
    version      = optional(string)
  })
  default     = null
  description = "SMBIOS settings. No smbios block is created when null."
}

variable "ip_address" {
  type        = string
  description = "IPv4 address in CIDR notation, e.g. 192.168.50.27/24"
}

variable "gateway" {
  type        = string
  default     = null
  description = "IPv4 gateway address. Defaults to the first host in the subnet derived from ip_address (e.g. 192.168.50.1 for 192.168.50.0/24)."
}

variable "username" {
  type        = string
  default     = null
  description = "Username for the initial user account, defaults to the default user of the template (e.g. ubuntu)"
}

variable "pve_node" {
  type    = string
  default = "pve"
}

variable "ssh_public_key_file" {
  type    = string
  default = "~/.ssh/id_rsa.pub"
}

variable "qemu_agent_enabled" {
  type        = bool
  default     = true
  description = "Whether to enable the QEMU guest agent. This is required for Proxmox to consider the VM 'ready' and to allow for clean shutdowns."
}
