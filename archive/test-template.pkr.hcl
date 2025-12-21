packer {
  required_plugins {
    name = {
      version = "~> 1"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

# example: https://github.com/ChristianLempa/boilerplates/blob/main/packer/proxmox/ubuntu-server-focal/ubuntu-server-focal.pkr.hcl
# ISOs: https://cloud-images.ubuntu.com/

source "proxmox-iso" "test-template" {
  insecure_skip_tls_verify = true
  node                     = "pve"

  cores    = 2
  sockets  = 1
  memory   = 2048
  cpu_type = "x86-64-v2-AES"
  os       = "l26"

  qemu_agent              = true
  scsi_controller         = "virtio-scsi-pci"
  cloud_init              = true
  cloud_init_storage_pool = "local-lvm"

  disks {
    disk_size    = "10G"
    format       = "raw"
    storage_pool = "local-lvm"
    type         = "scsi"
  }

  boot_iso {
    type             = "scsi"
    iso_file         = "local:iso/noble-server-cloudimg-amd64.img"
    iso_checksum     = "sha256:834af9cd766d1fd86eca156db7dff34c3713fbbc7f5507a3269be2a72d2d1820"
    iso_storage_pool = "local"
    unmount          = true
  }

  network_adapters {
    bridge = "vmbr0"
    # firewall = true
    model = "virtio"
    # vlan_tag = var.network_vlan
  }

  # boot = "order=scsi1"
  serials = [
    "socket"
  ]
  vga {
    type = "serial0"
  }

  ssh_username = "root"
  ssh_password = "packer"
}

build {
  sources = [
    "source.proxmox-iso.test-template"
  ]

  provisioner "shell" {
    inline = ["./template-bootstrap.sh"]
  }
}
