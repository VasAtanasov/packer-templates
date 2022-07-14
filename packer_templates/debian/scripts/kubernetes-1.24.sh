#!/bin/sh -eux

KUBERNETES_VERSION="1.24.2-00"

echo 'Common setup for all servers (Control Plane and Nodes)'

echo $KUBERNETES_VERSION > /tmp/k8s-version

echo 'Create the .conf file to load the modules at boot ...'
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# Apply sysctl params without reboot
sysctl --system

echo '* Turn off the swap ...'
swapoff -a
sed -i '/swap/ s/^/#/' /etc/fstab

pre_reqs="apt-transport-https ca-certificates curl"

echo "Updateing the apt package index and install packages to allow apt to use a repository over HTTPS"

apt-get update -qq >/dev/null
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $pre_reqs

echo '* Download and install the Kubernetes repository key ...'
curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg

echo '* Add the Kubernetes repository ...'
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list

echo "* Install the selected ($KUBERNETES_VERSION) version ..."
apt-get update -qq >/dev/null
if [ "$KUBERNETES_VERSION" != 'latest' ]; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq kubelet="$KUBERNETES_VERSION" kubectl="$KUBERNETES_VERSION" kubeadm="$KUBERNETES_VERSION"
else
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq kubelet kubeadm kubectl
fi

echo '* Exclude the Kubernetes packages from being updated ...'
apt-mark hold kubelet kubeadm kubectl