# K8s Variant Scripts - Automated Testing

This directory provides automated testing of K8s variant scripts on a base Debian box without requiring a full Packer rebuild.

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
cd test/k8s-automated
vagrant up
```

This will:
1. Start a Debian 12 base box
2. Sync the scripts from `packer_templates/scripts`
3. Automatically run all K8s variant scripts in order
4. Display verification results

### Test script changes

After modifying scripts on your host machine:

```bash
# Scripts are automatically synced via VirtualBox shared folders
# Just re-provision to run updated scripts
vagrant provision
```

### SSH into the VM

```bash
vagrant ssh
```

### Clean up

```bash
vagrant destroy -f
```

## What Gets Tested

1. **prepare.sh** - Swap disabling, kernel modules, sysctl
2. **configure_kernel.sh** - Kernel parameters
3. **install_container_runtime.sh** - containerd installation
4. **install_kubernetes.sh** - kubeadm, kubelet, kubectl
5. **configure_networking.sh** - Network configuration

## Verification

The provisioner automatically verifies:
- ✅ Kubernetes component versions
- ✅ Container runtime status
- ✅ Kernel modules loaded
- ✅ Sysctl parameters
- ✅ Swap status

## Notes

- Uses 4GB RAM and 2 CPUs (adjust in Vagrantfile if needed)
- Scripts are synced via VirtualBox shared folders (Windows compatible)
- Environment variables match Packer configuration
- Full script output is visible during provisioning
- Script changes on host are automatically reflected in the VM
