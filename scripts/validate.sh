#!/bin/bash
# =============================================================================
# Monitoring Platform - Validation Script
# =============================================================================
# Validates all components of the monitoring stack
# Usage: ./validate.sh
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $1"; ((PASSED_CHECKS++)); ((TOTAL_CHECKS++)); }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; ((WARNING_CHECKS++)); ((TOTAL_CHECKS++)); }
log_error() { echo -e "${RED}[FAIL]${NC} $1"; ((FAILED_CHECKS++)); ((TOTAL_CHECKS++)); }

# Print banner
print_banner() {
    echo "=============================================="
    echo "  Monitoring Platform Validation"
    echo "  $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=============================================="
    echo ""
}

# Check container status
check_container() {
    local name=$1
    local status=$(docker inspect --format='{{.State.Status}}' "$name" 2>/dev/null || echo "not found")
    local health=$(docker inspect --format='{{.State.Health.Status}}' "$name" 2>/dev/null || echo "unknown")

    if [ "$status" = "running" ] && [ "$health" = "healthy" ]; then
        log_success "Container $name: running and healthy"
        return 0
    elif [ "$status" = "running" ]; then
        log_warning "Container $name: running but health=$health"
        return 1
    else
        log_error "Container $name: $status"
        return 1
    fi
}

# Check HTTP endpoint
check_endpoint() {
    local name=$1
    local url=$2
    local expected_code=${3:-200}

    local response=$(curl -sf -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")

    if [ "$response" = "$expected_code" ]; then
        log_success "Endpoint $name: HTTP $response"
        return 0
    else
        log_error "Endpoint $name: HTTP $response (expected $expected_code)"
        return 1
    fi
}

# Check Prometheus targets
check_prometheus_targets() {
    log_info "Checking Prometheus targets..."

    local targets=$(curl -sf "http://localhost:9090/api/v1/targets" 2>/dev/null)

    if [ -z "$targets" ]; then
        log_error "Cannot fetch Prometheus targets"
        return 1
    fi

    local active_targets=$(echo "$targets" | grep -o '"health":"up"' | wc -l)
    local down_targets=$(echo "$targets" | grep -o '"health":"down"' | wc -l)

    if [ "$down_targets" -eq 0 ]; then
        log_success "Prometheus targets: $active_targets up, 0 down"
    else
        log_warning "Prometheus targets: $active_targets up, $down_targets down"
    fi
}

# Check Prometheus rules
check_prometheus_rules() {
    log_info "Checking Prometheus alert rules..."

    local rules=$(curl -sf "http://localhost:9090/api/v1/rules" 2>/dev/null)

    if [ -z "$rules" ]; then
        log_error "Cannot fetch Prometheus rules"
        return 1
    fi

    local total_rules=$(echo "$rules" | grep -o '"name":' | wc -l)

    if [ "$total_rules" -gt 0 ]; then
        log_success "Prometheus rules: $total_rules rules loaded"
    else
        log_warning "Prometheus rules: no rules loaded"
    fi
}

# Check Loki
check_loki() {
    log_info "Checking Loki..."

    # Check readiness
    local ready=$(curl -sf "http://localhost:3100/ready" 2>/dev/null || echo "not ready")

    if [ "$ready" = "ready" ]; then
        log_success "Loki: ready"
    else
        log_error "Loki: $ready"
        return 1
    fi
}

# Check Grafana datasources
check_grafana_datasources() {
    log_info "Checking Grafana datasources..."

    local datasources=$(curl -sf -u admin:admin "http://localhost:3000/api/datasources" 2>/dev/null)

    if [ -z "$datasources" ]; then
        log_error "Cannot fetch Grafana datasources"
        return 1
    fi

    local count=$(echo "$datasources" | grep -o '"id":' | wc -l)

    if [ "$count" -ge 2 ]; then
        log_success "Grafana datasources: $count configured"
    else
        log_warning "Grafana datasources: only $count configured"
    fi
}

# Check Alertmanager
check_alertmanager() {
    log_info "Checking Alertmanager..."

    local status=$(curl -sf "http://localhost:9093/api/v2/status" 2>/dev/null)

    if [ -n "$status" ]; then
        log_success "Alertmanager: operational"
    else
        log_error "Alertmanager: cannot fetch status"
        return 1
    fi
}

# Check volumes
check_volumes() {
    log_info "Checking data volumes..."

    local volumes=("prometheus_data" "grafana_data" "loki_data" "alertmanager_data")

    for vol in "${volumes[@]}"; do
        if docker volume inspect "$vol" &>/dev/null; then
            log_success "Volume $vol: exists"
        else
            log_error "Volume $vol: not found"
        fi
    done
}

# Check network
check_network() {
    log_info "Checking Docker network..."

    if docker network inspect monitoring-network &>/dev/null; then
        local containers=$(docker network inspect monitoring-network --format='{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null)
        log_success "Network monitoring-network: connected containers: $containers"
    else
        log_error "Network monitoring-network: not found"
    fi
}

# Check disk space
check_disk_space() {
    log_info "Checking disk space..."

    local usage=$(df -h . | awk 'NR==2 {print $5}' | tr -d '%')

    if [ "$usage" -lt 80 ]; then
        log_success "Disk space: ${usage}% used"
    elif [ "$usage" -lt 90 ]; then
        log_warning "Disk space: ${usage}% used (consider cleanup)"
    else
        log_error "Disk space: ${usage}% used (critical)"
    fi
}

# Generate validation report
generate_report() {
    local report_file="reports/validation-$(date '+%Y%m%d-%H%M%S').txt"
    mkdir -p reports

    {
        echo "=============================================="
        echo "  Validation Report"
        echo "  $(date '+%Y-%m-%d %H:%M:%S')"
        echo "=============================================="
        echo ""
        echo "Summary:"
        echo "  Total checks: $TOTAL_CHECKS"
        echo "  Passed: $PASSED_CHECKS"
        echo "  Warnings: $WARNING_CHECKS"
        echo "  Failed: $FAILED_CHECKS"
        echo ""
        echo "Container Status:"
        docker compose ps
        echo ""
        echo "Resource Usage:"
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null || echo "Stats not available"
    } > "$report_file"

    echo ""
    log_info "Validation report saved to: $report_file"
}

# Main execution
main() {
    print_banner

    echo "=== Container Health ==="
    check_container "prometheus"
    check_container "grafana"
    check_container "alertmanager"
    check_container "loki"
    check_container "promtail"
    check_container "node-exporter"
    check_container "cadvisor"
    check_container "blackbox-exporter"
    echo ""

    echo "=== Service Endpoints ==="
    check_endpoint "Prometheus" "http://localhost:9090/-/healthy"
    check_endpoint "Grafana" "http://localhost:3000/api/health"
    check_endpoint "Alertmanager" "http://localhost:9093/-/healthy"
    echo ""

    echo "=== Component Validation ==="
    check_prometheus_targets
    check_prometheus_rules
    check_loki
    check_grafana_datasources
    check_alertmanager
    echo ""

    echo "=== Infrastructure ==="
    check_volumes
    check_network
    check_disk_space
    echo ""

    generate_report

    echo ""
    echo "=============================================="
    echo "  Validation Summary"
    echo "=============================================="
    echo "  Total: $TOTAL_CHECKS | Passed: $PASSED_CHECKS | Warnings: $WARNING_CHECKS | Failed: $FAILED_CHECKS"
    echo "=============================================="

    if [ $FAILED_CHECKS -gt 0 ]; then
        exit 1
    fi
}

main "$@"
