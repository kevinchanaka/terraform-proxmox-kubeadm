variable "name" {
  type        = string
  description = "Name of the VM to create"
}

variable "id" {
  type        = number
  description = "VM ID of the new VM to create"
}

variable "disks" {
  type = list(object({
    size = number
  }))
  default     = []
  description = "Data disks to create (attached as scsi0, scsi1, ...)"
}

variable "pve_node" {
  type    = string
  default = "pve"
}

variable "datastore_id" {
  type        = string
  default     = "local-lvm"
  description = "Datastore to create the data disks in."
}
