-- ============================================
-- Bisheng Enterprise - Database Initialization
-- ============================================

-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- Full-text search configuration
CREATE EXTENSION IF NOT EXISTS "unaccent";

-- Vector search (if available)
-- CREATE EXTENSION IF NOT EXISTS "vector";

-- ============================================
-- Create Database User (if not exists)
-- ============================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'bisheng_user') THEN
        CREATE USER bisheng_user WITH PASSWORD 'BiSheng@2024!Secure#PG';
    END IF;
END
$$;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE bisheng TO bisheng_user;
GRANT ALL ON SCHEMA public TO bisheng_user;

-- ============================================
-- Performance Tables
-- ============================================

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_created_at ON flows(created_at);
CREATE INDEX IF NOT EXISTS idx_user_id ON flows(user_id);
CREATE INDEX IF NOT EXISTS idx_status ON flows(status);

-- Full-text search indexes
-- Example: CREATE INDEX idx_fts_documents ON documents USING gin(to_tsvector('english', content));

-- ============================================
-- Maintenance
-- ============================================

-- Analyze tables
ANALYZE;

-- ============================================
-- Logging
-- ============================================
\echo 'Database initialization completed successfully'