# Deployment Guide

Complete guide for deploying the monitoring platform.

## Prerequisites

### System Requirements

- **OS**: Ubuntu Server 24.04 LTS
- **CPU**: 2+ cores
- **RAM**: 4GB minimum, 8GB recommended
- **Disk**: 50GB minimum for data retention

### Software Requirements

- Docker Engine 24.0+
- Docker Compose v2.20+

## Pre-Deployment Checklist

- [ ] Docker Engine installed
- [ ] Docker Compose installed
- [ ] User added to docker group
- [ ] Firewall configured
- [ ] Disk space verified

## Installation Steps

### 1. Install Docker

```bash
# Update packages
sudo apt update && sudo apt upgrade -y

# Install prerequisites
sudo apt install -y ca-certificates curl gnupg

# Add Docker GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Verify installation
docker --version
docker compose version
```

### 2. Configure Firewall

```bash
# Allow SSH
sudo ufw allow 22/tcp

# Allow Grafana
sudo ufw allow 3000/tcp

# Allow Prometheus (restrict to trusted IPs in production)
sudo ufw allow 9090/tcp

# Allow Alertmanager (restrict to trusted IPs in production)
sudo ufw allow 9093/tcp

# Enable firewall
sudo ufw enable
```

### 3. Clone/Copy Project

```bash
# Create project directory
mkdir -p /opt/monitoring-platform
cd /opt/monitoring-platform

# Copy all files to this directory
```

### 4. Configure Environment Variables

All credentials and settings are centralized in the `.env` file.

```bash
# Copy the template
cp .env.example .env

# Edit with your settings
nano .env
```

#### Required Settings

```bash
# Grafana admin credentials
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=your-secure-password
GRAFANA_ROOT_URL=https://grafana.example.com

# Email notifications (SMTP)
SMTP_SMARTHOST=smtp.gmail.com:587
SMTP_FROM=alerts@example.com
SMTP_AUTH_USERNAME=alerts@example.com
SMTP_AUTH_PASSWORD=your-app-password
SMTP_REQUIRE_TLS=true
ALERT_EMAIL_TO=oncall@example.com

# Slack notifications (optional)
SLACK_API_URL=https://hooks.slack.com/services/xxx/yyy/zzz
SLACK_CHANNEL_CRITICAL=#alerts-critical
SLACK_CHANNEL_WARNING=#alerts-warning

# Data retention
PROMETHEUS_RETENTION_TIME=30d
PROMETHEUS_RETENTION_SIZE=10GB
```

#### Gmail App Password

For Gmail SMTP, create an App Password:
1. Go to Google Account > Security > 2-Step Verification
2. At the bottom, select App passwords
3. Generate a new app password for "Mail"
4. Use this password in `SMTP_AUTH_PASSWORD`

#### Slack Webhook

To get a Slack webhook URL:
1. Go to https://api.slack.com/apps
2. Create New App > From scratch
3. Add Incoming Webhooks feature
4. Create a webhook for your channel
5. Copy the webhook URL to `SLACK_API_URL`

### 5. Add Custom Scrape Targets (Optional)

Edit `prometheus/prometheus.yml` to add your application targets:

```yaml
scrape_configs:
  - job_name: 'my-application'
    static_configs:
      - targets: ['app-server:8080']
```

### 6. Deploy

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Deploy the stack
./scripts/deploy.sh
```

### 6. Validate

```bash
./scripts/validate.sh
```

### 7. Post-Deployment

1. Access Grafana at http://your-server:3000
2. Login with admin/admin
3. **Change the admin password immediately**
4. Import dashboards from Grafana Labs:
   - Node Exporter Full: ID 1860
   - Docker Container Monitoring: ID 893
   - Loki Logs: ID 13639

## Production Hardening

### 1. Enable HTTPS

Use a reverse proxy (nginx/traefik) with SSL certificates:

```bash
# Example with Let's Encrypt and nginx
sudo apt install nginx certbot python3-certbot-nginx
sudo certbot --nginx -d grafana.example.com
```

### 2. Secure Grafana

```yaml
environment:
  - GF_SECURITY_ADMIN_PASSWORD=<strong-password>
  - GF_USERS_ALLOW_SIGN_UP=false
  - GF_AUTH_ANONYMOUS_ENABLED=false
```

### 3. Restrict Access

Update firewall rules to allow only trusted IPs:

```bash
sudo ufw allow from 10.0.0.0/8 to any port 9090
sudo ufw allow from 10.0.0.0/8 to any port 9093
```

### 4. Enable Authentication for Prometheus

Add basic auth via reverse proxy or use `--web.config.file` with a web config.

### 5. Set Up Automated Backups

```bash
# Add to crontab
crontab -e

# Daily backup at 2 AM
0 2 * * * /opt/monitoring-platform/scripts/backup.sh /opt/backups >> /var/log/monitoring-backup.log 2>&1
```

## Rollback Procedure

If deployment fails:

```bash
# Stop services
docker compose down

# Restore from backup
./scripts/restore.sh /path/to/backup.tar.gz

# Or restore previous configuration
cp -r pre-restore-backup/* .
docker compose up -d
```

## Maintenance

### Update Images

```bash
# Pull official images
docker compose pull

# Recreate containers
docker compose up -d
```

### Check Disk Usage

```bash
# Check volume sizes
docker system df -v

# Prune unused data
docker system prune -f
```

### Rotate Logs

Docker log rotation is configured in docker-compose.yml:
- Max size: 10MB per file
- Max files: 3 per container

## Support

### Deployment times out at Loki or Promtail is unhealthy

Loki has its in-container healthcheck disabled because its image does not
include an HTTP client. `deploy.sh` checks `http://loki:3100/ready` from the
Prometheus container on the internal network instead. A running Loki container
alone does not establish readiness.

Promtail's official image does not install wget/curl. Its healthcheck uses Bash
TCP support to send a GET request to `/ready` and requires HTTP 200.

After updating `scripts/deploy.sh` and `docker-compose.yml`, rerun:

```bash
./scripts/deploy.sh

# Inspect readiness without publishing additional ports.
docker compose exec -T prometheus wget -q -T 5 -O - http://loki:3100/ready
docker compose exec -T prometheus wget -q -T 5 -O - http://promtail:9080/ready
docker inspect --format='{{json .State.Health}}' promtail
```

Readiness checks have a default timeout of 300 seconds per service. For a slow
server, use `DEPLOY_TIMEOUT=600 ./scripts/deploy.sh` after checking the service
logs. Deployment failures include container health details and recent logs.

If the probe reports `wget: bad address 'loki:3100'`, deployment reads both
containers' current addresses on `monitoring-network` and retries Loki's
`/ready` endpoint using its current IP. Success emits a DNS warning; failed
HTTP readiness still blocks deployment. This fallback does not repair Docker
DNS for Grafana, Promtail, or other clients.

Check the live address and resolver configuration on the server:

```bash
LOKI_IP=$(docker inspect --format='{{with index .NetworkSettings.Networks "monitoring-network"}}{{.IPAddress}}{{end}}' loki)
docker compose exec -T prometheus wget -S -T 5 -O - "http://${LOKI_IP}:3100/ready"
docker compose exec -T prometheus cat /etc/resolv.conf
```

The IP probe should return HTTP 200 and `ready`. Docker service names should
resolve between containers on the same network; see the
[Docker Compose networking guide](https://docs.docker.com/compose/how-tos/networking/).

Run the local regression checks with `bash scripts/test-deploy.sh`. These checks
simulate Docker; verify the actual endpoints on the deployment server as well.

To roll back the DNS fallback alone, restore `scripts/deploy.sh` from the
deployment backup. To roll back the original readiness change, restore the previous `scripts/deploy.sh` and
`docker-compose.yml` from your deployment backup, then run
`docker compose up -d promtail` to restore its previous healthcheck. Existing
Loki and Grafana data stay in their named volumes.

For issues:
1. Check container logs: `docker compose logs <service>`
2. Run validation: `./scripts/validate.sh`
3. Check reports in `reports/` directory


## Telegram notifications

Telegram is an optional native Alertmanager integration. It sends alerts to one
chat alongside existing email/Slack/webhook routing, subject to silences and
inhibition. No additional service or image build is required.

### Create the bot and obtain a chat ID

1. Open [BotFather](https://t.me/BotFather), send `/newbot`, and follow its prompts.
   Save the token privately, following the [official bot setup guide](https://core.telegram.org/bots/tutorial#obtain-your-bot-token).
2. For a private destination, open your bot and send `/start`. For a group, add
   the bot, allow it to send messages, and send `/start@YourBotUsername` in that
   group so the bot receives an update even with privacy mode enabled.
3. In a trusted terminal, read the token without adding it to shell history,
   then fetch recent updates. Run these commands without shell tracing (`set -x`):

   ```bash
   read -rsp 'Telegram bot token: ' TELEGRAM_BOT_TOKEN; echo
   curl --fail --silent --show-error \
     "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getUpdates"
   unset TELEGRAM_BOT_TOKEN
   ```

4. Find the intended conversation in `result[].message.chat` and copy its numeric
   `id` (not the user ID or update ID). A group/supergroup usually has a negative
   ID, such as `-1001234567890`. Confirm the chat title or type before using it.
   An empty result means you should send a new command to the bot and retry.
   If another application already consumes updates or has a webhook registered,
   coordinate with its owner or create a dedicated bot. Do not delete its webhook.
   See the [Telegram getUpdates reference](https://core.telegram.org/bots/api#getupdates).

### Configure and apply

Fill these entries in the git-ignored `.env` file, replacing the sample values:

```dotenv
# Keep the bot token private; both settings are required to enable Telegram.
TELEGRAM_BOT_TOKEN=replace-with-your-bot-token
TELEGRAM_CHAT_ID=-1001234567890
```

Both empty disables Telegram. If only one is configured, or the chat ID is zero,
non-numeric, or outside signed 64-bit range, startup fails before rendering.
Negative IDs and decimal IDs with leading zeros are supported and normalized.
The renderer never prints the generated configuration, which contains secrets.
For Telegram-only delivery, also empty `SMTP_SMARTHOST`, `ALERT_EMAIL_TO`, and
`SLACK_API_URL` so the example SMTP/Slack credentials do not enable those channels.

```bash
# Recreate: a restart alone does not reread the .env settings.
docker compose up -d --force-recreate alertmanager
docker compose exec alertmanager /bin/amtool check-config /etc/alertmanager/alertmanager.yml
curl --fail http://localhost:9093/-/ready
```

Messages use plain text, with per-alert status, name, severity, instance, summary,
and description. Telegram waits 30 seconds for a new group, batches subsequent
updates every 5 minutes, and repeats firing alerts every 4 hours. Existing channel
routing retains its previous timing. Existing configured channels can also
receive the smoke-test alert below.

### Test firing and resolved delivery

Run on the Ubuntu Docker host after configuring the bot. These requests exercise
Alertmanager delivery; they do not test Prometheus rule evaluation. Choose a
fresh test label each time to avoid existing notification deduplication.

```bash
# Keep these variables in the same shell for both requests.
TEST_ID="telegram-$(date -u +%s)"
STARTS_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
ENDS_AT=$(date -u -d '+15 minutes' +%Y-%m-%dT%H:%M:%SZ)

curl --fail --silent --show-error \
  -H 'Content-Type: application/json' \
  -X POST http://localhost:9093/api/v2/alerts --data-binary @- <<EOF
[{
  "labels": {"alertname": "TelegramSmokeTest", "severity": "test", "instance": "$TEST_ID"},
  "annotations": {"summary": "Telegram integration test", "description": "Manual firing/resolved delivery check"},
  "startsAt": "$STARTS_AT",
  "endsAt": "$ENDS_AT"
}]
EOF
```

Wait until a `FIRING` message appears in Telegram (normally after 30 seconds).
Then resolve the identical alert, keeping its labels and start time unchanged:

```bash
ENDS_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
curl --fail --silent --show-error \
  -H 'Content-Type: application/json' \
  -X POST http://localhost:9093/api/v2/alerts --data-binary @- <<EOF
[{
  "labels": {"alertname": "TelegramSmokeTest", "severity": "test", "instance": "$TEST_ID"},
  "annotations": {"summary": "Telegram integration test", "description": "Manual firing/resolved delivery check"},
  "startsAt": "$STARTS_AT",
  "endsAt": "$ENDS_AT"
}]
EOF
```

Allow up to the next 5-minute group interval for `RESOLVED`. If the firing test
was left unattended, it expires after 15 minutes. This procedure sends real test
notifications only when you run it with your configured credentials.

### Troubleshooting and rollback

- Startup rejection: set both variables, use a nonzero numeric chat ID, then
  recreate the service. Error messages intentionally omit supplied values.
- No message: check Alertmanager readiness, active alerts, silences, inhibition,
  and `docker compose logs --tail=100 alertmanager`. An accepted API request alone
  does not prove delivery. Allow for the grouping intervals above.
- Telegram `401`: verify or rotate the bot token. `400`/`403`: check the chat ID,
  start the bot or add it to the chat, unblock it, and grant permission to send.
- Network/TLS errors: verify outbound DNS and HTTPS access to `api.telegram.org`.
  Certificate verification is enabled by default through
  `ALERTMANAGER_HTTP_INSECURE_SKIP_VERIFY=false`.
- Existing localhost:5001 webhook failures concern the pre-existing webhook
  receivers; Telegram sends independently through its own receiver.
- To disable Telegram, empty both variables and run
  `docker compose up -d --force-recreate alertmanager` again. For a code rollback,
  restore the affected files from the pre-change backup and recreate Alertmanager.

### Automated configuration checks

```bash
# Local renderer, credential rejection, and routing checks (POSIX shell required).
python3 -m pip install PyYAML
python3 scripts/test-alertmanager.py

# Full production-image check, including amtool syntax/template and routing validation.
# Requires Docker Compose and an existing .env; uses dummy credentials only.
AM_IMAGE=$(docker compose config --format json | python3 -c \
  'import json,sys; print(json.load(sys.stdin)["services"]["alertmanager"]["image"])')
python3 scripts/test-alertmanager.py --image "$AM_IMAGE"
```

CI runs the image-backed checks for disabled Telegram, Telegram alone, and
Telegram with SMTP/Slack, including positive/negative IDs, invalid configuration,
credential logging, and routing without duplicate Telegram notifications.
