# =============================================================================
# Alertmanager Custom Image
# =============================================================================
# Extends official image with envsubst for environment variable substitution
# =============================================================================

# Stage 1: Get envsubst from Alpine
FROM alpine:3.20 AS builder
RUN apk add --no-cache gettext

# Stage 2: Alertmanager with envsubst
FROM prom/alertmanager:v0.33.1

# Copy envsubst binary from builder
COPY --from=builder /usr/bin/envsubst /usr/bin/envsubst

# Copy entrypoint script
COPY --chmod=755 entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["--config.file=/etc/alertmanager/alertmanager.yml", "--storage.path=/alertmanager"]
