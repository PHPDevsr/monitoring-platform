# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Release notes for each version are generated automatically by
[git-cliff](https://git-cliff.org) from
[Conventional Commits](https://www.conventionalcommits.org/) when a version tag
(`v*`) is pushed. Do not hand-edit per-version sections below.
## [Unreleased]
### Added

- Add production-grade monitoring platform (f588197)
### Changed

- **changelog:** Update for v1.0.0 (45c4d7c)
- **changelog:** Update for v1.0.0 (70d79fe)
- Bump pinned actions to latest versions (SHA-pinned) (948196c)
- Pin all actions to full-length commit SHAs (28588b6)
- Switch to git-cliff tag-triggered release (v1.0.0 baseline) (9169e24)
- Add release-please release cycle and reset changelog skeleton (9aa5b90)
- Record alertmanager CI validation fix in changelog and tasks (5658ec7)
- **agent:** Mirror CLAUDE.md rules in AGENT.md (a34c0a3)
- Align alertmanager image tag with base image version (af59de8)
- Update image versions in documentation (8dbc7c1)
### Fixed

- **ci:** Use pat= arg for trim_start_matches in cliff.toml (dbe26b9)
- **ci:** Use git-cliff v2 per-release body context in cliff.toml (70e490c)
- **ci:** Use git-cliff v2 'releases' template context in cliff.toml (55c00dd)
- **alertmanager:** Awk-based marker expansion for multi-line blocks (60ce9b5)
- **ci:** Chmod bind-mounted alertmanager dir for render write (584515a)
- **alertmanager:** Use awk ENVIRON for ${VAR} sub (busybox-ash safe) (a69afd0)
- **alertmanager:** Replace fragile ${VAR} loop with sed to stop CI hang (6656ad8)
- **alertmanager:** Make global SMTP/Slack block conditional for amtool (b9ae15e)
- **ci:** Validate alertmanager config with amtool check-config (29cf0ca)
- **ci:** Exclude template from yamllint, validate rendered alertmanager config (09ce3fe)
- **alertmanager:** Conditional receiver generation for valid YAML without SMTP/Slack (400608d)
- **alertmanager:** Simplify variable substitution and add debug output (5c649da)
- **alertmanager:** Fix shell variable substitution for POSIX sh compatibility (0dec2a5)
- Replace envsubst with pure shell substitution and fix loki healthcheck (5a1c760)
- **docker:** Fix loki healthcheck for distroless image (a9fe509)
- **docker:** Add execute permission to alertmanager entrypoint (270e5d5)
- **docker:** Revert cAdvisor to v0.49.1 (92fd3fa)
- **docker:** Use multi-stage build for alertmanager image (6158fe7)
- **ci:** Create container path structure for promtool validation (03f2eb9)

