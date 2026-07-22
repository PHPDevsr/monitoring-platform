# Changelog

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
- Alertmanager v0.27.0 with routing configuration
- Loki v3.1.0 for log aggregation
- Promtail v3.1.0 for log collection
- Node Exporter v1.8.1 for host metrics
- cAdvisor v0.49.1 for container metrics
- Blackbox Exporter v0.25.0 for endpoint probing
- Alert rules for host, container, and service monitoring
- Deployment script with health checks
- Validation script for stack verification
- Backup and restore scripts
- Complete documentation
