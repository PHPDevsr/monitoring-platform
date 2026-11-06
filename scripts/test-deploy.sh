#!/bin/bash
# Regression checks for deploy readiness; Docker and time are simulated.
set -euo pipefail
cd "$(dirname "$0")/.."
source <(sed '$d' scripts/deploy.sh)

test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

docker() {
    local args="$*" service="${!#}"
    if [[ "$args" == *'{{.State.Status}}'* ]]; then
        if [[ "$SCENARIO" == exited && "$service" == loki ]]; then
            echo exited
        else
            echo running
        fi
    elif [[ "$args" == *'{{json .State.Health}}'* ]]; then
        echo 'healthcheck diagnostic output'
    elif [[ "$args" == *'.State.Health.Status'* ]]; then
        if [[ "$service" == loki || "$SCENARIO" == no-health ]]; then
            echo none
        elif [[ "$SCENARIO" == unhealthy && "$service" == promtail ]]; then
            echo unhealthy
        else
            echo healthy
        fi
    elif [[ "$args" == 'compose exec -T prometheus wget -q -T 5 -O /dev/null http://loki:3100/ready' ]]; then
        echo probe >> "$test_dir/probes"
        [[ "$SCENARIO" != timeout ]] || return 1
        if [[ "$SCENARIO" == retry && ! -f "$test_dir/retried" ]]; then
            touch "$test_dir/retried"
            return 1
        fi
        return 0
    elif [[ "$args" == 'compose logs '* || "$1" == inspect ]]; then
        echo 'container diagnostics'
    else
        echo "Unexpected Docker invocation: $args" >&2
        return 2
    fi
}

date() {
    # A file preserves simulated time across command-substitution subshells.
    local tick
    tick=$(cat "$test_dir/time")
    echo "$((tick + 1))" > "$test_dir/time"
    echo "$tick"
}
sleep() { :; }

check_scenario() {
    SCENARIO=$1
    echo 0 > "$test_dir/time"
    : > "$test_dir/probes"
    local output code=0
    output=$( (DEPLOY_TIMEOUT=5; wait_for_health) 2>&1) || code=$?
    if [[ "$code" != "$2" || "$output" != *"$3"* ]]; then
        printf 'FAIL %s (exit %s):\n%s\n' "$SCENARIO" "$code" "$output"
        exit 1
    fi
    if [[ "$SCENARIO" == retry && $(wc -l < "$test_dir/probes") != 2 ]]; then
        echo 'FAIL: Loki readiness was not retried'
        exit 1
    fi
    printf 'PASS %s\n' "$SCENARIO"
}

check_scenario ready 0 'All services are healthy'
check_scenario retry 0 'All services are healthy'
check_scenario timeout 1 'Timeout waiting for loki'
check_scenario exited 1 'loki is exited'
check_scenario unhealthy 1 'healthcheck diagnostic output'
check_scenario no-health 1 'prometheus has no healthcheck configured'

# URL splitting must preserve the scheme and port.
endpoint='http://localhost:9090/-/healthy:Prometheus'
[[ "${endpoint%:*}" == 'http://localhost:9090/-/healthy' ]]
echo 'PASS endpoint URL parsing'
