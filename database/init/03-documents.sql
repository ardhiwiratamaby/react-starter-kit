-- Document Management Tables

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
CREATE INDEX idx_documents_language ON documents(language);
CREATE INDEX idx_documents_is_public ON documents(is_public);
CREATE INDEX idx_documents_deleted_at ON documents(deleted_at);
CREATE INDEX idx_documents_tags_gin ON documents USING gin(tags);

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
CREATE INDEX idx_document_versions_document_id ON document_versions(document_id);
CREATE INDEX idx_document_versions_created_by ON document_versions(created_by);
CREATE INDEX idx_document_versions_created_at ON document_versions(created_at);

-- Create triggers for updated_at
CREATE TRIGGER update_documents_updated_at
    BEFORE UPDATE ON documents
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMIT;