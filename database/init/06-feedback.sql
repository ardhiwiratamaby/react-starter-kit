-- Pronunciation Feedback Tables

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
CREATE INDEX idx_pronunciation_feedback_provider ON pronunciation_feedback(processing_provider);

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
CREATE INDEX idx_user_progress_skill_area ON user_progress(skill_area);
CREATE INDEX idx_user_progress_current_level ON user_progress(current_level);
CREATE INDEX idx_user_progress_last_practice_date ON user_progress(last_practice_date);

-- Create triggers for updated_at
CREATE TRIGGER update_pronunciation_feedback_updated_at
    BEFORE UPDATE ON pronunciation_feedback
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_progress_updated_at
    BEFORE UPDATE ON user_progress
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMIT;