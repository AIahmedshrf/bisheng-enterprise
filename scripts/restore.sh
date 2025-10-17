#!/bin/bash
# ============================================
# Bisheng Enterprise - Restore Script
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

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

list_backups() {
    echo -e "\n${BLUE}Available backups:${NC}\n"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        log_error "Backup directory not found: $BACKUP_DIR"
        exit 1
    fi
    
    local manifests=($(ls -1t "${BACKUP_DIR}"/manifest_*.json 2>/dev/null))
    
    if [ ${#manifests[@]} -eq 0 ]; then
        log_warning "No backups found"
        exit 0
    fi
    
    local i=1
    for manifest in "${manifests[@]}"; do
        local timestamp=$(basename "$manifest" .json | sed 's/manifest_//')
        local date=$(jq -r '.date' "$manifest" 2>/dev/null || echo "Unknown")
        echo -e "  ${GREEN}[$i]${NC} Backup: $timestamp (Created: $date)"
        i=$((i + 1))
    done
    
    echo ""
}

select_backup() {
    list_backups
    
    read -p "Enter backup number to restore (or timestamp): " selection
    
    # Check if it's a number or timestamp
    if [[ "$selection" =~ ^[0-9]+$ ]]; then
        local manifests=($(ls -1t "${BACKUP_DIR}"/manifest_*.json 2>/dev/null))
        local index=$((selection - 1))
        
        if [ $index -ge 0 ] && [ $index -lt ${#manifests[@]} ]; then
            SELECTED_MANIFEST="${manifests[$index]}"
            BACKUP_TIMESTAMP=$(basename "$SELECTED_MANIFEST" .json | sed 's/manifest_//')
        else
            log_error "Invalid selection"
            exit 1
        fi
    else
        BACKUP_TIMESTAMP="$selection"
        SELECTED_MANIFEST="${BACKUP_DIR}/manifest_${BACKUP_TIMESTAMP}.json"
        
        if [ ! -f "$SELECTED_MANIFEST" ]; then
            log_error "Backup not found: $BACKUP_TIMESTAMP"
            exit 1
        fi
    fi
    
    log_info "Selected backup: $BACKUP_TIMESTAMP"
}

confirm_restore() {
    echo -e "\n${YELLOW}WARNING: This will restore data from backup!${NC}"
    echo -e "${YELLOW}Current data will be backed up before restoration.${NC}\n"
    
    read -p "Are you sure you want to continue? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log_info "Restore cancelled"
        exit 0
    fi
}

backup_current_data() {
    log_info "Backing up current data before restoration..."
    
    SAFETY_BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)_pre_restore
    
    bash "${SCRIPT_DIR}/backup.sh" || {
        log_error "Failed to backup current data"
        exit 1
    }
    
    log_success "Current data backed up"
}

stop_services() {
    log_info "Stopping services..."
    
    cd "$PROJECT_ROOT"
    docker compose --env-file "$ENV_FILE" stop backend backend-worker frontend
    
    log_success "Services stopped"
}

restore_postgres() {
    log_info "Restoring PostgreSQL database..."
    
    local dump_file="${BACKUP_DIR}/postgres/backup_${BACKUP_TIMESTAMP}.dump"
    
    if [ ! -f "$dump_file" ]; then
        log_error "PostgreSQL backup file not found: $dump_file"
        return 1
    fi
    
    # Drop and recreate database
    docker exec bisheng-postgres psql -U "${POSTGRES_USER}" -c "DROP DATABASE IF EXISTS ${POSTGRES_DB};"
    docker exec bisheng-postgres psql -U "${POSTGRES_USER}" -c "CREATE DATABASE ${POSTGRES_DB};"
    
    # Restore from dump
    cat "$dump_file" | docker exec -i bisheng-postgres pg_restore \
        -U "${POSTGRES_USER}" \
        -d "${POSTGRES_DB}" \
        --clean \
        --if-exists \
        --no-owner \
        --no-acl
    
    log_success "PostgreSQL database restored"
}

restore_redis() {
    log_info "Restoring Redis data..."
    
    local rdb_file="${BACKUP_DIR}/redis/dump_${BACKUP_TIMESTAMP}.rdb"
    
    if [ ! -f "$rdb_file" ]; then
        log_error "Redis backup file not found: $rdb_file"
        return 1
    fi
    
    # Stop Redis
    docker compose --env-file "$ENV_FILE" stop redis
    
    # Copy RDB file
    docker cp "$rdb_file" bisheng-redis:/data/dump.rdb
    
    # Start Redis
    docker compose --env-file "$ENV_FILE" start redis
    
    sleep 5
    
    log_success "Redis data restored"
}

restore_minio() {
    log_info "Restoring MinIO data..."
    
    local minio_backup="${BACKUP_DIR}/minio/bisheng_${BACKUP_TIMESTAMP}"
    
    if [ ! -d "$minio_backup" ]; then
        log_error "MinIO backup not found: $minio_backup"
        return 1
    fi
    
    # Use MinIO client to restore
    docker run --rm \
        --network bisheng-enterprise_bisheng-network \
        -v "${minio_backup}:/backup" \
        minio/mc \
        mirror --overwrite \
        /backup \
        minio/bisheng
    
    log_success "MinIO data restored"
}

restore_configs() {
    log_info "Restoring configurations..."
    
    local config_backup="${BACKUP_DIR}/configs/configs_${BACKUP_TIMESTAMP}.tar.gz"
    
    if [ ! -f "$config_backup" ]; then
        log_warning "Configuration backup not found, skipping..."
        return 0
    fi
    
    # Extract configs to temporary directory
    local temp_dir=$(mktemp -d)
    tar -xzf "$config_backup" -C "$temp_dir"
    
    # Ask user if they want to restore configs
    read -p "Do you want to restore configurations? (yes/no): " restore_configs
    
    if [ "$restore_configs" = "yes" ]; then
        cp -r "$temp_dir/configs/"* "${PROJECT_ROOT}/configs/"
        log_success "Configurations restored"
    else
        log_info "Skipping configuration restore"
    fi
    
    rm -rf "$temp_dir"
}

start_services() {
    log_info "Starting services..."
    
    cd "$PROJECT_ROOT"
    docker compose --env-file "$ENV_FILE" up -d
    
    log_success "Services started"
}

verify_restore() {
    log_info "Verifying restoration..."
    
    sleep 30
    
    # Check backend health
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s http://localhost:7860/api/v1/health > /dev/null 2>&1; then
            log_success "Backend is healthy"
            break
        fi
        
        log_info "Waiting for backend... (attempt $attempt/$max_attempts)"
        sleep 5
        attempt=$((attempt + 1))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log_warning "Backend health check timeout, please verify manually"
    fi
}

show_restore_info() {
    echo -e "\n${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║       Restoration Completed Successfully!      ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${BLUE}Restored from backup:${NC} $BACKUP_TIMESTAMP"
    echo -e "${BLUE}Safety backup created:${NC} $SAFETY_BACKUP_TIMESTAMP"
    echo -e "\n${YELLOW}Please verify that all data has been restored correctly.${NC}\n"
}

# ============================================
# Main Execution
# ============================================

main() {
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Bisheng Enterprise Restore Script    ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    
    select_backup
    confirm_restore
    backup_current_data
    stop_services
    restore_postgres
    restore_redis
    restore_minio
    restore_configs
    start_services
    verify_restore
    show_restore_info
}

main "$@"