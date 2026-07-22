#!/bin/sh
# =============================================================================
# Alertmanager Entrypoint Script
# =============================================================================
# Processes the config template with shell-based variable substitution
# then starts Alertmanager
# =============================================================================

set -e

CONFIG_TEMPLATE="/etc/alertmanager/alertmanager.yml.tmpl"
CONFIG_FILE="/etc/alertmanager/alertmanager.yml"

# Substitute environment variables in template using pure POSIX shell
# Replaces ${VAR_NAME} patterns with their environment variable values
process_template() {
    while IFS= read -r line || [ -n "$line" ]; do
        # Process until no more ${VAR} patterns exist
        while [ "$line" != "${line#*\$\{}" ]; do
            prefix="${line%%\$\{}*}"
            rest="${line#*\$\{}"
            var="${rest%%\}*}"
            suffix="${rest#*$var\}}"
            eval "val=\"\${$var:-}\""
            line="${prefix}${val}${suffix}"
        done
        echo "$line"
    done < "$1" > "$2"
}

# Check if template exists
if [ -f "$CONFIG_TEMPLATE" ]; then
    echo "[entrypoint] Processing alertmanager config template..."

    # Substitute environment variables
    process_template "$CONFIG_TEMPLATE" "$CONFIG_FILE"

    echo "[entrypoint] Config generated at $CONFIG_FILE"
else
    echo "[entrypoint] No template found, using existing config"
fi

# Debug: print generated config
echo "[entrypoint] === Generated config ==="
cat "$CONFIG_FILE"
echo "[entrypoint] === End config ==="

# Start Alertmanager
echo "[entrypoint] Starting Alertmanager..."
exec /bin/alertmanager "$@"
