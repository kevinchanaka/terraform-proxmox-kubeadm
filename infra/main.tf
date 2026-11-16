locals {
  control_plane_endpoint = var.control_plane_endpoint != null ? var.control_plane_endpoint : (
    length(var.control_plane_nodes) > 0 ? split("/", var.control_plane_nodes[0].ip_address)[0] : ""
  )
  cluster_mode   = length(var.control_plane_nodes) > 1 ? "high-availability" : "single"
  cluster_config = "${local.control_plane_endpoint} ${local.cluster_mode} ${var.bootstrap_token}"
}

check "ha_requires_endpoint" {
  assert {
    condition     = length(var.control_plane_nodes) <= 1 || var.control_plane_endpoint != null
    error_message = "control_plane_endpoint must be set for high-availability (2+ control plane nodes). Provide a DNS name that fronts the control plane."
  }
}

check "unique_vm_ids" {
  assert {
    condition = length(distinct(concat(
      [for n in var.control_plane_nodes : n.id],
      [for n in var.worker_nodes : n.id],
      [var.control_plane_data_vm.id],
    ))) == length(var.control_plane_nodes) + length(var.worker_nodes) + 1
    error_message = "VM IDs must be unique across control-plane nodes, worker nodes, and the data VM."
  }
}

module "control_plane_data" {
  source = "./modules/data_vm"

  name         = var.control_plane_data_vm.name
  id           = var.control_plane_data_vm.id
  disks        = [for n in var.control_plane_nodes : { size = n.persistent_disk_size }]
  pve_node     = var.pve_node
  datastore_id = var.datastore_id
}

module "control_plane_primary" {
  source = "./modules/homelab_vm"

  id           = var.control_plane_nodes[0].id
  name         = var.control_plane_nodes[0].name
  template_id  = var.control_plane_nodes[0].template_id != null ? var.control_plane_nodes[0].template_id : var.control_plane_template_id
  ip_address   = var.control_plane_nodes[0].ip_address
  memory       = var.control_plane_nodes[0].memory
  cpu_cores    = var.control_plane_nodes[0].cpu_cores
  disk_size    = var.control_plane_nodes[0].disk_size
  pve_node     = var.pve_node
  datastore_id = var.datastore_id
  gateway      = var.control_plane_nodes[0].gateway

  smbios = {
    product = "primary-control"
    family  = local.cluster_config
  }

  # Disk 0 of the data VM holds this node's etcd + PKI data.
  attached_disks = [module.control_plane_data.disks[0]]
}

module "control_plane" {
  source = "./modules/homelab_vm"
  # disk_index maps each secondary node to its disk in the data VM
  # (index 0 belongs to the primary).
  for_each = {
    for i, n in slice(var.control_plane_nodes, 1, length(var.control_plane_nodes)) :
    n.name => merge(n, { disk_index = i + 1 })
  }

  id           = each.value.id
  name         = each.key
  template_id  = each.value.template_id != null ? each.value.template_id : var.control_plane_template_id
  ip_address   = each.value.ip_address
  memory       = each.value.memory
  cpu_cores    = each.value.cpu_cores
  disk_size    = each.value.disk_size
  pve_node     = var.pve_node
  datastore_id = var.datastore_id
  gateway      = each.value.gateway

  smbios = {
    product = "control"
    family  = local.cluster_config
  }

  attached_disks = [module.control_plane_data.disks[each.value.disk_index]]

  depends_on = [module.control_plane_primary]
}

module "worker" {
  source   = "./modules/homelab_vm"
  for_each = { for n in var.worker_nodes : n.name => n }

  id           = each.value.id
  name         = each.key
  template_id  = each.value.template_id != null ? each.value.template_id : var.worker_template_id
  ip_address   = each.value.ip_address
  memory       = each.value.memory
  cpu_cores    = each.value.cpu_cores
  disk_size    = each.value.disk_size
  pve_node     = var.pve_node
  datastore_id = var.datastore_id
  gateway      = each.value.gateway

  smbios = {
    product = "worker"
    family  = local.cluster_config
  }

  depends_on = [module.control_plane_primary, module.control_plane]
}
