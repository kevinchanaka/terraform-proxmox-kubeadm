# ---------------------------------------------------------------------------
# Control-plane node with persistent etcd/PKI disk.
# The template already contains:
#   - node-setup.sh        → k8s components installed
#   - setup-persistent-storage.sh → mounts the persistent disk
#   - /etc/cloud/cloud.cfg.d/99-persist-storage.cfg → triggers it at boot
# No cicustom or snippet upload needed — cloud-init picks it up automatically.
# ---------------------------------------------------------------------------
resource "proxmox_vm_qemu" "control-plane" {
  vmid             = var.control_plane_vm_id
  clone_id         = var.clone_template_id
  full_clone       = true
  name             = var.control_plane_name
  target_node      = var.pve_node
  memory           = var.control_plane_memory
  boot             = "order=scsi0"
  scsihw           = "virtio-scsi-pci"
  vm_state         = "running"
  automatic_reboot = true

  cpu {
    cores = var.control_plane_cores
    type  = "x86-64-v2-AES"
  }

  ciupgrade = false
  ciuser    = "kevinf"
  sshkeys   = file(var.ssh_public_key_file)
  ipconfig0 = var.control_plane_ip
  skip_ipv6 = true

  serial {
    id = 0
  }

  # scsi0 = root disk from template, scsi1 = persistent etcd/PKI disk
  disks {
    scsi {
      scsi0 {
        disk {
          storage = "local-lvm"
          size    = "15G"
        }
      }
      scsi1 {
        disk {
          storage = "local-lvm"
          size    = var.persist_disk_size
        }
      }
    }
    ide {
      ide1 {
        cloudinit {
          storage = "local-lvm"
        }
      }
    }
  }

  network {
    id     = 0
    bridge = "vmbr0"
    model  = "virtio"
  }
}

# ---------------------------------------------------------------------------
# Test VM (kept from original setup)
# ---------------------------------------------------------------------------
resource "proxmox_vm_qemu" "test-vm" {
  vmid             = 100
  clone_id         = 902
  full_clone       = true
  name             = "test-vm"
  target_node      = var.pve_node
  memory           = 2048
  boot             = "order=scsi0"
  scsihw           = "virtio-scsi-pci"
  vm_state         = "running"
  automatic_reboot = true

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  # Cloud-Init configuration
  # cicustom   = "vendor=local:snippets/qemu-guest-agent.yml" # /var/lib/vz/snippets/qemu-guest-agent.yml
  # ciupgrade  = true
  # nameserver = "1.1.1.1 8.8.8.8"
  ipconfig0  = "ip=192.168.50.27/24,gw=192.168.50.1"
  skip_ipv6  = true
  ciupgrade  = false
  ciuser     = "kevinf"
  sshkeys    = file(var.ssh_public_key_file)

  serial {
    id = 0
  }

  disks {
    scsi {
      scsi0 {
        disk {
          storage = "local-lvm"
          size    = "15G"
        }
      }
    }
    ide {
      ide1 {
        cloudinit {
          storage = "local-lvm"
        }
      }
    }
  }

  network {
    id     = 0
    bridge = "vmbr0"
    model  = "virtio"
  }
}
