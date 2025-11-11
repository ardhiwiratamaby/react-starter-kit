# Stage 2: Database Schema & Container Setup

## Stage Overview

This stage focuses on extending the database schema to support all pronunciation assistant features and ensuring the PostgreSQL container is properly configured with persistence, backups, and migration management.

## Observable Outcomes

- ✅ PostgreSQL container running with persistent storage
- ✅ Extended database schema for pronunciation features
- ✅ Database migrations and seeding scripts
- ✅ MinIO file storage container configured
- ✅ Redis caching container operational
- ✅ Database administration tools accessible

## Technical Requirements

### Database Extensions
- UUID support for primary keys
- JSONB for flexible data storage
- Full-text search for document content
- Timestamp with timezone for accurate timing
- Connection pooling for performance

### Core Data Models
- Users and authentication (extended from Stage 1)
- Documents and file management
- Conversations and practice sessions
- Audio recordings and metadata
- Pronunciation feedback and analytics
- AI provider configurations

## Implementation Details

### Step 1: PostgreSQL Container Configuration

#### 1.1 Enhanced PostgreSQL Setup
```yaml
# Update to docker-compose.dev.yml
postgres:
  image: postgres:15-alpine
  ports:
    - "5432:5432"
  environment:
    - POSTGRES_DB=pronunciation_assistant
    - POSTGRES_USER=postgres
    - POSTGRES_PASSWORD=password
    - POSTGRES_INITDB_ARGS=--encoding=UTF-8 --lc-collate=C --lc-ctype=C
  volumes:
    - postgres_data:/var/lib/postgresql/data
    - ./database/init:/docker-entrypoint-initdb.d
    - ./database/backups:/backups
  command: >
    postgres
    -c max_connections=200
    -c shared_buffers=256MB
    -c effective_cache_size=1GB
    -c maintenance_work_mem=64MB
    -c checkpoint_completion_target=0.9
    -c wal_buffers=16MB
    -c default_statistics_target=100
  networks:
    - pronunciation-network
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U postgres"]
    interval: 10s
    timeout: 5s
    retries: 5
```

#### 1.2 Database Initialization Script
```sql
-- database/init/01-extensions.sql
-- Enable required PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";
CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- Create custom types
CREATE TYPE user_role AS ENUM ('USER', 'ADMIN');
CREATE TYPE document_status AS ENUM ('UPLOADING', 'PROCESSING', 'READY', 'ERROR');
CREATE TYPE conversation_status AS ENUM ('ACTIVE', 'COMPLETED', 'PAUSED');
CREATE TYPE audio_format AS ENUM ('WEBM', 'MP3', 'WAV', 'OGG');
CREATE TYPE feedback_type AS ENUM ('PRONUNCIATION', 'FLUENCY', 'RHYTHM', 'INTONATION');
CREATE TYPE ai_provider AS ENUM ('OPENAI', 'GOOGLE', 'AWS', 'AZURE', 'LOCAL');
CREATE TYPE script_generation_mode AS ENUM ('DOCUMENT_BASED', 'TOPIC_BASED', 'TEMPLATE_BASED');
```

### Step 2: Complete Database Schema

#### 2.1 User Management Tables
```sql
-- database/init/02-users.sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email VARCHAR(255) UNIQUE NOT NULL,
  name VARCHAR(255) NOT NULL,
  avatar_url VARCHAR(500),
  role user_role DEFAULT 'USER',
  email_verified BOOLEAN DEFAULT FALSE,
  email_verification_token VARCHAR(255),
  password_reset_token VARCHAR(255),
  password_reset_expires TIMESTAMPTZ,
  last_login TIMESTAMPTZ,
  login_count INTEGER DEFAULT 0,
  preferences JSONB DEFAULT '{}',
  subscription_tier VARCHAR(50) DEFAULT 'FREE',
  subscription_expires TIMESTAMPTZ,
  api_usage_quota INTEGER DEFAULT 100,
  api_usage_current INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- Indexes for performance
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_created_at ON users(created_at);
CREATE INDEX idx_users_email_verified ON users(email_verified);

-- User sessions for authentication
CREATE TABLE user_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token VARCHAR(255) UNIQUE NOT NULL,
  ip_address INET,
  user_agent TEXT,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_accessed TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX idx_user_sessions_token ON user_sessions(token);
CREATE INDEX idx_user_sessions_expires_at ON user_sessions(expires_at);
```

#### 2.2 Document Management Tables
```sql
-- database/init/03-documents.sql
CREATE TABLE documents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  original_filename VARCHAR(255),
  file_size BIGINT,
  file_mime_type VARCHAR(100),
  file_path VARCHAR(500),
  storage_provider VARCHAR(50) DEFAULT 'MINIO',
  content TEXT, -- Markdown content after conversion
  content_hash VARCHAR(64), -- SHA-256 hash for duplicate detection
  status document_status DEFAULT 'UPLOADING',
  processing_error TEXT,
  processing_progress INTEGER DEFAULT 0, -- 0-100 percentage
  language VARCHAR(10) DEFAULT 'en',
  word_count INTEGER,
  reading_time_minutes INTEGER,
  tags JSONB DEFAULT '[]',
  is_public BOOLEAN DEFAULT FALSE,
  view_count INTEGER DEFAULT 0,
  download_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- Full-text search index
CREATE INDEX idx_documents_content_gin ON documents USING gin(to_tsvector('english', content));
CREATE INDEX idx_documents_title_gin ON documents USING gin(to_tsvector('english', title));
CREATE INDEX idx_documents_user_id ON documents(user_id);
CREATE INDEX idx_documents_status ON documents(status);
CREATE INDEX idx_documents_created_at ON documents(created_at);
CREATE INDEX idx_documents_content_hash ON documents(content_hash);

-- Document versions for editing history
CREATE TABLE document_versions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
  version_number INTEGER NOT NULL,
  content TEXT,
  change_summary TEXT,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_document_versions_unique ON document_versions(document_id, version_number);
```

#### 2.3 Conversation and Script Tables
```sql
-- database/init/04-conversations.sql
CREATE TABLE conversations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  document_id UUID REFERENCES documents(id) ON DELETE SET NULL,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  script_content JSONB NOT NULL, -- Structured conversation script
  script_generation_mode script_generation_mode,
  generation_prompt TEXT, -- Original prompt used for generation
  source_document_hash VARCHAR(64), -- If generated from document
  language VARCHAR(10) DEFAULT 'en',
  difficulty_level VARCHAR(20) DEFAULT 'INTERMEDIATE',
  topic_tags JSONB DEFAULT '[]',
  estimated_duration_minutes INTEGER,
  status conversation_status DEFAULT 'ACTIVE',
  current_turn INTEGER DEFAULT 0,
  total_turns INTEGER,
  user_role VARCHAR(20) DEFAULT 'PERSON_A', -- Which role user plays
  is_template BOOLEAN DEFAULT FALSE,
  is_public BOOLEAN DEFAULT FALSE,
  usage_count INTEGER DEFAULT 0,
  rating INTEGER CHECK (rating >= 1 AND rating <= 5),
  feedback TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_conversations_user_id ON conversations(user_id);
CREATE INDEX idx_conversations_document_id ON conversations(document_id);
CREATE INDEX idx_conversations_status ON conversations(status);
CREATE INDEX idx_conversations_is_template ON conversations(is_template);
CREATE INDEX idx_conversations_created_at ON conversations(created_at);

-- Conversation sessions for practice tracking
CREATE TABLE conversation_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  started_at TIMESTAMPTZ DEFAULT NOW(),
  ended_at TIMESTAMPTZ,
  duration_seconds INTEGER,
  completed_turns INTEGER DEFAULT 0,
  total_turns INTEGER,
  completion_percentage INTEGER DEFAULT 0, -- 0-100
  overall_score DECIMAL(5,2), -- 0.00-100.00
  notes TEXT,
  device_type VARCHAR(50), -- DESKTOP, MOBILE, TABLET
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_conversation_sessions_conversation_id ON conversation_sessions(conversation_id);
CREATE INDEX idx_conversation_sessions_user_id ON conversation_sessions(user_id);
CREATE INDEX idx_conversation_sessions_started_at ON conversation_sessions(started_at);
```

#### 2.4 Audio Recording Tables
```sql
-- database/init/05-audio.sql
CREATE TABLE audio_recordings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  conversation_session_id UUID REFERENCES conversation_sessions(id) ON DELETE CASCADE,
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  turn_number INTEGER NOT NULL,
  script_line TEXT NOT NULL, -- The text that was supposed to be spoken
  original_filename VARCHAR(255),
  file_size BIGINT,
  file_mime_type VARCHAR(100),
  file_path VARCHAR(500),
  storage_provider VARCHAR(50) DEFAULT 'MINIO',
  audio_format audio_format,
  duration_seconds DECIMAL(10,3),
  sample_rate INTEGER,
  bit_rate INTEGER,
  channels INTEGER,
  recording_quality VARCHAR(20) DEFAULT 'STANDARD', -- LOW, STANDARD, HIGH
  background_noise_level DECIMAL(5,2),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_audio_recordings_user_id ON audio_recordings(user_id);
CREATE INDEX idx_audio_recordings_session_id ON audio_recordings(conversation_session_id);
CREATE INDEX idx_audio_recordings_conversation_id ON audio_recordings(conversation_id);
CREATE INDEX idx_audio_recordings_created_at ON audio_recordings(created_at);

-- Audio processing results
CREATE TABLE audio_processing_results (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  audio_recording_id UUID NOT NULL REFERENCES audio_recordings(id) ON DELETE CASCADE,
  transcription TEXT, -- What STT service understood
  confidence_score DECIMAL(5,2), -- 0.00-1.00
  processing_provider VARCHAR(50), -- whisper, deepgram, etc.
  processing_time_ms INTEGER,
  processing_cost DECIMAL(10,6), -- Cost in USD
  word_timestamps JSONB, -- Word-level timing data
  alternative_transcriptions JSONB, -- Other possible interpretations
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_audio_processing_results_audio_id ON audio_processing_results(audio_recording_id);
```

#### 2.5 Pronunciation Feedback Tables
```sql
-- database/init/06-feedback.sql
CREATE TABLE pronunciation_feedback (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  audio_recording_id UUID NOT NULL REFERENCES audio_recordings(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  feedback_type feedback_type NOT NULL,
  overall_score DECIMAL(5,2), -- 0.00-100.00
  detailed_scores JSONB, -- Breakdown by category
  phonetic_accuracy JSONB, -- Phonetic-level analysis
  word_level_feedback JSONB, -- Word-by-word feedback
  suggestions JSONB, -- Improvement suggestions
  strengths JSONB, -- What was done well
  areas_for_improvement JSONB,
  processing_provider VARCHAR(50),
  processing_model VARCHAR(100),
  processing_time_ms INTEGER,
  processing_cost DECIMAL(10,6),
  confidence_level DECIMAL(5,2), -- How confident the AI is in its assessment
  is_automated BOOLEAN DEFAULT TRUE,
  reviewed_by UUID REFERENCES users(id), -- If reviewed by human
  reviewer_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_pronunciation_feedback_audio_id ON pronunciation_feedback(audio_recording_id);
CREATE INDEX idx_pronunciation_feedback_user_id ON pronunciation_feedback(user_id);
CREATE INDEX idx_pronunciation_feedback_type ON pronunciation_feedback(feedback_type);
CREATE INDEX idx_pronunciation_feedback_created_at ON pronunciation_feedback(created_at);

-- User progress tracking
CREATE TABLE user_progress (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  skill_area VARCHAR(50) NOT NULL, -- pronunciation, fluency, rhythm, intonation
  current_level DECIMAL(5,2), -- 0.00-100.00
  target_level DECIMAL(5,2),
  progress_history JSONB, -- Historical scores over time
  practice_sessions_count INTEGER DEFAULT 0,
  total_practice_time_minutes INTEGER DEFAULT 0,
  average_session_score DECIMAL(5,2),
  last_practice_date TIMESTAMPTZ,
  streak_days INTEGER DEFAULT 0,
  longest_streak_days INTEGER DEFAULT 0,
  achievements JSONB DEFAULT '[]',
  next_milestone VARCHAR(255),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_user_progress_unique ON user_progress(user_id, skill_area);
```

#### 2.6 AI Provider and Configuration Tables
```sql
-- database/init/07-ai-providers.sql
CREATE TABLE ai_providers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name ai_provider NOT NULL UNIQUE,
  display_name VARCHAR(100) NOT NULL,
  description TEXT,
  api_endpoint_base VARCHAR(255),
  authentication_type VARCHAR(50), -- API_KEY, OAUTH, etc.
  is_configured BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  rate_limit_per_minute INTEGER,
  rate_limit_per_hour INTEGER,
  pricing_model JSONB, -- Pricing information
  supported_features JSONB, -- TTS, STT, LLM, etc.
  configuration_schema JSONB, -- Required configuration fields
  default_configuration JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- AI provider configurations
CREATE TABLE ai_provider_configs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  provider_id UUID NOT NULL REFERENCES ai_providers(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE, -- NULL for global config
  service_type VARCHAR(50) NOT NULL, -- TTS, STT, LLM, etc.
  configuration JSONB NOT NULL,
  priority INTEGER DEFAULT 1, -- Higher number = higher priority
  is_active BOOLEAN DEFAULT TRUE,
  daily_quota INTEGER,
  monthly_quota INTEGER,
  current_daily_usage INTEGER DEFAULT 0,
  current_monthly_usage INTEGER DEFAULT 0,
  last_reset_date DATE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_ai_provider_configs_provider_id ON ai_provider_configs(provider_id);
CREATE INDEX idx_ai_provider_configs_user_id ON ai_provider_configs(user_id);
CREATE INDEX idx_ai_provider_configs_service_type ON ai_provider_configs(service_type);

-- API usage tracking
CREATE TABLE api_usage_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider_id UUID NOT NULL REFERENCES ai_providers(id) ON DELETE CASCADE,
  service_type VARCHAR(50) NOT NULL,
  endpoint VARCHAR(255),
  request_size_bytes INTEGER,
  response_size_bytes INTEGER,
  processing_time_ms INTEGER,
  cost DECIMAL(10,6),
  status_code INTEGER,
  error_message TEXT,
  request_metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_api_usage_logs_user_id ON api_usage_logs(user_id);
CREATE INDEX idx_api_usage_logs_provider_id ON api_usage_logs(provider_id);
CREATE INDEX idx_api_usage_logs_created_at ON api_usage_logs(created_at);
```

#### 2.7 System Configuration Tables
```sql
-- database/init/08-system-config.sql
CREATE TABLE system_settings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  key VARCHAR(255) UNIQUE NOT NULL,
  value JSONB,
  description TEXT,
  is_public BOOLEAN DEFAULT FALSE, -- Can be exposed to frontend
  category VARCHAR(100),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert default settings
INSERT INTO system_settings (key, value, description, category) VALUES
('max_file_size_mb', '50', 'Maximum file size for uploads in MB', 'upload'),
('allowed_file_types', '["pdf", "docx", "txt"]', 'Allowed file types for upload', 'upload'),
('default_tts_provider', '"OPENAI"', 'Default TTS provider', 'ai'),
('default_stt_provider', '"OPENAI"', 'Default STT provider', 'ai'),
('default_llm_provider', '"OPENAI"', 'Default LLM provider', 'ai'),
('free_tier_quota_per_day', '10', 'Daily API quota for free users', 'billing'),
('audio_retention_days', '90', 'Days to retain audio recordings', 'storage');

-- Feature flags
CREATE TABLE feature_flags (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(255) UNIQUE NOT NULL,
  is_enabled BOOLEAN DEFAULT FALSE,
  description TEXT,
  target_users JSONB DEFAULT '[]', -- Specific user IDs or user types
  rollout_percentage INTEGER DEFAULT 0, -- 0-100
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO feature_flags (name, is_enabled, description) VALUES
('advanced_feedback', FALSE, 'Enable detailed pronunciation feedback'),
('real_time_processing', FALSE, 'Enable real-time audio processing'),
('offline_mode', FALSE, 'Enable offline practice mode'),
('social_features', FALSE, 'Enable sharing and community features');
```

### Step 3: Drizzle ORM Configuration

#### 3.1 Drizzle Schema Setup
```typescript
// packages/database/src/schema/index.ts
import { pgTable, uuid, varchar, text, boolean, integer, decimal, timestamp, jsonb, pgEnum } from 'drizzle-orm/pg-core';

// Enums
export const userRoleEnum = pgEnum('user_role', ['USER', 'ADMIN']);
export const documentStatusEnum = pgEnum('document_status', ['UPLOADING', 'PROCESSING', 'READY', 'ERROR']);
export const conversationStatusEnum = pgEnum('conversation_status', ['ACTIVE', 'COMPLETED', 'PAUSED']);
export const audioFormatEnum = pgEnum('audio_format', ['WEBM', 'MP3', 'WAV', 'OGG']);

// Users table
export const users = pgTable('users', {
  id: uuid('id').primaryKey().defaultRandom(),
  email: varchar('email', { length: 255 }).notNull().unique(),
  name: varchar('name', { length: 255 }).notNull(),
  avatarUrl: varchar('avatar_url', { length: 500 }),
  role: userRoleEnum('role').default('USER'),
  emailVerified: boolean('email_verified').default(false),
  preferences: jsonb('preferences').default('{}'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow()
});

// Documents table
export const documents = pgTable('documents', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: uuid('user_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  title: varchar('title', { length: 255 }).notNull(),
  description: text('description'),
  originalFilename: varchar('original_filename', { length: 255 }),
  fileSize: integer('file_size'),
  fileMimeType: varchar('file_mime_type', { length: 100 }),
  filePath: varchar('file_path', { length: 500 }),
  content: text('content'),
  contentHash: varchar('content_hash', { length: 64 }),
  status: documentStatusEnum('status').default('UPLOADING'),
  language: varchar('language', { length: 10 }).default('en'),
  wordCount: integer('word_count'),
  tags: jsonb('tags').default('[]'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow()
});

// Add other table definitions...
```

#### 3.2 Database Configuration
```typescript
// packages/database/src/index.ts
import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import * as schema from './schema';

const connectionString = process.env.DATABASE_URL!;

// Client for query operations
export const client = postgres(connectionString);
export const db = drizzle(client, { schema });

// Connection for migrations
export const migrationClient = postgres(connectionString, { max: 1 });
export const migrationDb = drizzle(migrationClient, { schema });

export { schema };
```

### Step 4: Migration and Seeding Scripts

#### 4.1 Migration Script
```typescript
// packages/database/scripts/migrate.ts
import { migrate } from 'drizzle-orm/postgres-js/migrator';
import { migrationDb } from '../src';

async function runMigrations() {
  try {
    await migrate(migrationDb, { migrationsFolder: './migrations' });
    console.log('✅ Migrations completed successfully');
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  }
}

runMigrations();
```

#### 4.2 Seeding Script
```typescript
// packages/database/scripts/seed.ts
import { migrationDb, schema } from '../src';

async function seed() {
  try {
    // Seed AI providers
    await migrationDb.insert(schema.aiProviders).values([
      {
        name: 'OPENAI',
        displayName: 'OpenAI',
        description: 'OpenAI GPT models and services',
        apiEndpointBase: 'https://api.openai.com/v1',
        authenticationType: 'API_KEY',
        supportedFeatures: ['TTS', 'STT', 'LLM'],
        isConfigured: false
      },
      {
        name: 'GOOGLE',
        displayName: 'Google Cloud AI',
        description: 'Google Cloud AI/ML services',
        apiEndpointBase: 'https://texttospeech.googleapis.com/v1',
        authenticationType: 'SERVICE_ACCOUNT',
        supportedFeatures: ['TTS', 'STT', 'LLM'],
        isConfigured: false
      }
    ]);

    console.log('✅ Database seeded successfully');
  } catch (error) {
    console.error('❌ Seeding failed:', error);
    process.exit(1);
  }
}

seed();
```

### Step 5: MinIO Configuration

#### 5.1 MinIO Bucket Setup
```yaml
# Add to docker-compose.dev.yml
minio-setup:
  image: minio/mc:latest
  depends_on:
    - minio
  entrypoint: >
    /bin/sh -c "
    /usr/bin/mc alias set myminio http://minio:9000 minioadmin minioadmin;
    /usr/bin/mc mb myminio/documents;
    /usr/bin/mc mb myminio/recordings;
    /usr/bin/mc mb myminio/temp;
    /usr/bin/mc policy set public myminio/temp;
    exit 0;
    "
  networks:
    - pronunciation-network
```

#### 5.2 Storage Configuration Script
```typescript
// packages/storage/src/config.ts
export const storageConfig = {
  buckets: {
    documents: 'documents',
    recordings: 'recordings',
    temp: 'temp',
    backups: 'backups'
  },
  policies: {
    documents: 'private', // User can only access their own documents
    recordings: 'private', // User can only access their own recordings
    temp: 'public', // Temporary files accessible via URL
    backups: 'private' // System backups
  }
};
```

## Testing Strategy

### Database Tests
```bash
# Run database tests
docker-compose -f docker-compose.dev.yml exec api bun run test:db

# Test migration
docker-compose -f docker-compose.dev.yml exec api bun run db:migrate

# Test seeding
docker-compose -f docker-compose.dev.yml exec api bun run db:seed
```

### Connection Validation
```bash
# Test PostgreSQL connection
docker-compose -f docker-compose.dev.yml exec postgres psql -U postgres -d pronunciation_assistant -c "SELECT version();"

# Test MinIO connection
curl http://localhost:9000/minio/health/live

# Test Redis connection
docker-compose -f docker-compose.dev.yml exec redis redis-cli ping
```

## Estimated Timeline: 1 Week

### Day 1-2: Schema Design and PostgreSQL Setup
- Complete database schema design
- Configure PostgreSQL container with extensions
- Set up persistent volumes and backup strategy

### Day 3-4: Drizzle ORM Integration
- Set up Drizzle schema definitions
- Create migration scripts
- Implement seeding scripts

### Day 5: Storage and Testing
- Configure MinIO buckets and policies
- Set up Redis for caching
- Test all database operations
- Document database administration

## Success Criteria

- [ ] PostgreSQL container running with all extensions
- [ ] All tables created with proper indexes
- [ ] Drizzle migrations running successfully
- [ ] Seeding scripts populating initial data
- [ ] MinIO storage configured and accessible
- [ ] Redis cache operational
- [ ] Database connections from all services working
- [ ] Backup strategy implemented
- [ ] Performance indexes created
- [ ] Full-text search working

## Monitoring and Maintenance

### Database Health Checks
```sql
-- Monitor database performance
SELECT
  schemaname,
  tablename,
  n_tup_ins as inserts,
  n_tup_upd as updates,
  n_tup_del as deletes,
  n_live_tup as live_tuples,
  n_dead_tup as dead_tuples
FROM pg_stat_user_tables;
```

### Backup Scripts
```bash
#!/bin/bash
# scripts/backup-db.sh
BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)
docker exec postgres pg_dump -U postgres pronunciation_assistant > "$BACKUP_DIR/backup_$DATE.sql"
```

This comprehensive database setup provides the foundation for all features in the pronunciation assistant while ensuring scalability, performance, and data integrity.