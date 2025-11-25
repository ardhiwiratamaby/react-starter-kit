-- System Configuration Tables

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
('audio_retention_days', '90', 'Days to retain audio recordings', 'storage'),
('max_audio_file_size_mb', '25', 'Maximum audio file size in MB', 'audio'),
('supported_audio_formats', '["WEBM", "MP3", "WAV", "OGG"]', 'Supported audio formats', 'audio'),
('default_recording_quality', '"STANDARD"', 'Default recording quality', 'audio'),
('session_timeout_minutes', '60', 'Session timeout in minutes', 'auth');

CREATE INDEX idx_system_settings_key ON system_settings(key);
CREATE INDEX idx_system_settings_category ON system_settings(category);
CREATE INDEX idx_system_settings_is_public ON system_settings(is_public);

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
('social_features', FALSE, 'Enable sharing and community features'),
('analytics_dashboard', FALSE, 'Enable user analytics dashboard'),
('ai_model_selection', FALSE, 'Allow users to select AI models'),
('export_progress_data', FALSE, 'Allow users to export progress data'),
('custom_conversation_scripts', FALSE, 'Enable custom script creation');

CREATE INDEX idx_feature_flags_name ON feature_flags(name);
CREATE INDEX idx_feature_flags_is_enabled ON feature_flags(is_enabled);
CREATE INDEX idx_feature_flags_rollout_percentage ON feature_flags(rollout_percentage);

-- Create triggers for updated_at
CREATE TRIGGER update_system_settings_updated_at
    BEFORE UPDATE ON system_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_feature_flags_updated_at
    BEFORE UPDATE ON feature_flags
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMIT;