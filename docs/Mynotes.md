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