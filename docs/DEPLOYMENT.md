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
# Pull new images
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

For issues:
1. Check container logs: `docker compose logs <service>`
2. Run validation: `./scripts/validate.sh`
3. Check reports in `reports/` directory
