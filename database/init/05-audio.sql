-- Audio Recording Tables

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
CREATE INDEX idx_audio_recordings_audio_format ON audio_recordings(audio_format);
CREATE INDEX idx_audio_recordings_recording_quality ON audio_recordings(recording_quality);
CREATE INDEX idx_audio_recordings_deleted_at ON audio_recordings(deleted_at);

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
CREATE INDEX idx_audio_processing_results_provider ON audio_processing_results(processing_provider);
CREATE INDEX idx_audio_processing_results_created_at ON audio_processing_results(created_at);

COMMIT;