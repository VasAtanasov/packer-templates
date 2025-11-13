# Docker Variant Scripts - Automated Testing

This directory provides automated testing of Docker variant scripts on a base Debian box without requiring a full Packer rebuild.

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
cd test/docker-automated
vagrant up
```

This will:
1. Start a Debian 12 base box
2. Sync the scripts from `packer_templates/scripts`
3. Automatically run all Docker variant scripts in order
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

# Test Docker as vagrant user
docker run --rm hello-world
docker compose version
```

### Clean up

```bash
vagrant destroy -f
```

## What Gets Tested

1. **install_docker.sh** - Docker Engine, CLI, containerd, buildx, compose plugins
2. **configure_docker.sh** - daemon.json, logging, systemd limits

## Verification

The provisioner automatically verifies:
- ✅ Docker version
- ✅ Docker Compose version
- ✅ Docker service status
- ✅ Storage driver configuration
- ✅ Vagrant user in docker group
- ✅ Docker daemon configuration
- ✅ Basic Docker functionality (hello-world)

## Notes

- Uses 2GB RAM and 2 CPUs (adjust in Vagrantfile if needed)
- Scripts are synced via VirtualBox shared folders (Windows compatible)
- Environment variables match Packer configuration
- The vagrant user is added to the docker group (passwordless docker commands)
- Full script output is visible during provisioning
- Script changes on host are automatically reflected in the VM

## Common Commands

```bash
# Check Docker installation
docker version
docker info

# Test Docker Compose
docker compose version

# Run a test container
docker run --rm alpine echo "Hello from Docker!"

# View Docker logs
sudo journalctl -u docker -n 50

# Check daemon configuration
cat /etc/docker/daemon.json
```
