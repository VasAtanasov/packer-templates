---
title: Bash Script Tests
version: 1.0.0
status: Active
scope: tests/scripts
---

# Bash Script Tests

Run integration tests for provisioning scripts inside a Vagrant VM built from this repo.

## Prerequisites
- A built box in `builds/build_complete/` (e.g., debian-12.12-x86_64.virtualbox.box)
- Added to Vagrant with a friendly name (e.g., `debian-12`)

## Run Tests

```bash
export BOX_NAME=debian-12
VAGRANT_VAGRANTFILE=Vagrantfile.test vagrant up --provision
VAGRANT_VAGRANTFILE=Vagrantfile.test vagrant destroy -f
```

## What It Does
- Installs `bats` in the VM
- Installs `lib.sh` to `/usr/local/lib/k8s/lib.sh`
- Runs all tests under `tests/scripts/`

## Doc Changelog

| Version | Date       | Changes                     |
|---------|------------|-----------------------------|
| 1.0.0   | 2025-11-13 | Initial testing instructions |

