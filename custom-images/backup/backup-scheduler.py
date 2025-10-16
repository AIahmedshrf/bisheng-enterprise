#!/usr/bin/env python3
"""
============================================
Bisheng Enterprise - Backup Scheduler
============================================
"""

import os
import sys
import time
import json
import logging
import schedule
import subprocess
from datetime import datetime
from pathlib import Path

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/logs/backup-scheduler.log'),
        logging.StreamHandler(sys.stdout)
    ]
)

logger = logging.getLogger('backup-scheduler')

# Configuration from environment
BACKUP_SCHEDULE = os.getenv('BACKUP_SCHEDULE', '0 2 * * *')  # Default: 2 AM daily
BACKUP_DIR = Path('/backups')
RETENTION_DAYS = int(os.getenv('BACKUP_RETENTION_DAYS', '30'))
ENABLE_S3_UPLOAD = os.getenv('S3_BACKUP_BUCKET', '') != ''

class BackupScheduler:
    def __init__(self):
        self.backup_dir = BACKUP_DIR
        self.retention_days = RETENTION_DAYS
        
    def run_backup_script(self, script_name):
        """Execute a backup script"""
        try:
            logger.info(f"Running backup script: {script_name}")
            
            result = subprocess.run(
                [f'/scripts/{script_name}'],
                capture_output=True,
                text=True,
                timeout=3600  # 1 hour timeout
            )
            
            if result.returncode == 0:
                logger.info(f"✓ {script_name} completed successfully")
                return True
            else:
                logger.error(f"✗ {script_name} failed: {result.stderr}")
                return False
                
        except subprocess.TimeoutExpired:
            logger.error(f"✗ {script_name} timed out")
            return False
        except Exception as e:
            logger.error(f"✗ {script_name} error: {e}")
            return False
    
    def backup_postgres(self):
        """Backup PostgreSQL database"""
        return self.run_backup_script('backup-postgres.sh')
    
    def backup_redis(self):
        """Backup Redis data"""
        return self.run_backup_script('backup-redis.sh')
    
    def backup_minio(self):
        """Backup MinIO objects"""
        return self.run_backup_script('backup-minio.sh')
    
    def create_manifest(self, timestamp, results):
        """Create backup manifest file"""
        manifest = {
            'timestamp': timestamp,
            'date': datetime.now().isoformat(),
            'version': '2.0',
            'results': results,
            'retention_days': self.retention_days
        }
        
        manifest_file = self.backup_dir / f'manifest_{timestamp}.json'
        
        try:
            with open(manifest_file, 'w') as f:
                json.dump(manifest, f, indent=2)
            logger.info(f"Manifest created: {manifest_file}")
        except Exception as e:
            logger.error(f"Failed to create manifest: {e}")
    
    def cleanup_old_backups(self):
        """Remove backups older than retention period"""
        try:
            logger.info(f"Cleaning up backups older than {self.retention_days} days")
            
            result = subprocess.run(
                ['/scripts/cleanup-old-backups.sh'],
                capture_output=True,
                text=True
            )
            
            if result.returncode == 0:
                logger.info("✓ Cleanup completed")
            else:
                logger.error(f"✗ Cleanup failed: {result.stderr}")
                
        except Exception as e:
            logger.error(f"Cleanup error: {e}")
    
    def upload_to_s3(self, timestamp):
        """Upload backup to S3 (if configured)"""
        if not ENABLE_S3_UPLOAD:
            return
        
        try:
            logger.info("Uploading backup to S3...")
            
            s3_bucket = os.getenv('S3_BACKUP_BUCKET')
            
            # Use AWS CLI to upload
            subprocess.run([
                'aws', 's3', 'sync',
                str(self.backup_dir),
                f's3://{s3_bucket}/bisheng-backups/{timestamp}/',
                '--exclude', '*',
                '--include', f'*{timestamp}*'
            ], check=True)
            
            logger.info("✓ S3 upload completed")
            
        except Exception as e:
            logger.error(f"S3 upload failed: {e}")
    
    def run_full_backup(self):
        """Execute full backup routine"""
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        
        logger.info("=" * 60)
        logger.info(f"Starting full backup: {timestamp}")
        logger.info("=" * 60)
        
        results = {
            'postgres': self.backup_postgres(),
            'redis': self.backup_redis(),
            'minio': self.backup_minio()
        }
        
        # Create manifest
        self.create_manifest(timestamp, results)
        
        # Cleanup old backups
        self.cleanup_old_backups()
        
        # Upload to S3 if enabled
        self.upload_to_s3(timestamp)
        
        # Summary
        success_count = sum(1 for v in results.values() if v)
        total_count = len(results)
        
        logger.info("=" * 60)
        logger.info(f"Backup completed: {success_count}/{total_count} successful")
        logger.info("=" * 60)
        
        # Send notification (implement as needed)
        self.send_notification(timestamp, results)
    
    def send_notification(self, timestamp, results):
        """Send backup notification (email, Slack, etc.)"""
        # TODO: Implement notification logic
        pass
    
    def parse_cron_schedule(self, cron_expr):
        """Parse cron expression and schedule job"""
        # Simple cron parsing (expand as needed)
        parts = cron_expr.split()
        
        if len(parts) != 5:
            logger.error(f"Invalid cron expression: {cron_expr}")
            return
        
        minute, hour, day, month, weekday = parts
        
        # For simplicity, handle common cases
        if minute.isdigit() and hour.isdigit():
            schedule.every().day.at(f"{hour.zfill(2)}:{minute.zfill(2)}").do(
                self.run_full_backup
            )
            logger.info(f"Scheduled daily backup at {hour}:{minute}")
        else:
            logger.warning(f"Complex cron expression, using default schedule")
            schedule.every().day.at("02:00").do(self.run_full_backup)
    
    def run(self):
        """Start the backup scheduler"""
        logger.info("Bisheng Backup Scheduler starting...")
        logger.info(f"Backup directory: {self.backup_dir}")
        logger.info(f"Retention days: {self.retention_days}")
        logger.info(f"Schedule: {BACKUP_SCHEDULE}")
        
        # Parse and set schedule
        self.parse_cron_schedule(BACKUP_SCHEDULE)
        
        # Run initial backup
        logger.info("Running initial backup...")
        self.run_full_backup()
        
        # Run scheduler
        logger.info("Scheduler is running. Press Ctrl+C to exit.")
        
        try:
            while True:
                schedule.run_pending()
                time.sleep(60)  # Check every minute
        except KeyboardInterrupt:
            logger.info("Scheduler stopped by user")
        except Exception as e:
            logger.error(f"Scheduler error: {e}")
            sys.exit(1)

def main():
    scheduler = BackupScheduler()
    scheduler.run()

if __name__ == '__main__':
    main()