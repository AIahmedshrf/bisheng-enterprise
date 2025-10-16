الملف 30: docs/TROUBLESHOOTING.md

Markdown

# 🔧 دليل استكشاف الأخطاء وإصلاحها

## جدول المحتويات

- [مشاكل التثبيت](#مشاكل-التثبيت)
- [مشاكل قاعدة البيانات](#مشاكل-قاعدة-البيانات)
- [مشاكل الأداء](#مشاكل-الأداء)
- [مشاكل الشبكة](#مشاكل-الشبكة)
- [مشاكل التخزين](#مشاكل-التخزين)
- [مشاكل الذكاء الاصطناعي](#مشاكل-الذكاء-الاصطناعي)
- [الأخطاء الشائعة](#الأخطاء-الشائعة)

---

## مشاكل التثبيت

### ❌ المشكلة: فشل بناء الصور المخصصة

**الأعراض:**

ERROR: failed to solve: process "/bin/sh -c pip install torch" did not complete successfully

text


**الحل:**

```bash
# 1. زيادة ذاكرة Docker
# في Docker Desktop: Settings → Resources → Memory (8GB+)

# 2. بناء بدون cache
docker build --no-cache -t bisheng-backend-enterprise:latest custom-images/backend/

# 3. استخدام multi-stage build (تم تطبيقه مسبقاً)

# 4. تنظيف Docker
docker system prune -a
docker volume prune

❌ المشكلة: الخدمات لا تبدأ

الأعراض:

text

ERROR: for postgres  Container "xxxxx" is unhealthy

التشخيص:

Bash

# 1. فحص السجلات
docker compose logs postgres

# 2. فحص الصحة
docker compose ps

# 3. فحص الموارد
docker stats

الحل:

Bash

# 1. إعادة إنشاء الحاوية
docker compose up -d --force-recreate postgres

# 2. فحص ملف التكوين
cat configs/postgresql/postgresql.conf

# 3. التحقق من الأذونات
ls -la data/postgresql/

# 4. زيادة timeout الصحة
# في docker-compose.yml:
healthcheck:
  start_period: 120s  # بدلاً من 60s

❌ المشكلة: Port already in use

الأعراض:

text

Error: bind: address already in use

الحل:

Bash

# 1. إيجاد العملية التي تستخدم المنفذ
sudo lsof -i :7860
sudo netstat -tulpn | grep :7860

# 2. إيقاف العملية
sudo kill -9 <PID>

# 3. أو تغيير المنفذ في .env.production
BACKEND_PORT=7861

مشاكل قاعدة البيانات
❌ المشكلة: PostgreSQL - Too many connections

الأعراض:

text

FATAL: sorry, too many clients already

التشخيص:

SQL

-- الاتصالات الحالية
SELECT count(*) FROM pg_stat_activity;

-- الاتصالات حسب التطبيق
SELECT application_name, count(*) 
FROM pg_stat_activity 
GROUP BY application_name;

-- الاتصالات الخاملة
SELECT pid, state, query_start, state_change 
FROM pg_stat_activity 
WHERE state = 'idle' 
  AND state_change < now() - interval '5 minutes';

الحل:

Bash

# 1. زيادة max_connections
# في configs/postgresql/postgresql.conf:
max_connections = 300

# 2. إنهاء الاتصالات الخاملة
docker compose exec postgres psql -U bisheng_user -d bisheng -c "
SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE state = 'idle' 
  AND state_change < now() - interval '10 minutes';
"

# 3. استخدام Connection Pooling (PgBouncer)
# إضافة في docker-compose.yml:

YAML

pgbouncer:
  image: pgbouncer/pgbouncer:latest
  environment:
    DATABASES_HOST: postgres
    DATABASES_PORT: 5432
    DATABASES_USER: bisheng_user
    DATABASES_PASSWORD: ${POSTGRES_PASSWORD}
    DATABASES_DBNAME: bisheng
    PGBOUNCER_POOL_MODE: transaction
    PGBOUNCER_MAX_CLIENT_CONN: 1000
    PGBOUNCER_DEFAULT_POOL_SIZE: 25
  ports:
    - "6432:6432"

❌ المشكلة: استعلامات بطيئة

التشخيص:

SQL

-- أبطأ 10 استعلامات
SELECT 
    query,
    calls,
    total_exec_time,
    mean_exec_time,
    max_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;

-- الاستعلامات الجارية
SELECT 
    pid,
    now() - query_start as duration,
    state,
    query
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY duration DESC;

-- فحص الفهارس المفقودة
SELECT 
    schemaname,
    tablename,
    attname,
    n_distinct,
    correlation
FROM pg_stats
WHERE schemaname = 'public'
  AND n_distinct > 100
  AND correlation < 0.1;

الحل:

SQL

-- 1. إنشاء فهارس
CREATE INDEX CONCURRENTLY idx_flows_user_id ON flows(user_id);
CREATE INDEX CONCURRENTLY idx_flows_created_at ON flows(created_at);
CREATE INDEX CONCURRENTLY idx_documents_collection ON documents(collection_id);

-- 2. فهارس للبحث النصي
CREATE INDEX idx_documents_content_gin ON documents USING gin(to_tsvector('english', content));

-- 3. تحليل الجداول
ANALYZE flows;
ANALYZE documents;

-- 4. إعادة بناء الفهارس
REINDEX TABLE CONCURRENTLY flows;

-- 5. تنظيف الجداول
VACUUM ANALYZE flows;

❌ المشكلة: Database corruption

الأعراض:

text

ERROR: invalid page in block 1234 of relation base/16384/12345

الحل:

Bash

# 1. إيقاف التطبيق
docker compose stop backend backend-worker

# 2. فحص قاعدة البيانات
docker compose exec postgres pg_checksums --check -D /var/lib/postgresql/data

# 3. محاولة الإصلاح
docker compose exec postgres psql -U bisheng_user -d bisheng -c "
REINDEX DATABASE bisheng;
VACUUM FULL;
"

# 4. إذا فشل: استعادة من النسخة الاحتياطية
./scripts/restore.sh

# 5. منع التكرار: تفعيل checksums
# عند إنشاء قاعدة جديدة:
initdb --data-checksums -D /var/lib/postgresql/data

مشاكل الأداء
❌ المشكلة: استهلاك عالي للذاكرة

التشخيص:

Bash

# 1. فحص استخدام الذاكرة
docker stats --no-stream

# 2. فحص العمليات داخل الحاوية
docker compose exec backend top

# 3. فحص تسرب الذاكرة
docker compose exec backend python -c "
import psutil
process = psutil.Process()
print(f'Memory: {process.memory_info().rss / 1024 / 1024:.2f} MB')
"

الحل:

Bash

# 1. زيادة حدود الذاكرة
# في .env.production:
BACKEND_MEMORY_LIMIT=8G
WORKER_MEMORY_LIMIT=8G

# 2. تفعيل garbage collection
# إضافة في backend config:
import gc
gc.set_threshold(700, 10, 10)

# 3. استخدام memory profiling
docker compose exec backend pip install memory_profiler
docker compose exec backend python -m memory_profiler script.py

# 4. تقليل عدد Workers
CELERY_WORKER_CONCURRENCY=2  # بدلاً من 4

❌ المشكلة: CPU usage مرتفع

التشخيص:

Bash

# 1. تحديد العملية المستهلكة
docker stats

# 2. Profiling داخل Python
docker compose exec backend python -m cProfile -o output.prof script.py
docker compose exec backend python -c "
import pstats
p = pstats.Stats('output.prof')
p.sort_stats('cumulative')
p.print_stats(10)
"

# 3. فحص Celery tasks
docker compose exec backend celery -A bisheng.worker inspect active

الحل:

Bash

# 1. تحسين الكود
# استخدام async/await
# تفادي الحلقات المتداخلة

# 2. Caching
ENABLE_QUERY_CACHE=true
CACHE_TTL=3600

# 3. توزيع الحمل
# زيادة عدد Workers
WORKER_REPLICAS=5

# 4. استخدام PyPy للأداء الأفضل
# في Dockerfile:
FROM pypy:3.10

❌ المشكلة: بطء في الاستجابة

التشخيص:

Bash

# 1. قياس زمن الاستجابة
curl -w "@curl-format.txt" -o /dev/null -s https://localhost/api/v1/health

# ملف curl-format.txt:
# time_namelookup:  %{time_namelookup}\n
# time_connect:  %{time_connect}\n
# time_appconnect:  %{time_appconnect}\n
# time_pretransfer:  %{time_pretransfer}\n
# time_redirect:  %{time_redirect}\n
# time_starttransfer:  %{time_starttransfer}\n
# ----------\n
# time_total:  %{time_total}\n

# 2. تتبع الطلبات
docker compose logs -f nginx | grep "request_time"

الحل:

Bash

# 1. تفعيل Nginx caching
# في nginx.conf:
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=my_cache:10m;

location /api/ {
    proxy_cache my_cache;
    proxy_cache_valid 200 5m;
}

# 2. تحسين PostgreSQL
shared_buffers = 4GB
effective_cache_size = 12GB

# 3. استخدام Redis للتخزين المؤقت
ENABLE_REDIS_CACHE=true

# 4. CDN للملفات الثابتة
# استخدام CloudFlare أو AWS CloudFront

مشاكل الشبكة
❌ المشكلة: Cannot connect to backend

الأعراض:

text

502 Bad Gateway

التشخيص:

Bash

# 1. فحص الشبكة
docker network ls
docker network inspect bisheng-enterprise_bisheng-network

# 2. فحص الاتصال
docker compose exec frontend ping backend
docker compose exec nginx curl http://backend:7860/api/v1/health

# 3. فحص DNS
docker compose exec frontend nslookup backend

الحل:

Bash

# 1. إعادة إنشاء الشبكة
docker compose down
docker network rm bisheng-enterprise_bisheng-network
docker compose up -d

# 2. التحقق من الـ hostname
# في docker-compose.yml تأكد من:
services:
  backend:
    hostname: backend
    networks:
      - bisheng-network

# 3. استخدام IP بدلاً من اسم الخدمة
docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' bisheng-backend

❌ المشكلة: SSL/TLS errors

الأعراض:

text

SSL certificate problem: self signed certificate

الحل:

Bash

# للتطوير: تجاهل التحقق من الشهادة
curl -k https://localhost/api/v1/health

# للإنتاج: استخدام شهادة صالحة
# 1. Let's Encrypt
sudo certbot certonly --standalone -d yourdomain.com

# 2. نسخ الشهادات
sudo cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem ssl/cert.pem
sudo cp /etc/letsencrypt/live/yourdomain.com/privkey.pem ssl/key.pem

# 3. إعادة تشغيل Nginx
docker compose restart nginx

# 4. التجديد التلقائي
echo "0 0 1 * * certbot renew --quiet && docker compose restart nginx" | sudo crontab -

مشاكل التخزين
❌ المشكلة: Disk space full

الأعراض:

text

Error: No space left on device

التشخيص:

Bash

# 1. فحص المساحة
df -h

# 2. إيجاد أكبر الملفات
du -h --max-depth=1 /var/lib/docker | sort -hr | head -10
du -h --max-depth=1 data/ | sort -hr | head -10

# 3. فحص volumes
docker system df -v

الحل:

Bash

# 1. تنظيف Docker
docker system prune -a --volumes
# تحذير: سيحذف كل الصور والحاويات غير المستخدمة

# 2. تنظيف النسخ الاحتياطية القديمة
find data/backups -type f -mtime +30 -delete

# 3. تنظيف السجلات
find logs/ -name "*.log" -mtime +7 -delete

# 4. ضغط السجلات القديمة
find logs/ -name "*.log" -mtime +1 -exec gzip {} \;

# 5. تنظيف Elasticsearch
curl -X DELETE "http://localhost:9200/logs-*" \
  -H 'Content-Type: application/json' \
  -d '{"query": {"range": {"@timestamp": {"lt": "now-30d"}}}}'

# 6. تنظيف MinIO
docker compose exec minio mc rm --recursive --force --older-than 30d minio/tmp-dir/

❌ المشكلة: Volume mount errors

الأعراض:

text

Error: failed to mount local volume: mount /path/to/volume: permission denied

الحل:

Bash

# 1. إصلاح الأذونات
sudo chown -R 1000:1000 data/
sudo chmod -R 755 data/

# 2. SELinux (للـ CentOS/RHEL)
sudo chcon -Rt svirt_sandbox_file_t data/

# 3. إعادة إنشاء الـ volume
docker volume rm bisheng-enterprise_postgres-data
docker compose up -d postgres

مشاكل الذكاء الاصطناعي
❌ المشكلة: PyTorch not found

الأعراض:

text

ModuleNotFoundError: No module named 'torch'

الحل:

Bash

# 1. إعادة بناء الصورة
docker compose build --no-cache backend

# 2. التثبيت اليدوي
docker compose exec backend pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# 3. التحقق من التثبيت
docker compose exec backend python -c "import torch; print(torch.__version__)"

❌ المشكلة: Out of memory in model loading

الأعراض:

text

RuntimeError: CUDA out of memory

الحل:

Bash

# 1. استخدام نماذج أصغر
DEFAULT_EMBEDDING_MODEL=sentence-transformers/all-MiniLM-L6-v2

# 2. تقليل batch size
MAX_BATCH_SIZE=16  # بدلاً من 100

# 3. استخدام CPU بدلاً من GPU
CUDA_VISIBLE_DEVICES=""

# 4. Model quantization
# في الكود:
from transformers import AutoModelForSequenceClassification
model = AutoModelForSequenceClassification.from_pretrained(
    "model_name",
    load_in_8bit=True  # Quantization
)

❌ المشكلة: Slow embedding generation

التشخيص:

Python

import time
from sentence_transformers import SentenceTransformer

model = SentenceTransformer('paraphrase-multilingual-MiniLM-L12-v2')

texts = ["test"] * 100
start = time.time()
embeddings = model.encode(texts)
print(f"Time: {time.time() - start:.2f}s")

الحل:

Python

# 1. استخدام batch processing
embeddings = model.encode(texts, batch_size=32, show_progress_bar=True)

# 2. Caching
from functools import lru_cache

@lru_cache(maxsize=10000)
def get_embedding(text):
    return model.encode([text])[0]

# 3. استخدام GPU
model = SentenceTransformer('model_name', device='cuda')

# 4. نموذج أسرع
model = SentenceTransformer('all-MiniLM-L6-v2')  # أصغر وأسرع

الأخطاء الشائعة
❌ Error: "Connection refused"

Bash

# التحقق من أن الخدمة تعمل
docker compose ps

# إعادة التشغيل
docker compose restart [service-name]

# التحقق من الـ firewall
sudo ufw status
sudo ufw allow 7860/tcp

❌ Error: "Permission denied"

Bash

# إصلاح الأذونات
sudo chown -R $USER:$USER .
chmod +x scripts/*.sh

# للـ volumes
sudo chown -R 1000:1000 data/

❌ Error: "Port already allocated"

Bash

# إيجاد العملية
sudo lsof -i :<port>
sudo kill -9 <PID>

# أو تغيير المنفذ في .env.production

❌ Error: "Network not found"

Bash

# إعادة إنشاء الشبكة
docker compose down
docker network prune
docker compose up -d

📞 الحصول على مساعدة إضافية

إذا لم تجد حلاً لمشكلتك:

    فحص السجلات الكاملة:

Bash

./scripts/health-check.sh > diagnosis.txt
docker compose logs > full-logs.txt
tar -czf bisheng-debug.tar.gz diagnosis.txt full-logs.txt

    الإبلاغ عن المشكلة:
        GitHub Issues
        Discord Community
        Email: support@bisheng.io

    معلومات مفيدة للإبلاغ:
        نظام التشغيل والإصدار
        إصدار Docker و Docker Compose
        ملف .env.production (بدون كلمات المرور!)
        السجلات الكاملة
        خطوات إعادة إنتاج المشكلة

💡 نصيحة: احتفظ بنسخة احتياطية دائماً قبل تطبيق أي حل!

Bash

# نسخ احتياطي سريع
./scripts/backup.sh

text


---

## 📄 الملف 31: `docs/API.md`

```markdown
# 📡 Bisheng Enterprise API Documentation

## نظرة عامة

Bisheng Enterprise يوفر RESTful API شامل للتفاعل مع النظام.

**Base URL:** `https://your-domain.com/api/v1`

**Authentication:** Bearer Token (JWT)

---

## 🔐 المصادقة (Authentication)

### الحصول على Token

**Endpoint:** `POST /auth/login`

**Request:**
```json
{
  "email": "admin@bisheng.io",
  "password": "your-password"
}

Response:

JSON

{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 3600
}

مثال باستخدام curl:

Bash

curl -X POST https://your-domain.com/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@bisheng.io","password":"your-password"}'

تجديد Token

Endpoint: POST /auth/refresh

Request:

JSON

{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}