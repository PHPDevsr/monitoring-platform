# =============================================================================
# Alertmanager Custom Image
# =============================================================================
# Extends official image with envsubst for environment variable substitution
# =============================================================================

FROM prom/alertmanager:v0.33.1

# Switch to root to install packages
USER root

# Install envsubst (part of gettext)
RUN apk add --no-cache gettext

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Switch back to nobody user
USER nobody

ENTRYPOINT ["/entrypoint.sh"]
CMD ["--config.file=/etc/alertmanager/alertmanager.yml", "--storage.path=/alertmanager"]
