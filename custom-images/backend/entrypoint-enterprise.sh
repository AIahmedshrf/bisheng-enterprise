#!/bin/bash
# ============================================
# Bisheng Backend Enterprise Entrypoint
# ============================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "============================================"
echo "  Bisheng Enterprise Backend Starting"
echo "============================================"
echo -e "${NC}"

# ============================================
# Wait for dependencies
# ============================================
wait_for_service() {
    local host=$1
    local port=$2
    local service=$3
    local max_attempts=30
    local attempt=1
    
    echo -e "${YELLOW}Waiting for $service at $host:$port...${NC}"
    
    while ! nc -z "$host" "$port" > /dev/null 2>&1; do
        if [ $attempt -eq $max_attempts ]; then
            echo -e "${RED}✗ Failed to connect to $service after $max_attempts attempts${NC}"
            exit 1
        fi
        echo -e "${YELLOW}  Attempt $attempt/$max_attempts...${NC}"
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo -e "${GREEN}✓ $service is ready${NC}"
}

# Wait for PostgreSQL
if [ -n "$POSTGRES_HOST" ]; then
    wait_for_service "$POSTGRES_HOST" "${POSTGRES_PORT:-5432}" "PostgreSQL"
fi

# Wait for Redis
if [ -n "$REDIS_HOST" ]; then
    wait_for_service "$REDIS_HOST" "${REDIS_PORT:-6379}" "Redis"
fi

# Wait for Milvus
if [ -n "$MILVUS_HOST" ]; then
    wait_for_service "$MILVUS_HOST" "${MILVUS_PORT:-19530}" "Milvus"
fi

# Wait for Elasticsearch
if [ -n "$ELASTICSEARCH_HOST" ]; then
    wait_for_service "$ELASTICSEARCH_HOST" "${ELASTICSEARCH_PORT:-9200}" "Elasticsearch"
fi

# Wait for MinIO
if [ -n "$MINIO_HOST" ]; then
    wait_for_service "$MINIO_HOST" "9000" "MinIO"
fi

# ============================================
# Database Migration
# ============================================
if [ "${RUN_MIGRATIONS:-true}" = "true" ]; then
    echo -e "${YELLOW}Running database migrations...${NC}"
    if python -m alembic upgrade head 2>/dev/null || true; then
        echo -e "${GREEN}✓ Migrations completed${NC}"
    else
        echo -e "${YELLOW}⚠ Migration script not found or failed (this may be normal)${NC}"
    fi
fi

# ============================================
# Initialize Admin User
# ============================================
if [ -n "$BISHENG_ADMIN_USER" ] && [ -n "$BISHENG_ADMIN_PASSWORD" ]; then
    echo -e "${YELLOW}Initializing admin user...${NC}"
    python -c "
from bisheng.database import init_admin_user
try:
    init_admin_user('$BISHENG_ADMIN_USER', '$BISHENG_ADMIN_PASSWORD')
    print('Admin user initialized')
except Exception as e:
    print(f'Admin initialization: {e}')
" 2>/dev/null || echo -e "${YELLOW}⚠ Admin initialization skipped${NC}"
fi

# ============================================
# Start Application
# ============================================
echo -e "${BLUE}"
echo "============================================"
echo "  Starting Bisheng Backend"
echo "  Mode: ${1:-api}"
echo "============================================"
echo -e "${NC}"

case "${1:-api}" in
    api)
        echo -e "${GREEN}Starting API server...${NC}"
        exec uvicorn bisheng.main:app \
            --host 0.0.0.0 \
            --port 7860 \
            --workers ${WORKERS:-4} \
            --loop uvloop \
            --log-level ${LOG_LEVEL:-info}
        ;;
    
    worker)
        echo -e "${GREEN}Starting Celery worker...${NC}"
        exec celery -A bisheng.worker worker \
            --loglevel=${LOG_LEVEL:-info} \
            --concurrency=${CELERY_WORKER_CONCURRENCY:-4} \
            --max-tasks-per-child=${CELERY_MAX_TASKS_PER_CHILD:-1000}
        ;;
    
    beat)
        echo -e "${GREEN}Starting Celery beat...${NC}"
        exec celery -A bisheng.worker beat \
            --loglevel=${LOG_LEVEL:-info}
        ;;
    
    flower)
        echo -e "${GREEN}Starting Flower monitoring...${NC}"
        exec celery -A bisheng.worker flower \
            --port=5555 \
            --broker=${CELERY_BROKER_URL}
        ;;
    
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo "Available commands: api, worker, beat, flower"
        exit 1
        ;;
esac