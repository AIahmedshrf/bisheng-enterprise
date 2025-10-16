#!/bin/bash
# ============================================
# MinIO Backup Script
# ============================================

set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups/minio/bisheng_${TIMESTAMP}"

mkdir -p "$BACKUP_DIR"

echo "[INFO] Backing up MinIO data..."

# Configure MinIO client
mc alias set minio "${MINIO_ENDPOINT}" "${MINIO_ACCESS_KEY}" "${MINIO_SECRET_KEY}"

# Mirror bucket
mc mirror --overwrite minio/bisheng "$BACKUP_DIR"

BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)

echo "[SUCCESS] MinIO backup completed: $BACKUP_DIR ($BACKUP_SIZE)"