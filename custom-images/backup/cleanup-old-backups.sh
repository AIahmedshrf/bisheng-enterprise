#!/bin/bash
# ============================================
# Cleanup Old Backups Script
# ============================================

RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-30}
BACKUP_ROOT="/backups"

echo "[INFO] Cleaning up backups older than ${RETENTION_DAYS} days..."

# Find and delete old files
find "$BACKUP_ROOT" -type f -mtime +${RETENTION_DAYS} -delete

# Find and delete empty directories
find "$BACKUP_ROOT" -type d -empty -delete

echo "[SUCCESS] Cleanup completed"