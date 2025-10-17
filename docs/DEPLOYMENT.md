📄 الملف 28: DEPLOYMENT.md

Markdown

# 🚀 دليل النشر - Bisheng Enterprise

## جدول المحتويات

- [نشر على خادم واحد](#نشر-على-خادم-واحد)
- [نشر موزع](#نشر-موزع)
- [نشر على Kubernetes](#نشر-على-kubernetes)
- [نشر على السحابة](#نشر-على-السحابة)
- [تحسينات الأداء](#تحسينات-الأداء)

---

## نشر على خادم واحد

### المتطلبات

- Ubuntu 22.04 LTS
- 32GB RAM
- 8 CPU cores
- 500GB SSD

### الخطوات

```bash
# 1. تحديث النظام
sudo apt update && sudo apt upgrade -y

# 2. تثبيت Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# 3. تثبيت Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 4. استنساخ المشروع
git clone https://github.com/yourusername/bisheng-enterprise.git
cd bisheng-enterprise

# 5. تكوين البيئة
cp .env.example .env.production
nano .env.production  # عدّل الإعدادات

# 6. النشر
./scripts/deploy.sh

نشر موزع
البنية

text

┌─────────────┐
│ Load Balancer│
│   (Nginx)   │
└──────┬──────┘
       │
   ┌───┴───┐
   ▼       ▼
┌────┐  ┌────┐
│App1│  │App2│  ← Backend Instances
└─┬──┘  └─┬──┘
  │       │
  └───┬───┘
      ▼
┌──────────┐
│ Database │  ← PostgreSQL Primary
│ Cluster  │
└─────┬────┘
      │
   ┌──┴──┐
   ▼     ▼
┌────┐ ┌────┐
│DB2 │ │DB3 │  ← PostgreSQL Replicas
└────┘ └────┘

إعداد PostgreSQL Replication

Bash

# في Primary
echo "wal_level = replica" >> /etc/postgresql/15/main/postgresql.conf
echo "max_wal_senders = 3" >> /etc/postgresql/15/main/postgresql.conf

# إنشاء مستخدم Replication
sudo -u postgres psql -c "CREATE USER replicator REPLICATION LOGIN PASSWORD 'password';"

# في Replica
pg_basebackup -h primary-host -D /var/lib/postgresql/15/main -U replicator -P -v -R

نشر على Kubernetes
المتطلبات

    Kubernetes 1.25+
    Helm 3.10+
    kubectl

Helm Chart

Bash

# إضافة المستودع
helm repo add bisheng https://charts.bisheng.io

# تثبيت
helm install bisheng bisheng/bisheng-enterprise \
  --namespace bisheng \
  --create-namespace \
  --values values.yaml

values.yaml

YAML

replicaCount: 3

image:
  backend:
    repository: bisheng-backend-enterprise
    tag: latest
  
resources:
  backend:
    limits:
      cpu: 2000m
      memory: 4Gi
    requests:
      cpu: 1000m
      memory: 2Gi

postgresql:
  enabled: true
  replication:
    enabled: true
    slaveReplicas: 2
  
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: bisheng.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: bisheng-tls
      hosts:
        - bisheng.example.com

نشر على السحابة
AWS

Bash

# استخدام Terraform
cd terraform/aws
terraform init
terraform plan
terraform apply

# أو CloudFormation
aws cloudformation create-stack \
  --stack-name bisheng-enterprise \
  --template-body file://cloudformation.yaml

Google Cloud

Bash

# إنشاء Cluster
gcloud container clusters create bisheng-cluster \
  --num-nodes=3 \
  --machine-type=n1-standard-4

# النشر
kubectl apply -f k8s/

Azure

Bash

# إنشاء AKS
az aks create \
  --resource-group bisheng-rg \
  --name bisheng-cluster \
  --node-count 3 \
  --node-vm-size Standard_D4s_v3

# الاتصال
az aks get-credentials --resource-group bisheng-rg --name bisheng-cluster

تحسينات الأداء
1. Database Tuning

SQL

-- تحليل الاستعلامات البطيئة
SELECT query, calls, mean_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;

-- إنشاء فهارس
CREATE INDEX CONCURRENTLY idx_documents_embedding 
ON documents USING ivfflat (embedding vector_cosine_ops);

2. Redis Optimization

Bash

# في .env.production
REDIS_MAX_MEMORY=4gb
REDIS_MAXMEMORY_POLICY=allkeys-lru

3. Nginx Caching

nginx

# في nginx.conf
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=api_cache:10m max_size=1g;

location /api/ {
    proxy_cache api_cache;
    proxy_cache_valid 200 5m;
}

المزيد من التفاصيل في التوثيق الكامل.