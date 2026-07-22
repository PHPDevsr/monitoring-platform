#!/bin/bash
# =============================================================================
# Monitoring Platform - Deployment Script
# =============================================================================
# Deploys the complete monitoring stack with validation
# Usage: ./deploy.sh [--force]
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="docker-compose.yml"
DEPLOY_TIMEOUT=300
HEALTH_CHECK_INTERVAL=10

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Print banner
print_banner() {
    echo "=============================================="
    echo "  Monitoring Platform Deployment"
    echo "  $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=============================================="
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi

    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed"
        exit 1
    fi

    # Check Docker daemon
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        exit 1
    fi

    # Check compose file exists
    if [ ! -f "$COMPOSE_FILE" ]; then
        log_error "Compose file not found: $COMPOSE_FILE"
        exit 1
    fi

    log_success "All prerequisites met"
}

# Validate configuration files
validate_configs() {
    log_info "Validating configuration files..."

    local configs=(
        "prometheus/prometheus.yml"
        "prometheus/alert.rules.yml"
        "alertmanager/alertmanager.yml"
        "loki/loki-config.yml"
        "promtail/promtail-config.yml"
        "blackbox-exporter/blackbox.yml"
        "grafana/provisioning/datasources/datasources.yml"
        "grafana/provisioning/dashboards/dashboards.yml"
    )

    for config in "${configs[@]}"; do
        if [ ! -f "$config" ]; then
            log_error "Configuration file missing: $config"
            exit 1
        fi
    done

    # Validate YAML syntax
    if command -v yamllint &> /dev/null; then
        for config in "${configs[@]}"; do
            if ! yamllint -d relaxed "$config" &> /dev/null; then
                log_warning "YAML validation warning in: $config"
            fi
        done
    fi

    # Validate docker-compose syntax
    if ! docker compose config --quiet 2>/dev/null; then
        log_error "Docker Compose configuration is invalid"
        exit 1
    fi

    log_success "All configuration files validated"
}

# Create required directories and set permissions
prepare_environment() {
    log_info "Preparing environment..."

    # Create data directories if they don't exist
    mkdir -p prometheus alertmanager grafana loki promtail blackbox-exporter scripts

    log_success "Environment prepared"
}

# Pull latest images
pull_images() {
    log_info "Pulling Docker images..."

    if ! docker compose pull; then
        log_error "Failed to pull Docker images"
        exit 1
    fi

    log_success "Docker images pulled"
}

# Deploy the stack
deploy_stack() {
    log_info "Deploying monitoring stack..."

    if ! docker compose up -d; then
        log_error "Failed to deploy monitoring stack"
        exit 1
    fi

    log_success "Monitoring stack deployed"
}

# Wait for services to be healthy
wait_for_health() {
    log_info "Waiting for services to become healthy..."

    local services=("prometheus" "grafana" "alertmanager" "loki" "node-exporter" "cadvisor" "blackbox-exporter" "promtail")
    local start_time=$(date +%s)

    for service in "${services[@]}"; do
        log_info "Checking $service..."

        while true; do
            local current_time=$(date +%s)
            local elapsed=$((current_time - start_time))

            if [ $elapsed -ge $DEPLOY_TIMEOUT ]; then
                log_error "Timeout waiting for $service to become healthy"
                docker compose logs "$service" --tail=50
                exit 1
            fi

            local health=$(docker inspect --format='{{.State.Health.Status}}' "$service" 2>/dev/null || echo "unknown")

            if [ "$health" = "healthy" ]; then
                log_success "$service is healthy"
                break
            elif [ "$health" = "unhealthy" ]; then
                log_error "$service is unhealthy"
                docker compose logs "$service" --tail=50
                exit 1
            fi

            sleep $HEALTH_CHECK_INTERVAL
        done
    done

    log_success "All services are healthy"
}

# Verify endpoints
verify_endpoints() {
    log_info "Verifying service endpoints..."

    local endpoints=(
        "http://localhost:9090/-/healthy:Prometheus"
        "http://localhost:3000/api/health:Grafana"
        "http://localhost:9093/-/healthy:Alertmanager"
    )

    for endpoint in "${endpoints[@]}"; do
        local url="${endpoint%%:*}"
        local name="${endpoint##*:}"

        if curl -sf "$url" > /dev/null 2>&1; then
            log_success "$name endpoint is accessible"
        else
            log_warning "$name endpoint check failed (may still be starting)"
        fi
    done
}

# Generate deployment report
generate_report() {
    local report_file="reports/deployment-$(date '+%Y%m%d-%H%M%S').txt"
    mkdir -p reports

    {
        echo "=============================================="
        echo "  Deployment Report"
        echo "  $(date '+%Y-%m-%d %H:%M:%S')"
        echo "=============================================="
        echo ""
        echo "Services Status:"
        docker compose ps
        echo ""
        echo "Docker Images:"
        docker compose images
        echo ""
        echo "Network:"
        docker network inspect monitoring-network 2>/dev/null || echo "Network info not available"
        echo ""
        echo "Volumes:"
        docker volume ls | grep -E "(prometheus|grafana|loki|alertmanager)"
        echo ""
        echo "Access URLs:"
        echo "  - Prometheus: http://localhost:9090"
        echo "  - Grafana: http://localhost:3000 (admin/admin)"
        echo "  - Alertmanager: http://localhost:9093"
    } > "$report_file"

    log_success "Deployment report saved to: $report_file"
}

# Main execution
main() {
    print_banner

    # Parse arguments
    local force=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                force=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    check_prerequisites
    validate_configs
    prepare_environment
    pull_images
    deploy_stack
    wait_for_health
    verify_endpoints
    generate_report

    echo ""
    log_success "=============================================="
    log_success "  Deployment completed successfully!"
    log_success "=============================================="
    echo ""
    echo "Access URLs:"
    echo "  - Prometheus: http://localhost:9090"
    echo "  - Grafana: http://localhost:3000 (admin/admin)"
    echo "  - Alertmanager: http://localhost:9093"
    echo ""
}

main "$@"
