# ============================================
# Bisheng Backup Service
# ============================================
FROM alpine:3.19

LABEL maintainer="Bisheng Enterprise Team"
LABEL description="Automated Backup Service for Bisheng Enterprise"

# ============================================
# Install Dependencies
# ============================================
RUN apk add --no-cache \
    bash \
    curl \
    postgresql15-client \
    redis \
    python3 \
    py3-pip \
    docker-cli \
    aws-cli \
    gzip \
    tar \
    && rm -rf /var/cache/apk/*

# ============================================
# Install Python packages
# ============================================
RUN pip3 install --no-cache-dir \
    boto3 \
    schedule \
    python-dateutil \
    psycopg2-binary \
    redis

# ============================================
# Create directories
# ============================================
RUN mkdir -p /backups /scripts /logs && \
    chmod 755 /backups /scripts /logs

# ============================================
# Copy backup scripts
# ============================================
COPY backup-postgres.sh /scripts/backup-postgres.sh
COPY backup-redis.sh /scripts/backup-redis.sh
COPY backup-minio.sh /scripts/backup-minio.sh
COPY backup-scheduler.py /scripts/backup-scheduler.py
COPY cleanup-old-backups.sh /scripts/cleanup-old-backups.sh

RUN chmod +x /scripts/*.sh /scripts/*.py

# ============================================
# Working Directory
# ============================================
WORKDIR /scripts

# ============================================
# Entrypoint
# ============================================
CMD ["python3", "/scripts/backup-scheduler.py"]