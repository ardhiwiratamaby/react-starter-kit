-- Conversation and Script Tables

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
CREATE INDEX idx_conversations_language ON conversations(language);
CREATE INDEX idx_conversations_difficulty_level ON conversations(difficulty_level);
CREATE INDEX idx_conversations_is_public ON conversations(is_public);
CREATE INDEX idx_conversations_deleted_at ON conversations(deleted_at);
CREATE INDEX idx_conversations_topic_tags_gin ON conversations USING gin(topic_tags);

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
CREATE INDEX idx_conversation_sessions_device_type ON conversation_sessions(device_type);

-- Create triggers for updated_at
CREATE TRIGGER update_conversations_updated_at
    BEFORE UPDATE ON conversations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMIT;