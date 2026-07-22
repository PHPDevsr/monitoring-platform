#!/bin/bash
# =============================================================================
# Monitoring Platform - Restore Script
# =============================================================================
# Restores monitoring data from backup
# Usage: ./restore.sh <backup_file.tar.gz>
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Print banner
print_banner() {
    echo "=============================================="
    echo "  Monitoring Platform Restore"
    echo "  $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=============================================="
    echo ""
}

# Check arguments
check_args() {
    if [ $# -lt 1 ]; then
        log_error "Usage: $0 <backup_file.tar.gz>"
        exit 1
    fi

    if [ ! -f "$1" ]; then
        log_error "Backup file not found: $1"
        exit 1
    fi
}

# Extract backup
extract_backup() {
    local backup_file=$1
    local extract_dir="restore-temp-$(date +%s)"

    log_info "Extracting backup: $backup_file"

    mkdir -p "$extract_dir"
    tar -xzf "$backup_file" -C "$extract_dir"

    # Find the backup directory inside
    BACKUP_DIR=$(find "$extract_dir" -maxdepth 1 -type d -name "monitoring-backup-*" | head -1)

    if [ -z "$BACKUP_DIR" ]; then
        log_error "Invalid backup format - no monitoring-backup directory found"
        rm -rf "$extract_dir"
        exit 1
    fi

    log_success "Backup extracted to: $BACKUP_DIR"
}

# Stop services
stop_services() {
    log_info "Stopping monitoring services..."

    if docker compose ps -q 2>/dev/null | grep -q .; then
        docker compose down
        log_success "Services stopped"
    else
        log_info "No services running"
    fi
}

# Restore configurations
restore_configs() {
    log_info "Restoring configuration files..."

    if [ -d "$BACKUP_DIR/configs" ]; then
        # Backup current configs
        if [ -f "docker-compose.yml" ]; then
            mkdir -p "pre-restore-backup"
            cp -r prometheus alertmanager grafana loki promtail blackbox-exporter docker-compose.yml "pre-restore-backup/" 2>/dev/null || true
            log_info "Current configs backed up to pre-restore-backup/"
        fi

        # Restore configs
        cp -r "$BACKUP_DIR/configs/"* . 2>/dev/null || true
        log_success "Configuration files restored"
    else
        log_warning "No configuration backup found"
    fi
}

# Restore volumes
restore_volumes() {
    log_info "Restoring Docker volumes..."

    if [ -d "$BACKUP_DIR/volumes" ]; then
        local volumes=("prometheus_data" "grafana_data" "loki_data" "alertmanager_data")

        for vol in "${volumes[@]}"; do
            local backup_file="$BACKUP_DIR/volumes/${vol}.tar.gz"

            if [ -f "$backup_file" ]; then
                log_info "Restoring volume: $vol"

                # Remove existing volume
                docker volume rm "$vol" 2>/dev/null || true

                # Create new volume
                docker volume create "$vol"

                # Restore data
                docker run --rm \
                    -v "$vol":/target \
                    -v "$(pwd)/$backup_file":/backup.tar.gz:ro \
                    alpine sh -c "cd /target && tar -xzf /backup.tar.gz"

                log_success "Volume restored: $vol"
            else
                log_warning "Volume backup not found: $vol"
            fi
        done
    else
        log_warning "No volume backups found"
    fi
}

# Start services
start_services() {
    log_info "Starting monitoring services..."

    docker compose up -d

    log_success "Services started"
}

# Wait for health
wait_for_health() {
    log_info "Waiting for services to become healthy..."

    local timeout=120
    local elapsed=0

    while [ $elapsed -lt $timeout ]; do
        local healthy=$(docker compose ps --format json 2>/dev/null | grep -c '"healthy"' || echo "0")
        local total=$(docker compose ps -q 2>/dev/null | wc -l)

        if [ "$healthy" -ge "$total" ] 2>/dev/null; then
            log_success "All services healthy"
            return 0
        fi

        sleep 5
        elapsed=$((elapsed + 5))
        log_info "Waiting... ($elapsed/$timeout seconds)"
    done

    log_warning "Timeout waiting for health - check services manually"
}

# Cleanup
cleanup() {
    log_info "Cleaning up temporary files..."

    local extract_dir=$(dirname "$BACKUP_DIR")
    rm -rf "$extract_dir"

    log_success "Cleanup complete"
}

# Main execution
main() {
    print_banner

    check_args "$@"

    local backup_file="$1"

    echo "WARNING: This will restore from backup and overwrite current data."
    echo "Backup file: $backup_file"
    echo ""
    read -p "Continue? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        log_info "Restore cancelled"
        exit 0
    fi

    extract_backup "$backup_file"
    stop_services
    restore_configs
    restore_volumes
    start_services
    wait_for_health
    cleanup

    echo ""
    log_success "=============================================="
    log_success "  Restore completed!"
    log_success "=============================================="
    echo ""
    echo "Please verify services at:"
    echo "  - Prometheus: http://localhost:9090"
    echo "  - Grafana: http://localhost:3000"
    echo "  - Alertmanager: http://localhost:9093"
    echo ""
}

main "$@"
