#!/bin/bash
# ============================================
# Bisheng Enterprise - Health Check Script
# ============================================

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

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# ============================================
# Functions
# ============================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

check_service() {
    local service=$1
    local container_name=$2
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if docker ps --filter "name=$container_name" --filter "status=running" | grep -q "$container_name"; then
        log_success "$service is running"
        return 0
    else
        log_error "$service is not running"
        return 1
    fi
}

check_service_health() {
    local service=$1
    local container_name=$2
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    local health=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null)
    
    if [ "$health" = "healthy" ]; then
        log_success "$service health check passed"
        return 0
    elif [ "$health" = "starting" ]; then
        log_warning "$service is starting..."
        return 0
    else
        log_error "$service health check failed (status: $health)"
        return 1
    fi
}

check_http_endpoint() {
    local name=$1
    local url=$2
    local expected_code=${3:-200}
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
    
    if [ "$response" = "$expected_code" ]; then
        log_success "$name endpoint is accessible ($url)"
        return 0
    else
        log_error "$name endpoint failed (expected: $expected_code, got: $response)"
        return 1
    fi
}

check_database_connection() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if docker exec bisheng-postgres pg_isready -U bisheng_user -d bisheng > /dev/null 2>&1; then
        log_success "PostgreSQL is accepting connections"
        
        # Check number of connections
        local connections=$(docker exec bisheng-postgres psql -U bisheng_user -d bisheng -t -c "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null | tr -d ' ')
        log_info "Active database connections: $connections"
        return 0
    else
        log_error "PostgreSQL is not accepting connections"
        return 1
    fi
}

check_redis_connection() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if docker exec bisheng-redis redis-cli -a "${REDIS_PASSWORD}" --no-auth-warning PING 2>/dev/null | grep -q "PONG"; then
        log_success "Redis is responding"
        
        # Check memory usage
        local mem=$(docker exec bisheng-redis redis-cli -a "${REDIS_PASSWORD}" --no-auth-warning INFO memory 2>/dev/null | grep used_memory_human | cut -d: -f2 | tr -d '\r')
        log_info "Redis memory usage: $mem"
        return 0
    else
        log_error "Redis is not responding"
        return 1
    fi
}

check_milvus_connection() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if curl -f -s http://localhost:9091/healthz > /dev/null 2>&1; then
        log_success "Milvus is healthy"
        return 0
    else
        log_error "Milvus health check failed"
        return 1
    fi
}

check_elasticsearch_cluster() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    local health=$(curl -s -u elastic:${ELASTICSEARCH_PASSWORD} http://localhost:9200/_cluster/health 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    
    case "$health" in
        green)
            log_success "Elasticsearch cluster is healthy (green)"
            return 0
            ;;
        yellow)
            log_warning "Elasticsearch cluster is degraded (yellow)"
            return 0
            ;;
        red)
            log_error "Elasticsearch cluster is unhealthy (red)"
            return 1
            ;;
        *)
            log_error "Cannot determine Elasticsearch cluster health"
            return 1
            ;;
    esac
}

check_disk_space() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    local usage=$(df -h "${PROJECT_ROOT}/data" | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ "$usage" -lt 80 ]; then
        log_success "Disk space is adequate (${usage}% used)"
        return 0
    elif [ "$usage" -lt 90 ]; then
        log_warning "Disk space is running low (${usage}% used)"
        return 0
    else
        log_error "Disk space is critical (${usage}% used)"
        return 1
    fi
}

check_docker_resources() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    # Check if docker stats is available
    if ! docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" > /dev/null 2>&1; then
        log_warning "Cannot get Docker resource stats"
        return 0
    fi
    
    log_success "Docker resources check passed"
    
    # Show top 5 containers by CPU
    echo -e "\n${BLUE}Top 5 containers by CPU usage:${NC}"
    docker stats --no-stream --format "{{.Name}}\t{{.CPUPerc}}" | sort -k2 -hr | head -5 | while read name cpu; do
        echo -e "  $name: $cpu"
    done
    
    return 0
}

check_network() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if docker network inspect bisheng-enterprise_bisheng-network > /dev/null 2>&1; then
        log_success "Docker network is configured"
        return 0
    else
        log_error "Docker network is not configured"
        return 1
    fi
}

check_volumes() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    local required_volumes=(
        "bisheng-enterprise_postgres-data"
        "bisheng-enterprise_redis-data"
        "bisheng-enterprise_milvus-data"
        "bisheng-enterprise_elasticsearch-data"
        "bisheng-enterprise_minio-data"
    )
    
    local missing_volumes=0
    
    for volume in "${required_volumes[@]}"; do
        if ! docker volume inspect "$volume" > /dev/null 2>&1; then
            log_warning "Volume missing: $volume"
            missing_volumes=$((missing_volumes + 1))
        fi
    done
    
    if [ $missing_volumes -eq 0 ]; then
        log_success "All required volumes exist"
        return 0
    else
        log_error "$missing_volumes volumes are missing"
        return 1
    fi
}

check_ssl_certificates() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [ -f "${PROJECT_ROOT}/ssl/cert.pem" ] && [ -f "${PROJECT_ROOT}/ssl/key.pem" ]; then
        # Check certificate expiration
        local expiry=$(openssl x509 -in "${PROJECT_ROOT}/ssl/cert.pem" -noout -enddate 2>/dev/null | cut -d= -f2)
        local expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null)
        local now_epoch=$(date +%s)
        local days_left=$(( ($expiry_epoch - $now_epoch) / 86400 ))
        
        if [ $days_left -gt 30 ]; then
            log_success "SSL certificate is valid (expires in $days_left days)"
            return 0
        elif [ $days_left -gt 0 ]; then
            log_warning "SSL certificate expires soon ($days_left days)"
            return 0
        else
            log_error "SSL certificate has expired"
            return 1
        fi
    else
        log_error "SSL certificates not found"
        return 1
    fi
}

# ============================================
# Main Execution
# ============================================

main() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════╗"
    echo "║     Bisheng Enterprise Health Check Report    ║"
    echo "║              $(date '+%Y-%m-%d %H:%M:%S')              ║"
    echo "╚════════════════════════════════════════════════╝"
    echo -e "${NC}\n"
    
    # Load environment
    if [ -f "$ENV_FILE" ]; then
        set -a
        source "$ENV_FILE"
        set +a
    fi
    
    # Container Status
    echo -e "${BLUE}=== Container Status ===${NC}"
    check_service "PostgreSQL" "bisheng-postgres"
    check_service "Redis" "bisheng-redis"
    check_service "MinIO" "bisheng-minio"
    check_service "Milvus" "bisheng-milvus"
    check_service "Elasticsearch" "bisheng-elasticsearch"
    check_service "Backend" "bisheng-backend"
    check_service "Backend Worker" "bisheng-backend-worker"
    check_service "Frontend" "bisheng-frontend"
    check_service "Nginx" "bisheng-nginx"
    
    echo ""
    
    # Health Checks
    echo -e "${BLUE}=== Service Health Checks ===${NC}"
    check_service_health "PostgreSQL" "bisheng-postgres"
    check_service_health "Redis" "bisheng-redis"
    check_service_health "MinIO" "bisheng-minio"
    check_service_health "Milvus" "bisheng-milvus"
    
    echo ""
    
    # Connectivity
    echo -e "${BLUE}=== Connectivity Checks ===${NC}"
    check_database_connection
    check_redis_connection
    check_milvus_connection
    check_elasticsearch_cluster
    
    echo ""
    
    # HTTP Endpoints
    echo -e "${BLUE}=== HTTP Endpoint Checks ===${NC}"
    check_http_endpoint "Backend API" "http://localhost:7860/api/v1/health"
    check_http_endpoint "Frontend" "http://localhost:3001"
    check_http_endpoint "MinIO Console" "http://localhost:9101/minio/health/live"
    
    echo ""
    
    # Infrastructure
    echo -e "${BLUE}=== Infrastructure Checks ===${NC}"
    check_network
    check_volumes
    check_disk_space
    check_docker_resources
    check_ssl_certificates
    
    echo ""
    
    # Summary
    echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                Health Check Summary            ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
    echo -e "\nTotal Checks: ${TOTAL_CHECKS}"
    echo -e "${GREEN}Passed: ${PASSED_CHECKS}${NC}"
    echo -e "${RED}Failed: ${FAILED_CHECKS}${NC}"
    
    local success_rate=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    echo -e "\nSuccess Rate: ${success_rate}%"
    
    if [ $FAILED_CHECKS -eq 0 ]; then
        echo -e "\n${GREEN}✓ All health checks passed!${NC}\n"
        exit 0
    else
        echo -e "\n${RED}✗ Some health checks failed. Please investigate.${NC}\n"
        exit 1
    fi
}

main "$@"