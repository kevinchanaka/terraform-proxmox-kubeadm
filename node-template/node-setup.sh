#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[node-setup] $1"
}


if [[ "$UID" -ne 0 ]]; then
  echo "Must be run as root"
  exit 1
fi

log "Starting node setup"

log "Disabling swap"
sed -i '/^[^#].*\s\+swap\s\+/ s/^/# /' /etc/fstab

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
  apt-transport-https \
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
mkdir -p /etc/kubernetes
mkdir -p /etc/containerd/
mkdir -p /opt/cni/bin/

log "Installing containerd"
apt install -y containerd

log "Configuring containerd"
mkdir -p /etc/containerd

cat > /etc/containerd/config.toml <<EOF
version = 2
[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    [plugins."io.containerd.grpc.v1.cri".containerd]
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v2"
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            SystemdCgroup = true
EOF

systemctl enable containerd

log "Installing Kubernetes packages"

mkdir -p /etc/apt/keyrings

# These commands change based on k8s version
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg

cat > /etc/apt/sources.list.d/kubernetes.list <<EOF
deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /
EOF

apt update
apt install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

log "Installing crictl config"
cat >/etc/crictl.yaml <<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF

log "Installing multipath tools"
apt install -y multipath-tools

cat >/etc/multipath.conf <<EOF
defaults {
  user_friendly_names yes
  find_multipaths yes
}
EOF

log "Enable services"
systemctl enable kubelet
systemctl enable multipathd
systemctl enable open-iscsi