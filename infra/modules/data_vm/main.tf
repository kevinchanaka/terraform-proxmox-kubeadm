resource "proxmox_virtual_environment_vm" "this" {
  vm_id     = var.id
  name      = var.name
  node_name = var.pve_node

  started = false
  on_boot = false

  scsi_hardware = "virtio-scsi-pci"

  dynamic "disk" {
    for_each = var.disks
    content {
      interface    = "scsi${disk.key}"
      size         = disk.value.size
      datastore_id = var.datastore_id
    }
  }

  lifecycle {
    # Must be a literal: Terraform does not allow variables in lifecycle rules.
    # This VM is a disk container — never let Terraform destroy it.
    prevent_destroy = true
  }
}
