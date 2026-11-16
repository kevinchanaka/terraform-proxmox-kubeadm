# memory is in MiB, disk sizes are in GiB
proxmox_endpoint = "https://pve.lab.kevinf.xyz/"

control_plane_template_id = 910
worker_template_id        = 910

datastore_id = "local-lvm"

control_plane_data_vm = {
  name = "k8s-cp-data"
  id   = 110
}

# The first entry runs kubeadm init; the rest join as control-plane nodes.
control_plane_nodes = [
  {
    name                 = "k8s-cp"
    id                   = 100
    ip_address           = "192.168.50.27/24"
    cpu_cores            = 2
    memory               = 4096
    disk_size            = 32
    persistent_disk_size = 12
  }
]

worker_nodes = [
  {
    name       = "k8s-worker-1"
    id         = 101
    ip_address = "192.168.50.28/24"
    cpu_cores  = 2
    memory     = 4096
    disk_size  = 32
  }
]
