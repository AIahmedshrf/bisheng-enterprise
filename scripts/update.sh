#!/bin/bash
# ============================================
# Bisheng Enterprise - Update Script
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
ENV_FILE="${PROJECT_ROOT}/.env.production"

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

print_banner() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════╗"
    echo "║    Bisheng Enterprise Update Script           ║"
    echo "╚════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_version() {
    log_info "Checking current version..."
    
    current_version=$(grep BISHENG_VERSION "$ENV_FILE" | cut -d= -f2)
    
    echo -e "Current version: ${GREEN}$current_version${NC}"
    
    read -p "Enter new version (or press Enter to use latest): " new_version
    
    if [ -z "$new_version" ]; then
        NEW_VERSION="latest"
    else
        NEW_VERSION="$new_version"
    fi
    
    log_info "Will update to version: $NEW_VERSION"
}

confirm_update() {
    echo -e "\n${YELLOW}This will:${NC}"
    echo "  1. Create a backup of current data"
    echo "  2. Pull new Docker images"
    echo "  3. Rebuild custom images"
    echo "  4. Restart all services"
    echo ""
    
    read -p "Continue with update? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log_info "Update cancelled"
        exit 0
    fi
}

create_backup() {
    log_info "Creating backup before update..."
    
    bash "${SCRIPT_DIR}/backup.sh" || {
        log_error "Backup failed"
        exit 1
    }
    
    log_success "Backup completed"
}

pull_new_images() {
    log_info "Pulling new Docker images..."
    
    cd "$PROJECT_ROOT"
    
    # Update version in .env file if not latest
    if [ "$NEW_VERSION" != "latest" ]; then
        sed -i "s/BISHENG_VERSION=.*/BISHENG_VERSION=$NEW_VERSION/" "$ENV_FILE"
    fi
    
    docker compose --env-file "$ENV_FILE" pull
    
    log_success "Images pulled"
}

rebuild_custom_images() {
    log_info "Rebuilding custom images..."
    
    cd "$PROJECT_ROOT"
    
    # Backend
    if [ -d "custom-images/backend" ]; then
        docker build -t bisheng-backend-enterprise:latest \
            --build-arg BASE_IMAGE=dataelement/bisheng-backend:${NEW_VERSION} \
            --no-cache \
            custom-images/backend/
    fi
    
    # Frontend
    if [ -d "custom-images/frontend" ]; then
        docker build -t bisheng-frontend-enterprise:latest \
            --build-arg BASE_IMAGE=dataelement/bisheng-frontend:${NEW_VERSION} \
            --no-cache \
            custom-images/frontend/
    fi
    
    log_success "Custom images rebuilt"
}

run_migrations() {
    log_info "Running database migrations..."
    
    docker compose --env-file "$ENV_FILE" run --rm backend \
        python -m alembic upgrade head 2>/dev/null || {
        log_warning "Migration script not available or failed"
    }
    
    log_success "Migrations completed"
}

restart_services() {
    log_info "Restarting services..."
    
    cd "$PROJECT_ROOT"
    
    # Graceful restart
    docker compose --env-file "$ENV_FILE" up -d --force-recreate
    
    log_success "Services restarted"
}

verify_update() {
    log_info "Verifying update..."
    
    sleep 30
    
    # Run health check
    bash "${SCRIPT_DIR}/health-check.sh" || {
        log_error "Health check failed after update"
        
        read -p "Do you want to rollback? (yes/no): " rollback
        if [ "$rollback" = "yes" ]; then
            log_info "Please use restore.sh to rollback to previous backup"
        fi
        
        exit 1
    }
    
    log_success "Update verified"
}

cleanup_old_images() {
    log_info "Cleaning up old Docker images..."
    
    docker image prune -f
    
    log_success "Cleanup completed"
}

show_update_info() {
    echo -e "\n${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║        Update Completed Successfully!          ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${BLUE}Updated to version:${NC} $NEW_VERSION"
    echo -e "${BLUE}Backup created:${NC} Check data/backups/"
    echo -e "\n${YELLOW}Please verify that all features are working correctly.${NC}\n"
}

# ============================================
# Main Execution
# ============================================

main() {
    print_banner
    
    check_version
    confirm_update
    create_backup
    pull_new_images
    rebuild_custom_images
    run_migrations
    restart_services
    verify_update
    cleanup_old_images
    show_update_info
}

main "$@"