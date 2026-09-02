#!/usr/bin/env bash
set -euo pipefail

log() { echo "[node-runtime] $1"; }
err_exit() { echo "[node-runtime] ERROR: $1"; exit 1; }

if [[ "$UID" -ne 0 ]]; then
  err_exit "Must be run as root"
fi

K8S_MINOR="${K8S_VERSION%.*}"

if [[ "$UID" -ne 0 ]]; then
  echo "Must be run as root"
  exit 1
fi

log "Starting node setup"

log "Disabling swap"
sed -i '/^[^#].*\s\+swap\s\+sw\s\+/ s/^/# /' /etc/fstab

log "Loading kernel modules"
cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

log "Applying sysctl settings"
cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

log "Updating OS packages"
apt update
apt dist-upgrade -y
apt autoremove -y

log "Installing base packages"
apt install -y \
  ca-certificates \
  curl \
  gpg \
  nfs-common \
  open-iscsi \
  lsscsi \
  sg3-utils \
  multipath-tools \
  scsitools

log "Write multipath config"
cat >/etc/multipath.conf <<EOF
defaults {
  user_friendly_names yes
  find_multipaths yes
}
EOF

log "Creating required directories"
mkdir -p /etc/kubernetes/pki/
mkdir -p /etc/containerd/
mkdir -p /opt/cni/bin/
mkdir -p /etc/apt/keyrings/
mkdir -p /var/lib/etcd/

log "Installing CNI plugins (v${CNI_VERSION})"
curl -fsSL "https://github.com/containernetworking/plugins/releases/download/v${CNI_VERSION}/cni-plugins-linux-amd64-v${CNI_VERSION}.tgz" \
  | tar -C /opt/cni/bin -xz

log "Installing containerd"
apt install -y containerd

log "Configuring containerd"
mkdir -p /etc/containerd

cat > /etc/containerd/config.toml <<EOF
version = 3
[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc.options]
  SystemdCgroup = true
EOF

systemctl enable containerd

log "Installing Kubernetes packages"

# These commands change based on k8s version
curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${K8S_MINOR}/deb/Release.key" \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg

cat > /etc/apt/sources.list.d/kubernetes.list <<EOF
deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] \
https://pkgs.k8s.io/core:/stable:/v${K8S_MINOR}/deb/ /
EOF

apt update
apt install -y kubeadm=${K8S_VERSION}* kubelet=${K8S_VERSION}* kubectl=${K8S_VERSION}*
apt-mark hold kubelet kubeadm kubectl

log "Enable services"
systemctl enable multipathd
systemctl enable open-iscsi
