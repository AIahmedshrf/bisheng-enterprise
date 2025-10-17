bisheng-enterprise/
├── 📁 base/                          # الخدمات الأساسية
├── 📁 features/                      # الميزات الاختيارية
├── 📁 infrastructure/                # البنية التحتية
├── 📁 configs/                       # ملفات التكوين
│   ├── nginx/                        # تكوين Nginx
│   ├── postgresql/                   # تكوين PostgreSQL
│   ├── prometheus/                   # تكوين Prometheus
│   ├── grafana/                      # لوحات Grafana
│   ├── elasticsearch/                # تكوين Elasticsearch
│   └── milvus/                       # تكوين Milvus
├── 📁 custom-images/                 # صور Docker مخصصة
│   ├── backend/                      # Backend محسّن
│   ├── frontend/                     # Frontend محسّن
│   └── backup/                       # خدمة النسخ الاحتياطي
├── 📁 scripts/                       # سكربتات الإدارة
│   ├── deploy.sh                     # نشر النظام
│   ├── backup.sh                     # نسخ احتياطي
│   ├── restore.sh                    # استعادة
│   ├── health-check.sh               # فحص الصحة
│   └── update.sh                     # تحديث
├── 📁 data/                          # البيانات والنسخ الاحتياطية
│   ├── postgresql/                   # بيانات PostgreSQL
│   ├── redis/                        # بيانات Redis
│   ├── milvus/                       # بيانات Milvus
│   ├── elasticsearch/                # بيانات Elasticsearch
│   ├── minio/                        # بيانات MinIO
│   └── backups/                      # النسخ الاحتياطية
├── 📁 logs/                          # سجلات النظام
│   ├── nginx/                        # سجلات Nginx
│   ├── backend/                      # سجلات Backend
│   ├── worker/                       # سجلات Workers
│   └── frontend/                     # سجلات Frontend
├── 📁 ssl/                           # شهادات SSL
├── 📁 docs/                          # التوثيق
│   ├── API.md                        # توثيق API
│   ├── DEPLOYMENT.md                 # دليل النشر
│   ├── TROUBLESHOOTING.md            # حل المشاكل
│   └── CONTRIBUTING.md               # دليل المساهمة
├── 📄 .env.example                   # مثال لملف البيئة
├── 📄 .env.production                # إعدادات الإنتاج
├── 📄 docker-compose.yml             # الملف الرئيسي
├── 📄 README.md                      # هذا الملف
├── 📄 LICENSE                        # الترخيص
└── 📄 CHANGELOG.md                   # سجل التغييرات