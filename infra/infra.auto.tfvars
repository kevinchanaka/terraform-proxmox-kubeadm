proxmox_endpoint = "https://pve.lab.kevinf.xyz/"

control_plane_template_id = 910
worker_template_id        = 910

control_plane_data_vm_name = "k8s-cp-data"
control_plane_data_vm_id   = 110

control_plane_nodes = [
  {
    name       = "k8s-cp"
    id         = 100
    ip_address = "192.168.50.27/24"
    cpu_cores  = 2
    memory     = 2048
    disk_size  = 20
  }
]

worker_nodes = [
  {
    name       = "k8s-worker-1"
    id         = 101
    ip_address = "192.168.50.28/24"
    cpu_cores  = 2
    disk_size  = 20
    memory     = 4096
  }
]
