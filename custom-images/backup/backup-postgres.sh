#!/bin/bash
# ============================================
# PostgreSQL Backup Script
# ============================================

set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups/postgres"
BACKUP_FILE="${BACKUP_DIR}/backup_${TIMESTAMP}.dump"

mkdir -p "$BACKUP_DIR"

echo "[INFO] Backing up PostgreSQL database..."

# Perform backup
PGPASSWORD="${POSTGRES_PASSWORD}" pg_dump \
    -h "${POSTGRES_HOST}" \
    -U "${POSTGRES_USER}" \
    -d "${POSTGRES_DB}" \
    --clean \
    --if-exists \
    --format=custom \
    --compress=9 \
    --file="$BACKUP_FILE"

# Get backup size
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)

echo "[SUCCESS] PostgreSQL backup completed: $BACKUP_FILE ($BACKUP_SIZE)"