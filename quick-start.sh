#!/bin/bash

echo "============================================"
echo "�� Bisheng Enterprise - Quick Start"
echo "============================================"
echo ""

# ============================================
# 1. إنشاء الشبكة
# ============================================
echo "1️⃣ إنشاء الشبكة..."
docker network create bisheng-network 2>/dev/null || echo "  الشبكة موجودة بالفعل"

# ============================================
# 2. تشغيل الخدمات الأساسية
# ============================================
echo ""
echo "2️⃣ تشغيل PostgreSQL..."
docker run -d \
  --name bisheng-postgres \
  --network bisheng-network \
  -p 5432:5432 \
  -e POSTGRES_DB=bisheng_dev \
  -e POSTGRES_USER=bisheng_dev \
  -e POSTGRES_PASSWORD=dev_password_123 \
  postgres:15-alpine

echo ""
echo "3️⃣ تشغيل Redis..."
docker run -d \
  --name bisheng-redis \
  --network bisheng-network \
  -p 6379:6379 \
  redis:7.2-alpine

echo ""
echo "4️⃣ تشغيل MinIO..."
docker run -d \
  --name bisheng-minio \
  --network bisheng-network \
  -p 9000:9000 \
  -p 9001:9001 \
  -e MINIO_ROOT_USER=minioadmin \
  -e MINIO_ROOT_PASSWORD=minioadmin123 \
  minio/minio:RELEASE.2023-03-20T20-16-18Z \
  server /data --console-address ":9001"

echo ""
echo "5️⃣ تشغيل Elasticsearch..."
docker run -d \
  --name bisheng-elasticsearch \
  --network bisheng-network \
  -p 9200:9200 \
  -e discovery.type=single-node \
  -e xpack.security.enabled=false \
  -e "ES_JAVA_OPTS=-Xms512m -Xmx512m" \
  docker.elastic.co/elasticsearch/elasticsearch:8.12.0

echo ""
echo "⏳ انتظار الخدمات الأساسية (30 ثانية)..."
sleep 30

# ============================================
# 6. تشغيل Backend (بدون config.yaml)
# ============================================
echo ""
echo "6️⃣ تشغيل Backend (بدون config.yaml)..."

docker run -d \
  --name bisheng-backend \
  --network bisheng-network \
  -p 7860:7860 \
  -w /app \
  -e DATABASE_URL="postgresql://bisheng_dev:dev_password_123@bisheng-postgres:5432/bisheng_dev" \
  -e REDIS_URL="redis://bisheng-redis:6379/0" \
  -e CELERY_BROKER_URL="redis://bisheng-redis:6379/1" \
  -e MINIO_ENDPOINT="bisheng-minio:9000" \
  -e MINIO_ACCESS_KEY="minioadmin" \
  -e MINIO_SECRET_KEY="minioadmin123" \
  -e MINIO_BUCKET="bisheng-dev" \
  -e ELASTICSEARCH_URL="http://bisheng-elasticsearch:9200" \
  -e SECRET_KEY="dev-secret-key" \
  -e PYTHONUNBUFFERED="1" \
  -e PYTHONPATH="/app" \
  --entrypoint="" \
  dataelement/bisheng-backend:v2.2.0-beta2 \
  python -m uvicorn bisheng.main:app --host 0.0.0.0 --port 7860 --workers 1 --log-level info

echo ""
echo "⏳ انتظار Backend (60 ثانية)..."

for i in {1..60}; do
    if docker logs bisheng-backend 2>&1 | grep -q "Uvicorn running\|Application startup"; then
        echo ""
        echo "🎉 Backend بدأ في $i ثانية!"
        break
    fi
    
    if [ $((i % 15)) -eq 0 ]; then
        echo "  ⏳ $i/60..."
    fi
    
    sleep 1
done

# ============================================
# 7. التحقق من النظام
# ============================================
echo ""
echo "============================================"
echo "📊 حالة النظام"
echo "============================================"
echo ""

docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "🧪 اختبار الخدمات:"
echo ""

# PostgreSQL
if docker exec bisheng-postgres pg_isready -U bisheng_dev >/dev/null 2>&1; then
    echo "  ✅ PostgreSQL"
else
    echo "  ❌ PostgreSQL"
fi

# Redis
if docker exec bisheng-redis redis-cli ping >/dev/null 2>&1; then
    echo "  ✅ Redis"
else
    echo "  ❌ Redis"
fi

# MinIO
if curl -f http://localhost:9000/minio/health/live >/dev/null 2>&1; then
    echo "  ✅ MinIO"
else
    echo "  ❌ MinIO"
fi

# Elasticsearch
if curl -f http://localhost:9200 >/dev/null 2>&1; then
    echo "  ✅ Elasticsearch"
else
    echo "  ❌ Elasticsearch"
fi

# Backend API
echo ""
echo "  🔍 اختبار Backend API (قد يستغرق دقيقة)..."
sleep 10

success=false
for i in {1..10}; do
    if curl -f http://localhost:7860/api/v1/health >/dev/null 2>&1; then
        echo "  ✅ Backend API"
        success=true
        break
    fi
    sleep 3
done

if [ "$success" != true ]; then
    echo "  ⚠️ Backend API (لا يزال يحمّل أو هناك مشكلة)"
    echo ""
    echo "  📋 آخر 20 سطر من السجلات:"
    docker logs bisheng-backend --tail 20
fi

echo ""
echo "============================================"

if [ "$success" = true ]; then
    echo "🎉🎉🎉 النظام يعمل بنجاح! 🎉🎉🎉"
    echo "============================================"
    echo ""
    echo "🌐 روابط الوصول:"
    echo ""
    echo "  📄 Backend API Docs:"
    echo "     http://localhost:7860/docs"
    echo ""
    echo "  🏥 Health Check:"
    echo "     http://localhost:7860/api/v1/health"
    echo ""
    echo "  📦 MinIO Console:"
    echo "     http://localhost:9001"
    echo "     (minioadmin / minioadmin123)"
    echo ""
    echo "  🔍 Elasticsearch:"
    echo "     http://localhost:9200"
    echo ""
    echo "  📊 PostgreSQL:"
    echo "     localhost:5432 / bisheng_dev / bisheng_dev / dev_password_123"
    echo ""
    echo "📝 الأوامر المفيدة:"
    echo ""
    echo "  عرض السجلات:"
    echo "     docker logs bisheng-backend -f"
    echo ""
    echo "  إيقاف النظام:"
    echo "     docker stop bisheng-backend bisheng-postgres bisheng-redis bisheng-minio bisheng-elasticsearch"
    echo ""
    echo "  إعادة التشغيل:"
    echo "     bash quick-start.sh"
    echo ""
else
    echo "⚠️ النظام يعمل جزئياً"
    echo "============================================"
    echo ""
    echo "🔍 للتشخيص:"
    echo "     docker logs bisheng-backend --tail 50"
    echo ""
fi

echo "============================================"

