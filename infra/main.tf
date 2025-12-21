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
  #cipassword = "Enter123!"
  sshkeys    = file(var.ssh_public_key_file)
  #sshkeys    = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE/Pjg7YXZ8Yau9heCc4YWxFlzhThnI+IhUx2hLJRxYE Cloud-Init@Terraform"

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
