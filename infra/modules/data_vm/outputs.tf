output "disks" {
  description = "Disks owned by the data VM, in interface order. Consumers attach these with path_in_datastore."
  value       = proxmox_virtual_environment_vm.this.disk
}
