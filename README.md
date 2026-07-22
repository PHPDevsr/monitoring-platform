# Monitoring Platform

Production-grade centralized monitoring platform using Docker Compose.

## Stack Components

| Component | Version | Purpose |
|-----------|---------|---------|
| Prometheus | v2.53.0 | Metrics collection and storage |
| Grafana | v11.1.0 | Visualization and dashboards |
| Alertmanager | v0.33.1 | Alert routing and notification |
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
│   ├── Dockerfile              # Custom image with envsubst
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

### Alertmanager - Email (SMTP)

| Variable | Description | Example |
|----------|-------------|---------|
| `SMTP_SMARTHOST` | SMTP server:port | smtp.gmail.com:587 |
| `SMTP_FROM` | Sender email address | alerts@example.com |
| `SMTP_AUTH_USERNAME` | SMTP username | alerts@example.com |
| `SMTP_AUTH_PASSWORD` | SMTP password/app password | your-app-password |
| `SMTP_REQUIRE_TLS` | Require TLS | true |
| `ALERT_EMAIL_TO` | Alert recipient email | oncall@example.com |

### Alertmanager - Slack

| Variable | Description | Example |
|----------|-------------|---------|
| `SLACK_API_URL` | Slack webhook URL | https://hooks.slack.com/... |
| `SLACK_CHANNEL_CRITICAL` | Channel for critical alerts | #alerts-critical |
| `SLACK_CHANNEL_WARNING` | Channel for warning alerts | #alerts-warning |

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

Edit `alertmanager/alertmanager.yml` to configure email, Slack, or webhook receivers.

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
