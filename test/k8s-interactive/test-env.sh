#!/bin/bash
#
# Helper script to set up K8s testing environment
# Usage: sudo /scripts/test-env.sh
#        source /scripts/test-env.sh  (to set env vars in current shell)
#

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

echo -e "${GREEN}=================================================="
echo "K8s Variant Script Testing Environment"
echo -e "==================================================${RESET}"
echo ""

# Set environment variables (same as Packer)
export LIB_DIR=/usr/local/lib/scripts
export LIB_CORE_SH=/usr/local/lib/scripts/_common/lib-core.sh
export LIB_OS_SH=/usr/local/lib/scripts/_common/lib-debian.sh
export OS_FAMILY=debian
export K8S_VERSION="1.33"
export CONTAINER_RUNTIME="containerd"
export CRIO_VERSION="1.33"
export VARIANT="k8s-node"
export DEBIAN_FRONTEND=noninteractive

echo -e "${BLUE}Environment variables set:${RESET}"
echo "  LIB_DIR=$LIB_DIR"
echo "  LIB_CORE_SH=$LIB_CORE_SH"
echo "  LIB_OS_SH=$LIB_OS_SH"
echo "  K8S_VERSION=$K8S_VERSION"
echo "  CONTAINER_RUNTIME=$CONTAINER_RUNTIME"
echo "  VARIANT=$VARIANT"
echo "  OS_FAMILY=$OS_FAMILY"
echo ""

# Install scripts to persistent location if not already done
if [ ! -d "/usr/local/lib/scripts" ]; then
    echo -e "${YELLOW}Installing scripts to ${LIB_DIR}...${RESET}"
    mkdir -p /usr/local/lib/scripts
    cp -r /scripts /usr/local/lib/scripts
    chmod -R 0755 /usr/local/lib/scripts
    find /usr/local/lib/scripts -type f -name '*.sh' -exec chmod 0755 {} \;
    chown -R root:root /usr/local/lib/scripts
    echo -e "${GREEN}✓ Scripts installed${RESET}"
else
    echo -e "${GREEN}✓ Scripts already installed${RESET}"
fi

echo ""
echo -e "${BLUE}Available K8s variant scripts:${RESET}"
echo "  1. ${LIB_DIR}/scripts/variants/k8s-node/common/prepare.sh"
echo "  2. ${LIB_DIR}/scripts/variants/k8s-node/common/configure_kernel.sh"
echo "  3. ${LIB_DIR}/scripts/variants/k8s-node/${OS_FAMILY}/install_container_runtime.sh"
echo "  4. ${LIB_DIR}/scripts/variants/k8s-node/${OS_FAMILY}/install_kubernetes.sh"
echo "  5. ${LIB_DIR}/scripts/variants/k8s-node/common/configure_networking.sh"
echo ""

echo -e "${BLUE}Quick commands:${RESET}"
echo "  # Run scripts one by one:"
echo "  bash ${LIB_DIR}/scripts/variants/k8s-node/common/prepare.sh"
echo "  bash ${LIB_DIR}/scripts/variants/k8s-node/common/configure_kernel.sh"
echo "  bash ${LIB_DIR}/scripts/variants/k8s-node/${OS_FAMILY}/install_container_runtime.sh"
echo "  bash ${LIB_DIR}/scripts/variants/k8s-node/${OS_FAMILY}/install_kubernetes.sh"
echo "  bash ${LIB_DIR}/scripts/variants/k8s-node/common/configure_networking.sh"
echo ""
echo "  # Or run all at once (ordered):"
echo "  bash ${LIB_DIR}/scripts/variants/k8s-node/common/prepare.sh"
echo "  bash ${LIB_DIR}/scripts/variants/k8s-node/common/configure_kernel.sh"
echo "  bash ${LIB_DIR}/scripts/variants/k8s-node/${OS_FAMILY}/install_container_runtime.sh"
echo "  bash ${LIB_DIR}/scripts/variants/k8s-node/${OS_FAMILY}/install_kubernetes.sh"
echo "  bash ${LIB_DIR}/scripts/variants/k8s-node/common/configure_networking.sh"
echo ""

echo -e "${BLUE}Verification commands:${RESET}"
echo "  kubeadm version"
echo "  kubelet --version"
echo "  kubectl version --client"
echo "  systemctl status containerd"
echo "  lsmod | grep -E 'br_netfilter|overlay'"
echo "  swapon --show"
echo ""

echo -e "${GREEN}Environment ready! Run scripts as needed.${RESET}"
