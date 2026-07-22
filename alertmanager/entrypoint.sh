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
        result=""
        remaining="$line"
        while [ -n "$remaining" ]; do
            case "$remaining" in
                *'${'*)
                    # Get text before ${var}
                    prefix="${remaining%%\$\{}*}"
                    result="${result}${prefix}"
                    remaining="${remaining#*\$\{}"

                    # Extract variable name
                    var="${remaining%%\}*}"
                    remaining="${remaining#*$var\}}"

                    # Get value from environment variable (use default empty string if unset)
                    eval "value=\"\${$var:-}\""
                    result="${result}${value}"
                    ;;
                *)
                    result="${result}${remaining}"
                    remaining=""
                    ;;
            esac
        done
        echo "$result"
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

# Start Alertmanager
echo "[entrypoint] Starting Alertmanager..."
exec /bin/alertmanager "$@"
