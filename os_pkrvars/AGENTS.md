---
title: AGENTS (os_pkrvars Guidance)
version: 1.2.0
status: Active
scope: os_pkrvars
---

# AGENTS.md (os_pkrvars)

Guidance for creating and maintaining `.pkrvars.hcl` variable files under `os_pkrvars/`.
This file applies to `os_pkrvars/` and all subdirectories.

## Style and Naming
- Use snake_case for variable names and filenames.
- Filename pattern: `<distro>-<major>[-minor]_<arch>.pkrvars.hcl` (examples in `os_pkrvars/debian`).
- Keep files minimal and focused on inputs; avoid embedding logic.

## Required Fields
- `os_name`, `os_version`, `os_arch` (must be `x86_64`).
- `iso_url` (official Debian mirror URL).
- `iso_checksum` (use Debian’s published SHA256 lists via `file:` URLs).
- `vbox_guest_os_type` (e.g., `Debian12_64`).
- `boot_command` appropriate for the x86_64 architecture.

## Optional and Common Overrides
- `headless` (default true; set to false to debug): `headless = false`.
- `cpus`, `memory`, `disk_size` when deviating from defaults.
- `vboxmanage` to add/override VirtualBox settings per template. Example:
  ```hcl
  vboxmanage = [
    ["modifyvm", "{{.Name}}", "--cableconnected1", "on"],
    ["modifyvm", "{{.Name}}", "--audio-enabled", "off"],
  ]
  ```
- `iso_target_path`: when set to `"build_dir_iso"` (default), the template caches the ISO as `builds/iso/<os>-<version>-<arch>-<sha8>.iso` (sha8 = first 8 of sha256(url)). You may provide an absolute/relative path to reuse a pre-downloaded ISO.
- `vbox_guest_additions_mode` and `vbox_guest_additions_path` to support Guest Additions.

## Security and Integrity
- ISOs must have checksums; prefer `file:` URLs that point to Debian’s `SHA256SUMS`.
- Do not store secrets in these files; if secrets become necessary, pass them via environment variables or as sensitive Packer variables outside version control.

## Definition of Done (for a new .pkrvars.hcl)
- `packer validate` passes for the file.
- Full build completes using `make build TEMPLATE=<path/filename>`.
- Resulting box name matches `<os_name>-<os_version>-<os_arch>.virtualbox.box` and boots with `vagrant up` (login `vagrant/vagrant`).
- Guest Additions installed and basic provisioning sanity checks pass.

## Quick Workflow
- Validate one: `make validate-one TEMPLATE=debian/debian-12-x86_64.pkrvars.hcl`
- Build one: `make build TEMPLATE=debian/debian-12-x86_64.pkrvars.hcl`
- Debug (optional): set `headless = false` during troubleshooting.

## Doc Changelog

| Version | Date       | Changes                                                    |
|---------|------------|------------------------------------------------------------|
| 1.2.0   | 2025-11-20 | Changed: Removed ARM support from guidance.                |
| 1.1.0   | 2025-11-13 | Added frontmatter; clarified required fields and examples. |
| 1.0.0   | 2025-11-13 | Initial guidance for variable files.                       |
