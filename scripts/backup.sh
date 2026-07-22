#!/bin/bash
# =============================================================================
# Monitoring Platform - Backup Script
# =============================================================================
# Creates backups of all monitoring data and configurations
# Usage: ./backup.sh [backup_dir]
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
BACKUP_DIR="${1:-backups}"
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
BACKUP_NAME="monitoring-backup-$TIMESTAMP"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Print banner
print_banner() {
    echo "=============================================="
    echo "  Monitoring Platform Backup"
    echo "  $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=============================================="
    echo ""
}

# Create backup directory
create_backup_dir() {
    log_info "Creating backup directory: $BACKUP_PATH"
    mkdir -p "$BACKUP_PATH"/{configs,volumes,metadata}
}

# Backup configuration files
backup_configs() {
    log_info "Backing up configuration files..."

    local configs=(
        "docker-compose.yml"
        "prometheus"
        "alertmanager"
        "grafana"
        "loki"
        "promtail"
        "blackbox-exporter"
    )

    for item in "${configs[@]}"; do
        if [ -e "$item" ]; then
            cp -r "$item" "$BACKUP_PATH/configs/"
            log_success "Backed up: $item"
        else
            log_warning "Not found: $item"
        fi
    done
}

# Backup Docker volumes
backup_volumes() {
    log_info "Backing up Docker volumes..."

    local volumes=(
        "prometheus_data"
        "grafana_data"
        "loki_data"
        "alertmanager_data"
    )

    for vol in "${volumes[@]}"; do
        if docker volume inspect "$vol" &>/dev/null; then
            log_info "Backing up volume: $vol"

            # Create volume backup using temporary container
            docker run --rm \
                -v "$vol":/source:ro \
                -v "$(pwd)/$BACKUP_PATH/volumes":/backup \
                alpine tar -czf "/backup/${vol}.tar.gz" -C /source .

            log_success "Backed up volume: $vol"
        else
            log_warning "Volume not found: $vol"
        fi
    done
}

# Backup Grafana dashboards via API
backup_grafana_dashboards() {
    log_info "Backing up Grafana dashboards via API..."

    mkdir -p "$BACKUP_PATH/grafana-dashboards"

    # Get all dashboards
    local dashboards=$(curl -sf -u admin:admin "http://localhost:3000/api/search?type=dash-db" 2>/dev/null || echo "[]")

    if [ "$dashboards" = "[]" ]; then
        log_warning "No Grafana dashboards found or Grafana not accessible"
        return
    fi

    # Extract dashboard UIDs and save each
    echo "$dashboards" | grep -o '"uid":"[^"]*"' | cut -d'"' -f4 | while read -r uid; do
        if [ -n "$uid" ]; then
            local dashboard=$(curl -sf -u admin:admin "http://localhost:3000/api/dashboards/uid/$uid" 2>/dev/null)
            if [ -n "$dashboard" ]; then
                echo "$dashboard" > "$BACKUP_PATH/grafana-dashboards/${uid}.json"
            fi
        fi
    done

    log_success "Grafana dashboards backed up"
}

# Backup Prometheus snapshots
backup_prometheus_snapshot() {
    log_info "Creating Prometheus snapshot..."

    # Trigger snapshot via admin API
    local response=$(curl -sf -X POST "http://localhost:9090/api/v1/admin/tsdb/snapshot" 2>/dev/null || echo "")

    if [ -n "$response" ]; then
        local snapshot_name=$(echo "$response" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$snapshot_name" ]; then
            log_success "Prometheus snapshot created: $snapshot_name"
            echo "$snapshot_name" > "$BACKUP_PATH/metadata/prometheus_snapshot.txt"
        fi
    else
        log_warning "Could not create Prometheus snapshot (admin API may be disabled)"
    fi
}

# Create metadata file
create_metadata() {
    log_info "Creating backup metadata..."

    {
        echo "Backup Metadata"
        echo "==============="
        echo "Timestamp: $TIMESTAMP"
        echo "Backup Name: $BACKUP_NAME"
        echo "Created: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        echo "Docker Version: $(docker --version)"
        echo "Docker Compose Version: $(docker compose version)"
        echo ""
        echo "Running Containers:"
        docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Image}}"
        echo ""
        echo "Volumes:"
        docker volume ls --format "table {{.Name}}\t{{.Driver}}" | grep -E "(prometheus|grafana|loki|alertmanager)"
    } > "$BACKUP_PATH/metadata/backup_info.txt"

    log_success "Metadata created"
}

# Compress backup
compress_backup() {
    log_info "Compressing backup..."

    cd "$BACKUP_DIR"
    tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"
    rm -rf "$BACKUP_NAME"

    local size=$(du -h "${BACKUP_NAME}.tar.gz" | cut -f1)
    log_success "Backup compressed: ${BACKUP_NAME}.tar.gz ($size)"
    cd - > /dev/null
}

# Cleanup old backups (keep last 7)
cleanup_old_backups() {
    log_info "Cleaning up old backups (keeping last 7)..."

    local count=$(ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null | wc -l)

    if [ "$count" -gt 7 ]; then
        ls -1t "$BACKUP_DIR"/*.tar.gz | tail -n +8 | xargs rm -f
        log_success "Removed $(($count - 7)) old backup(s)"
    else
        log_info "No old backups to remove"
    fi
}

# Main execution
main() {
    print_banner

    create_backup_dir
    backup_configs
    backup_volumes
    backup_grafana_dashboards
    backup_prometheus_snapshot
    create_metadata
    compress_backup
    cleanup_old_backups

    echo ""
    log_success "=============================================="
    log_success "  Backup completed successfully!"
    log_success "=============================================="
    echo ""
    echo "Backup location: $BACKUP_DIR/${BACKUP_NAME}.tar.gz"
    echo ""
}

main "$@"
