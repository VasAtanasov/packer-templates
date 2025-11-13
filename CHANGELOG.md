# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog (https://keepachangelog.com/en/1.1.0/),
and this project adheres to Semantic Versioning where practical.

## [Unreleased]

### Added
- Root `AGENTS.md` refined: scope/precedence, minimum versions, HCL conventions, reproducibility, DoD, fast dev loop, security, and cross‑refs.
- `packer_templates/scripts/AGENTS.md` with script rules (strict mode, idempotent, root required) and skeleton (no local fallback).
- `os_pkrvars/AGENTS.md` for variable file guidance and examples.
- `CHANGELOG.md` following Keep a Changelog.
- Documentation standard in root `AGENTS.md` defining metadata header, SemVer for docs, per-doc changelog, and repo-level changelog requirements.
- New doc: `doc/packer-organization-matrix-priority.md` outlining provider directories, OS-split sources, and arch/variant via variables.

### Changed
- Documentation now states Guest Additions are to be installed during provisioning.
- Host stance clarified as agnostic (no WSL2‑specific accommodations required).
- Rakefile updated to match Makefile environment checks and minimum version enforcement.
 - Aligned documentation to the repo Documentation Standard (frontmatter + Doc Changelog across docs).
 - Merged general Bash guidance into `packer_templates/scripts/AGENTS.md` and tailored to project.

### Removed
- Deleted `doc/CONTRIBUTING_BASH.md` in favor of consolidated guidance in `packer_templates/scripts/AGENTS.md`.
