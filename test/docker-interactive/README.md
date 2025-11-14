# Docker Variant Scripts - Interactive Testing

This directory provides an interactive testing environment for Docker variant scripts. Perfect for step-by-step debugging and script development.

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
cd test/docker-interactive
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
- Set all required environment variables (LIB_DIR, LIB_CORE_SH, LIB_OS_SH, VARIANT, etc.)
- Install scripts to `/usr/local/lib/k8s/scripts/`
- Display available scripts and commands

### Run scripts step-by-step

```bash
# Run each script individually
bash /usr/local/lib/k8s/scripts/variants/docker-host/debian/install_docker.sh
bash /usr/local/lib/k8s/scripts/variants/docker-host/debian/configure_docker.sh
```

### Verify after each step

```bash
# After install_docker.sh
docker --version
docker compose version
systemctl status docker

# Check vagrant user can use docker (may need logout/login)
su - vagrant -c "docker run --rm hello-world"

# After configure_docker.sh
cat /etc/docker/daemon.json
docker info | grep -E "(Storage Driver|Logging Driver)"
```

### Test script modifications

1. Edit scripts on your host machine in `packer_templates/scripts/variants/docker-host/`
2. Scripts are automatically synced to `/scripts/` in the VM
3. Re-run the modified script:
   ```bash
   # Copy updated script
   cp /scripts/variants/docker-host/debian/install_docker.sh /usr/local/lib/k8s/scripts/variants/docker-host/debian/

   # Re-run it
   bash /usr/local/lib/k8s/scripts/variants/docker-host/debian/install_docker.sh
   ```

### Run all scripts at once

```bash
bash /usr/local/lib/k8s/scripts/variants/docker-host/debian/install_docker.sh
bash /usr/local/lib/k8s/scripts/variants/docker-host/debian/configure_docker.sh
```

### Test Docker as non-root

```bash
# Exit root shell
exit

# Logout and login again (for group membership)
exit
vagrant ssh

# Test Docker
docker run --rm alpine echo "Hello from Docker!"
docker compose version
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
- `VARIANT="docker-host"`
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
3. **Check logs** - Use `journalctl -u docker -xe` to debug Docker issues
4. **Test idempotency** - Run scripts multiple times to ensure they're idempotent
5. **Group membership** - Remember to logout/login after adding user to docker group

## Common Docker Tests

```bash
# Test basic functionality
docker run --rm alpine echo "Hello!"

# Test Docker Compose
echo 'services:
  test:
    image: alpine
    command: echo "Hello from Compose!"' > docker-compose.yml
docker compose up

# Test image building
echo 'FROM alpine
CMD echo "Hello from build!"' > Dockerfile
docker build -t test .
docker run --rm test

# Check resource limits
docker run --rm alpine sh -c "ulimit -n"

# View daemon configuration
docker info
```
