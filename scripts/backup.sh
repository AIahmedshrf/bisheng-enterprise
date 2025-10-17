#!/bin/bash
# ============================================
# Bisheng Enterprise - Backup Script
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${PROJECT_ROOT}/data/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ENV_FILE="${PROJECT_ROOT}/.env.production"

# Load environment variables
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
fi

# ============================================
# Functions
# ============================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

backup_postgres() {
    log_info "Backing up PostgreSQL database..."
    
    mkdir -p "${BACKUP_DIR}/postgres"
    
    docker exec bisheng-postgres pg_dump \
        -U "${POSTGRES_USER}" \
        -d "${POSTGRES_DB}" \
        --clean \
        --if-exists \
        --format=custom \
        --compress=9 \
        > "${BACKUP_DIR}/postgres/backup_${TIMESTAMP}.dump"
    
    log_success "PostgreSQL backup completed"
}

backup_redis() {
    log_info "Backing up Redis..."
    
    mkdir -p "${BACKUP_DIR}/redis"
    
    # Trigger Redis save
    docker exec bisheng-redis redis-cli -a "${REDIS_PASSWORD}" --no-auth-warning SAVE
    
    # Copy RDB file
    docker cp bisheng-redis:/data/dump.rdb "${BACKUP_DIR}/redis/dump_${TIMESTAMP}.rdb"
    
    log_success "Redis backup completed"
}

backup_minio() {
    log_info "Backing up MinIO data..."
    
    mkdir -p "${BACKUP_DIR}/minio"
    
    # Use MinIO client to backup
    docker run --rm \
        --network bisheng-enterprise_bisheng-network \
        -v "${BACKUP_DIR}/minio:/backup" \
        minio/mc \
        mirror --overwrite \
        minio/bisheng \
        /backup/bisheng_${TIMESTAMP}
    
    log_success "MinIO backup completed"
}

backup_configs() {
    log_info "Backing up configurations..."
    
    mkdir -p "${BACKUP_DIR}/configs"
    
    tar -czf "${BACKUP_DIR}/configs/configs_${TIMESTAMP}.tar.gz" \
        -C "${PROJECT_ROOT}" \
        configs \
        .env.production
    
    log_success "Configurations backup completed"
}

cleanup_old_backups() {
    log_info "Cleaning up old backups..."
    
    RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-30}
    
    find "${BACKUP_DIR}" -type f -mtime +${RETENTION_DAYS} -delete
    
    log_success "Old backups cleaned up (retention: ${RETENTION_DAYS} days)"
}

create_backup_manifest() {
    log_info "Creating backup manifest..."
    
    cat > "${BACKUP_DIR}/manifest_${TIMESTAMP}.json" <<EOF
{
  "timestamp": "${TIMESTAMP}",
  "date": "$(date -Iseconds)",
  "version": "2.0",
  "backups": {
    "postgres": "postgres/backup_${TIMESTAMP}.dump",
    "redis": "redis/dump_${TIMESTAMP}.rdb",
    "minio": "minio/bisheng_${TIMESTAMP}",
    "configs": "configs/configs_${TIMESTAMP}.tar.gz"
  },
  "sizes": {
    "postgres": "$(du -h "${BACKUP_DIR}/postgres/backup_${TIMESTAMP}.dump" | cut -f1)",
    "redis": "$(du -h "${BACKUP_DIR}/redis/dump_${TIMESTAMP}.rdb" | cut -f1)",
    "configs": "$(du -h "${BACKUP_DIR}/configs/configs_${TIMESTAMP}.tar.gz" | cut -f1)"
  }
}
EOF
    
    log_success "Backup manifest created"
}

# ============================================
# Main Execution
# ============================================

main() {
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   Bisheng Enterprise Backup Script    ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}\n"
    
    backup_postgres
    backup_redis
    backup_minio
    backup_configs
    create_backup_manifest
    cleanup_old_backups
    
    echo -e "\n${GREEN}✓ Backup completed successfully!${NC}"
    echo -e "Backup location: ${BACKUP_DIR}"
    echo -e "Timestamp: ${TIMESTAMP}\n"
}

main "$@"