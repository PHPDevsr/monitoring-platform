#!/bin/sh
# =============================================================================
# Alertmanager Entrypoint Script
# =============================================================================
# Processes the config template with environment variables substitution
# then starts Alertmanager
# =============================================================================

set -e

CONFIG_TEMPLATE="/etc/alertmanager/alertmanager.yml.tmpl"
CONFIG_FILE="/etc/alertmanager/alertmanager.yml"

# Check if template exists
if [ -f "$CONFIG_TEMPLATE" ]; then
    echo "[entrypoint] Processing alertmanager config template..."

    # Substitute environment variables
    envsubst < "$CONFIG_TEMPLATE" > "$CONFIG_FILE"

    echo "[entrypoint] Config generated at $CONFIG_FILE"
else
    echo "[entrypoint] No template found, using existing config"
fi

# Start Alertmanager
echo "[entrypoint] Starting Alertmanager..."
exec /bin/alertmanager "$@"
