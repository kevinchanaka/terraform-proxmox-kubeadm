control_plane_ip = "192.168.50.30/24"

proxmox_endpoint  = "https://pve.lab.kevinf.xyz/"

# ---------------------------------------------------------------------------
# Persistent etcd/PKI disk — create once with:
#   ../scripts/create-persistent-disk.sh pve local-lvm vm-999-k8s-persist 10
# Then set the volume ID below.
# ---------------------------------------------------------------------------
persist_disk_volume_id = "local-lvm:vm-999-k8s-persist"
