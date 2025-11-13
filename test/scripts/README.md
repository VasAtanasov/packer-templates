---
title: Bash Script Tests
version: 1.1.0
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
- Sets test environment variables:
  - `SCRIPTS_DIR=/scripts` - Location of provisioning scripts
  - `LIB_SH=/usr/local/lib/k8s/lib.sh` - Path to lib.sh
  - `LIB_DIR=/usr/local/lib/k8s` - Library directory
- Runs all tests under `tests/`

## Doc Changelog

| Version | Date       | Changes                                                       |
|---------|------------|---------------------------------------------------------------|
| 1.1.0   | 2025-11-13 | Added environment variables for flexible script path testing |
| 1.0.0   | 2025-11-13 | Initial testing instructions                                  |

