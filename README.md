# terraform-proxmox-kubernetes

Project to provision a Kubernetes homelab


Tools:
- packer to create proxmox VM templates
- Proxmox to provision VMs
- bash scripts to run kubeadm commands to initialise the cluster and join nodes


Disk layout (need to fix, only need one disk)

df -h
Filesystem      Size  Used Avail Use% Mounted on
tmpfs           197M 1000K  196M   1% /run
/dev/sda1       2.4G  2.2G  166M  94% /
tmpfs           984M     0  984M   0% /dev/shm
tmpfs           5.0M     0  5.0M   0% /run/lock
/dev/sda16      881M  112M  708M  14% /boot
/dev/sda15      105M  6.2M   99M   6% /boot/efi
tmpfs           197M   12K  197M   1% /run/user/1001

lsblk
NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda       8:0    0  3.5G  0 disk
├─sda1    8:1    0  2.5G  0 part /
├─sda14   8:14   0    4M  0 part
├─sda15   8:15   0  106M  0 part /boot/efi
└─sda16 259:0    0  913M  0 part /boot
sdb       8:16   0   10G  0 disk
sr0      11:0    1    4M  0 rom

Test file location

sudo find / -name testfile.txt
/home/packer/testfile.txt



# Notes

Need to create VM tempale first on the node, prior to creating images. This is due to limitations of packer provisoiner, it cannot create VM images directly from qcow2 images

# https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox
proxmox-clone is better than proxmox-iso

# example: https://github.com/ChristianLempa/boilerplates/blob/main/packer/proxmox/ubuntu-server-focal/ubuntu-server-focal.pkr.hcl
# ISOs: https://cloud-images.ubuntu.com/
