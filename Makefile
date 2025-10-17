# ============================================
# Bisheng Enterprise - Makefile
# ============================================

.PHONY: help dev prod test clean backup restore

# Default target
.DEFAULT_GOAL := help

# Variables
COMPOSE_DEV = docker compose -f docker-compose.dev.yml
COMPOSE_PROD = docker compose -f docker-compose.yml --env-file .env.production

# ============================================
# Help
# ============================================
help: ## عرض المساعدة
	@echo "Bisheng Enterprise - Available Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ============================================
# Development
# ============================================
dev: ## تشغيل بيئة التطوير
	$(COMPOSE_DEV) up -d
	@echo "✓ Development environment started"
	@echo "  - Frontend: http://localhost:3000"
	@echo "  - Backend:  http://localhost:7860"
	@echo "  - Flower:   http://localhost:5555"
	@echo "  - Adminer:  http://localhost:8080"

dev-build: ## بناء صور التطوير
	$(COMPOSE_DEV) build

dev-logs: ## عرض سجلات التطوير
	$(COMPOSE_DEV) logs -f

dev-stop: ## إيقاف بيئة التطوير
	$(COMPOSE_DEV) stop

dev-down: ## إيقاف وحذف حاويات التطوير
	$(COMPOSE_DEV) down

dev-restart: ## إعادة تشغيل بيئة التطوير
	$(COMPOSE_DEV) restart

dev-shell: ## فتح shell في backend
	$(COMPOSE_DEV) exec backend bash

dev-db: ## فتح PostgreSQL shell
	$(COMPOSE_DEV) exec postgres psql -U bisheng_dev -d bisheng_dev

# ============================================
# Production
# ============================================
prod: ## نشر الإنتاج
	./scripts/deploy.sh

prod-build: ## بناء صور الإنتاج
	$(COMPOSE_PROD) build --no-cache

prod-up: ## تشغيل الإنتاج
	$(COMPOSE_PROD) up -d

prod-logs: ## عرض سجلات الإنتاج
	$(COMPOSE_PROD) logs -f

prod-stop: ## إيقاف الإنتاج
	$(COMPOSE_PROD) stop

prod-restart: ## إعادة تشغيل الإنتاج
	$(COMPOSE_PROD) restart

# ============================================
# Database
# ============================================
db-migrate: ## تشغيل migrations
	$(COMPOSE_PROD) exec backend alembic upgrade head

db-rollback: ## التراجع عن migration
	$(COMPOSE_PROD) exec backend alembic downgrade -1

db-reset: ## إعادة تعيين قاعدة البيانات (خطير!)
	@echo "⚠️  This will delete all data!"
	@read -p "Are you sure? (yes/no): " confirm && [ "$$confirm" = "yes" ]
	$(COMPOSE_DEV) exec postgres psql -U bisheng_dev -c "DROP DATABASE IF EXISTS bisheng_dev;"
	$(COMPOSE_DEV) exec postgres psql -U bisheng_dev -c "CREATE DATABASE bisheng_dev;"

# ============================================
# Testing
# ============================================
test: ## تشغيل الاختبارات
	$(COMPOSE_DEV) exec backend pytest tests/

test-unit: ## اختبارات الوحدة
	$(COMPOSE_DEV) exec backend pytest tests/unit/

test-integration: ## اختبارات التكامل
	$(COMPOSE_DEV) exec backend pytest tests/integration/

test-coverage: ## اختبارات مع تغطية
	$(COMPOSE_DEV) exec backend pytest --cov=bisheng --cov-report=html tests/

# ============================================
# Maintenance
# ============================================
backup: ## نسخ احتياطي
	./scripts/backup.sh

restore: ## استعادة من نسخة احتياطية
	./scripts/restore.sh

health: ## فحص صحة النظام
	./scripts/health-check.sh

update: ## تحديث النظام
	./scripts/update.sh

# ============================================
# Cleanup
# ============================================
clean: ## تنظيف الملفات المؤقتة
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	find . -type f -name "*.pyo" -delete
	find . -type f -name ".DS_Store" -delete

clean-docker: ## تنظيف Docker
	docker system prune -af --volumes
	@echo "✓ Docker cleaned"

clean-logs: ## تنظيف السجلات
	find logs/ -name "*.log" -mtime +7 -delete
	@echo "✓ Logs cleaned"

# ============================================
# Utilities
# ============================================
ps: ## عرض حالة الخدمات
	docker compose ps

stats: ## عرض إحصائيات الموارد
	docker stats

shell: ## فتح shell في backend
	docker compose exec backend bash

format: ## تنسيق الكود
	$(COMPOSE_DEV) exec backend black .
	$(COMPOSE_DEV) exec backend isort .

lint: ## فحص الكود
	$(COMPOSE_DEV) exec backend flake8 .
	$(COMPOSE_DEV) exec backend mypy .

install-dev: ## تثبيت متطلبات التطوير
	pip install -r requirements-dev.txt