# Changelog

## [Unreleased] - 2026-07-23

### Fixed
- Alertmanager config template no longer emits empty `global` SMTP/Slack
  fields when credentials are absent. The `global` block now uses
  `{{SMTP_GLOBAL}}` / `{{SLACK_GLOBAL}}` markers expanded only when
  `SMTP_SMARTHOST`+`ALERT_EMAIL_TO` / `SLACK_API_URL` are set, so the
  no-credentials render stays valid for `amtool check-config`.
- `entrypoint.sh` `${VAR}` substitution rewritten in `awk` (was a
  busybox-ash-fragile shell string-chopping loop that hung the CI render
  step for 10+ minutes).
- `entrypoint.sh` marker expansion rewritten in `awk` with fixed-string
  splicing (sed `s|||` cannot handle the multi-line email/slack/global
  blocks — embedded newlines terminate the sed command with "unmatched
  '|'"). All markers are pre-initialised to empty so unused ones are
  removed rather than left literally in the output.
- CI render step now `chmod 777` the bind-mounted config dir so the
  container can write the rendered `alertmanager.yml` (was
  "Permission denied", hidden behind the earlier hang).
- CI render `docker run` calls wrapped with `timeout 90` so any future
  hang fails fast. Rendered config is printed in CI logs for
  traceability.

### Changed
- `alertmanager.yml.tmpl`: static `global` SMTP/Slack lines replaced
  with conditional markers; header comments updated to describe the
  marker behaviour.

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
