title: Packer/Vagrant Helper Commands
version: 1.0.0
status: Active
scope: Common Packer/Make/Rake/Vagrant commands for local box builds

---

This document collects frequently used commands for building Packer boxes and adding them to the local Vagrant box repository. Commands are grouped for Windows/PowerShell (Rake) and Linux/WSL (Make).

## Windows / PowerShell (Rake)

> Assumes you run these from the repo root in PowerShell.

### 1. Build Debian 12 base box (from ISO)

```powershell
rake debian_12
```

### 2. Build Debian 12 k8s-node from existing OVF

Kubernetes version is taken from `K8S_VERSION` (used both for install and box naming).

```powershell
rake debian_12_k8s_ovf K8S_VERSION=1.33.3
```

Resulting box file:

```text
builds\build_complete\debian-12.12-x86_64-k8s-node-1.33.3.virtualbox.box
```

### 3. Generate Vagrant metadata JSON (version = K8S_VERSION)

This creates a metadata file that tells Vagrant to use the Kubernetes version as the box version.

```powershell
rake vagrant_metadata `
  TEMPLATE=debian/12-x86_64.pkrvars.hcl `
  VARIANT=k8s-node `
  K8S_VERSION=1.33.3
```

Resulting metadata file:

```text
builds\build_complete\debian-12.12-x86_64-k8s-node-1.33.3.json
```

### 4. Add the box to local Vagrant with version 1.33.3

Run from the `builds\build_complete` directory so the relative URL in metadata resolves correctly:

```powershell
Set-Location C:\Users\v.atanasov\softuni\packer\builds\build_complete

vagrant box add .\debian-12.12-x86_64-k8s-node-1.33.3.json
```

Vagrant will register the box as:

- Name: `debian-12.12-x86_64-k8s-node`
- Version: `1.33.3`

### 5. Optional: add with custom name but same version

```powershell
rake vagrant_metadata `
  TEMPLATE=debian/12-x86_64.pkrvars.hcl `
  VARIANT=k8s-node `
  K8S_VERSION=1.33.3 `
  BOX_NAME=debian-12-k8s-node `
  BOX_VERSION=1.33.3

Set-Location C:\Users\v.atanasov\softuni\packer\builds\build_complete

vagrant box add .\debian-12-k8s-node-1.33.3.json
```

In your `Vagrantfile`:

```ruby
config.vm.box = "debian-12-k8s-node"
config.vm.box_version = "1.33.3"
```

## Linux / WSL (Make)

> Assumes you run these from the repo root in a Bash shell.

### 1. Build Debian 12 base box (from ISO)

```bash
make debian-12
```

### 2. Build Debian 12 k8s-node from existing OVF

```bash
K8S_VERSION=1.33.3 make debian-12-k8s-ovf
```

### 3. Generate Vagrant metadata JSON (version = K8S_VERSION)

```bash
K8S_VERSION=1.33.3 make vagrant-metadata \
  TEMPLATE=debian/12-x86_64.pkrvars.hcl \
  VARIANT=k8s-node
```

### 4. Add the box using metadata

```bash
cd builds/build_complete
vagrant box add ./debian-12.12-x86_64-k8s-node-1.33.3.json
```

## AlmaLinux 9 k8s-node (PowerShell)

Build from existing OVF:

```powershell
rake almalinux_9_k8s_ovf K8S_VERSION=1.33.3
```

Generate metadata JSON (version = `K8S_VERSION`):

```powershell
rake vagrant_metadata `
  TEMPLATE=almalinux/9-x86_64.pkrvars.hcl `
  VARIANT=k8s-node `
  K8S_VERSION=1.33.3
```

Add to Vagrant (run from `builds\build_complete`):

```powershell
Set-Location C:\Users\v.atanasov\softuni\packer\builds\build_complete

vagrant box add .\almalinux-9.6-x86_64-k8s-node-1.33.3.json
```

## Doc Changelog

| Version | Date       | Changes                                                               |
|---------|------------|-----------------------------------------------------------------------|
| 1.0.0   | 2025-11-19 | Added initial helper commands for Packer/Make/Rake/Vagrant workflows. |
