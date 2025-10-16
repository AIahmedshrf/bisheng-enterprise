#!/bin/bash
# ============================================
# Bisheng Backend Health Check Script
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Check API endpoint
check_api() {
    if curl -f -s http://localhost:7860/api/v1/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ API is healthy${NC}"
        return 0
    else
        echo -e "${RED}✗ API is unhealthy${NC}"
        return 1
    fi
}

# Check database connection
check_database() {
    if python3 -c "
import psycopg2
import os
try:
    conn = psycopg2.connect(os.environ['DATABASE_URL'])
    conn.close()
    print('Database OK')
    exit(0)
except Exception as e:
    print(f'Database Error: {e}')
    exit(1)
" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Database is reachable${NC}"
        return 0
    else
        echo -e "${RED}✗ Database is unreachable${NC}"
        return 1
    fi
}

# Check Redis connection
check_redis() {
    if python3 -c "
import redis
import os
import re
# Parse Redis URL
url = os.environ.get('REDIS_URL', '')
match = re.match(r'redis://:(.+)@(.+):(\d+)/(\d+)', url)
if match:
    password, host, port, db = match.groups()
    r = redis.Redis(host=host, port=int(port), db=int(db), password=password)
    r.ping()
    print('Redis OK')
" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Redis is reachable${NC}"
        return 0
    else
        echo -e "${RED}✗ Redis is unreachable${NC}"
        return 1
    fi
}

# Main health check
main() {
    local status=0
    
    check_api || status=1
    
    # Only check dependencies if DATABASE_URL is set
    if [ -n "$DATABASE_URL" ]; then
        check_database || status=1
    fi
    
    if [ -n "$REDIS_URL" ]; then
        check_redis || status=1
    fi
    
    exit $status
}

main