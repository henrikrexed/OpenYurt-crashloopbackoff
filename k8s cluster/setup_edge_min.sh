#!/bin/bash -e
swapoff -a
sed -i '/ swap / Ys/^\(.*\)$/#\1/g' /etc/fstab



modprobe overlay
modprobe br_netfilter
echo -e "Install containerd..."

sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y containerd.io

# Configure cgroup drivers
# https://kubernetes.io/docs/setup/production-environment/container-runtimes/#systemd-cgroup-driver
cat <<EOF | sudo tee /etc/containerd/config.toml
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

# Configure crictl
cat <<EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF

# Installing kubeadm, kubelet, kubectl and cni-plugin
# Ref: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl
echo -e "Install kubeadm and others..."
sudo apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
# If the directory `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
# sudo mkdir -p -m 755 /etc/apt/keyrings
c

sudo modprobe overlay
sudo modprobe br_netfilter


sudo sysctl --system

# Install tools
echo -e "Install utility tools..."

sudo apt-get install software-properties-common

sudo add-apt-repository -y ppa:rmescandon/yq
sudo apt update
sudo apt install -y yq

# Reload configuration and Restart daemon
echo -e "Reload and Restart daemons..."
sudo sysctl -p
sudo systemctl daemon-reload
sudo systemctl restart containerd


echo -e "Setup has been completed."

# Version info
echo -e "\n- containerd:"
containerd -v

echo -e "\n- runc:"
runc --version

