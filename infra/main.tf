locals {
  cluster_config = "192.168.50.27 single ${var.bootstrap_token}"
}


module "test-vm" {
  source = "./modules/homelab_vm"

  id     = 100
  name      = "test-vm"
  clone_id = 903

  cpu_cores = 2
  memory    = 4096

  smbios = {
    product = "primary-control"
    family = local.cluster_config
  }

  ip_address = "192.168.50.27/24"
  username   = "kevinf"

  disk_size = 15

  additional_disks = [
    {
      interface    = "scsi1"
      size         = 10
    }
  ]
}

module "test-vm-1" {
  source = "./modules/homelab_vm"

  id     = 101
  name      = "test-vm-1"
  clone_id = 903

  cpu_cores = 2
  memory    = 4096

  smbios = {
    product = "worker"
    family = local.cluster_config
  }

  ip_address = "192.168.50.28/24"
  username   = "kevinf"

  disk_size = 15

  depends_on = [module.test-vm]
}
