terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.111"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  insecure  = true

  # SSH is required for file uploads / snippet management. If you only clone
  # templates and configure cloud-init, SSH can be left unset.
  # ssh {
  #   username = var.proxmox_ssh_username
  #   password = var.proxmox_ssh_password
  # }
}
