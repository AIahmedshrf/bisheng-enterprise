#!/bin/bash
# ============================================
# Bisheng Enterprise - Deployment Script
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_ROOT}/.env.production"

# ============================================
# Functions
# ============================================

print_banner() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════╗"
    echo "║                                                ║"
    echo "║     Bisheng Enterprise Deployment Script      ║"
    echo "║                 Version 2.0                    ║"
    echo "║                                                ║"
    echo "╚════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_requirements() {
    log_info "Checking requirements..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker compose &> /dev/null; then
        log_error "Docker Compose is not installed"
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        exit 1
    fi
    
    log_success "All requirements met"
}

check_env_file() {
    log_info "Checking environment file..."
    
    if [ ! -f "$ENV_FILE" ]; then
        log_warning ".env.production not found, creating from example..."
        if [ -f "${PROJECT_ROOT}/.env.example" ]; then
            cp "${PROJECT_ROOT}/.env.example" "$ENV_FILE"
            log_success "Created .env.production from example"
            log_warning "Please review and update .env.production with your settings"
            exit 0
        else
            log_error "No .env.example found"
            exit 1
        fi
    fi
    
    log_success "Environment file found"
}

create_directories() {
    log_info "Creating necessary directories..."
    
    cd "$PROJECT_ROOT"
    
    mkdir -p data/{postgresql,redis,milvus,elasticsearch,minio,backups}
    mkdir -p logs/{nginx,backend,worker,frontend}
    mkdir -p ssl
    mkdir -p configs/{nginx/conf.d,postgresql/init-scripts,prometheus/rules,grafana/{provisioning,dashboards}}
    
    log_success "Directories created"
}

generate_ssl_cert() {
    log_info "Checking SSL certificates..."
    
    if [ ! -f "${PROJECT_ROOT}/ssl/cert.pem" ] || [ ! -f "${PROJECT_ROOT}/ssl/key.pem" ]; then
        log_warning "SSL certificates not found, generating self-signed certificate..."
        
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "${PROJECT_ROOT}/ssl/key.pem" \
            -out "${PROJECT_ROOT}/ssl/cert.pem" \
            -subj "/C=US/ST=State/L=City/O=Bisheng/CN=localhost"
        
        log_success "Self-signed certificate generated"
        log_warning "For production, replace with a valid SSL certificate"
    else
        log_success "SSL certificates found"
    fi
}

build_custom_images() {
    log_info "Building custom Docker images..."
    
    cd "$PROJECT_ROOT"
    
    # Build backend image
    if [ -d "custom-images/backend" ]; then
        log_info "Building backend image..."
        docker build -t bisheng-backend-enterprise:latest \
            --build-arg BASE_IMAGE=dataelement/bisheng-backend:v2.2.0-beta2 \
            custom-images/backend/
        log_success "Backend image built"
    fi
    
    # Build frontend image
    if [ -d "custom-images/frontend" ]; then
        log_info "Building frontend image..."
        docker build -t bisheng-frontend-enterprise:latest \
            --build-arg BASE_IMAGE=dataelement/bisheng-frontend:v2.2.0-beta2 \
            custom-images/frontend/
        log_success "Frontend image built"
    fi
    
    # Build backup image
    if [ -d "custom-images/backup" ]; then
        log_info "Building backup image..."
        docker build -t bisheng-backup:latest custom-images/backup/
        log_success "Backup image built"
    fi
}

pull_images() {
    log_info "Pulling required Docker images..."
    
    docker compose --env-file "$ENV_FILE" pull
    
    log_success "Images pulled"
}

start_services() {
    log_info "Starting services..."
    
    cd "$PROJECT_ROOT"
    
    # Start infrastructure services first
    log_info "Starting infrastructure services..."
    docker compose --env-file "$ENV_FILE" up -d \
        postgres redis minio etcd
    
    sleep 10
    
    # Start data services
    log_info "Starting data services..."
    docker compose --env-file "$ENV_FILE" up -d \
        milvus elasticsearch
    
    sleep 20
    
    # Start application services
    log_info "Starting application services..."
    docker compose --env-file "$ENV_FILE" up -d \
        backend backend-worker frontend
    
    sleep 10
    
    # Start monitoring
    log_info "Starting monitoring services..."
    docker compose --env-file "$ENV_FILE" up -d \
        prometheus grafana
    
    # Start nginx
    log_info "Starting nginx..."
    docker compose --env-file "$ENV_FILE" up -d nginx
    
    log_success "All services started"
}

check_health() {
    log_info "Checking service health..."
    
    sleep 30
    
    # Check each service
    services=("postgres" "redis" "minio" "milvus" "elasticsearch" "backend" "frontend" "nginx")
    
    for service in "${services[@]}"; do
        if docker compose --env-file "$ENV_FILE" ps | grep "$service" | grep -q "Up"; then
            log_success "$service is running"
        else
            log_error "$service is not running"
        fi
    done
}

show_info() {
    echo -e "\n${CYAN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║        Deployment Completed Successfully!      ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${GREEN}Access URLs:${NC}"
    echo -e "  • Frontend:    ${YELLOW}https://localhost${NC}"
    echo -e "  • API:         ${YELLOW}https://localhost/api${NC}"
    echo -e "  • Grafana:     ${YELLOW}https://localhost/grafana${NC}"
    echo -e "  • Prometheus:  ${YELLOW}https://localhost/prometheus${NC}"
    echo -e "  • MinIO:       ${YELLOW}http://localhost:9101${NC}"
    
    echo -e "\n${GREEN}Default Credentials:${NC}"
    echo -e "  • Admin User:  ${YELLOW}admin@bisheng.io${NC}"
    echo -e "  • Grafana:     ${YELLOW}admin / BiSheng@2024!Grafana${NC}"
    echo -e "  • MinIO:       ${YELLOW}bisheng_admin / BiSheng@2024!MinIO#Secure${NC}"
    
    echo -e "\n${GREEN}Useful Commands:${NC}"
    echo -e "  • View logs:       ${YELLOW}docker compose logs -f [service]${NC}"
    echo -e "  • Stop all:        ${YELLOW}docker compose down${NC}"
    echo -e "  • Restart service: ${YELLOW}docker compose restart [service]${NC}"
    echo -e "  • Service status:  ${YELLOW}docker compose ps${NC}"
    
    echo -e "\n${GREEN}Next Steps:${NC}"
    echo -e "  1. Review and update .env.production with your API keys"
    echo -e "  2. Replace self-signed SSL certificate for production"
    echo -e "  3. Configure backups: ./scripts/backup.sh"
    echo -e "  4. Set up monitoring alerts in Grafana"
    echo ""
}

# ============================================
# Main Execution
# ============================================

main() {
    print_banner
    
    check_requirements
    check_env_file
    create_directories
    generate_ssl_cert
    build_custom_images
    pull_images
    start_services
    check_health
    show_info
}

# Run main function
main "$@"