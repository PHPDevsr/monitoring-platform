#!/bin/sh
# =============================================================================
# Alertmanager Entrypoint Script
# =============================================================================
# 1. Substitutes ${VAR} placeholders from environment variables
# 2. Expands {{EMAIL_CONFIG_*}} / {{SLACK_CONFIG_*}} markers into email/slack
#    configs only when the relevant credentials are present, otherwise removes
#    them so the rendered YAML stays valid without SMTP/Slack.
# 3. Starts Alertmanager
# =============================================================================

set -e

CONFIG_TEMPLATE="/etc/alertmanager/alertmanager.yml.tmpl"
CONFIG_FILE="/etc/alertmanager/alertmanager.yml"

# --- Step 1: ${VAR} substitution -------------------------------------------
# Replaces ${VAR_NAME} placeholders with the value of the matching environment
# variable. Implemented with awk instead of a shell string-chopping loop or
# eval, because busybox ash (the image's /bin/sh) rejects the brace matching in
# ${line#*\$\{} (hangs) and the eval indirection ("bad substitution"). awk is
# present in the Alpine-based alertmanager image; ENVIRON[] reads env values
# directly with no shell brace expansion.
substitute_vars() {
    awk '{
        line = $0
        while (match(line, /\$\{[A-Za-z_][A-Za-z0-9_]*\}/)) {
            name = substr(line, RSTART + 2, RLENGTH - 3)
            line = substr(line, 1, RSTART - 1) ENVIRON[name] substr(line, RSTART + RLENGTH)
        }
        print line
    }' "$1" > "$2"
}

# --- Step 2: receiver marker expansion -------------------------------------
# Builds the email_configs / slack_configs YAML snippets, or empty lines.
expand_markers() {
    # Email config blocks (only when SMTP host and recipient are set)
    if [ -n "${SMTP_SMARTHOST:-}" ] && [ -n "${ALERT_EMAIL_TO:-}" ]; then
        EMAIL_CONFIG_DEFAULT="email_configs:
      - to: '${ALERT_EMAIL_TO}'
        send_resolved: true
        headers:
          Subject: '[ALERT] {{ .GroupLabels.alertname }}'"
        EMAIL_CONFIG_CRITICAL="email_configs:
      - to: '${ALERT_EMAIL_TO}'
        send_resolved: true
        headers:
          Subject: '[CRITICAL] {{ .GroupLabels.alertname }}'"
        EMAIL_CONFIG_WARNING="email_configs:
      - to: '${ALERT_EMAIL_TO}'
        send_resolved: true
        headers:
          Subject: '[WARNING] {{ .GroupLabels.alertname }}'"
        EMAIL_CONFIG_PROBE="email_configs:
      - to: '${ALERT_EMAIL_TO}'
        send_resolved: true
        headers:
          Subject: '[PROBE] {{ .GroupLabels.alertname }}'"
        # Global SMTP block emitted only with email creds so the rendered
        # config never contains empty smtp_* fields that amtool would reject.
        SMTP_GLOBAL="  smtp_smarthost: '${SMTP_SMARTHOST}'
  smtp_from: '${SMTP_FROM}'
  smtp_auth_username: '${SMTP_AUTH_USERNAME}'
  smtp_auth_password: '${SMTP_AUTH_PASSWORD}'
  smtp_require_tls: ${SMTP_REQUIRE_TLS}"
    else
        EMAIL_CONFIG_DEFAULT=""
        EMAIL_CONFIG_CRITICAL=""
        EMAIL_CONFIG_WARNING=""
        EMAIL_CONFIG_PROBE=""
        SMTP_GLOBAL=""
    fi

    # Slack config blocks (only when webhook URL is set)
    if [ -n "${SLACK_API_URL:-}" ]; then
        SLACK_CONFIG_CRITICAL="slack_configs:
      - channel: '${SLACK_CHANNEL_CRITICAL:-#alerts}'
        send_resolved: true
        title: '{{ .Status | toUpper }}: {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'"
        SLACK_CONFIG_WARNING="slack_configs:
      - channel: '${SLACK_CHANNEL_WARNING:-#alerts}'
        send_resolved: true
        title: '{{ .Status | toUpper }}: {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'"
        # Global Slack API URL emitted only with a webhook URL set.
        SLACK_GLOBAL="  slack_api_url: '${SLACK_API_URL}'"
    else
        SLACK_CONFIG_CRITICAL=""
        SLACK_CONFIG_WARNING=""
        SLACK_GLOBAL=""
    fi

    # Replace markers using sed
    sed \
        -e "s|{{EMAIL_CONFIG_DEFAULT}}|${EMAIL_CONFIG_DEFAULT}|" \
        -e "s|{{EMAIL_CONFIG_CRITICAL}}|${EMAIL_CONFIG_CRITICAL}|" \
        -e "s|{{EMAIL_CONFIG_WARNING}}|${EMAIL_CONFIG_WARNING}|" \
        -e "s|{{EMAIL_CONFIG_PROBE}}|${EMAIL_CONFIG_PROBE}|" \
        -e "s|{{SLACK_CONFIG_CRITICAL}}|${SLACK_CONFIG_CRITICAL}|" \
        -e "s|{{SLACK_CONFIG_WARNING}}|${SLACK_CONFIG_WARNING}|" \
        -e "s|{{SMTP_GLOBAL}}|${SMTP_GLOBAL}|" \
        -e "s|{{SLACK_GLOBAL}}|${SLACK_GLOBAL}|" \
        "$1" > "$2"
}

# --- Main -----------------------------------------------------------------
if [ -f "$CONFIG_TEMPLATE" ]; then
    echo "[entrypoint] Processing alertmanager config template..."

    # Step 1: variable substitution into temp file
    TMP_FILE="/tmp/alertmanager.yml.subst"
    substitute_vars "$CONFIG_TEMPLATE" "$TMP_FILE"

    # Step 2: expand receiver markers
    expand_markers "$TMP_FILE" "$CONFIG_FILE"
    rm -f "$TMP_FILE"

    echo "[entrypoint] Config generated at $CONFIG_FILE"
else
    echo "[entrypoint] No template found, using existing config"
fi

# Debug: print generated config
echo "[entrypoint] === Generated config ==="
cat "$CONFIG_FILE"
echo "[entrypoint] === End config ==="

# Start Alertmanager (unless only rendering was requested)
if [ "${AM_RENDER_ONLY:-0}" = "1" ]; then
    echo "[entrypoint] AM_RENDER_ONLY=1, exiting after render"
    exit 0
fi

echo "[entrypoint] Starting Alertmanager..."
exec /bin/alertmanager "$@"
