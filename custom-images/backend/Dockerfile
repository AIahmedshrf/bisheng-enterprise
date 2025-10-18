# ============================================
# Bisheng Backend Enterprise - Simplified
# ============================================
ARG BASE_IMAGE=dataelement/bisheng-backend:v2.2.0-beta2
FROM ${BASE_IMAGE}

LABEL maintainer="Bisheng Enterprise Team"
LABEL version="2.0-enterprise-simplified"
LABEL description="Bisheng Backend with custom config"

# ============================================
# Environment
# ============================================
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1

# ============================================
# System packages (minimal)
# ============================================
USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# ============================================
# Python packages (minimal - only what's missing)
# ============================================
RUN pip install --no-cache-dir --upgrade \
    PyYAML \
    pydantic-settings \
    || true

# ============================================
# Create directories
# ============================================
RUN mkdir -p \
    /app/bisheng \
    /app/logs \
    /app/uploads \
    /app/temp \
    /app/cache && \
    chmod -R 777 /app/bisheng /app/logs /app/uploads /app/temp /app/cache

# ============================================
# Copy config.yaml
# ============================================
COPY configs/backend/config.yaml /app/bisheng/config.yaml
RUN chmod 644 /app/bisheng/config.yaml

# ============================================
# Copy scripts
# ============================================
COPY custom-images/backend/healthcheck.sh /usr/local/bin/healthcheck.sh
COPY custom-images/backend/entrypoint-enterprise.sh /usr/local/bin/entrypoint-enterprise.sh

RUN chmod +x /usr/local/bin/healthcheck.sh && \
    chmod +x /usr/local/bin/entrypoint-enterprise.sh

# ============================================
# User permissions
# ============================================
RUN if ! id -u bisheng > /dev/null 2>&1; then \
        useradd -m -u 1000 -s /bin/bash bisheng; \
    fi && \
    chown -R bisheng:bisheng /app 2>/dev/null || chown -R 1000:1000 /app

USER bisheng

# ============================================
# Expose & Health
# ============================================
EXPOSE 7860

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

# ============================================
# Entrypoint
# ============================================
ENTRYPOINT ["/usr/local/bin/entrypoint-enterprise.sh"]
CMD ["api"]
