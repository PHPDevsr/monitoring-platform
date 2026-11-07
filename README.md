# Monitoring Platform

Production-grade centralized monitoring platform using Docker Compose.

## Stack Components

| Component | Version | Purpose |
|-----------|---------|---------|
| Prometheus | v2.53.0 | Metrics collection and storage |
| Grafana | v11.1.0 | Visualization and dashboards |
| Alertmanager | v0.34.2 | Alert routing and notification |
| Loki | v3.7.4 | Log aggregation |
| Promtail | v3.6.11 | Log collector |
| Node Exporter | v1.12.1 | Host system metrics |
| cAdvisor | v0.49.1 | Container metrics |
| Blackbox Exporter | v0.28.0 | Endpoint probing |

## Quick Start

```bash
# 1. Copy and configure environment variables
cp .env.example .env
nano .env  # Edit credentials and settings

# 2. Deploy the stack
./scripts/deploy.sh

# 3. Validate deployment
./scripts/validate.sh
```

## Access URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| Grafana | http://localhost:3000 | Configured in .env |
| Prometheus | http://localhost:9090 | - |
| Alertmanager | http://localhost:9093 | - |

## Directory Structure

```
monitoring-platform/
├── docker-compose.yml          # Main compose file
├── .env.example                # Environment variables template
├── .env                        # Your credentials (git-ignored)
├── prometheus/
│   ├── prometheus.yml          # Prometheus configuration
│   └── alert.rules.yml         # Alert rules
├── alertmanager/
│   ├── entrypoint.sh           # Config template processor
│   └── alertmanager.yml.tmpl   # Alertmanager config template
├── grafana/
│   └── provisioning/
│       ├── datasources/        # Auto-configured datasources
│       └── dashboards/         # Dashboard provisioning
├── loki/
│   └── loki-config.yml         # Loki configuration
├── promtail/
│   └── promtail-config.yml     # Promtail configuration
├── blackbox-exporter/
│   ├── entrypoint.sh           # ENV-backed TLS config renderer
│   └── blackbox.yml            # Blackbox probe modules
├── scripts/
│   ├── deploy.sh               # Deployment script
│   ├── validate.sh             # Validation script
│   ├── backup.sh               # Backup script
│   └── restore.sh              # Restore script
└── docs/
    └── DEPLOYMENT.md           # Deployment guide
```

## Environment Variables

All credentials and configurable settings are centralized in `.env` file.

Alertmanager uses the official `prom/alertmanager` image directly. Compose mounts
the entrypoint script and configuration template read-only; the script renders
email, Slack, and Telegram settings from `.env` before starting Alertmanager. No image build
is required.

### Grafana

| Variable | Description | Default |
|----------|-------------|---------|
| `GRAFANA_ADMIN_USER` | Admin username | admin |
| `GRAFANA_ADMIN_PASSWORD` | Admin password | admin |
| `GRAFANA_ROOT_URL` | Public URL for Grafana | http://localhost:3000 |

### Prometheus

| Variable | Description | Default |
|----------|-------------|---------|
| `PROMETHEUS_RETENTION_TIME` | How long to keep metrics | 30d |
| `PROMETHEUS_RETENTION_SIZE` | Max storage size | 10GB |

### Blackbox Exporter

| Variable | Description | Default |
|----------|-------------|---------|
| `BLACKBOX_INSECURE_SKIP_VERIFY` | Skip TLS certificate verification for `http_2xx`, `https_2xx`, and `tcp_tls` | false |

Set `BLACKBOX_INSECURE_SKIP_VERIFY=false` in `.env` to verify certificates, or
`true` to skip verification. Only lowercase `true` and `false` are accepted;
unset or empty values default to `false`. Other probe modules keep their existing
settings. The entrypoint renders `/tmp/blackbox.yml` from the read-only source.

Apply changes to `.env` by recreating the service:

```bash
docker compose up -d --force-recreate blackbox-exporter
```

To roll back the setting, use `BLACKBOX_INSECURE_SKIP_VERIFY=false` and run the
same command. To roll back the implementation, restore `docker-compose.yml`,
`.env.example`, `blackbox-exporter/blackbox.yml`, and `scripts/deploy.sh` from
the deployment backup, then recreate the service.

### Alertmanager - Email (SMTP)

| Variable | Description | Example |
|----------|-------------|---------|
| `SMTP_SMARTHOST` | SMTP server:port | smtp.gmail.com:587 |
| `SMTP_FROM` | Sender email address | alerts@example.com |
| `SMTP_AUTH_USERNAME` | SMTP username | alerts@example.com |
| `SMTP_AUTH_PASSWORD` | SMTP password/app password | your-app-password |
| `SMTP_REQUIRE_TLS` | Require TLS | true |
| `SMTP_TLS_INSECURE_SKIP_VERIFY` | Skip SMTP certificate verification (default false) | false |
| `ALERT_EMAIL_TO` | Alert recipient email | oncall@example.com |

`SMTP_TLS_INSECURE_SKIP_VERIFY` controls `global.smtp_tls_config` when email is
configured. `ALERTMANAGER_HTTP_INSECURE_SKIP_VERIFY` controls
`global.http_config.tls_config` for outgoing HTTPS notifications, including Slack
and webhooks. Both default to `false` (certificate verification enabled), accept
only lowercase `true`/`false`, and treat unset or empty values as `false`.
`SMTP_REQUIRE_TLS` separately controls whether SMTP requires TLS.

After editing `.env`, apply the settings with:

```bash
docker compose up -d --force-recreate alertmanager
```

To restore certificate verification, set both values to `false` and recreate
Alertmanager with the same command.

### Alertmanager - Slack

| Variable | Description | Example |
|----------|-------------|---------|
| `SLACK_API_URL` | Slack webhook URL | https://hooks.slack.com/... |
| `SLACK_CHANNEL_CRITICAL` | Channel for critical alerts | #alerts-critical |
| `SLACK_CHANNEL_WARNING` | Channel for warning alerts | #alerts-warning |

### Alertmanager - Telegram

| Variable | Description | Default |
|----------|-------------|---------|
| `TELEGRAM_BOT_TOKEN` | Bot token issued by BotFather | Empty (disabled) |
| `TELEGRAM_CHAT_ID` | Nonzero numeric chat ID; negative for groups | Empty (disabled) |

Set both variables in `.env` to send all eligible alerts to one Telegram chat,
including firing and resolved notifications. Both empty disables Telegram;
partial credentials or an invalid chat ID prevent startup. Chat IDs must fit a
signed 64-bit integer. Existing silences and inhibition rules still apply.

Telegram uses a 30-second group wait, 5-minute group interval, and 4-hour repeat
interval. Messages include status, alert name, severity, instance, summary, and
description as plain text. Notification credentials are not printed at startup.

```bash
docker compose up -d --force-recreate alertmanager
```

See [Telegram setup, smoke test, and rollback](docs/DEPLOYMENT.md#telegram-notifications).

## Operations

### Deploy

```bash
./scripts/deploy.sh
```

### Validate

```bash
./scripts/validate.sh
```

### Backup

```bash
./scripts/backup.sh [backup_directory]
```

### Restore

```bash
./scripts/restore.sh <backup_file.tar.gz>
```

### Stop

```bash
docker compose down
```

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f prometheus
```

## Security Notes

1. **Change default credentials** - Update Grafana admin password immediately
2. **Firewall** - Only ports 3000, 9090, 9093 are exposed; restrict access via firewall
3. **Exporters** - Node Exporter, cAdvisor, Blackbox Exporter are internal only
4. **Network** - All services communicate via internal Docker network

## Customization

### Add Scrape Targets

Edit `prometheus/prometheus.yml` and add new targets under `scrape_configs`.

### Add Alert Rules

Edit `prometheus/alert.rules.yml` to add new alerting rules.

### Configure Notifications

Configure email, Slack, and Telegram through `.env`. For custom routing or webhook
receivers, edit `alertmanager/alertmanager.yml.tmpl`, which is rendered at startup;
the standalone `alertmanager/alertmanager.yml` is not mounted by Compose.

### Add HTTP Probes

Edit `prometheus/prometheus.yml` under the `blackbox-http` job to add endpoints to monitor.

## Troubleshooting

### Check container status
```bash
docker compose ps
```

### Check container logs
```bash
docker compose logs <service_name>
```

### Restart a service
```bash
docker compose restart <service_name>
```

### Reload Prometheus configuration
```bash
curl -X POST http://localhost:9090/-/reload
```
