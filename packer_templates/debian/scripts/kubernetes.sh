#!/bin/sh -eux

KUBERNETES_VERSION=${KUBERNETES_VERSION:-1.23.8-00}

echo 'Common setup for all servers (Control Plane and Nodes)'

echo $KUBERNETES_VERSION > /tmp/k8s-version

echo 'Create the .conf file to load the modules at boot ...'
modprobe br_netfilter
cat <<EOF | sudo tee /etc/modules-load.d/crio.conf
br_netfilter
EOF

# Set up required sysctl params, these persist across reboots.
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system

# echo '* Install iptables and switch it iptables to legacy version ...'
# apt-get update -qq >/dev/null
# DEBIAN_FRONTEND=noninteractive apt-get install -y -qq iptables jq >/dev/null
# update-alternatives --set iptables /usr/sbin/iptables-legacy

echo '* Turn off the swap ...'
swapoff -a
sed -i '/swap/ s/^/#/' /etc/fstab

echo '* Adjust container runtime configuration ...'
cat <<EOF | tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

systemctl enable docker
systemctl daemon-reload
systemctl restart docker

echo '* Download and install the Kubernetes repository key ...'
curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg

echo '* Add the Kubernetes repository ...'
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

echo "* Install the selected ($KUBERNETES_VERSION) version ..."
apt-get update -qq >/dev/null
if [ "$KUBERNETES_VERSION" != 'latest' ]; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq kubelet="$KUBERNETES_VERSION" kubectl="$KUBERNETES_VERSION" kubeadm="$KUBERNETES_VERSION"
else
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq kubelet kubeadm kubectl
fi

echo '* Exclude the Kubernetes packages from being updated ...'
apt-mark hold kubelet kubeadm kubectl