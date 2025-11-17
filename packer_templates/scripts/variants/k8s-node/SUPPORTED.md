title: k8s-node Variant Support Matrix
version: 0.1.0
status: Active
scope: OS support and script layout for k8s-node variant

# k8s-node Variant Support

This document lists the supported OS families and describes the script layout for the `k8s-node` variant.

## Layout

```
variants/k8s-node/
├── common/                     # OS-agnostic scripts
│   ├── prepare.sh
│   ├── configure_kernel.sh
│   └── configure_networking.sh
├── debian/                     # Debian/Ubuntu-specific scripts
│   ├── install_container_runtime.sh
│   └── install_kubernetes.sh
└── rhel/                       # RHEL/AlmaLinux/Rocky-specific scripts
    ├── install_container_runtime.sh
    ├── install_kubernetes.sh
    └── cleanup_k8s.sh
```

## Supported OS Families

- Debian family: Debian 12, Debian 13 (x86_64, aarch64)
- Ubuntu family: Planned
- RHEL family (RHEL/AlmaLinux/Rocky): Implemented (containerd, docker via cri-dockerd)

Packer selects the appropriate OS-specific scripts at build time using a computed `os_family` derived from `os_name`.

## Environment Variables

- `LIB_DIR=/usr/local/lib/scripts`
- `LIB_CORE_SH=/usr/local/lib/scripts/_common/lib-core.sh`
- `LIB_OS_SH=/usr/local/lib/scripts/_common/lib-debian.sh` (Debian) or `lib-rhel.sh` (RHEL)
- `K8S_VERSION` (e.g., `1.28`)
- `CONTAINER_RUNTIME` (`containerd` or `cri-o`)
- `CRIO_VERSION` (e.g., `1.28`, when `CONTAINER_RUNTIME=cri-o`)

## Notes

- Scripts are uploaded once to `/usr/local/lib/scripts/` and invoked from there to survive reboots/cleanup.
- All scripts are idempotent and source both `lib-core.sh` and the OS-specific library via `LIB_OS_SH`.

## Doc Changelog

| Version | Date       | Changes                                      |
|---------|------------|----------------------------------------------|
| 0.2.0   | 2025-11-17 | Add RHEL-family implementation (containerd runtime).   |
| 0.1.0   | 2025-11-14 | Initial support matrix and layout structure.           |
