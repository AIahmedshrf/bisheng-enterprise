#!/bin/bash
# ============================================
# Redis Backup Script
# ============================================

set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups/redis"
BACKUP_FILE="${BACKUP_DIR}/dump_${TIMESTAMP}.rdb"

mkdir -p "$BACKUP_DIR"

echo "[INFO] Backing up Redis..."

# Trigger Redis save
redis-cli -h "${REDIS_HOST}" -a "${REDIS_PASSWORD}" --no-auth-warning SAVE

# Copy RDB file
sleep 2
scp "redis@${REDIS_HOST}:/data/dump.rdb" "$BACKUP_FILE" 2>/dev/null || \
    docker cp bisheng-redis:/data/dump.rdb "$BACKUP_FILE"

BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)

echo "[SUCCESS] Redis backup completed: $BACKUP_FILE ($BACKUP_SIZE)"