-- AI Provider and Configuration Tables

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
CREATE INDEX idx_ai_provider_configs_priority ON ai_provider_configs(priority);
CREATE INDEX idx_ai_provider_configs_is_active ON ai_provider_configs(is_active);

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
CREATE INDEX idx_api_usage_logs_service_type ON api_usage_logs(service_type);
CREATE INDEX idx_api_usage_logs_created_at ON api_usage_logs(created_at);
CREATE INDEX idx_api_usage_logs_status_code ON api_usage_logs(status_code);

-- Create triggers for updated_at
CREATE TRIGGER update_ai_providers_updated_at
    BEFORE UPDATE ON ai_providers
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_ai_provider_configs_updated_at
    BEFORE UPDATE ON ai_provider_configs
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMIT;