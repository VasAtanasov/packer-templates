title: docker-host Variant Support Matrix
version: 0.1.0
status: Active
scope: OS support and script layout for docker-host variant

# docker-host Variant Support

This document lists the supported OS families and describes the script layout for the `docker-host` variant.

## Layout

```
variants/docker-host/
└── debian/                      # Debian/Ubuntu-specific scripts
    ├── install_docker.sh
    └── configure_docker.sh
```

RHEL family scripts will be added under `variants/docker-host/rhel/` in a future phase if needed.

## Supported OS Families

- Debian family: Debian 12, Debian 13 (x86_64, aarch64)
- Ubuntu family: Planned
- RHEL family (RHEL/AlmaLinux/Rocky): Planned

Packer selects OS-specific scripts at build time using a computed `os_family` derived from `os_name`.

## Environment Variables

- `LIB_DIR=/usr/local/lib/k8s`
- `LIB_CORE_SH=/usr/local/lib/k8s/scripts/_common/lib-core.sh`
- `LIB_OS_SH=/usr/local/lib/k8s/scripts/_common/lib-debian.sh` (Debian) or `lib-rhel.sh` (RHEL)
- `VARIANT=docker-host`

## Notes

- Scripts are uploaded once to `/usr/local/lib/k8s/scripts/` and invoked from there to survive reboots/cleanup.
- All scripts are idempotent and source both `lib-core.sh` and the OS-specific library via `LIB_OS_SH`.

## Doc Changelog

| Version | Date       | Changes                                      |
|---------|------------|----------------------------------------------|
| 0.1.0   | 2025-11-14 | Initial support matrix and layout structure. |

