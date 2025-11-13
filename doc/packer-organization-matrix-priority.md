title: Packer Template Organization by Matrix Priority
version: 1.0.0
status: Draft
scope: Organization of Packer templates and scripts by Provider→OS→Arch→Variant across the repo

# Packer Template Organization by Matrix Priority

Key insight: prioritize dimensions by how fundamentally they differ at build time, and reflect that in the repository layout and composition.

- FUNDAMENTAL ← Provider (builder type differs)
- MODERATE    ← OS (installer and OS scripts differ)
- MINOR       ← Architecture (parameters differ)
- MINIMAL     ← Variant (conditional provisioning)

Organization rule:
- Split directories for Provider.
- Split files for OS.
- Use variables and locals for Arch and Variant.

This document shows a Packer‑valid HCL2 structure that scales across providers while keeping files small and composition explicit.

## Top‑Level Layout

```
packer_templates/
  providers/
    virtualbox/
    vmware/
    qemu/
  scripts/
    _common/
    debian/
    ubuntu/
    providers/
      virtualbox/
      vmware/
      qemu/
    variants/
      k8s-node/
      docker-host/
  pkr-plugins.pkr.hcl   # canonical plugin pins (symlinked into each provider dir)

os_pkrvars/
  debian-12-x86_64.pkrvars.hcl
  debian-12-aarch64.pkrvars.hcl
  debian-13-x86_64.pkrvars.hcl
  debian-13-aarch64.pkrvars.hcl
  ...
```

Notes
- Provider directories are Packer working directories; run `packer init/build` from there.
- OS differences live in separate source files under each provider.
- Arch and Variant are expressed as variables and used to select/compose behavior.

## Inside a Provider Directory (example: VirtualBox)

```
packer_templates/providers/virtualbox/
  pkr-plugins.pkr.hcl      # symlink to ../../pkr-plugins.pkr.hcl
  variables.pkr.hcl        # shared variables (os_name, os_version, os_arch, variant)
  locals-scripts.pkr.hcl   # ordered script lists per phase, keyed by OS/variant
  locals-arch.pkr.hcl      # arch/provider defaults (efi/BIOS, chipset, vboxmanage)
  build.pkr.hcl            # provider-specific build block(s)
  sources/
    debian.pkr.hcl         # Debian sources (12/13 × arches)
    ubuntu.pkr.hcl         # Ubuntu sources (24.x × arches)
```

### Sources split by OS (example)

File: `packer_templates/providers/virtualbox/sources/debian.pkr.hcl`

```hcl
source "virtualbox-iso" "debian-12-x86_64" {
  # ISO, checksum, boot_command, guest_os_type, communicator, ssh, shutdown, http_directory, etc.
}

source "virtualbox-iso" "debian-12-aarch64" {
  # aarch64-specific ISO + firmware assumptions
}

source "virtualbox-iso" "debian-13-x86_64" {
  # Debian 13 x86_64 specifics
}

source "virtualbox-iso" "debian-13-aarch64" {
  # Debian 13 aarch64 specifics
}
```

Add Ubuntu by creating `sources/ubuntu.pkr.hcl` with analogous sources (e.g., `ubuntu-24-x86_64`).

### Build (provider‑scoped; OS via files, arch/variant via vars)

File: `packer_templates/providers/virtualbox/build.pkr.hcl`

```hcl
build {
  # Reference all relevant sources for this provider; filter at runtime with -only
  sources = [
    "source.virtualbox-iso.debian-12-x86_64",
    "source.virtualbox-iso.debian-12-aarch64",
    "source.virtualbox-iso.debian-13-x86_64",
    "source.virtualbox-iso.debian-13-aarch64",
    # Add ubuntu sources as needed
  ]

  # Phase 1: system preparation
  provisioner "shell" {
    scripts = local.phase1[var.os_name]
    environment_vars = local.prov_env
  }

  # Phase 2: provider deps + base OS config + variant overlay
  provisioner "shell" {
    scripts = local.phase2_provider
    environment_vars = local.prov_env
  }

  provisioner "shell" {
    scripts = local.phase2_base[var.os_name] ++ local.phase2_variant[var.variant]
    environment_vars = local.prov_env
  }

  # Phase 3: cleanup & minimize
  provisioner "shell" {
    scripts = local.phase3[var.os_name]
    environment_vars = local.prov_env
  }

  post-processor "manifest" {
    output = "manifest.json"
  }
}
```

You may also split provider-specific differences into separate `build {}` blocks if that reads clearer. Both patterns are valid.

### Locals for scripts and environment

File: `packer_templates/providers/virtualbox/locals-scripts.pkr.hcl`

```hcl
locals {
  prov_env = {
    LIB_DIR = "/usr/local/lib/k8s"
    LIB_SH  = "/usr/local/lib/k8s/scripts/_common/lib.sh"
  }

  # Phase 1: OS update, may reboot
  phase1 = {
    debian = ["../../scripts/_common/update_packages.sh"]
    ubuntu = ["../../scripts/_common/update_packages.sh"]
  }

  # Phase 2a/2b: provider dependencies + integration
  phase2_provider = [
    "../../scripts/providers/virtualbox/install_dependencies.sh",
    "../../scripts/providers/virtualbox/guest_additions.sh",
  ]

  # Phase 2c: base OS configuration
  phase2_base = {
    debian = [
      "../../scripts/debian/sshd.sh",
      "../../scripts/debian/vagrant.sh",
      "../../scripts/debian/systemd_debian.sh",
    ]
    ubuntu = [
      "../../scripts/ubuntu/sshd.sh",
      "../../scripts/ubuntu/vagrant.sh",
      "../../scripts/ubuntu/systemd_ubuntu.sh",
    ]
  }

  # Phase 2d: variant overlay
  phase2_variant = {
    base        = []
    k8s-node    = [
      "../../scripts/variants/k8s-node/prepare.sh",
      "../../scripts/variants/k8s-node/containerd/install.sh",
      "../../scripts/variants/k8s-node/install_kubernetes.sh",
      "../../scripts/variants/k8s-node/configure_networking.sh",
    ]
    docker-host = [
      "../../scripts/variants/docker-host/install_docker.sh",
      "../../scripts/variants/docker-host/configure_docker.sh",
    ]
  }

  # Phase 3: cleanup and minimization
  phase3 = {
    debian = [
      "../../scripts/debian/cleanup.sh",
      "../../scripts/_common/minimize.sh",
    ]
    ubuntu = [
      "../../scripts/ubuntu/cleanup.sh",
      "../../scripts/_common/minimize.sh",
    ]
  }
}
```

### Arch defaults (variables + maps)

File: `packer_templates/providers/virtualbox/locals-arch.pkr.hcl`

```hcl
locals {
  # Example: VBoxManage defaults by arch
  vboxmanage_defaults = {
    x86_64  = [["modifyvm","{{.Name}}","--chipset","ich9"],["modifyvm","{{.Name}}","--storagectl","SATA"]]
    aarch64 = [["modifyvm","{{.Name}}","--chipset","armv8virtual"],["modifyvm","{{.Name}}","--firmware","efi"]]
  }
}
```

Use these locals in your source definitions as needed (e.g., `vboxmanage = local.vboxmanage_defaults["${var.os_arch}"]`).

### Variables

File: `packer_templates/providers/virtualbox/variables.pkr.hcl`

```hcl
variable "os_name" {
  type        = string
  description = "OS family (debian, ubuntu)"
  validation {
    condition     = contains(["debian","ubuntu"], var.os_name)
    error_message = "os_name must be debian or ubuntu."
  }
}

variable "os_version" {
  type        = string
  description = "OS version (e.g., 12, 13, 24.04)"
}

variable "os_arch" {
  type        = string
  description = "Architecture (x86_64 or aarch64)"
  validation {
    condition     = contains(["x86_64","aarch64"], var.os_arch)
    error_message = "os_arch must be x86_64 or aarch64."
  }
}

variable "variant" {
  type        = string
  default     = "base"
  description = "Variant: base, k8s-node, docker-host"
  validation {
    condition     = contains(["base","k8s-node","docker-host"], var.variant)
    error_message = "variant must be base, k8s-node, or docker-host."
  }
}
```

OS/arch‑specific ISO inputs belong in `os_pkrvars/*.pkrvars.hcl` and are passed with `-var-file`.

## Scripts Layout

```
packer_templates/scripts/
  _common/                      # update_packages.sh, minimize.sh, lib.sh
  debian/                       # sshd.sh, vagrant.sh, cleanup.sh, systemd_debian.sh
  ubuntu/                       # sshd.sh, vagrant.sh, cleanup.sh, systemd_ubuntu.sh
  providers/
    virtualbox/                 # install_dependencies.sh, guest_additions.sh
    vmware/                     # tools install, deps
    qemu/                       # guest agent, deps
  variants/
    k8s-node/                   # prepare.sh, containerd/install.sh, install_kubernetes.sh, configure_networking.sh
    docker-host/                # install_docker.sh, configure_docker.sh
```

All scripts should `source "$LIB_SH"` and follow the 3‑phase model. Use the persistent library pattern (`LIB_DIR`, `LIB_SH`) during provisioning.

## Naming and Selection

- Source names: `<os>-<version>-<arch>`; provider is encoded in the source type.
  - Example: `source "virtualbox-iso" "debian-12-x86_64" { ... }`
- Select provider × OS × arch with `-only`:
  - `-only=virtualbox-iso.debian-12-x86_64`
- Select variant via variable (default `base`), affecting script lists in locals:
  - `-var variant=k8s-node`

## Build Commands (examples)

From provider directory (VirtualBox):

```
packer init packer_templates/providers/virtualbox

# Debian 12 x86_64 base
packer build \
  -only=virtualbox-iso.debian-12-x86_64 \
  -var-file=os_pkrvars/debian-12-x86_64.pkrvars.hcl \
  -var variant=base \
  packer_templates/providers/virtualbox

# Debian 12 aarch64 k8s-node
packer build \
  -only=virtualbox-iso.debian-12-aarch64 \
  -var-file=os_pkrvars/debian-12-aarch64.pkrvars.hcl \
  -var variant=k8s-node \
  packer_templates/providers/virtualbox
```

## CI and Make/Rake Integration

- Dimensions: `OS={debian-12,debian-13,ubuntu-24}`, `ARCH={x86_64,aarch64}`, `PROVIDER={virtualbox,vmware,qemu}`, `VARIANT={base,k8s-node,docker-host}`.
- For each tuple:
  - Resolve `-only=<provider-type>.<os>-<version>-<arch>`.
  - Resolve `-var-file=os_pkrvars/<os>-<version>-<arch>.pkrvars.hcl`.
  - Pass `-var variant=<variant>` and the provider working directory.
- Keep Makefile/Rakefile parity for all targets.

## Packer HCL Composition Notes

- Packer does not support `import`/modules; it loads all `.pkr.hcl` files in the working directory only.
- Provisioners must be declared inside a `build {}` block.
- `*.auto.pkrvars.hcl` auto‑loads only from the working directory.
- Keep `pkr-plugins.pkr.hcl` in each provider directory (or symlink) to pin plugin versions consistently.

## Migration Outline

1) Extract sources per provider into `providers/<provider>/sources/<os>.pkr.hcl`.
2) Move provider build logic to `providers/<provider>/build.pkr.hcl`.
3) Add `variables.pkr.hcl`, `locals-scripts.pkr.hcl`, and optional `locals-arch.pkr.hcl` per provider.
4) Restructure scripts into `scripts/{_common,os,providers,variants}`; update locals paths accordingly.
5) Update Make/Rake targets to run `init/build` from provider directories and to pass OS var files and variant.
6) Validate and build one known cell (`debian-12-x86_64@virtualbox#base`) before expanding the matrix.

## Doc Changelog

| Version | Date       | Changes                                                                      |
|---------|------------|-------------------------------------------------------------------------------|
| 1.0.0   | 2025-11-13 | Initial guidance: provider dirs, OS files, arch/variant via vars; examples. |

