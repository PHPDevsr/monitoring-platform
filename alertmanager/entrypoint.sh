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
# Replaces {{EMAIL_CONFIG_*}}, {{SLACK_CONFIG_*}}, {{SMTP_GLOBAL}} and
# {{SLACK_GLOBAL}} markers with email/slack/global YAML blocks, but only when
# the relevant credentials are present; otherwise the markers are removed so
# the rendered config stays valid without SMTP/Slack.
#
# The blocks are multi-line, which sed cannot substitute (an embedded newline
# terminates the s command). Instead a single awk program reads the scalar env
# values via ENVIRON[] and builds each block as an awk string literal with
# explicit "\n" separators, then gsub()s the marker on each input line. gsub
# emits the embedded newlines as real line breaks in the output. The scalar
# values are also escaped for gsub (which treats & and \ specially in the
# replacement) so credentials containing those characters stay intact.
expand_markers() {
    awk '
    function esc(s) { gsub(/\\/, "\\\\", s); gsub(/&/, "\\\\&", s); return s }
    function email_block(subj,    to) {
        to = esc(ENVIRON["ALERT_EMAIL_TO"])
        return "email_configs:\n      - to: \x27" to "\x27\n        send_resolved: true\n        headers:\n          Subject: \x27" subj " {{ .GroupLabels.alertname }}\x27"
    }
    function slack_block(ch,    c) {
        c = esc(ch)
        return "slack_configs:\n      - channel: \x27" c "\x27\n        send_resolved: true\n        title: \x27{{ .Status | toUpper }}: {{ .GroupLabels.alertname }}\x27\n        text: \x27{{ range .Alerts }}{{ .Annotations.description }}{{ end }}\x27"
    }
    function smtp_global(    h, f, u, p, t) {
        h = esc(ENVIRON["SMTP_SMARTHOST"]); f = esc(ENVIRON["SMTP_FROM"])
        u = esc(ENVIRON["SMTP_AUTH_USERNAME"]); p = esc(ENVIRON["SMTP_AUTH_PASSWORD"])
        t = esc(ENVIRON["SMTP_REQUIRE_TLS"])
        return "  smtp_smarthost: \x27" h "\x27\n  smtp_from: \x27" f "\x27\n  smtp_auth_username: \x27" u "\x27\n  smtp_auth_password: \x27" p "\x27\n  smtp_require_tls: " t
    }
    function slack_global(    u) {
        u = esc(ENVIRON["SLACK_API_URL"])
        return "  slack_api_url: \x27" u "\x27"
    }
    BEGIN {
        # Initialise every marker to empty so unused ones are removed (not
        # left literally in the output, which amtool would reject).
        M["{{EMAIL_CONFIG_DEFAULT}}"]  = ""
        M["{{EMAIL_CONFIG_CRITICAL}}"] = ""
        M["{{EMAIL_CONFIG_WARNING}}"]  = ""
        M["{{EMAIL_CONFIG_PROBE}}"]    = ""
        M["{{SLACK_CONFIG_CRITICAL}}"] = ""
        M["{{SLACK_CONFIG_WARNING}}"]  = ""
        M["{{SMTP_GLOBAL}}"]           = ""
        M["{{SLACK_GLOBAL}}"]          = ""
        has_email = (ENVIRON["SMTP_SMARTHOST"] != "" && ENVIRON["ALERT_EMAIL_TO"] != "")
        has_slack = (ENVIRON["SLACK_API_URL"] != "")
        if (has_email) {
            M["{{EMAIL_CONFIG_DEFAULT}}"]  = email_block("[ALERT]")
            M["{{EMAIL_CONFIG_CRITICAL}}"] = email_block("[CRITICAL]")
            M["{{EMAIL_CONFIG_WARNING}}"]  = email_block("[WARNING]")
            M["{{EMAIL_CONFIG_PROBE}}"]    = email_block("[PROBE]")
            M["{{SMTP_GLOBAL}}"]           = smtp_global()
        }
        if (has_slack) {
            M["{{SLACK_CONFIG_CRITICAL}}"] = slack_block(ENVIRON["SLACK_CHANNEL_CRITICAL"])
            M["{{SLACK_CONFIG_WARNING}}"]  = slack_block(ENVIRON["SLACK_CHANNEL_WARNING"])
            M["{{SLACK_GLOBAL}}"]          = slack_global()
        }
    }
    # Replace each marker with its block using fixed-string substitution
    # (index + substr), not regex gsub: the markers contain {{ }} which are
    # regex interval chars and would need escaping, and the replacement values
    # may contain & or \ which gsub interprets specially. Fixed-string splice
    # avoids both pitfalls and is portable across awk implementations.
    function replace_str(s, find, repl,    out, p) {
        out = ""
        while ((p = index(s, find)) > 0) {
            out = out substr(s, 1, p - 1) repl
            s = substr(s, p + length(find))
        }
        return out s
    }
    {
        line = $0
        for (marker in M) {
            if (index(line, marker)) line = replace_str(line, marker, M[marker])
        }
        print line
    }
    ' "$1" > "$2"
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
