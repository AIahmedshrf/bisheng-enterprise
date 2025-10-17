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

```
ERROR: failed to solve: process "/bin/sh -c pip install torch" did not complete successfully
```

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
```

---

### ❌ المشكلة: الخدمات لا تبدأ

**الأعراض:**

```
ERROR: for postgres  Container "xxxxx" is unhealthy
```

**التشخيص:**

```bash
# 1. فحص السجلات
docker compose logs postgres

# 2. فحص الصحة
docker compose ps

# 3. فحص الموارد
docker stats
```

**الحل:**

```bash
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
```

---

### ❌ المشكلة: Port already in use

**الأعراض:**

```
Error: bind: address already in use
```

**الحل:**

```bash
# 1. إيجاد العملية التي تستخدم المنفذ
sudo lsof -i :7860
sudo netstat -tulpn | grep :7860

# 2. إيقاف العملية
sudo kill -9 <PID>

# 3. أو تغيير المنفذ في .env.production
BACKEND_PORT=7861
```

---

## مشاكل قاعدة البيانات

### ❌ المشكلة: PostgreSQL - Too many connections

**الأعراض:**

```
FATAL: sorry, too many clients already
```

**التشخيص:**

```sql
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
```

**الحل:**

```bash
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

# 3. إعادة تشغيل PostgreSQL
docker compose restart postgres
```

---

(بقية النص تم تنسيقه بنفس الأسلوب...)
