 I start 
 # 1. فحص المساحة
df -h

# 2. إيجاد أكبر الملفات
du -h --max-depth=1 /var/lib/docker | sort -hr | head -10
du -h --max-depth=1 data/ | sort -hr | head -10

# 3. فحص volumes
docker system df -v



1.
➜ /workspaces/bisheng-enterprise (main) $ df -h
Filesystem      Size  Used Avail Use% Mounted on
overlay          32G   12G   19G  40% /
tmpfs            64M     0   64M   0% /dev
shm              64M     0   64M   0% /dev/shm
/dev/root        29G   22G  7.5G  75% /vscode
/dev/loop4       32G   12G   19G  40% /workspaces
/dev/sda1        44G  4.2G   38G  10% /tmp

2. تنفيذ الاوامر التالية :

كيف تعيد تشغيل Docker وتغيّر مسار التخزين في Codespaces

الهدف: نقل data-root إلى /tmp (الذي عندك فيه ~100GB) لتفادي امتلاء الـ overlay.

انسخ هذه الأوامر كما هي:
# 1) أنشئ مجلد التخزين الجديد على /tmp
sudo mkdir -p /tmp/docker-data

# 2) اكتب إعداد data-root إلى daemon.json
printf '{\n  "data-root": "/tmp/docker-data"\n}\n' | sudo tee /etc/docker/daemon.json

# 3) أوقف الديمون الحالي (لا يوجد service، فنقتل العملية)
sudo pkill -f dockerd || true

# 4) شغّل Docker بالطريقة الصحيحة في Codespaces
if [ -x /usr/local/share/docker-init.sh ]; then
  sudo /usr/local/share/docker-init.sh
else
  # مسار احتياطي إذا لم يوجد سكربت التهيئة (نادرًا)
  sudo nohup dockerd --host=unix:///var/run/docker.sock --data-root=/tmp/docker-data \
    >/tmp/dockerd.log 2>&1 &
fi

# 5) تأكد من تغيّر مسار الجذر
docker info | grep -i "Docker Root Dir"
 
 ➜ /workspaces/bisheng-enterprise (main) $ tree -L 3
.
├── CHANGELOG.md
├── Makefile
├── README.md
├── base
│   └── docker-compose.base.yml
├── configs
│   ├── alertmanager
│   │   └── alertmanager.yml
│   ├── elasticsearch
│   │   └── elasticsearch.yml
│   ├── grafana
│   │   └── provisioning
│   ├── milvus
│   │   └── milvus.yaml
│   ├── nginx
│   │   └── nginx.conf
│   ├── postgresql
│   │   ├── init-scripts
│   │   └── postgresql.conf
│   └── prometheus
│       ├── prometheus.yml
│       └── rules
├── custom-images
│   ├── backend
│   │   ├── Dockerfile
│   │   ├── entrypoint-enterprise.sh
│   │   └── healthcheck.sh
│   ├── backup
│   │   ├── Dockerfile
│   │   ├── backup-minio.sh
│   │   ├── backup-postgres.sh
│   │   ├── backup-redis.sh
│   │   ├── backup-scheduler.py
│   │   └── cleanup-old-backups.sh
│   └── frontend
│       └── Dockerfile
├── data
│   ├── backups
│   ├── elasticsearch
│   ├── milvus
│   ├── minio
│   ├── postgresql
│   └── redis
├── docker-compose.dev.yml
├── docker-compose.yml
├── docs
│   ├── API.md
│   ├── DEPLOYMENT.md
│   ├── HR.md
│   ├── Mynotes.md
│   ├── TROUBLESHOOTING.md
│   └── python-sdk.md
├── features
│   ├── docker-compose.ft.yml
│   ├── docker-compose.ml.yml
│   └── docker-compose.office.yml
├── infrastructure
│   ├── docker-compose.backup.yml
│   ├── docker-compose.monitoring.yml
│   └── docker-compose.security.yml
├── logs
│   ├── backend
│   ├── frontend
│   ├── nginx
│   └── worker
├── scripts
│   ├── backup.sh
│   ├── deploy.sh
│   ├── health-check.sh
│   ├── restore.sh
│   └── update.sh
├── ssl
└── tmp
    └── create-troubleshooting.sh

35 directories, 40 files


ظهور مشكلة 📋
قبل ان اكتب لك الانتقال الى "الخطوة التالية" ، ظهرت مشكلة 📋 الخطوة 2: إنشاء Dockerfiles وبناء الصور .
وهي رسالة الخطاء التالية : "ط
The terminal process "/bin/bash" terminated with exit code: 1"

🔧 تحليل وحل المشكلة
📊 تحليل الوضع الحالي

المساحة ممتازة الآن! لكن المشكلة ليست في المساحة. دعنا نشخص السبب الحقيقي:
🔍 الخطوة الأولى: التشخيص

# ============================================
# تشخيص شامل للمشكلة
# ============================================

echo "🔍 بدء التشخيص الشامل..."
echo "============================================"
echo ""

# 1. التحقق من حالة Docker
echo "1️⃣ التحقق من Docker daemon..."
if sudo systemctl is-active --quiet docker 2>/dev/null; then
    echo "✅ Docker daemon يعمل (systemctl)"
elif pgrep -x dockerd > /dev/null; then
    echo "✅ Docker daemon يعمل (process)"
else
    echo "❌ Docker daemon لا يعمل"
fi

echo ""

# 2. اختبار Docker
echo "2️⃣ اختبار أوامر Docker..."
if docker ps > /dev/null 2>&1; then
    echo "✅ Docker يستجيب للأوامر"
    docker version
else
    echo "❌ Docker لا يستجيب"
    echo "محاولة إعادة التشغيل..."
fi

echo ""

# 3. التحقق من Docker Root Dir
echo "3️⃣ التحقق من مسار التخزين..."
docker info 2>/dev/null | grep -i "Docker Root Dir" || echo "⚠️ لا يمكن الحصول على معلومات Docker"

echo ""

# 4. فحص المساحة
echo "4️⃣ فحص المساحة المتاحة..."
df -h | grep -E "Filesystem|/tmp|overlay|/vscode"

echo ""

# 5. فحص السجلات
echo "5️⃣ فحص آخر أخطاء Docker..."
if [ -f /tmp/dockerd.log ]; then
    echo "آخر 10 أسطر من سجل Docker:"
    tail -10 /tmp/dockerd.log
fi

echo ""
echo "============================================"
echo "انتهى التشخيص"
echo "============================================"

نتائج التشخيص
➜ /workspaces/bisheng-enterprise (main) $ # ============================================
# تشخيص شامل للمشكلة
# ============================================

echo "🔍 بدء التشخيص الشامل..."
echo "============================================"
echo ""

# 1. التحقق من حالة Docker
echo "1️⃣ التحقق من Docker daemon..."
if sudo systemctl is-active --quiet docker 2>/dev/null; then
    echo "✅ Docker daemon يعمل (systemctl)"
echo "============================================" || echo "⚠️ لا يمكن الحصول على معلومات Docker"
🔍 بدء التشخيص الشامل...
============================================

1️⃣ التحقق من Docker daemon...

"systemd" is not running in this container due to its overhead.
Use the "service" command to start services instead. e.g.: 

service --status-all
✅ Docker daemon يعمل (systemctl)

2️⃣ اختبار أوامر Docker...
✅ Docker يستجيب للأوامر
Client:
 Version:           28.5.1-1
 API version:       1.51
 Go version:        go1.24.7
 Git commit:        e180ab8ab82d22b7895a3e6e110cf6dd5c45f1d7
 Built:             Wed Oct  8 02:50:32 UTC 2025
 OS/Arch:           linux/amd64
 Context:           default

Server:
 Engine:
  Version:          28.5.1-1
  API version:      1.51 (minimum version 1.24)
  Go version:       go1.24.7
  Git commit:       f8215cc266744ef195a50a70d427c345da2acdbb
  Built:            Wed Oct  8 02:34:32 2025
  OS/Arch:          linux/amd64
  Experimental:     false
 containerd:
  Version:          1.7.28-1
  GitCommit:        b98a3aace656320842a23f4a392a33f46af97866
 runc:
  Version:          1.3.2-2
  GitCommit:        aeabe4e711d903ef0ea86a4155da0f9e00eabd29
 docker-init:
  Version:          0.19.0
  GitCommit:        de40ad0

3️⃣ التحقق من مسار التخزين...
 Docker Root Dir: /tmp/docker-data

4️⃣ فحص المساحة المتاحة...
Filesystem      Size  Used Avail Use% Mounted on
overlay          32G   12G   19G  39% /
/dev/root        29G   21G  8.2G  72% /vscode
/dev/sda1       118G  3.5G  109G   4% /tmp

5️⃣ فحص آخر أخطاء Docker...
آخر 10 أسطر من سجل Docker:
time="2025-10-18T14:44:11.550818734Z" level=info msg="CDI directory does not exist, skipping: failed to monitor for changes: no such file or directory" dir=/var/run/cdi
time="2025-10-18T14:44:12.213251390Z" level=info msg="Creating a containerd client" address=/var/run/docker/containerd/containerd.sock timeout=1m0s
time="2025-10-18T14:44:12.756852676Z" level=info msg="Loading containers: start."
time="2025-10-18T14:44:12.984156437Z" level=info msg="Loading containers: done."
time="2025-10-18T14:44:13.001205071Z" level=warning msg="Not using native diff for overlay2, this may cause degraded performance for building images: kernel has CONFIG_OVERLAY_FS_REDIRECT_DIR enabled" storage-driver=overlay2
time="2025-10-18T14:44:13.001271415Z" level=info msg="Docker daemon" commit=f8215cc266744ef195a50a70d427c345da2acdbb containerd-snapshotter=false storage-driver=overlay2 version=28.5.1-1
time="2025-10-18T14:44:13.001342878Z" level=info msg="Initializing buildkit"
time="2025-10-18T14:44:13.022061114Z" level=info msg="Completed buildkit initialization"
time="2025-10-18T14:44:13.027166865Z" level=info msg="Daemon has completed initialization"
time="2025-10-18T14:44:13.027223145Z" level=info msg="API listen on /var/run/docker.sock"

============================================
انتهى التشخيص
============================================


🛠️ الحل المقترح (بناءً على التشخيص)

الحل 1: إعادة تشغيل Docker بشكل صحيح

# ============================================
# إعادة تشغيل Docker في Codespace
# ============================================

echo "🔄 إعادة تشغيل Docker..."
echo ""

# 1. إيقاف كل عمليات Docker
echo "1️⃣ إيقاف العمليات الجارية..."
sudo pkill -9 dockerd 2>/dev/null || true
sudo pkill -9 containerd 2>/dev/null || true
sleep 3

# 2. تنظيف
echo "2️⃣ تنظيف..."
sudo rm -f /var/run/docker.sock
sudo rm -f /var/run/docker.pid

# 3. التأكد من daemon.json
echo "3️⃣ التحقق من الإعدادات..."
cat /etc/docker/daemon.json

# 4. إعادة تشغيل Docker
echo "4️⃣ إعادة تشغيل Docker daemon..."
if [ -x /usr/local/share/docker-init.sh ]; then
    echo "استخدام docker-init.sh..."
    sudo /usr/local/share/docker-init.sh
else
    echo "تشغيل dockerd مباشرة..."
    sudo nohup dockerd --config-file=/etc/docker/daemon.json \
        > /tmp/dockerd.log 2>&1 &
fi

# 5. الانتظار حتى يصبح Docker جاهزاً
echo "5️⃣ انتظار Docker..."
for i in {1..30}; do
    if docker info > /dev/null 2>&1; then
        echo "✅ Docker جاهز!"
        break
    fi
    echo "  انتظار... ($i/30)"
    sleep 2
done

# 6. التحقق النهائي
echo ""
echo "6️⃣ التحقق النهائي..."
docker info | grep -E "Server Version|Docker Root Dir|Storage Driver"

echo ""
echo "✅ Docker تم إعادة تشغيله بنجاح"

الحل 2: بناء الصور بطريقة أكثر أماناً
بعد التأكد من عمل Docker، استخدم هذا البديل للبناء:

# ============================================
# بناء الصور بطريقة آمنة ومتدرجة
# ============================================

cd /workspaces/bisheng-enterprise

echo "🏗️ بناء الصور بطريقة آمنة..."
echo "============================================"
echo ""

# ============================================
# خيار 1: استخدام الصور الأساسية بدون تعديل (الأسرع)
# ============================================

echo "📦 الخيار الأول: استخدام الصور الأساسية مباشرة"
echo ""

# سحب الصور الأساسية
echo "1️⃣ سحب Backend base image..."
docker pull dataelement/bisheng-backend:v2.2.0-beta2
if [ $? -ne 0 ]; then
    echo "❌ فشل سحب backend image"
    echo "جرب:"
    echo "  docker pull dataelement/bisheng-backend:latest"
fi

echo ""
echo "2️⃣ سحب Frontend base image..."
docker pull dataelement/bisheng-frontend:v2.2.0-beta2
if [ $? -ne 0 ]; then
    echo "❌ فشل سحب frontend image"
    echo "جرب:"
    echo "  docker pull dataelement/bisheng-frontend:latest"
fi

echo ""

# إنشاء tags محلية
echo "3️⃣ إنشاء tags محلية..."
docker tag dataelement/bisheng-backend:v2.2.0-beta2 bisheng-backend-enterprise:latest 2>/dev/null || \
docker tag dataelement/bisheng-backend:latest bisheng-backend-enterprise:latest

docker tag dataelement/bisheng-frontend:v2.2.0-beta2 bisheng-frontend-enterprise:latest 2>/dev/null || \
docker tag dataelement/bisheng-frontend:latest bisheng-frontend-enterprise:latest

echo ""

# بناء backup image فقط (صغير وسريع)
echo "4️⃣ بناء Backup image..."
docker build -t bisheng-backup:latest custom-images/backup/ || {
    echo "❌ فشل بناء backup image"
    echo "سنستخدم Alpine مباشرة"
    docker pull alpine:3.19
    docker tag alpine:3.19 bisheng-backup:latest
}

echo ""
echo "============================================"
echo "✅ الصور جاهزة للاستخدام!"
echo "============================================"
echo ""

# التحقق
docker images | grep -E "bisheng|REPOSITORY"

echo ""
echo "🎯 الصور المتاحة الآن:"
docker images --format "{{.Repository}}:{{.Tag}}" | grep bisheng

🎯 خطة العمل الموصى بها لحل المشكلة
المسار السريع (موصى به):

# ============================================
# المسار السريع - تشغيل مباشر
# ============================================

cd /workspaces/bisheng-enterprise

# 1. إعادة تشغيل Docker
sudo pkill -9 dockerd; sleep 2; sudo /usr/local/share/docker-init.sh
sleep 5

# 2. اختبار Docker
docker run --rm hello-world

# 3. سحب الصور الأساسية مباشرة
docker pull postgres:15-alpine
docker pull redis:7.2-alpine
docker pull minio/minio:RELEASE.2023-03-20T20-16-18Z
docker pull dataelement/bisheng-backend:v2.2.0-beta2 || docker pull dataelement/bisheng-backend:latest
docker pull dataelement/bisheng-frontend:v2.2.0-beta2 || docker pull dataelement/bisheng-frontend:latest

# 4. إنشاء tags
docker tag dataelement/bisheng-backend:v2.2.0-beta2 bisheng-backend-enterprise:latest 2>/dev/null || true
docker tag dataelement/bisheng-frontend:v2.2.0-beta2 bisheng-frontend-enterprise:latest 2>/dev/null || true

# 5. التحقق
docker images

echo ""
echo "✅ جاهز للخطوة التالية!"

نتائج تنفيذ 📝 ما أقترحه الآن:

نفذ الأوامر بهذا الترتيب:

    التشخيص (الكود الأول) - اعرض النتائج
    إعادة تشغيل Docker (الحل 1)
    المسار السريع (الكود الأخير)

ثم أخبرني بالنتيجة، وسنكمل معاً.

نتائج تنفيذ  إعادة تشغيل Docker (الحل 1)

➜ /workspaces/bisheng-enterprise (main) $ # ============================================
# إعادة تشغيل Docker في Codespace
# ============================================

echo "🔄 إعادة تشغيل Docker..."
echo ""

# 1. إيقاف كل عمليات Docker
echo "1️⃣ إيقاف العمليات الجارية..."
sudo pkill -9 dockerd 2>/dev/null || true
sudo pkill -9 containerd 2>/dev/null || true
echo "✅ Docker تم إعادة تشغيله بنجاح"Docker Root Dir|Storage Driver"
🔄 إعادة تشغيل Docker...

1️⃣ إيقاف العمليات الجارية...
2️⃣ تنظيف...
3️⃣ التحقق من الإعدادات...
{
  "data-root": "/tmp/docker-data"
}
4️⃣ إعادة تشغيل Docker daemon...
استخدام docker-init.sh...
Setting dockerd Azure DNS.
5️⃣ انتظار Docker...
✅ Docker جاهز!

6️⃣ التحقق النهائي...
 Server Version: 28.5.1-1
 Storage Driver: overlay2
 Docker Root Dir: /tmp/docker-data

✅ Docker تم إعادة تشغيله بنجاح
 ➜ /workspaces/bisheng-enterprise (main) $ 


نتائج تنفيذالمسار السريع (الكود الأخير)

➜ /workspaces/bisheng-enterprise (main) $ # ============================================
# المسار السريع - تشغيل مباشر
# ============================================

cd /workspaces/bisheng-enterprise

# 1. إعادة تشغيل Docker
sudo pkill -9 dockerd; sleep 2; sudo /usr/local/share/docker-init.sh
sleep 5

# 2. اختبار Docker
echo "✅ جاهز للخطوة التالية!"-frontend:v2.2.0-beta2 bisheng-frontend-enterprise:latest 2>/dev/null || true
Setting dockerd Azure DNS.
Unable to find image 'hello-world:latest' locally
latest: Pulling from library/hello-world
17eec7bbc9d7: Pull complete 
Digest: sha256:6dc565aa630927052111f823c303948cf83670a3903ffa3849f1488ab517f891
Status: Downloaded newer image for hello-world:latest

Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
    (amd64)
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.

To try something more ambitious, you can run an Ubuntu container with:
 $ docker run -it ubuntu bash

Share images, automate workflows, and more with a free Docker ID:
 https://hub.docker.com/

For more examples and ideas, visit:
 https://docs.docker.com/get-started/

15-alpine: Pulling from library/postgres
2d35ebdb57d9: Pull complete 
cad436dd248c: Pull complete 
2ea3ebf7d306: Pull complete 
84a991b0a3f7: Pull complete 
3945a9548b2f: Pull complete 
a623f40cda43: Pull complete 
c60bbb65edfc: Pull complete 
76774548c03c: Pull complete 
b1b6b375f3c3: Pull complete 
6cd0b72d8da2: Pull complete 
6986ebe18735: Pull complete 
Digest: sha256:6bd113a3de3274beda0f056ebf0d75cf060dc4a493b72bea6f9d810dce63f897
Status: Downloaded newer image for postgres:15-alpine
docker.io/library/postgres:15-alpine
7.2-alpine: Pulling from library/redis
f637881d1138: Pull complete 
b42585dd5781: Pull complete 
7b00dfa6f01a: Pull complete 
9814da52ba6e: Pull complete 
046d5698e26d: Pull complete 
3a7323b794be: Pull complete 
4f4fb700ef54: Pull complete 
32431906a570: Pull complete 
Digest: sha256:1a34bdba051ecd8a58ec8a3cc460acef697a1605e918149cc53d920673c1a0a7
Status: Downloaded newer image for redis:7.2-alpine
docker.io/library/redis:7.2-alpine
RELEASE.2023-03-20T20-16-18Z: Pulling from minio/minio
c7e856e03741: Pull complete 
c1ff217ec952: Pull complete 
b12cc8972a67: Pull complete 
4324e307ea00: Pull complete 
152089595ebc: Pull complete 
05f217fb8612: Pull complete 
Digest: sha256:6d770d7f255cda1f18d841ffc4365cb7e0d237f6af6a15fcdb587480cd7c3b93
Status: Downloaded newer image for minio/minio:RELEASE.2023-03-20T20-16-18Z
docker.io/minio/minio:RELEASE.2023-03-20T20-16-18Z
v2.2.0-beta2: Pulling from dataelement/bisheng-backend
396b1da7636e: Pulling fs layer 
7732878f45d9: Pulling fs layer 
72e8e193aa94: Pulling fs layer 
3a195ff1e161: Pulling fs layer 
db784a34f885: Pulling fs layer 
0376f59a4d57: Pulling fs layer 
dc16ee938d05: Pulling fs layer 
63a7fc8cd262: Pull complete 
85abed0bdf37: Pull complete 
799a698ac773: Pull complete 
0d7635f20aef: Pull complete 
4f077a993c24: Pull complete 
abca10864064: Pull complete 
4f4fb700ef54: Pull complete 
80b562a6ada4: Pull complete 
25fd7eea304e: Pull complete 
55497a3bee83: Pull complete 
e95bd45a96ec: Pull complete 
Digest: sha256:bda0e419e53128c0373cb54d5d12f2526bff027d7d24d6b5e0ab0df9a3c5e7dc
Status: Downloaded newer image for dataelement/bisheng-backend:v2.2.0-beta2
docker.io/dataelement/bisheng-backend:v2.2.0-beta2
v2.2.0-beta2: Pulling from dataelement/bisheng-frontend
d107e437f729: Pull complete 
cb497a329a81: Pull complete 
f1c4d397f477: Pull complete 
f72106e86507: Pull complete 
899c83fc198b: Pull complete 
a785b80f5a67: Pull complete 
6c50e4e0c439: Pull complete 
e8e6bf73976a: Pull complete 
82a7ae5ac219: Pull complete 
a5cdb2152060: Pull complete 
Digest: sha256:aa3102b313a40021c67fa2e6a138e13e937d1576ebe8f881ed3cc4c9d91231b2
Status: Downloaded newer image for dataelement/bisheng-frontend:v2.2.0-beta2
docker.io/dataelement/bisheng-frontend:v2.2.0-beta2
REPOSITORY                     TAG                            IMAGE ID       CREATED        SIZE
redis                          7.2-alpine                     645b5492c574   2 weeks ago    40.9MB
postgres                       15-alpine                      45032e5996dc   2 weeks ago    273MB
dataelement/bisheng-backend    v2.2.0-beta2                   8000aa6f8f43   3 weeks ago    6.01GB
bisheng-backend-enterprise     latest                         8000aa6f8f43   3 weeks ago    6.01GB
dataelement/bisheng-frontend   v2.2.0-beta2                   2007cddf057d   3 weeks ago    292MB
bisheng-frontend-enterprise    latest                         2007cddf057d   3 weeks ago    292MB
hello-world                    latest                         1b44b5a3e06a   2 months ago   10.1kB
minio/minio                    RELEASE.2023-03-20T20-16-18Z   400c20c8aac0   2 years ago    252MB

✅ جاهز للخطوة التالية!
 ➜ /workspaces/bisheng-enterprise (main) $ 



🎉 ممتاز! الخطوة الثالثة: سحب باقي الصور وتحضير البيئة


# ============================================
# الخطوة 3: سحب باقي الصور وإعداد البيئة
# ============================================

cd /workspaces/bisheng-enterprise

echo "📦 سحب باقي الصور المطلوبة..."
echo "============================================"
echo ""

# ============================================
# 1. سحب Elasticsearch
# ============================================
echo "1️⃣ سحب Elasticsearch 8.12.0..."
docker pull docker.elastic.co/elasticsearch/elasticsearch:8.12.0

if [ $? -eq 0 ]; then
    echo "✅ Elasticsearch تم سحبها بنجاح"
else
    echo "⚠️ فشل سحب Elasticsearch، سنحاول نسخة أخرى..."
    docker pull elasticsearch:8.11.0
fi

echo ""

# ============================================
# 2. سحب Etcd (لـ Milvus)
# ============================================
echo "2️⃣ سحب Etcd..."
docker pull quay.io/coreos/etcd:v3.5.5

if [ $? -eq 0 ]; then
    echo "✅ Etcd تم سحبها بنجاح"
else
    echo "❌ فشل سحب Etcd"
fi

echo ""

# ============================================
# 3. سحب Milvus
# ============================================
echo "3️⃣ سحب Milvus 2.5.10..."
docker pull milvusdb/milvus:v2.5.10

if [ $? -eq 0 ]; then
    echo "✅ Milvus تم سحبها بنجاح"
else
    echo "⚠️ فشل سحب Milvus v2.5.10، سنحاول نسخة أخرى..."
    docker pull milvusdb/milvus:v2.3.0
fi

echo ""
echo "============================================"
echo "✅ جميع الصور تم سحبها!"
echo "============================================"
echo ""

# ============================================
# 4. عرض جميع الصور
# ============================================
echo "📊 قائمة الصور المتاحة:"
echo ""
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

echo ""

# ============================================
# 5. حساب المساحة المستخدمة
# ============================================
echo "💾 المساحة المستخدمة:"
docker system df

echo ""
echo "============================================"

# ============================================
# 6. التحقق من ملف .env.development
# ============================================
echo "⚙️ التحقق من ملف البيئة..."
echo ""

if [ ! -f .env.development ]; then
    echo "📝 إنشاء ملف .env.development..."
    
    cat > .env.development << 'ENV_EOF'
# ============================================
# Bisheng Enterprise - Development Environment
# ============================================

ENVIRONMENT=development
COMPOSE_PROJECT_NAME=bisheng-enterprise

# Database
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_DB=bisheng_dev
POSTGRES_USER=bisheng_dev
POSTGRES_PASSWORD=dev_password_123
DATABASE_URL=postgresql://bisheng_dev:dev_password_123@postgres:5432/bisheng_dev

# Redis
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_URL=redis://redis:6379/0
CELERY_BROKER_URL=redis://redis:6379/1

# Milvus
MILVUS_HOST=milvus
MILVUS_PORT=19530

# Elasticsearch
ELASTICSEARCH_HOST=elasticsearch
ELASTICSEARCH_PORT=9200
ELASTICSEARCH_URL=http://elasticsearch:9200
ELASTICSEARCH_PASSWORD=

# MinIO
MINIO_HOST=minio
MINIO_ENDPOINT=http://minio:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin123
MINIO_BUCKET=bisheng-dev

# Application
SECRET_KEY=dev-secret-key-change-me
BISHENG_ADMIN_USER=admin@bisheng.local
BISHENG_ADMIN_PASSWORD=admin123
LOG_LEVEL=INFO

# Features
ENABLE_OCR=true
ENABLE_DEBUG_TOOLBAR=false

# Workers
CELERY_WORKER_CONCURRENCY=2
WORKERS=1
ENV_EOF

    echo "✅ ملف .env.development تم إنشاؤه"
else
    echo "✅ ملف .env.development موجود مسبقاً"
fi

echo ""

# ============================================
# 7. إعداد docker-compose للتشغيل التدريجي
# ============================================
echo "🔧 إنشاء docker-compose للتشغيل التدريجي..."
echo ""

cat > docker-compose.step1.yml << 'COMPOSE_EOF'
# ============================================
# Bisheng Enterprise - Step 1: Infrastructure
# PostgreSQL + Redis + MinIO فقط
# ============================================
version: '3.8'

networks:
  bisheng-network:
    driver: bridge

volumes:
  postgres-data:
  redis-data:
  minio-data:

services:
  # PostgreSQL
  postgres:
    image: postgres:15-alpine
    container_name: bisheng-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-bisheng_dev}
      POSTGRES_USER: ${POSTGRES_USER:-bisheng_dev}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-dev_password_123}
    volumes:
      - postgres-data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    networks:
      - bisheng-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-bisheng_dev}"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Redis
  redis:
    image: redis:7.2-alpine
    container_name: bisheng-redis
    restart: unless-stopped
    command: redis-server --appendonly yes
    volumes:
      - redis-data:/data
    ports:
      - "6379:6379"
    networks:
      - bisheng-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  # MinIO
  minio:
    image: minio/minio:RELEASE.2023-03-20T20-16-18Z
    container_name: bisheng-minio
    restart: unless-stopped
    environment:
      MINIO_ROOT_USER: ${MINIO_ACCESS_KEY:-minioadmin}
      MINIO_ROOT_PASSWORD: ${MINIO_SECRET_KEY:-minioadmin123}
    volumes:
      - minio-data:/data
    ports:
      - "9000:9000"
      - "9001:9001"
    networks:
      - bisheng-network
    command: server /data --console-address ":9001"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 20s
      retries: 3
COMPOSE_EOF

echo "✅ تم إنشاء docker-compose.step1.yml"

echo ""
echo "============================================"
echo "✅ الخطوة 3 اكتملت بنجاح!"
echo "============================================"
echo ""

echo "📊 ملخص ما تم:"
echo "  ✅ تم سحب Elasticsearch"
echo "  ✅ تم سحب Etcd"
echo "  ✅ تم سحب Milvus"
echo "  ✅ تم إنشاء/التحقق من .env.development"
echo "  ✅ تم إنشاء docker-compose.step1.yml للاختبار"
echo ""

echo "📦 الصور المتاحة الآن:"
docker images --format "{{.Repository}}" | sort -u | grep -v "^$"

echo ""
echo "💾 المساحة الإجمالية المستخدمة:"
du -sh /tmp/docker-data 2>/dev/null || echo "المساحة: يتم حسابها بواسطة Docker"

echo ""
echo "🎯 الخطوة التالية:"
echo "  سيتم اختبار تشغيل الخدمات الأساسية:"
echo "  - PostgreSQL"
echo "  - Redis"
echo "  - MinIO"
echo ""
echo "⏸️  في انتظار أمر 'الخطوة التالية'..."


🎬 قم بتنفيذ الأوامر

انسخ الكود أعلاه والصقه في terminal.

هذه الخطوة ستقوم بـ:

    ✅ سحب Elasticsearch 8.12.0
    ✅ سحب Etcd v3.5.5
    ✅ سحب Milvus v2.5.10
    ✅ التحقق من/إنشاء ملف .env.development
    ✅ إنشاء docker-compose.step1.yml للاختبار التدريجي

كانت النتائج لتنفيذ الخطوة رقم 3 سحب بقية الصور كالتالي :

➜ /workspaces/bisheng-enterprise (main) $ # ============================================
# الخطوة 3: سحب باقي الصور وإعداد البيئة
# ============================================

cd /workspaces/bisheng-enterprise

echo "📦 سحب باقي الصور المطلوبة..."
echo "============================================"
echo ""

# ============================================
# 1. سحب Elasticsearch
# ============================================
echo "1️⃣ سحب Elasticsearch 8.12.0..."
docker pull docker.elastic.co/elasticsearch/elasticsearch:8.12.0

echo "⏸️  في انتظار أمر 'الخطوة التالية'..."""المساحة: يتم حسابها بواسطة Docker"v
📦 سحب باقي الصور المطلوبة...
============================================

1️⃣ سحب Elasticsearch 8.12.0...
8.12.0: Pulling from elasticsearch/elasticsearch
e4d291082c72: Pull complete 
e6947a0eeb2c: Pull complete 
af7f7cf6eb22: Pull complete 
89732bc75041: Pull complete 
d38d8a4afa78: Pull complete 
fb65ac828db6: Pull complete 
d3b6064b8ab8: Pull complete 
f8484251cc74: Pull complete 
9ffe1c016006: Pull complete 
e40fcac62c91: Pull complete 
Digest: sha256:ec72548cf833e58578d8ff40df44346a49480b2c88a4e73a91e1b85ec7ef0d44
Status: Downloaded newer image for docker.elastic.co/elasticsearch/elasticsearch:8.12.0
docker.elastic.co/elasticsearch/elasticsearch:8.12.0
✅ Elasticsearch تم سحبها بنجاح

2️⃣ سحب Etcd...
v3.5.5: Pulling from coreos/etcd
dbba69284b27: Pull complete 
270b322b3c62: Pull complete 
7c21e2da1038: Pull complete 
cb4f77bfee6c: Pull complete 
e5485096ca5d: Pull complete 
3ea3736f61e1: Pull complete 
1e815a2c4f55: Pull complete 
Digest: sha256:89b6debd43502d1088f3e02f39442fd3e951aa52bee846ed601cf4477114b89e
Status: Downloaded newer image for quay.io/coreos/etcd:v3.5.5
quay.io/coreos/etcd:v3.5.5
✅ Etcd تم سحبها بنجاح

3️⃣ سحب Milvus 2.5.10...
v2.5.10: Pulling from milvusdb/milvus
7646c8da3324: Pull complete 
ab26a7b25cc3: Pull complete 
2a04f6776554: Pull complete 
3ab4ca9180b0: Pull complete 
c6909e665471: Pull complete 
cd5e79a37fbf: Pull complete 
a9b3d7bb6508: Pull complete 
Digest: sha256:02e1d60d71ab60f435c60076f4fed2abe59602ecd5e18dcfe229c8c558c4379d
Status: Downloaded newer image for milvusdb/milvus:v2.5.10
docker.io/milvusdb/milvus:v2.5.10
✅ Milvus تم سحبها بنجاح

============================================
✅ جميع الصور تم سحبها!
============================================

📊 قائمة الصور المتاحة:

REPOSITORY                                      TAG                            SIZE
redis                                           7.2-alpine                     40.9MB
postgres                                        15-alpine                      273MB
bisheng-backend-enterprise                      latest                         6.01GB
dataelement/bisheng-backend                     v2.2.0-beta2                   6.01GB
dataelement/bisheng-frontend                    v2.2.0-beta2                   292MB
bisheng-frontend-enterprise                     latest                         292MB
hello-world                                     latest                         10.1kB
milvusdb/milvus                                 v2.5.10                        1.72GB
docker.elastic.co/elasticsearch/elasticsearch   8.12.0                         1.36GB
minio/minio                                     RELEASE.2023-03-20T20-16-18Z   252MB
quay.io/coreos/etcd                             v3.5.5                         182MB

💾 المساحة المستخدمة:
TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
Images          9         0         10.14GB   10.14GB (100%)
Containers      0         0         0B        0B
Local Volumes   0         0         0B        0B
Build Cache     0         0         0B        0B

============================================
⚙️ التحقق من ملف البيئة...

✅ ملف .env.development موجود مسبقاً

🔧 إنشاء docker-compose للتشغيل التدريجي...

✅ تم إنشاء docker-compose.step1.yml

============================================
✅ الخطوة 3 اكتملت بنجاح!
============================================

📊 ملخص ما تم:
  ✅ تم سحب Elasticsearch
  ✅ تم سحب Etcd
  ✅ تم سحب Milvus
  ✅ تم إنشاء/التحقق من .env.development
  ✅ تم إنشاء docker-compose.step1.yml للاختبار

📦 الصور المتاحة الآن:
bisheng-backend-enterprise
bisheng-frontend-enterprise
dataelement/bisheng-backend
dataelement/bisheng-frontend
docker.elastic.co/elasticsearch/elasticsearch
hello-world
milvusdb/milvus
minio/minio
postgres
quay.io/coreos/etcd
redis

💾 المساحة الإجمالية المستخدمة:
4.0K    /tmp/docker-data
المساحة: يتم حسابها بواسطة Docker

🎯 الخطوة التالية:
  سيتم اختبار تشغيل الخدمات الأساسية:
  - PostgreSQL
  - Redis
  - MinIO

⏸️  في انتظار أمر 'الخطوة التالية'...
➜ /workspaces/bisheng-enterprise (main) $ 

🚀 الخطوة الرابعة: تشغيل الخدمات الأساسية
📋 الخطوة 4: تشغيل واختبار PostgreSQL + Redis + MinIO


# ============================================
# الخطوة 4: تشغيل الخدمات الأساسية
# ============================================

cd /workspaces/bisheng-enterprise

echo "🚀 بدء تشغيل الخدمات الأساسية..."
echo "============================================"
echo ""

# ============================================
# 1. التحقق من عدم وجود حاويات سابقة
# ============================================
echo "1️⃣ التحقق من الحاويات الموجودة..."
if [ "$(docker ps -a -q)" ]; then
    echo "⚠️  يوجد حاويات سابقة، سيتم تنظيفها..."
    docker compose -f docker-compose.step1.yml down -v 2>/dev/null || true
    docker rm -f $(docker ps -a -q) 2>/dev/null || true
    echo "✅ تم التنظيف"
else
    echo "✅ لا توجد حاويات سابقة"
fi

echo ""

# ============================================
# 2. تشغيل الخدمات الأساسية
# ============================================
echo "2️⃣ تشغيل PostgreSQL + Redis + MinIO..."
echo "هذا قد يستغرق 1-2 دقيقة..."
echo ""

docker compose -f docker-compose.step1.yml --env-file .env.development up -d

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ تم تشغيل الخدمات بنجاح"
else
    echo ""
    echo "❌ فشل تشغيل الخدمات"
    echo "عرض السجلات:"
    docker compose -f docker-compose.step1.yml logs
    exit 1
fi

echo ""

# ============================================
# 3. انتظار جاهزية الخدمات
# ============================================
echo "3️⃣ انتظار جاهزية الخدمات..."
echo ""

# انتظار PostgreSQL
echo "  📊 PostgreSQL..."
for i in {1..30}; do
    if docker exec bisheng-postgres pg_isready -U bisheng_dev > /dev/null 2>&1; then
        echo "  ✅ PostgreSQL جاهز"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "  ❌ PostgreSQL لم يصبح جاهزاً"
    fi
    sleep 2
    echo "     انتظار... ($i/30)"
done

echo ""

# انتظار Redis
echo "  🔴 Redis..."
for i in {1..30}; do
    if docker exec bisheng-redis redis-cli ping > /dev/null 2>&1; then
        echo "  ✅ Redis جاهز"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "  ❌ Redis لم يصبح جاهزاً"
    fi
    sleep 2
    echo "     انتظار... ($i/30)"
done

echo ""

# انتظار MinIO
echo "  📦 MinIO..."
for i in {1..30}; do
    if curl -f http://localhost:9000/minio/health/live > /dev/null 2>&1; then
        echo "  ✅ MinIO جاهز"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "  ❌ MinIO لم يصبح جاهزاً"
    fi
    sleep 2
    echo "     انتظار... ($i/30)"
done

echo ""

# ============================================
# 4. التحقق من حالة الحاويات
# ============================================
echo "4️⃣ التحقق من حالة الحاويات..."
echo ""
docker compose -f docker-compose.step1.yml ps

echo ""

# ============================================
# 5. اختبار الاتصال بالخدمات
# ============================================
echo "5️⃣ اختبار الاتصال بالخدمات..."
echo ""

# PostgreSQL
echo "📊 اختبار PostgreSQL..."
docker exec bisheng-postgres psql -U bisheng_dev -d bisheng_dev -c "SELECT version();" | head -3
if [ $? -eq 0 ]; then
    echo "✅ PostgreSQL يعمل بشكل صحيح"
else
    echo "❌ مشكلة في PostgreSQL"
fi

echo ""

# Redis
echo "🔴 اختبار Redis..."
docker exec bisheng-redis redis-cli ping
if [ $? -eq 0 ]; then
    echo "✅ Redis يعمل بشكل صحيح"
else
    echo "❌ مشكلة في Redis"
fi

echo ""

# MinIO
echo "📦 اختبار MinIO..."
curl -I http://localhost:9000/minio/health/live 2>/dev/null | head -1
if [ $? -eq 0 ]; then
    echo "✅ MinIO يعمل بشكل صحيح"
else
    echo "❌ مشكلة في MinIO"
fi

echo ""

# ============================================
# 6. اختبار إنشاء قاعدة بيانات
# ============================================
echo "6️⃣ اختبار إنشاء جدول في PostgreSQL..."
docker exec bisheng-postgres psql -U bisheng_dev -d bisheng_dev -c "
CREATE TABLE IF NOT EXISTS test_table (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO test_table (name) VALUES ('test_entry');

SELECT * FROM test_table;
" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ PostgreSQL يمكنه إنشاء الجداول والبيانات"
else
    echo "❌ مشكلة في عمليات PostgreSQL"
fi

echo ""

# ============================================
# 7. اختبار Redis
# ============================================
echo "7️⃣ اختبار تخزين البيانات في Redis..."
docker exec bisheng-redis redis-cli SET test_key "test_value" > /dev/null
REDIS_VALUE=$(docker exec bisheng-redis redis-cli GET test_key)

if [ "$REDIS_VALUE" = "test_value" ]; then
    echo "✅ Redis يمكنه تخزين واسترجاع البيانات"
else
    echo "❌ مشكلة في عمليات Redis"
fi

echo ""

# ============================================
# 8. معلومات الوصول
# ============================================
echo "============================================"
echo "✅ الخطوة 4 اكتملت بنجاح!"
echo "============================================"
echo ""
echo "📊 ملخص الخدمات الجارية:"
docker compose -f docker-compose.step1.yml ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "🌐 معلومات الوصول:"
echo "  PostgreSQL:"
echo "    - Host: localhost"
echo "    - Port: 5432"
echo "    - Database: bisheng_dev"
echo "    - User: bisheng_dev"
echo "    - Password: dev_password_123"
echo "    - الاتصال: psql -h localhost -U bisheng_dev -d bisheng_dev"
echo ""
echo "  Redis:"
echo "    - Host: localhost"
echo "    - Port: 6379"
echo "    - الاتصال: redis-cli -h localhost"
echo ""
echo "  MinIO:"
echo "    - API: http://localhost:9000"
echo "    - Console: http://localhost:9001"
echo "    - User: minioadmin"
echo "    - Password: minioadmin123"
echo ""

# ============================================
# 9. عرض السجلات
# ============================================
echo "📝 آخر سجلات الخدمات:"
echo ""
docker compose -f docker-compose.step1.yml logs --tail=5

echo ""
echo "============================================"
echo ""
echo "💡 نصائح:"
echo "  - لعرض السجلات المباشرة: docker compose -f docker-compose.step1.yml logs -f"
echo "  - لإيقاف الخدمات: docker compose -f docker-compose.step1.yml stop"
echo "  - لحذف كل شيء: docker compose -f docker-compose.step1.yml down -v"
echo ""
echo "🎯 الخطوة التالية:"
echo "  سيتم إضافة وتشغيل الخدمات المتقدمة:"
echo "  - Etcd (لـ Milvus)"
echo "  - Milvus (قاعدة بيانات المتجهات)"
echo "  - Elasticsearch (البحث النصي)"
echo ""
echo "⏸️  في انتظار أمر 'الخطوة التالية'..."




🎬 قم بتنفيذ الأوامر

انسخ الكود أعلاه والصقه في terminal.

هذه الخطوة ستقوم بـ:

    ✅ تنظيف أي حاويات سابقة
    ✅ تشغيل PostgreSQL + Redis + MinIO
    ✅ انتظار جاهزية الخدمات
    ✅ اختبار الاتصال بكل خدمة
    ✅ اختبار عمليات قاعدة البيانات
    ✅ عرض معلومات الوصول

⏱️ الوقت المتوقع: 2-3 دقائق

النتائج كانت على النحو التالي :

➜ /workspaces/bisheng-enterprise (main) $ # ============================================
# الخطوة 4: تشغيل الخدمات الأساسية
# ============================================

cd /workspaces/bisheng-enterprise

echo "🚀 بدء تشغيل الخدمات الأساسية..."
echo "============================================"
echo ""

# ============================================
# 1. التحقق من عدم وجود حاويات سابقة
# ============================================
echo "1️⃣ التحقق من الحاويات الموجودة..."
if [ "$(docker ps -a -q)" ]; then
    echo "⚠️  يوجد حاويات سابقة، سيتم تنظيفها..."
echo "⏸️  في انتظار أمر 'الخطوة التالية'...""ker-compose.step1.yml down -v"l logs -f"\t{{.Ports}}"
🚀 بدء تشغيل الخدمات الأساسية...
============================================

1️⃣ التحقق من الحاويات الموجودة...
✅ لا توجد حاويات سابقة

2️⃣ تشغيل PostgreSQL + Redis + MinIO...
هذا قد يستغرق 1-2 دقيقة...

WARN[0000] /workspaces/bisheng-enterprise/docker-compose.step1.yml: the attribute `version` is obsolete, it will be ignored, please remove it to avoid potential confusion 
[+] Running 7/7
 ✔ Network bisheng-enterprise_bisheng-network  Created                                                                                0.0s 
 ✔ Volume bisheng-enterprise_redis-data        Created                                                                                0.0s 
 ✔ Volume bisheng-enterprise_minio-data        Created                                                                                0.0s 
 ✔ Volume bisheng-enterprise_postgres-data     Created                                                                                0.0s 
 ✔ Container bisheng-postgres                  Started                                                                                0.4s 
 ✔ Container bisheng-redis                     Started                                                                                0.4s 
 ✔ Container bisheng-minio                     Started                                                                                0.5s 

✅ تم تشغيل الخدمات بنجاح

3️⃣ انتظار جاهزية الخدمات...

  📊 PostgreSQL...
     انتظار... (1/30)
  ✅ PostgreSQL جاهز

  🔴 Redis...
  ✅ Redis جاهز

  📦 MinIO...
  ✅ MinIO جاهز

4️⃣ التحقق من حالة الحاويات...

WARN[0000] /workspaces/bisheng-enterprise/docker-compose.step1.yml: the attribute `version` is obsolete, it will be ignored, please remove it to avoid potential confusion 
NAME               IMAGE                                      COMMAND                  SERVICE    CREATED         STATUS                            PORTS
bisheng-minio      minio/minio:RELEASE.2023-03-20T20-16-18Z   "/usr/bin/docker-ent…"   minio      4 seconds ago   Up 4 seconds (health: starting)   0.0.0.0:9000-9001->9000-9001/tcp, [::]:9000-9001->9000-9001/tcp
bisheng-postgres   postgres:15-alpine                         "docker-entrypoint.s…"   postgres   4 seconds ago   Up 4 seconds (health: starting)   0.0.0.0:5432->5432/tcp, [::]:5432->5432/tcp
bisheng-redis      redis:7.2-alpine                           "docker-entrypoint.s…"   redis      4 seconds ago   Up 4 seconds (health: starting)   0.0.0.0:6379->6379/tcp, [::]:6379->6379/tcp

5️⃣ اختبار الاتصال بالخدمات...

📊 اختبار PostgreSQL...
                                         version                                          
------------------------------------------------------------------------------------------
 PostgreSQL 15.14 on x86_64-pc-linux-musl, compiled by gcc (Alpine 14.2.0) 14.2.0, 64-bit
✅ PostgreSQL يعمل بشكل صحيح

🔴 اختبار Redis...
PONG
✅ Redis يعمل بشكل صحيح

📦 اختبار MinIO...
HTTP/1.1 200 OK
✅ MinIO يعمل بشكل صحيح

6️⃣ اختبار إنشاء جدول في PostgreSQL...
CREATE TABLE
INSERT 0 1
 id |    name    |         created_at         
----+------------+----------------------------
  1 | test_entry | 2025-10-18 15:21:31.779307
(1 row)

✅ PostgreSQL يمكنه إنشاء الجداول والبيانات

7️⃣ اختبار تخزين البيانات في Redis...
✅ Redis يمكنه تخزين واسترجاع البيانات

============================================
✅ الخطوة 4 اكتملت بنجاح!
============================================

📊 ملخص الخدمات الجارية:
WARN[0000] /workspaces/bisheng-enterprise/docker-compose.step1.yml: the attribute `version` is obsolete, it will be ignored, please remove it to avoid potential confusion 
NAME               STATUS                            PORTS
bisheng-minio      Up 5 seconds (health: starting)   0.0.0.0:9000-9001->9000-9001/tcp, [::]:9000-9001->9000-9001/tcp
bisheng-postgres   Up 5 seconds (health: starting)   0.0.0.0:5432->5432/tcp, [::]:5432->5432/tcp
bisheng-redis      Up 5 seconds (health: starting)   0.0.0.0:6379->6379/tcp, [::]:6379->6379/tcp

🌐 معلومات الوصول:
  PostgreSQL:
    - Host: localhost
    - Port: 5432
    - Database: bisheng_dev
    - User: bisheng_dev
    - Password: dev_password_123
    - الاتصال: psql -h localhost -U bisheng_dev -d bisheng_dev

  Redis:
    - Host: localhost
    - Port: 6379
    - الاتصال: redis-cli -h localhost

  MinIO:
    - API: http://localhost:9000
    - Console: http://localhost:9001
    - User: minioadmin
    - Password: minioadmin123

📝 آخر سجلات الخدمات:

WARN[0000] /workspaces/bisheng-enterprise/docker-compose.step1.yml: the attribute `version` is obsolete, it will be ignored, please remove it to avoid potential confusion 
bisheng-postgres  | 2025-10-18 15:21:28.929 UTC [1] LOG:  listening on IPv4 address "0.0.0.0", port 5432
bisheng-postgres  | 2025-10-18 15:21:28.929 UTC [1] LOG:  listening on IPv6 address "::", port 5432
bisheng-postgres  | 2025-10-18 15:21:28.930 UTC [1] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
bisheng-postgres  | 2025-10-18 15:21:28.932 UTC [62] LOG:  database system was shut down at 2025-10-18 15:21:28 UTC
bisheng-postgres  | 2025-10-18 15:21:28.936 UTC [1] LOG:  database system is ready to accept connections
bisheng-redis     | 1:M 18 Oct 2025 15:21:27.490 * Running mode=standalone, port=6379.
bisheng-redis     | 1:M 18 Oct 2025 15:21:27.490 * Server initialized
bisheng-redis     | 1:M 18 Oct 2025 15:21:27.492 * Creating AOF base file appendonly.aof.1.base.rdb on server start
bisheng-redis     | 1:M 18 Oct 2025 15:21:27.493 * Creating AOF incr file appendonly.aof.1.incr.aof on server start
bisheng-redis     | 1:M 18 Oct 2025 15:21:27.493 * Ready to accept connections tcp
bisheng-minio     | 
bisheng-minio     |  You are running an older version of MinIO released 2 years ago 
bisheng-minio     |  Update: Run `mc admin update` 
bisheng-minio     | 
bisheng-minio     | 

============================================

💡 نصائح:
  - لعرض السجلات المباشرة: docker compose -f docker-compose.step1.yml logs -f
  - لإيقاف الخدمات: docker compose -f docker-compose.step1.yml stop
  - لحذف كل شيء: docker compose -f docker-compose.step1.yml down -v

🎯 الخطوة التالية:
  سيتم إضافة وتشغيل الخدمات المتقدمة:
  - Etcd (لـ Milvus)
  - Milvus (قاعدة بيانات المتجهات)
  - Elasticsearch (البحث النصي)

⏸️  في انتظار أمر 'الخطوة التالية'...
 ➜ /workspaces/bisheng-enterprise (main) $ 


🚀 الخطوة الخامسة: تشغيل الخدمات المتقدمة
📋 الخطوة 5: إضافة Etcd + Milvus + Elasticsearch
أوامر التنفيذ:

# ============================================
# الخطوة 5: تشغيل الخدمات المتقدمة
# ============================================

cd /workspaces/bisheng-enterprise

echo "🚀 بدء تشغيل الخدمات المتقدمة..."
echo "============================================"
echo ""

# ============================================
# 1. إنشاء docker-compose.step2.yml
# ============================================
echo "1️⃣ إنشاء ملف التكوين للخدمات المتقدمة..."

cat > docker-compose.step2.yml << 'COMPOSE_EOF'
# ============================================
# Bisheng Enterprise - Step 2: Advanced Services
# إضافة Etcd + Milvus + Elasticsearch
# ============================================
version: '3.8'

networks:
  bisheng-network:
    driver: bridge

volumes:
  postgres-data:
  redis-data:
  minio-data:
  etcd-data:
  milvus-data:
  elasticsearch-data:

services:
  # ============================================
  # الخدمات الأساسية (من الخطوة السابقة)
  # ============================================
  postgres:
    image: postgres:15-alpine
    container_name: bisheng-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-bisheng_dev}
      POSTGRES_USER: ${POSTGRES_USER:-bisheng_dev}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-dev_password_123}
    volumes:
      - postgres-data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    networks:
      - bisheng-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-bisheng_dev}"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7.2-alpine
    container_name: bisheng-redis
    restart: unless-stopped
    command: redis-server --appendonly yes
    volumes:
      - redis-data:/data
    ports:
      - "6379:6379"
    networks:
      - bisheng-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  minio:
    image: minio/minio:RELEASE.2023-03-20T20-16-18Z
    container_name: bisheng-minio
    restart: unless-stopped
    environment:
      MINIO_ROOT_USER: ${MINIO_ACCESS_KEY:-minioadmin}
      MINIO_ROOT_PASSWORD: ${MINIO_SECRET_KEY:-minioadmin123}
    volumes:
      - minio-data:/data
    ports:
      - "9000:9000"
      - "9001:9001"
    networks:
      - bisheng-network
    command: server /data --console-address ":9001"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 20s
      retries: 3

  # ============================================
  # الخدمات المتقدمة
  # ============================================
  
  # Etcd (لـ Milvus)
  etcd:
    image: quay.io/coreos/etcd:v3.5.5
    container_name: bisheng-etcd
    restart: unless-stopped
    environment:
      ETCD_AUTO_COMPACTION_MODE: revision
      ETCD_AUTO_COMPACTION_RETENTION: 1000
      ETCD_QUOTA_BACKEND_BYTES: 4294967296
      ETCD_SNAPSHOT_COUNT: 50000
    volumes:
      - etcd-data:/etcd
    networks:
      - bisheng-network
    command: >
      etcd
      -advertise-client-urls=http://127.0.0.1:2379
      -listen-client-urls=http://0.0.0.0:2379
      --data-dir=/etcd
    healthcheck:
      test: ["CMD", "etcdctl", "endpoint", "health"]
      interval: 30s
      timeout: 20s
      retries: 3

  # Milvus
  milvus:
    image: milvusdb/milvus:v2.5.10
    container_name: bisheng-milvus
    restart: unless-stopped
    environment:
      ETCD_ENDPOINTS: etcd:2379
      MINIO_ADDRESS: minio:9000
      MINIO_ACCESS_KEY_ID: ${MINIO_ACCESS_KEY:-minioadmin}
      MINIO_SECRET_ACCESS_KEY: ${MINIO_SECRET_KEY:-minioadmin123}
    volumes:
      - milvus-data:/var/lib/milvus
    ports:
      - "19530:19530"
      - "9091:9091"
    networks:
      - bisheng-network
    command: ["milvus", "run", "standalone"]
    depends_on:
      etcd:
        condition: service_healthy
      minio:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9091/healthz"]
      interval: 30s
      timeout: 20s
      retries: 5
      start_period: 90s

  # Elasticsearch
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.12.0
    container_name: bisheng-elasticsearch
    restart: unless-stopped
    environment:
      discovery.type: single-node
      xpack.security.enabled: "false"
      ES_JAVA_OPTS: "-Xms512m -Xmx512m"
      bootstrap.memory_lock: "false"
    volumes:
      - elasticsearch-data:/usr/share/elasticsearch/data
    ports:
      - "9200:9200"
    networks:
      - bisheng-network
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9200/_cluster/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s
COMPOSE_EOF

echo "✅ تم إنشاء docker-compose.step2.yml"

echo ""

# ============================================
# 2. إيقاف الخدمات الحالية
# ============================================
echo "2️⃣ إيقاف الخدمات الأساسية للانتقال للإصدار المتقدم..."
docker compose -f docker-compose.step1.yml down

echo "✅ تم إيقاف الخدمات الأساسية"
echo ""

# ============================================
# 3. تشغيل جميع الخدمات (أساسية + متقدمة)
# ============================================
echo "3️⃣ تشغيل جميع الخدمات (أساسية + متقدمة)..."
echo "⏱️  هذا قد يستغرق 3-5 دقائق..."
echo ""

docker compose -f docker-compose.step2.yml --env-file .env.development up -d

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ تم تشغيل الخدمات بنجاح"
else
    echo ""
    echo "❌ فشل تشغيل الخدمات"
    docker compose -f docker-compose.step2.yml logs
    exit 1
fi

echo ""

# ============================================
# 4. مراقبة بدء الخدمات
# ============================================
echo "4️⃣ مراقبة بدء الخدمات..."
echo ""

# عرض حالة الحاويات
echo "📊 حالة الحاويات:"
docker compose -f docker-compose.step2.yml ps

echo ""
echo "⏳ انتظار جاهزية الخدمات (قد يستغرق 2-3 دقائق)..."
echo ""

# انتظار PostgreSQL
echo "  1/6 📊 PostgreSQL..."
for i in {1..30}; do
    if docker exec bisheng-postgres pg_isready -U bisheng_dev > /dev/null 2>&1; then
        echo "       ✅ PostgreSQL جاهز"
        break
    fi
    sleep 2
done

# انتظار Redis
echo "  2/6 🔴 Redis..."
for i in {1..30}; do
    if docker exec bisheng-redis redis-cli ping > /dev/null 2>&1; then
        echo "       ✅ Redis جاهز"
        break
    fi
    sleep 2
done

# انتظار MinIO
echo "  3/6 📦 MinIO..."
for i in {1..30}; do
    if curl -f http://localhost:9000/minio/health/live > /dev/null 2>&1; then
        echo "       ✅ MinIO جاهز"
        break
    fi
    sleep 2
done

# انتظار Etcd
echo "  4/6 🔷 Etcd..."
for i in {1..30}; do
    if docker exec bisheng-etcd etcdctl endpoint health > /dev/null 2>&1; then
        echo "       ✅ Etcd جاهز"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "       ⚠️ Etcd لم يصبح جاهزاً بعد، سنستمر..."
    fi
    sleep 2
done

# انتظار Milvus (يحتاج وقت أطول)
echo "  5/6 🔺 Milvus (قد يستغرق دقيقتين)..."
for i in {1..60}; do
    if curl -f http://localhost:9091/healthz > /dev/null 2>&1; then
        echo "       ✅ Milvus جاهز"
        break
    fi
    if [ $((i % 10)) -eq 0 ]; then
        echo "       ⏳ انتظار... ($i/60)"
    fi
    sleep 2
done

# انتظار Elasticsearch
echo "  6/6 🔍 Elasticsearch (قد يستغرق دقيقتين)..."
for i in {1..60}; do
    if curl -f http://localhost:9200/_cluster/health > /dev/null 2>&1; then
        echo "       ✅ Elasticsearch جاهز"
        break
    fi
    if [ $((i % 10)) -eq 0 ]; then
        echo "       ⏳ انتظار... ($i/60)"
    fi
    sleep 2
done

echo ""

# ============================================
# 5. اختبار الاتصال بالخدمات المتقدمة
# ============================================
echo "5️⃣ اختبار الاتصال بالخدمات..."
echo ""

# Milvus
echo "🔺 اختبار Milvus..."
MILVUS_HEALTH=$(curl -s http://localhost:9091/healthz)
if [ "$MILVUS_HEALTH" = "OK" ]; then
    echo "✅ Milvus يعمل بشكل صحيح"
else
    echo "⚠️ Milvus: $MILVUS_HEALTH"
fi

echo ""

# Elasticsearch
echo "🔍 اختبار Elasticsearch..."
ES_HEALTH=$(curl -s http://localhost:9200/_cluster/health | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
if [ -n "$ES_HEALTH" ]; then
    echo "✅ Elasticsearch يعمل (حالة: $ES_HEALTH)"
    curl -s http://localhost:9200 | grep -E "cluster_name|version" | head -2
else
    echo "⚠️ Elasticsearch لم يستجب بعد"
fi

echo ""

# Etcd
echo "🔷 اختبار Etcd..."
if docker exec bisheng-etcd etcdctl endpoint health 2>/dev/null | grep -q "is healthy"; then
    echo "✅ Etcd يعمل بشكل صحيح"
else
    echo "⚠️ Etcd قد لا يكون جاهزاً بالكامل"
fi

echo ""

# ============================================
# 6. حالة نهائية
# ============================================
echo "6️⃣ الحالة النهائية لجميع الخدمات..."
echo ""
docker compose -f docker-compose.step2.yml ps

echo ""
echo "============================================"
echo "✅ الخطوة 5 اكتملت بنجاح!"
echo "============================================"
echo ""

echo "📊 ملخص الخدمات الجارية:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep bisheng

echo ""
echo "🌐 معلومات الوصول للخدمات الجديدة:"
echo ""
echo "  Milvus (قاعدة بيانات المتجهات):"
echo "    - gRPC Port: 19530"
echo "    - Metrics: http://localhost:9091/metrics"
echo "    - Health: http://localhost:9091/healthz"
echo ""
echo "  Elasticsearch (البحث النصي):"
echo "    - API: http://localhost:9200"
echo "    - Health: http://localhost:9200/_cluster/health"
echo "    - اختبار: curl http://localhost:9200"
echo ""
echo "  Etcd (تنسيق Milvus):"
echo "    - Client Port: 2379 (داخلي)"
echo ""

echo "💡 نصائح للفحص:"
echo "  - حالة Elasticsearch: curl http://localhost:9200/_cat/health?v"
echo "  - حالة Milvus: curl http://localhost:9091/healthz"
echo "  - سجلات Milvus: docker logs bisheng-milvus --tail 50"
echo "  - سجلات Elasticsearch: docker logs bisheng-elasticsearch --tail 50"
echo ""

echo "🎯 الخطوة التالية:"
echo "  سيتم إضافة وتشغيل خدمات Bisheng (Backend + Frontend)"
echo ""
echo "⏸️  في انتظار أمر 'الخطوة التالية'..."






🎬 قم بتنفيذ الأوامر

انسخ الكود أعلاه والصقه في terminal.

هذه الخطوة ستقوم بـ:

    ✅ إنشاء docker-compose.step2.yml مع جميع الخدمات
    ✅ إيقاف الخدمات الأساسية السابقة
    ✅ تشغيل جميع الخدمات (أساسية + متقدمة)
    ✅ مراقبة وانتظار جاهزية كل خدمة
    ✅ اختبار الاتصال بالخدمات الجديدة
    ✅ عرض معلومات الوصول

⏱️ الوقت المتوقع: 3-5 دقائق

ملاحظة: Milvus و Elasticsearch يحتاجان وقتاً أطول للبدء، لذلك قد ترى "انتظار..." عدة مرات - هذا طبيعي.

نتائج تنفيذ الخطوات المتقدمة:

➜ /workspaces/bisheng-enterprise (main) $ # ============================================
# الخطوة 5: تشغيل الخدمات المتقدمة
# ============================================

cd /workspaces/bisheng-enterprise

echo "🚀 بدء تشغيل الخدمات المتقدمة..."
echo "============================================"
echo ""

# ============================================
# 1. إنشاء docker-compose.step2.yml
# ============================================
echo "1️⃣ إنشاء ملف التكوين للخدمات المتقدمة..."

cat > docker-compose.step2.yml << 'COMPOSE_EOF'
echo "⏸️  في انتظار أمر 'الخطوة التالية'..."ckend + Frontend)"rch --tail 50"ng healthy"; then -d'"' -f4)
🚀 بدء تشغيل الخدمات المتقدمة...
============================================

1️⃣ إنشاء ملف التكوين للخدمات المتقدمة...
✅ تم إنشاء docker-compose.step2.yml

2️⃣ إيقاف الخدمات الأساسية للانتقال للإصدار المتقدم...
WARN[0000] /workspaces/bisheng-enterprise/docker-compose.step1.yml: the attribute `version` is obsolete, it will be ignored, please remove it to avoid potential confusion 
[+] Running 4/4
 ✔ Container bisheng-redis                     Removed                                                                                0.3s 
 ✔ Container bisheng-minio                     Removed                                                                                0.6s 
 ✔ Container bisheng-postgres                  Removed                                                                                0.2s 
 ✔ Network bisheng-enterprise_bisheng-network  Removed                                                                                0.0s 
✅ تم إيقاف الخدمات الأساسية

3️⃣ تشغيل جميع الخدمات (أساسية + متقدمة)...
⏱️  هذا قد يستغرق 3-5 دقائق...

WARN[0000] /workspaces/bisheng-enterprise/docker-compose.step2.yml: the attribute `version` is obsolete, it will be ignored, please remove it to avoid potential confusion 
[+] Running 10/10
 ✔ Network bisheng-enterprise_bisheng-network    Created                                                                              0.0s 
 ✔ Volume bisheng-enterprise_etcd-data           Created                                                                              0.0s 
 ✔ Volume bisheng-enterprise_milvus-data         Created                                                                              0.0s 
 ✔ Volume bisheng-enterprise_elasticsearch-data  Created                                                                              0.0s 
 ✔ Container bisheng-minio                       Healthy                                                                             30.5s 
 ✔ Container bisheng-etcd                        Healthy                                                                             31.0s 
 ✔ Container bisheng-postgres                    Started                                                                              0.3s 
 ✔ Container bisheng-redis                       Started                                                                              0.4s 
 ✔ Container bisheng-elasticsearch               Started                                                                              0.3s 
 ✔ Container bisheng-milvus                      Started                                                                             31.1s 

✅ تم تشغيل الخدمات بنجاح

4️⃣ مراقبة بدء الخدمات...

📊 حالة الحاويات:
WARN[0000] /workspaces/bisheng-enterprise/docker-compose.step2.yml: the attribute `version` is obsolete, it will be ignored, please remove it to avoid potential confusion 
NAME                    IMAGE                                                  COMMAND                  SERVICE         CREATED          STATUS                                     PORTS
bisheng-elasticsearch   docker.elastic.co/elasticsearch/elasticsearch:8.12.0   "/bin/tini -- /usr/l…"   elasticsearch   31 seconds ago   Up 31 seconds (healthy)                    0.0.0.0:9200->9200/tcp, [::]:9200->9200/tcp, 9300/tcp
bisheng-etcd            quay.io/coreos/etcd:v3.5.5                             "etcd -advertise-cli…"   etcd            31 seconds ago   Up 31 seconds (healthy)                    2379-2380/tcp
bisheng-milvus          milvusdb/milvus:v2.5.10                                "/tini -- milvus run…"   milvus          31 seconds ago   Up Less than a second (health: starting)   0.0.0.0:9091->9091/tcp, [::]:9091->9091/tcp, 0.0.0.0:19530->19530/tcp, [::]:19530->19530/tcp
bisheng-minio           minio/minio:RELEASE.2023-03-20T20-16-18Z               "/usr/bin/docker-ent…"   minio           31 seconds ago   Up 31 seconds (healthy)                    0.0.0.0:9000-9001->9000-9001/tcp, [::]:9000-9001->9000-9001/tcp
bisheng-postgres        postgres:15-alpine                                     "docker-entrypoint.s…"   postgres        31 seconds ago   Up 31 seconds (healthy)                    0.0.0.0:5432->5432/tcp, [::]:5432->5432/tcp
bisheng-redis           redis:7.2-alpine                                       "docker-entrypoint.s…"   redis           31 seconds ago   Up 31 seconds (healthy)                    0.0.0.0:6379->6379/tcp, [::]:6379->6379/tcp

⏳ انتظار جاهزية الخدمات (قد يستغرق 2-3 دقائق)...

  1/6 📊 PostgreSQL...
       ✅ PostgreSQL جاهز
  2/6 🔴 Redis...
       ✅ Redis جاهز
  3/6 📦 MinIO...
       ✅ MinIO جاهز
  4/6 🔷 Etcd...
       ✅ Etcd جاهز
  5/6 🔺 Milvus (قد يستغرق دقيقتين)...
       ✅ Milvus جاهز
  6/6 🔍 Elasticsearch (قد يستغرق دقيقتين)...
       ✅ Elasticsearch جاهز

5️⃣ اختبار الاتصال بالخدمات...

🔺 اختبار Milvus...
✅ Milvus يعمل بشكل صحيح

🔍 اختبار Elasticsearch...
✅ Elasticsearch يعمل (حالة: green)
  "cluster_name" : "docker-cluster",
  "version" : {

🔷 اختبار Etcd...
✅ Etcd يعمل بشكل صحيح

6️⃣ الحالة النهائية لجميع الخدمات...

WARN[0000] /workspaces/bisheng-enterprise/docker-compose.step2.yml: the attribute `version` is obsolete, it will be ignored, please remove it to avoid potential confusion 
NAME                    IMAGE                                                  COMMAND                  SERVICE         CREATED          STATUS                            PORTS
bisheng-elasticsearch   docker.elastic.co/elasticsearch/elasticsearch:8.12.0   "/bin/tini -- /usr/l…"   elasticsearch   34 seconds ago   Up 34 seconds (healthy)           0.0.0.0:9200->9200/tcp, [::]:9200->9200/tcp, 9300/tcp
bisheng-etcd            quay.io/coreos/etcd:v3.5.5                             "etcd -advertise-cli…"   etcd            34 seconds ago   Up 34 seconds (healthy)           2379-2380/tcp
bisheng-milvus          milvusdb/milvus:v2.5.10                                "/tini -- milvus run…"   milvus          34 seconds ago   Up 3 seconds (health: starting)   0.0.0.0:9091->9091/tcp, [::]:9091->9091/tcp, 0.0.0.0:19530->19530/tcp, [::]:19530->19530/tcp
bisheng-minio           minio/minio:RELEASE.2023-03-20T20-16-18Z               "/usr/bin/docker-ent…"   minio           34 seconds ago   Up 34 seconds (healthy)           0.0.0.0:9000-9001->9000-9001/tcp, [::]:9000-9001->9000-9001/tcp
bisheng-postgres        postgres:15-alpine                                     "docker-entrypoint.s…"   postgres        34 seconds ago   Up 34 seconds (healthy)           0.0.0.0:5432->5432/tcp, [::]:5432->5432/tcp
bisheng-redis           redis:7.2-alpine                                       "docker-entrypoint.s…"   redis           34 seconds ago   Up 34 seconds (healthy)           0.0.0.0:6379->6379/tcp, [::]:6379->6379/tcp

============================================
✅ الخطوة 5 اكتملت بنجاح!
============================================

📊 ملخص الخدمات الجارية:
bisheng-milvus          Up 3 seconds (health: starting)   0.0.0.0:9091->9091/tcp, [::]:9091->9091/tcp, 0.0.0.0:19530->19530/tcp, [::]:19530->19530/tcp
bisheng-redis           Up 34 seconds (healthy)           0.0.0.0:6379->6379/tcp, [::]:6379->6379/tcp
bisheng-minio           Up 34 seconds (healthy)           0.0.0.0:9000-9001->9000-9001/tcp, [::]:9000-9001->9000-9001/tcp
bisheng-elasticsearch   Up 34 seconds (healthy)           0.0.0.0:9200->9200/tcp, [::]:9200->9200/tcp, 9300/tcp
bisheng-postgres        Up 34 seconds (healthy)           0.0.0.0:5432->5432/tcp, [::]:5432->5432/tcp
bisheng-etcd            Up 34 seconds (healthy)           2379-2380/tcp

🌐 معلومات الوصول للخدمات الجديدة:

  Milvus (قاعدة بيانات المتجهات):
    - gRPC Port: 19530
    - Metrics: http://localhost:9091/metrics
    - Health: http://localhost:9091/healthz

  Elasticsearch (البحث النصي):
    - API: http://localhost:9200
    - Health: http://localhost:9200/_cluster/health
    - اختبار: curl http://localhost:9200

  Etcd (تنسيق Milvus):
    - Client Port: 2379 (داخلي)

💡 نصائح للفحص:
  - حالة Elasticsearch: curl http://localhost:9200/_cat/health?v
  - حالة Milvus: curl http://localhost:9091/healthz
  - سجلات Milvus: docker logs bisheng-milvus --tail 50
  - سجلات Elasticsearch: docker logs bisheng-elasticsearch --tail 50

🎯 الخطوة التالية:
  سيتم إضافة وتشغيل خدمات Bisheng (Backend + Frontend)

⏸️  في انتظار أمر 'الخطوة التالية'...
 ➜ /workspaces/bisheng-enterprise (main) $ 
 الخطوة التالية .