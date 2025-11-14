---
title: Bash Script Tests
version: 1.2.0
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
- Installs modular libraries under `/usr/local/lib/k8s/scripts/_common/`:
  - `lib-core.sh` (OS-agnostic)
  - `lib-debian.sh` (APT-based)
  - `lib-rhel.sh` (DNF-based)
- Sets test environment variables:
  - `SCRIPTS_DIR=/scripts` - Location of provisioning scripts
  - `LIB_CORE_SH=/usr/local/lib/k8s/scripts/_common/lib-core.sh`
  - `LIB_OS_SH=/usr/local/lib/k8s/scripts/_common/lib-debian.sh` (or `lib-rhel.sh`)
  - `LIB_DIR=/usr/local/lib/k8s` - Library directory
- Runs all tests under `tests/`

## Doc Changelog

| Version | Date       | Changes                                                       |
|---------|------------|---------------------------------------------------------------|
| 1.2.0   | 2025-11-14 | Switched docs to modular libraries (LIB_CORE_SH, LIB_OS_SH).  |
| 1.1.0   | 2025-11-13 | Added environment variables for flexible script path testing |
| 1.0.0   | 2025-11-13 | Initial testing instructions                                  |

