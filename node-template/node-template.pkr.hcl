packer {
  required_plugins {
    name = {
      version = "~> 1"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

variable "vm_template_source_id" {
  type        = number
  description = "Source VM template to clone and create a new template with"
}

variable "vm_template_id" {
  type        = number
  description = "VM ID of new template"
}

variable "vm_template_name" {
  type        = string
  description = "Name of new template"
}

variable "vm_ip_and_network_cidr" {
  type        = string
  description = "IP and CIDR range to use for new VM in <ip>/<prefix> format e.g. 192.168.0.20/24"
}

variable "pve_node" {
  type        = string
  default     = "pve"
  description = "Name of proxmox node to create VM on"
}

variable "vm_username" {
  type        = string
  default     = "ubuntu"
  description = "Username to provision and use when creating image. Can use the same default user for source VM template"
}


source "proxmox-clone" "test-template-clone" {
  clone_vm_id              = var.vm_template_source_id
  vm_id                    = var.vm_template_id
  insecure_skip_tls_verify = true
  node                     = var.pve_node
  vm_name                  = var.vm_template_name


  cores    = 2
  sockets  = 1
  memory   = 2048
  cpu_type = "x86-64-v2-AES"
  os       = "l26"

  qemu_agent              = true
  scsi_controller         = "virtio-scsi-pci"
  cloud_init              = true
  cloud_init_storage_pool = "local-lvm"

  # disks {
  #   disk_size    = "10G"
  #   format       = "raw"
  #   storage_pool = "local-lvm"
  #   type         = "scsi"
  # }

  full_clone = true

  network_adapters {
    bridge = "vmbr0"
    model  = "virtio"
  }

  ipconfig {
    ip      = var.vm_ip_and_network_cidr
    gateway = cidrhost(var.vm_ip_and_network_cidr, 1)
  }

  serials = [
    "socket"
  ]
  vga {
    type = "serial0"
  }

  ssh_username = var.vm_username
  ssh_host     = split("/", var.vm_ip_and_network_cidr)[0]
}

build {
  sources = [
    "source.proxmox-clone.test-template-clone"
  ]

  provisioner "file" {
    source = "template-bootstrap.sh"
    destination = "template-bootstrap.sh"
  }

  provisioner "shell" {
    inline = [
      "mv template-bootstrap.sh /root/template-bootstrap.sh",
      "cd /root && bash template-bootstrap.sh",
      "rm template-bootstrap.sh"
    ]
    execute_command = "sudo /bin/bash -c '{{ .Vars }} {{ .Path }}'"
  }
}
