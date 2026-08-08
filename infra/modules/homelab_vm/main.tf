resource "proxmox_virtual_environment_vm" "this" {
  vm_id     = var.id
  name      = var.name
  node_name = var.pve_node

  clone {
    vm_id = var.clone_id
    full  = true
  }

  cpu {
    cores = var.cpu_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.memory
  }

  scsi_hardware = "virtio-scsi-pci"

  operating_system {
    type = "l26"
  }

  agent {
    enabled = var.qemu_agent_enabled
    timeout = "15m"
    trim    = true
  }

  started = true

  disk {
    interface    = "scsi0"
    datastore_id = "local-lvm"
    size         = var.disk_size
  }

  dynamic "disk" {
    for_each = var.additional_disks
    content {
      interface    = disk.value.interface
      size         = disk.value.size
      datastore_id = disk.value.datastore_id
      file_id      = disk.value.file_id
    }
  }

  dynamic "smbios" {
    for_each = var.smbios != null ? [var.smbios] : []
    content {
      family       = smbios.value.family
      manufacturer = smbios.value.manufacturer
      product      = smbios.value.product
      serial       = smbios.value.serial
      sku          = smbios.value.sku
      uuid         = smbios.value.uuid
      version      = smbios.value.version
    }
  }

  initialization {
    datastore_id = "local-lvm"
    interface    = "ide2"

    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway != null ? var.gateway : cidrhost(var.ip_address, 1)
      }
    }

    dynamic "user_account" {
      for_each = var.username != null ? [var.username] : []
      content {
        username = user_account.value
        keys     = [trimspace(file(var.ssh_public_key_file))]
      }
    }

    upgrade = false
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  serial_device {
    device = "socket"
  }

  vga {
    type = "serial0"
  }
}
