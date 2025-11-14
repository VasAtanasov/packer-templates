# K8s Variant Scripts - Interactive Testing

This directory provides an interactive testing environment for K8s variant scripts. Perfect for step-by-step debugging and script development.

## Prerequisites

1. Build and add the base box to Vagrant:
   ```bash
   # From repository root
   make debian-12
   vagrant box add --name debian-12 builds/build_complete/debian-12.12-x86_64.virtualbox.box
   ```

2. Or use an existing Debian 12 base box.

## Usage

### Start the test VM

```bash
cd test/k8s-interactive
vagrant up
vagrant ssh
```

### Set up the environment

Inside the VM:

```bash
sudo -i
source /scripts/test-env.sh
```

This will:
- Set all required environment variables (LIB_DIR, LIB_CORE_SH, LIB_OS_SH, K8S_VERSION, etc.)
- Install scripts to `/usr/local/lib/k8s/scripts/`
- Display available scripts and commands

### Run scripts step-by-step

```bash
# Run each script individually
bash /usr/local/lib/k8s/scripts/variants/k8s-node/common/prepare.sh
bash /usr/local/lib/k8s/scripts/variants/k8s-node/common/configure_kernel.sh
bash /usr/local/lib/k8s/scripts/variants/k8s-node/debian/install_container_runtime.sh
bash /usr/local/lib/k8s/scripts/variants/k8s-node/debian/install_kubernetes.sh
bash /usr/local/lib/k8s/scripts/variants/k8s-node/common/configure_networking.sh
```

### Verify after each step

```bash
# After prepare.sh
swapon --show  # Should be empty
lsmod | grep br_netfilter

# After install_container_runtime.sh
systemctl status containerd
docker --version  # If Docker is installed

# After install_kubernetes.sh
kubeadm version
kubelet --version
kubectl version --client
```

### Test script modifications

1. Edit scripts on your host machine in `packer_templates/scripts/variants/k8s-node/`
2. Scripts are automatically synced to `/scripts/` in the VM
3. Re-run the modified script:
   ```bash
   # Copy updated script
   cp /scripts/variants/k8s-node/common/prepare.sh /usr/local/lib/k8s/scripts/variants/k8s-node/common/

   # Re-run it
   bash /usr/local/lib/k8s/scripts/variants/k8s-node/common/prepare.sh
   ```

### Run all scripts at once

```bash
bash /usr/local/lib/k8s/scripts/variants/k8s-node/common/prepare.sh
bash /usr/local/lib/k8s/scripts/variants/k8s-node/common/configure_kernel.sh
bash /usr/local/lib/k8s/scripts/variants/k8s-node/debian/install_container_runtime.sh
bash /usr/local/lib/k8s/scripts/variants/k8s-node/debian/install_kubernetes.sh
bash /usr/local/lib/k8s/scripts/variants/k8s-node/common/configure_networking.sh
```

### Clean up and restart

```bash
# Exit VM
exit

# Destroy and recreate
vagrant destroy -f
vagrant up
vagrant ssh
sudo -i
source /scripts/test-env.sh
```

## Environment Variables

The `test-env.sh` script sets these variables (same as Packer):

- `LIB_DIR=/usr/local/lib/k8s`
- `LIB_CORE_SH=/usr/local/lib/k8s/scripts/_common/lib-core.sh`
- `LIB_OS_SH=/usr/local/lib/k8s/scripts/_common/lib-debian.sh` (or `lib-rhel.sh`)
- `K8S_VERSION="1.28"`
- `CONTAINER_RUNTIME="containerd"`
- `CRIO_VERSION="1.28"`
- `VARIANT="k8s-node"`
- `DEBIAN_FRONTEND=noninteractive`

## Advantages

- ✅ **Fast iteration** - No Packer rebuild needed
- ✅ **Step-by-step debugging** - Run one script at a time
- ✅ **Inspect state** - Check system state after each script
- ✅ **Live editing** - Edit scripts on host, test immediately in VM
- ✅ **Error recovery** - Fix issues and re-run without starting over

## Tips

1. **Keep VM running** - Use `vagrant suspend` instead of `destroy` for faster restarts
2. **Snapshot before testing** - Take a VirtualBox snapshot for quick rollback
3. **Check logs** - Use `journalctl -xe` to debug service issues
4. **Test idempotency** - Run scripts multiple times to ensure they're idempotent
