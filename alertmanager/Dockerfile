# =============================================================================
# Alertmanager Custom Image
# =============================================================================
# Uses pure shell-based variable substitution (no external tools needed)
# =============================================================================

FROM prom/alertmanager:v0.33.1

# Copy entrypoint script
COPY --chmod=755 entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["--config.file=/etc/alertmanager/alertmanager.yml", "--storage.path=/alertmanager"]
