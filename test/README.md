# Variant Script Testing with Vagrant

This directory provides multiple approaches to test variant scripts without requiring full Packer rebuilds.

## Directory Structure

```
test/
├── k8s-automated/       # K8s variant - automated testing
├── k8s-interactive/     # K8s variant - interactive testing
├── docker-automated/    # Docker variant - automated testing
├── docker-interactive/  # Docker variant - interactive testing
└── README.md           # This file
```

## Testing Approaches

### Option 1: Automated Testing (Faster Feedback)

**Purpose**: Run all variant scripts automatically and see results immediately.

**Use when**:
- Testing the complete script sequence
- Validating scripts after changes
- Quick smoke testing before Packer builds

**Directories**:
- `k8s-automated/` - Tests all K8s scripts in sequence
- `docker-automated/` - Tests all Docker scripts in sequence

**Usage**:
```bash
cd k8s-automated/      # or docker-automated/
vagrant up             # Runs all scripts automatically
vagrant provision      # Re-run after script changes
vagrant ssh            # Explore the configured system
```

### Option 2: Interactive Testing (Best for Development)

**Purpose**: Run scripts manually, one at a time, for step-by-step debugging.

**Use when**:
- Developing new scripts
- Debugging script failures
- Understanding what each script does
- Testing script idempotency

**Directories**:
- `k8s-interactive/` - Manual K8s script testing
- `docker-interactive/` - Manual Docker script testing

**Usage**:
```bash
cd k8s-interactive/        # or docker-interactive/
vagrant up
vagrant ssh
sudo -i
source /scripts/test-env.sh
# Run scripts one by one
bash /usr/local/lib/k8s/scripts/variants/k8s-node/prepare.sh
```

## Prerequisites

### Windows Compatibility

All test environments use VirtualBox shared folders and are **fully compatible with Windows**. No additional tools (like rsync) are required.

### Base Box Required

Before using any test environment, you need a base Debian box:

### Option A: Build from this repository

```bash
# From repository root
make debian-12
vagrant box add --name debian-12 builds/build_complete/debian-12.12-x86_64.virtualbox.box
```

### Option B: Use existing Debian box

If you already have a Debian 12 box in Vagrant:

```bash
# List available boxes
vagrant box list

# Use your existing box name in test Vagrantfiles
# Edit Vagrantfile: config.vm.box = "your-box-name"
```

## Quick Start Guide

### Testing K8s Scripts (Automated)

```bash
cd test/k8s-automated
vagrant up
# Wait for provisioning to complete
vagrant ssh
kubeadm version  # Verify installation
```

### Testing K8s Scripts (Interactive)

```bash
cd test/k8s-interactive
vagrant up
vagrant ssh
sudo /scripts/test-env.sh
# Run scripts manually
```

### Testing Docker Scripts (Automated)

```bash
cd test/docker-automated
vagrant up
vagrant ssh
docker run --rm hello-world
```

### Testing Docker Scripts (Interactive)

```bash
cd test/docker-interactive
vagrant up
vagrant ssh
sudo /scripts/test-env.sh
# Run scripts manually
```

## Workflow Comparison

| Scenario | Recommended Approach | Time to Test |
|----------|---------------------|--------------|
| Initial script development | Interactive | ~5 min |
| Debugging script failures | Interactive | ~2 min |
| Quick validation after changes | Automated | ~10 min |
| Full integration testing | Automated | ~15 min |
| Testing idempotency | Interactive | ~5 min |
| Before Packer build | Automated | ~10 min |

Compare to full Packer build: ~30-45 minutes

## Testing Best Practices

1. **Start with base box** - Always test on a clean base box
2. **Test idempotency** - Run scripts multiple times
3. **Verify each step** - Check system state after each script
4. **Use snapshots** - Take VirtualBox snapshots before destructive tests
5. **Clean up** - Use `vagrant destroy` to start fresh

## Common Commands

```bash
# Create/start VM
vagrant up

# Re-run provisioning
vagrant provision

# SSH into VM
vagrant ssh

# Suspend VM (faster than destroy)
vagrant suspend
vagrant resume

# Destroy VM
vagrant destroy -f

# Check VM status
vagrant status

# Reload VM (if shared folders not updating)
vagrant reload
```

## Troubleshooting

### VM won't start
```bash
vagrant destroy -f
vagrant up
```

### Scripts not syncing
```bash
# Scripts should sync automatically via VirtualBox shared folders
vagrant reload       # Restart VM to refresh synced folders
```

### Need to test from scratch
```bash
vagrant destroy -f
rm -rf .vagrant
vagrant up
```

### Permission errors in VM
```bash
# Inside VM
sudo chown -R root:root /usr/local/lib/k8s
sudo chmod -R 0755 /usr/local/lib/k8s/scripts
```

## Tips

- **Automated tests**: Use when you want quick feedback on the full script sequence
- **Interactive tests**: Use when developing or debugging individual scripts
- **Keep VMs running**: Use `vagrant suspend` instead of `destroy` during active development
- **Edit on host**: Scripts sync automatically - edit on your host machine, test in VM
- **Use make**: Run `make validate` before testing to catch HCL syntax errors early

## Related Documentation

- See individual README files in each test directory for detailed usage
- Main documentation: `CLAUDE.md` in repository root
- Script guidelines: `packer_templates/scripts/AGENTS.md`
- Variant documentation: `packer_templates/scripts/AGENTS.md` (Variant Pattern section)
