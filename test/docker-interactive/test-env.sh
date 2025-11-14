#!/bin/bash
#
# Helper script to set up Docker testing environment
# Usage: sudo /scripts/test-env.sh
#        source /scripts/test-env.sh  (to set env vars in current shell)
#

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

echo -e "${GREEN}=================================================="
echo "Docker Variant Script Testing Environment"
echo -e "==================================================${RESET}"
echo ""

# Set environment variables (same as Packer)
export LIB_DIR=/usr/local/lib/k8s
export LIB_CORE_SH=/usr/local/lib/k8s/scripts/_common/lib-core.sh
export LIB_OS_SH=/usr/local/lib/k8s/scripts/_common/lib-debian.sh
export OS_FAMILY=debian
export VARIANT="docker-host"
export DEBIAN_FRONTEND=noninteractive

echo -e "${BLUE}Environment variables set:${RESET}"
echo "  LIB_DIR=$LIB_DIR"
echo "  LIB_CORE_SH=$LIB_CORE_SH"
echo "  LIB_OS_SH=$LIB_OS_SH"
echo "  VARIANT=$VARIANT"
echo ""

# Install scripts to persistent location if not already done
if [ ! -d "/usr/local/lib/k8s/scripts" ]; then
    echo -e "${YELLOW}Installing scripts to ${LIB_DIR}...${RESET}"
    mkdir -p /usr/local/lib/k8s
    cp -r /scripts /usr/local/lib/k8s/scripts
    chmod -R 0755 /usr/local/lib/k8s/scripts
    find /usr/local/lib/k8s/scripts -type f -name '*.sh' -exec chmod 0755 {} \;
    chown -R root:root /usr/local/lib/k8s
    echo -e "${GREEN}✓ Scripts installed${RESET}"
else
    echo -e "${GREEN}✓ Scripts already installed${RESET}"
fi

echo ""
echo -e "${BLUE}Available Docker variant scripts:${RESET}"
echo "  1. ${LIB_DIR}/scripts/variants/docker-host/${OS_FAMILY}/install_docker.sh"
echo "  2. ${LIB_DIR}/scripts/variants/docker-host/${OS_FAMILY}/configure_docker.sh"
echo ""

echo -e "${BLUE}Quick commands:${RESET}"
echo "  # Run scripts one by one:"
echo "  bash ${LIB_DIR}/scripts/variants/docker-host/${OS_FAMILY}/install_docker.sh"
echo "  bash ${LIB_DIR}/scripts/variants/docker-host/${OS_FAMILY}/configure_docker.sh"
echo ""
echo "  # Or run all at once:"
echo "  bash ${LIB_DIR}/scripts/variants/docker-host/${OS_FAMILY}/install_docker.sh && \\"
echo "  bash ${LIB_DIR}/scripts/variants/docker-host/${OS_FAMILY}/configure_docker.sh"
echo ""

echo -e "${BLUE}Verification commands:${RESET}"
echo "  docker --version"
echo "  docker compose version"
echo "  systemctl status docker"
echo "  docker info"
echo "  cat /etc/docker/daemon.json"
echo ""
echo "  # Test as vagrant user (after logout/login):"
echo "  su - vagrant -c 'docker run --rm hello-world'"
echo ""

echo -e "${GREEN}Environment ready! Run scripts as needed.${RESET}"
