# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog (https://keepachangelog.com/en/1.1.0/),
and this project adheres to Semantic Versioning where practical.

## [Unreleased]

### Added

- Root `AGENTS.md` refined: scope/precedence, minimum versions, HCL conventions, reproducibility, DoD, fast dev loop,
  security, and cross‑refs.
- `packer_templates/scripts/AGENTS.md` with script rules (strict mode, idempotent, root required) and skeleton (no local
  fallback).
- `os_pkrvars/AGENTS.md` for variable file guidance and examples.
- `CHANGELOG.md` following Keep a Changelog.
- Documentation standard in root `AGENTS.md` defining metadata header, SemVer for docs, per-doc changelog, and
  repo-level changelog requirements.
- New doc: `doc/packer-organization-matrix-priority.md` outlining provider directories, OS-split sources, and
  arch/variant via variables.
- Tests: `test/scripts/tests/lib_apt.bats` to validate APT helpers (TTL + invalidation, bulk installs).
- `packer_templates/scripts/variants/k8s-node/SUPPORTED.md` documenting OS support and layout.
- `packer_templates/scripts/variants/docker-host/SUPPORTED.md` documenting OS support and layout.
- Make/Rake: `validate-all`/`validate_all` target/task to validate every OS under `os_pkrvars/`, skipping OSes without matching template directories.
- AlmaLinux VirtualBox support: `packer_templates/virtualbox/almalinux/` with `sources.pkr.hcl`, `builds.pkr.hcl`,
  `pkr-plugins.pkr.hcl`, and Kickstart files under `http/rhel/` (`ks.cfg`, `8ks.cfg`).
- RHEL-family base scripts: `packer_templates/scripts/rhel/systemd.sh`, `sudoers.sh`, `networking.sh` used in AlmaLinux
  builds (Phase 2c).
- Quick build targets for AlmaLinux 8/9/10 (x86_64 + aarch64) added to Makefile and Rakefile.

### Changed

- Refactored monolithic `_common/lib.sh` into modular libraries: `_common/lib-core.sh` (OS-agnostic),
  `_common/lib-debian.sh` (Debian/Ubuntu APT), `_common/lib-rhel.sh` (AlmaLinux/Rocky DNF). All scripts now source
  `LIB_CORE_SH` + `LIB_OS_SH`.
- Packer templates updated to pass `LIB_CORE_SH` and `LIB_OS_SH` environment variables to all provisioners.
- Documentation updated (root AGENTS.md, scripts AGENTS.md, README) to reflect modular library structure and new env
  vars.
 - Providers/VirtualBox: Prepared for multi‑OS (common + per‑OS wrappers) and dynamic provider path selection in HCL.
- Tests updated to use modular libraries: Vagrantfiles and env scripts now export `LIB_CORE_SH`/`LIB_OS_SH`; Bats tests
  adjusted (`lib_apt.bats` now sources `lib-debian.sh`).
- Documentation now states Guest Additions are to be installed during provisioning.
- Host stance clarified as agnostic (no WSL2‑specific accommodations required).
- Rakefile updated to match Makefile environment checks and minimum version enforcement.
- Aligned documentation to the repo Documentation Standard (frontmatter + Doc Changelog across docs).
- Merged general Bash guidance into `packer_templates/scripts/AGENTS.md` and tailored to project.
- Docs: replaced references to `lib::apt_update_once` with `lib::ensure_apt_updated` in `AGENTS.md` and
  `packer_templates/scripts/AGENTS.md`.
- lib.sh: `lib::ensure_apt_updated` now uses TTL + repo invalidation to avoid repeated updates while guaranteeing
  freshness after adding sources.
- lib.sh: `lib::ensure_packages` performs a single bulk install after one apt cache refresh, improving performance for
  multiple packages.
- lib.sh: `lib::ensure_apt_key_from_url` now marks the cache invalidated after installing a key, ensuring the next apt
  update refreshes signatures.
- k8s-node variant scripts restructured into `common/` and `debian/` subdirectories; HCL updated to select per-OS
  scripts dynamically via `local.os_family`.
- docker-host variant scripts restructured into `debian/` subdirectory; HCL updated to select per-OS scripts via
  `local.os_family`.
- Test Vagrantfiles and helpers updated to the new k8s-node layout.
- Test Vagrantfiles and helpers updated to the new docker-host layout.
- os_pkrvars: reformatted `boot_command` in all distro var files to multi-line lists for readability (no semantic change).
- Ensure Makefile and Rakefile parity: added AlmaLinux quick build targets consistently.
 - Makefile/Rakefile: `validate` now scopes to `os_pkrvars/<TARGET_OS>` instead of all OS var files, aligning behavior with documentation (Validate current PROVIDER/TARGET_OS only).
 - Makefile/Rakefile: `validate` uses `-syntax-only` to avoid plugin/network requirements during validation (useful for CI/WSL/dev environments without initialized plugins).

### Removed

- Deleted `doc/CONTRIBUTING_BASH.md` in favor of consolidated guidance in `packer_templates/scripts/AGENTS.md`.

### Fixed

- AlmaLinux 9: Kickstart fetch failures fixed by correcting `boot_command` to use `/rhel/ks.cfg` and adding early-network kernel args (`ip=dhcp rd.neednet=1`).
- AlmaLinux 9 aarch64: Corrected `inst.repo` architecture from `x86_64` to `aarch64`.
