# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Release notes for each version are generated automatically by
[release-please](https://github.com/googleapis/release-please) from
[Conventional Commits](https://www.conventionalcommits.org/) since the previous
tag (`feat:` → Added, `fix:` → Fixed, `chore:`/`refactor:` → Changed, etc.).
Do not hand-edit the per-version sections; commit conventional messages and let
the release pull request update this file.

## [Unreleased]

## [1.1.0] - 2026-07-22

### Added
- Centralized credential management via `.env` file
- `.env.example` template with all configurable variables
- `.gitignore` to protect secrets from version control
- Custom Alertmanager Dockerfile with envsubst support
- Alertmanager config template (`alertmanager.yml.tmpl`)

### Changed
- Docker Compose now reads credentials from `.env` file
- Grafana credentials configurable via environment variables
- Prometheus retention settings configurable via environment variables
- Alertmanager uses template-based config for env var substitution
- Added security settings to Grafana (disable signup, disable anonymous)

## [1.0.0] - 2026-07-22

### Added
- Docker Compose configuration with all monitoring services
- Prometheus v2.53.0 with 30-day retention
- Grafana v11.1.0 with auto-provisioned datasources
- Alertmanager v0.33.1 with routing configuration
- Loki v3.7.4 for log aggregation
- Promtail v3.6.11 for log collection
- Node Exporter v1.12.1 for host metrics
- cAdvisor v0.49.1 for container metrics
- Blackbox Exporter v0.28.0 for endpoint probing
- Alert rules for host, container, and service monitoring
- Deployment script with health checks
- Validation script for stack verification
- Backup and restore scripts
- Complete documentation
