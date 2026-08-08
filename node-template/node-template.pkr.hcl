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

variable "vm_template_name_prefix" {
  type        = string
  description = "Prefix name of new template"
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

variable "k8s_version" {
  type        = string
  default     = "1.36.2"
  description = "Kubernetes version to install (full semver, e.g. 1.36.2)"
}

variable "cni_version" {
  type        = string
  default     = "1.9.1"
  description = "CNI plugins version to install"
}

source "proxmox-clone" "template" {
  clone_vm_id              = var.vm_template_source_id
  vm_id                    = var.vm_template_id
  insecure_skip_tls_verify = true
  node                     = var.pve_node
  vm_name                  = "${var.vm_template_name_prefix}-k8s-${var.k8s_version}"


  cores    = 2
  sockets  = 1
  memory   = 2048
  cpu_type = "x86-64-v2-AES"
  os       = "l26"

  qemu_agent              = true
  scsi_controller         = "virtio-scsi-pci"
  cloud_init              = true
  cloud_init_storage_pool = "local-lvm"

  full_clone = true
  task_timeout = "5m"

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
    "source.proxmox-clone.template"
  ]

  provisioner "file" {
    source = "config/node-setup.sh"
    destination = "/tmp/node-setup.sh"
  }

  provisioner "file" {
    source = "config/node-runtime.sh"
    destination = "/tmp/node-runtime.sh"
  }

  provisioner "file" {
    source = "config/99-node-runtime.cfg"
    destination = "/tmp/99-node-runtime.cfg"
  }

  provisioner "shell" {
    environment_vars = [
      "K8S_VERSION=${var.k8s_version}",
      "CNI_VERSION=${var.cni_version}",
      "KUBEADM_CONFIG_B64=${base64encode(templatefile("config/kubeadm-config.yaml", { K8S_VERSION = var.k8s_version }))}",
    ]
    inline = [
      "echo \"$KUBEADM_CONFIG_B64\" | base64 -d > /root/kubeadm-config.yaml",
      "mv /tmp/node-setup.sh /root/",
      "mv /tmp/node-runtime.sh /root/",
      "mkdir -p /etc/cloud/cloud.cfg.d",
      "mv /tmp/99-node-runtime.cfg /etc/cloud/cloud.cfg.d",
      "cd /root && bash node-setup.sh",
    ]
    execute_command = "sudo -E /bin/bash -c '{{ .Vars }} {{ .Path }}'"
  }
}
