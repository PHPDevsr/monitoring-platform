#!/bin/sh
# Render TLS verification settings into a writable runtime config.
set -eu

BLACKBOX_INSECURE_SKIP_VERIFY=${BLACKBOX_INSECURE_SKIP_VERIFY:-false}
case "$BLACKBOX_INSECURE_SKIP_VERIFY" in
    true|false) ;;
    *)
        echo "BLACKBOX_INSECURE_SKIP_VERIFY must be true or false" >&2
        exit 1
        ;;
esac

# Keep the mounted source read-only; replace only explicit TLS boolean settings.
export BLACKBOX_INSECURE_SKIP_VERIFY
awk '
    /^[[:space:]]*insecure_skip_verify:/ {
        sub(/(true|false)/, ENVIRON["BLACKBOX_INSECURE_SKIP_VERIFY"])
    }
    { print }
' \
    /etc/blackbox/blackbox.yml > /tmp/blackbox.yml

exec /bin/blackbox_exporter "$@"
