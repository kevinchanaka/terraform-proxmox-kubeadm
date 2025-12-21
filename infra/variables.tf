
variable "pve_node" {
  type    = string
  default = "pve"
}

variable "ssh_public_key_file" {
    type = string
    default = "~/.ssh/id_rsa.pub"
}