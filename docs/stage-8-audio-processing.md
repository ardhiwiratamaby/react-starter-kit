# Stage 8: Audio Processing Pipeline

## Stage Overview

This stage implements the complete audio recording and processing pipeline for the pronunciation assistant, including browser-based audio recording, speech-to-text conversion, text-to-speech generation, pronunciation feedback analysis, and audio storage with metadata management.

## Observable Outcomes

- ✅ Browser-based audio recording functionality
- ✅ Speech-to-text integration (STT)
- ✅ Text-to-speech generation (TTS)
- ✅ Audio storage and retrieval system
- ✅ Pronunciation feedback analysis
- ✅ Audio playback and download features
- ✅ Audio quality optimization
- ✅ Real-time audio processing feedback

## Technical Requirements

### Audio Recording

- Web Audio API integration
- Multiple audio format support (WebM, MP3, WAV)
- Audio quality control and optimization
- Background noise detection
- Recording level monitoring
- Real-time waveform visualization

### Speech Processing

- High-accuracy speech-to-text conversion
- Multiple STT provider integration
- Real-time transcription feedback
- Audio quality assessment
- Pronunciation analysis and scoring
- Word-level timing analysis

### Audio Storage

- Efficient audio compression
- Metadata preservation
- File organization and management
- Backup and redundancy
- Access control and privacy
- CDN optimization for playback

## Implementation Details

### Step 1: Frontend Audio Recording System

#### 1.1 Audio Recorder Component

```typescript
// apps/app/src/components/audio/AudioRecorder.tsx
import React, { useState, useRef, useCallback } from "react";
import { Button } from "@repo/ui/components/button";
import { Progress } from "@repo/ui/components/progress";
import { Card, CardContent } from "@repo/ui/components/card";
import { Mic, MicOff, Square, Volume2, AlertCircle } from "lucide-react";

interface AudioRecorderProps {
  onRecordingComplete: (audioBlob: Blob) => void;
  onRecordingStart?: () => void;
  onRecordingStop?: () => void;
  disabled?: boolean;
  maxDuration?: number; // seconds
  quality?: "low" | "medium" | "high";
}

export const AudioRecorder: React.FC<AudioRecorderProps> = ({
  onRecordingComplete,
  onRecordingStart,
  onRecordingStop,
  disabled = false,
  maxDuration = 60,
  quality = "medium"
}) => {
  const [isRecording, setIsRecording] = useState(false);
  const [recordingTime, setRecordingTime] = useState(0);
  const [audioLevel, setAudioLevel] = useState(0);
  const [error, setError] = useState<string | null>(null);

  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const audioChunksRef = useRef<Blob[]>([]);
  const streamRef = useRef<MediaStream | null>(null);
  const analyserRef = useRef<AnalyserNode | null>(null);
  const timerRef = useRef<NodeJS.Timeout | null>(null);
  const animationFrameRef = useRef<number | null>(null);

  const getAudioConstraints = useCallback(() => {
    const qualitySettings = {
      low: { sampleRate: 16000, channelCount: 1 },
      medium: { sampleRate: 22050, channelCount: 1 },
      high: { sampleRate: 44100, channelCount: 1 }
    };

    return {
      audio: {
        sampleRate: qualitySettings[quality].sampleRate,
        channelCount: qualitySettings[quality].channelCount,
        echoCancellation: true,
        noiseSuppression: true,
        autoGainControl: true,
      },
      video: false
    };
  }, [quality]);

  const startRecording = async () => {
    try {
      setError(null);
      audioChunksRef.current = [];

      // Request microphone access
      const stream = await navigator.mediaDevices.getUserMedia(getAudioConstraints());
      streamRef.current = stream;

      // Set up audio analysis
      const audioContext = new AudioContext();
      const source = audioContext.createMediaStreamSource(stream);
      const analyser = audioContext.createAnalyser();
      analyser.fftSize = 256;
      source.connect(analyser);
      analyserRef.current = analyser;

      // Set up media recorder
      const mimeType = getSupportedMimeType();
      if (!mimeType) {
        throw new Error("No supported audio format found");
      }

      const mediaRecorder = new MediaRecorder(stream, {
        mimeType,
        audioBitsPerSecond: quality === "high" ? 128000 : quality === "medium" ? 64000 : 32000
      });

      mediaRecorderRef.current = mediaRecorder;

      mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          audioChunksRef.current.push(event.data);
        }
      };

      mediaRecorder.onstop = () => {
        const audioBlob = new Blob(audioChunksRef.current, { type: mimeType });
        onRecordingComplete(audioBlob);
        cleanup();
      };

      // Start recording
      mediaRecorder.start(100); // Collect data every 100ms
      setIsRecording(true);
      setRecordingTime(0);

      // Start timer
      timerRef.current = setInterval(() => {
        setRecordingTime((prev) => {
          const newTime = prev + 1;
          if (newTime >= maxDuration) {
            stopRecording();
          }
          return newTime;
        });
      }, 1000);

      // Start audio level monitoring
      monitorAudioLevel();

      onRecordingStart?.();

    } catch (error) {
      console.error("Error starting recording:", error);
      setError("Failed to access microphone. Please check your permissions.");
      cleanup();
    }
  };

  const stopRecording = () => {
    if (mediaRecorderRef.current && isRecording) {
      mediaRecorderRef.current.stop();
      setIsRecording(false);
      onRecordingStop?.();
    }
  };

  const monitorAudioLevel = () => {
    if (!analyserRef.current) return;

    const dataArray = new Uint8Array(analyserRef.current.frequencyBinCount);

    const updateLevel = () => {
      if (!isRecording || !analyserRef.current) return;

      analyserRef.current.getByteFrequencyData(dataArray);
      const average = dataArray.reduce((a, b) => a + b, 0) / dataArray.length;
      setAudioLevel(average / 255); // Normalize to 0-1

      animationFrameRef.current = requestAnimationFrame(updateLevel);
    };

    updateLevel();
  };

  const cleanup = () => {
    // Stop timer
    if (timerRef.current) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }

    // Cancel animation frame
    if (animationFrameRef.current) {
      cancelAnimationFrame(animationFrameRef.current);
      animationFrameRef.current = null;
    }

    // Stop media recorder
    if (mediaRecorderRef.current && mediaRecorderRef.current.state !== "inactive") {
      mediaRecorderRef.current.stop();
    }

    // Stop stream
    if (streamRef.current) {
      streamRef.current.getTracks().forEach(track => track.stop());
      streamRef.current = null;
    }

    setAudioLevel(0);
  };

  const getSupportedMimeType = (): string => {
    const types = [
      "audio/webm;codecs=opus",
      "audio/webm",
      "audio/mp4",
      "audio/mpeg",
      "audio/wav"
    ];

    for (const type of types) {
      if (MediaRecorder.isTypeSupported(type)) {
        return type;
      }
    }

    return "audio/webm"; // Fallback
  };

  const formatTime = (seconds: number): string => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, "0")}`;
  };

  // Cleanup on unmount
  React.useEffect(() => {
    return cleanup;
  }, []);

  return (
    <Card className="w-full">
      <CardContent className="pt-6">
        <div className="space-y-4">
          {/* Recording Controls */}
          <div className="flex justify-center">
            {!isRecording ? (
              <Button
                size="lg"
                onClick={startRecording}
                disabled={disabled}
                className="w-32 h-32 rounded-full"
                variant={error ? "destructive" : "default"}
              >
                <Mic className="h-12 w-12" />
              </Button>
            ) : (
              <Button
                size="lg"
                onClick={stopRecording}
                className="w-32 h-32 rounded-full bg-red-600 hover:bg-red-700"
              >
                <Square className="h-12 w-12" />
              </Button>
            )}
          </div>

          {/* Audio Level Visualization */}
          {isRecording && (
            <div className="space-y-2">
              <div className="text-center text-sm font-medium">
                Recording... {formatTime(recordingTime)}
              </div>
              <div className="h-8 bg-gray-200 rounded-full overflow-hidden">
                <div
                  className="h-full bg-blue-600 transition-all duration-100"
                  style={{ width: `${audioLevel * 100}%` }}
                />
              </div>
              <div className="flex justify-center space-x-4 text-sm text-gray-600">
                <span>Quality: {quality.toUpperCase()}</span>
                <span>Max: {maxDuration}s</span>
              </div>
            </div>
          )}

          {/* Error Display */}
          {error && (
            <div className="flex items-center space-x-2 p-3 bg-red-50 border border-red-200 rounded-lg">
              <AlertCircle className="h-4 w-4 text-red-600" />
              <span className="text-red-800 text-sm">{error}</span>
            </div>
          )}

          {/* Instructions */}
          {!isRecording && !error && (
            <div className="text-center text-sm text-gray-600">
              <p>Click the microphone button to start recording</p>
              <p>Speak clearly and try to match the pronunciation</p>
            </div>
          )}
        </div>
      </CardContent>
    </Card>
  );
};
```

#### 1.2 Audio Player Component

```typescript
// apps/app/src/components/audio/AudioPlayer.tsx
import React, { useState, useRef, useEffect } from "react";
import { Button } from "@repo/ui/components/button";
import { Slider } from "@repo/ui/components/slider";
import { Card, CardContent } from "@repo/ui/components/card";
import { Play, Pause, Volume2, VolumeX, Download } from "lucide-react";

interface AudioPlayerProps {
  audioSrc: string | Blob;
  title?: string;
  showDownload?: boolean;
  className?: string;
}

export const AudioPlayer: React.FC<AudioPlayerProps> = ({
  audioSrc,
  title = "Audio Recording",
  showDownload = false,
  className
}) => {
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [volume, setVolume] = useState(1);
  const [isMuted, setIsMuted] = useState(false);

  const audioRef = useRef<HTMLAudioElement>(null);
  const progressIntervalRef = useRef<NodeJS.Timeout | null>(null);

  useEffect(() => {
    const audio = audioRef.current;
    if (!audio) return;

    const handleLoadedMetadata = () => {
      setDuration(audio.duration);
    };

    const handleTimeUpdate = () => {
      setCurrentTime(audio.currentTime);
    };

    const handleEnded = () => {
      setIsPlaying(false);
      setCurrentTime(0);
    };

    audio.addEventListener("loadedmetadata", handleLoadedMetadata);
    audio.addEventListener("timeupdate", handleTimeUpdate);
    audio.addEventListener("ended", handleEnded);

    return () => {
      audio.removeEventListener("loadedmetadata", handleLoadedMetadata);
      audio.removeEventListener("timeupdate", handleTimeUpdate);
      audio.removeEventListener("ended", handleEnded);
    };
  }, [audioSrc]);

  useEffect(() => {
    const audio = audioRef.current;
    if (!audio) return;

    audio.volume = isMuted ? 0 : volume;
  }, [volume, isMuted]);

  const togglePlayPause = () => {
    const audio = audioRef.current;
    if (!audio) return;

    if (isPlaying) {
      audio.pause();
    } else {
      audio.play();
    }

    setIsPlaying(!isPlaying);
  };

  const handleSeek = (value: number[]) => {
    const audio = audioRef.current;
    if (!audio) return;

    const newTime = (value[0] / 100) * duration;
    audio.currentTime = newTime;
    setCurrentTime(newTime);
  };

  const handleVolumeChange = (value: number[]) => {
    setVolume(value[0] / 100);
    setIsMuted(false);
  };

  const toggleMute = () => {
    setIsMuted(!isMuted);
  };

  const downloadAudio = () => {
    const link = document.createElement("a");
    link.href = typeof audioSrc === "string" ? audioSrc : URL.createObjectURL(audioSrc);
    link.download = `${title}.webm`;
    link.click();
  };

  const formatTime = (time: number): string => {
    const minutes = Math.floor(time / 60);
    const seconds = Math.floor(time % 60);
    return `${minutes}:${seconds.toString().padStart(2, "0")}`;
  };

  const getAudioObjectUrl = (): string => {
    if (typeof audioSrc === "string") {
      return audioSrc;
    }
    return URL.createObjectURL(audioSrc);
  };

  const progressPercent = duration > 0 ? (currentTime / duration) * 100 : 0;
  const volumePercent = volume * 100;

  return (
    <Card className={className}>
      <CardContent className="pt-6">
        <div className="space-y-4">
          {/* Title */}
          {title && (
            <h4 className="text-lg font-medium text-center">{title}</h4>
          )}

          {/* Hidden Audio Element */}
          <audio
            ref={audioRef}
            src={getAudioObjectUrl()}
            preload="metadata"
          />

          {/* Play/Pause Button */}
          <div className="flex justify-center">
            <Button
              size="lg"
              onClick={togglePlayPause}
              className="w-16 h-16 rounded-full"
            >
              {isPlaying ? (
                <Pause className="h-6 w-6" />
              ) : (
                <Play className="h-6 w-6" />
              )}
            </Button>
          </div>

          {/* Progress Bar */}
          <div className="space-y-2">
            <Slider
              value={[progressPercent]}
              onValueChange={handleSeek}
              max={100}
              step={1}
              className="w-full"
            />
            <div className="flex justify-between text-sm text-gray-600">
              <span>{formatTime(currentTime)}</span>
              <span>{formatTime(duration)}</span>
            </div>
          </div>

          {/* Volume Controls */}
          <div className="flex items-center space-x-3">
            <Button
              variant="ghost"
              size="sm"
              onClick={toggleMute}
            >
              {isMuted ? (
                <VolumeX className="h-4 w-4" />
              ) : (
                <Volume2 className="h-4 w-4" />
              )}
            </Button>
            <Slider
              value={[volumePercent]}
              onValueChange={handleVolumeChange}
              max={100}
              step={1}
              className="flex-1"
            />
          </div>

          {/* Download Button */}
          {showDownload && (
            <div className="flex justify-center">
              <Button variant="outline" onClick={downloadAudio}>
                <Download className="h-4 w-4 mr-2" />
                Download
              </Button>
            </div>
          )}
        </div>
      </CardContent>
    </Card>
  );
};
```

### Step 2: Backend Audio Processing Service

#### 2.1 Audio Processing Service

```typescript
// apps/api/src/services/audio-processing-service.ts
import { db } from "@repo/database";
import {
  audioRecordings,
  audioProcessingResults,
  pronunciationFeedback,
} from "@repo/database/src/schema";
import { eq, and } from "drizzle-orm";
import { AIGatewayClient } from "./ai-gateway-client";
import { MinioService } from "./minio-service";

export class AudioProcessingService {
  private aiClient: AIGatewayClient;
  private minioService: MinioService;

  constructor() {
    this.aiClient = new AIGatewayClient();
    this.minioService = new MinioService();
  }

  async processAudio(audioRecordingId: string, audioData: string) {
    try {
      // Get audio recording details
      const audioRecording = await db.query.audioRecordings.findFirst({
        where: eq(audioRecordings.id, audioRecordingId),
      });

      if (!audioRecording) {
        throw new Error("Audio recording not found");
      }

      // Store audio file in MinIO
      const audioBlob = this.base64ToBlob(
        audioData,
        audioRecording.audioFormat,
      );
      const filePath = await this.minioService.storeFile(
        Buffer.from(await audioBlob.arrayBuffer()),
        audioRecording.userId,
        `recording_${audioRecordingId}.${audioRecording.audioFormat}`,
        `audio/${audioRecording.audioFormat}`,
      );

      // Update audio recording with file path
      await db
        .update(audioRecordings)
        .set({
          filePath,
          updatedAt: new Date(),
        })
        .where(eq(audioRecordings.id, audioRecordingId));

      // Process speech-to-text
      const sttResult = await this.aiClient.speechToText(audioData);

      // Save processing result
      const [processingResult] = await db
        .insert(audioProcessingResults)
        .values({
          audioRecordingId,
          transcription: sttResult.text,
          confidenceScore: sttResult.confidence,
          processingProvider: sttResult.provider,
          processingTimeMs: sttResult.response_time_ms,
          processingCost: sttResult.cost_usd,
          wordTimestamps: sttResult.metadata?.word_timestamps || {},
        })
        .returning();

      // Generate pronunciation feedback
      const feedbackResult = await this.generatePronunciationFeedback(
        audioRecordingId,
        audioRecording.userId,
        processingResult.id,
        sttResult.text,
        audioRecording.scriptLine,
      );

      return {
        success: true,
        transcription: sttResult.text,
        confidenceScore: sttResult.confidence,
        feedback: feedbackResult,
      };
    } catch (error) {
      console.error("Audio processing failed:", error);
      throw new Error(
        `Audio processing failed: ${error instanceof Error ? error.message : "Unknown error"}`,
      );
    }
  }

  private async generatePronunciationFeedback(
    audioRecordingId: string,
    userId: string,
    processingResultId: string,
    transcription: string,
    targetText: string,
  ) {
    try {
      // Get pronunciation feedback from AI
      const feedbackResponse = await this.aiClient.analyzePronunciation({
        userSpeech: transcription,
        targetText: targetText,
        language: "en",
      });

      // Save feedback to database
      const [feedback] = await db
        .insert(pronunciationFeedback)
        .values({
          audioRecordingId,
          userId,
          feedbackType: "PRONUNCIATION",
          overallScore: feedbackResponse.overallScore,
          detailedScores: feedbackResponse.detailedScores,
          phoneticAccuracy: feedbackResponse.phoneticAccuracy,
          wordLevelFeedback: feedbackResponse.wordLevelFeedback,
          suggestions: feedbackResponse.suggestions,
          strengths: feedbackResponse.strengths,
          areasForImprovement: feedbackResponse.areasForImprovement,
          processingProvider: feedbackResponse.provider,
          processingTimeMs: feedbackResponse.response_time_ms,
          processingCost: feedbackResponse.cost_usd,
          confidenceLevel: feedbackResponse.confidence,
        })
        .returning();

      return feedback;
    } catch (error) {
      console.error("Pronunciation feedback generation failed:", error);
      // Return basic feedback if AI analysis fails
      const [feedback] = await db
        .insert(pronunciationFeedback)
        .values({
          audioRecordingId,
          userId,
          feedbackType: "PRONUNCIATION",
          overallScore: 70, // Default score
          detailedScores: {},
          suggestions: ["Practice speaking more clearly"],
          strengths: [],
          areasForImprovement: ["Clarity", "Pace"],
          processingProvider: "fallback",
          confidenceLevel: 0.5,
        })
        .returning();

      return feedback;
    }
  }

  async getAudioWithFeedback(audioRecordingId: string, userId: string) {
    const result = await db
      .select({
        recording: {
          id: audioRecordings.id,
          filePath: audioRecordings.filePath,
          durationSeconds: audioRecordings.durationSeconds,
          scriptLine: audioRecordings.scriptLine,
          audioFormat: audioRecordings.audioFormat,
        },
        processing: {
          transcription: audioProcessingResults.transcription,
          confidenceScore: audioProcessingResults.confidenceScore,
          wordTimestamps: audioProcessingResults.wordTimestamps,
        },
        feedback: {
          overallScore: pronunciationFeedback.overallScore,
          detailedScores: pronunciationFeedback.detailedScores,
          suggestions: pronunciationFeedback.suggestions,
          strengths: pronunciationFeedback.strengths,
          areasForImprovement: pronunciationFeedback.areasForImprovement,
        },
      })
      .from(audioRecordings)
      .leftJoin(
        audioProcessingResults,
        eq(audioProcessingResults.audioRecordingId, audioRecordings.id),
      )
      .leftJoin(
        pronunciationFeedback,
        eq(pronunciationFeedback.audioRecordingId, audioRecordings.id),
      )
      .where(
        and(
          eq(audioRecordings.id, audioRecordingId),
          eq(audioRecordings.userId, userId),
        ),
      )
      .limit(1);

    if (!result[0]) {
      return null;
    }

    // Get audio URL from MinIO
    let audioUrl = null;
    if (result[0].recording.filePath) {
      audioUrl = await this.minioService.getFileUrl(
        result[0].recording.filePath,
      );
    }

    return {
      ...result[0],
      recording: {
        ...result[0].recording,
        audioUrl,
      },
    };
  }

  async analyzeSpeechPatterns(userId: string, limit: number = 50) {
    const recentRecordings = await db
      .select({
        id: audioRecordings.id,
        durationSeconds: audioRecordings.durationSeconds,
        scriptLine: audioRecordings.scriptLine,
        processing: {
          transcription: audioProcessingResults.transcription,
          confidenceScore: audioProcessingResults.confidenceScore,
        },
        feedback: {
          overallScore: pronunciationFeedback.overallScore,
          detailedScores: pronunciationFeedback.detailedScores,
        },
      })
      .from(audioRecordings)
      .leftJoin(
        audioProcessingResults,
        eq(audioProcessingResults.audioRecordingId, audioRecordings.id),
      )
      .leftJoin(
        pronunciationFeedback,
        eq(pronunciationFeedback.audioRecordingId, audioRecordings.id),
      )
      .where(eq(audioRecordings.userId, userId))
      .orderBy(desc(audioRecordings.createdAt))
      .limit(limit);

    // Analyze patterns
    const totalRecordings = recentRecordings.length;
    const averageConfidence =
      recentRecordings.reduce(
        (sum, r) => sum + (r.processing?.confidenceScore || 0),
        0,
      ) / totalRecordings;

    const averageScore =
      recentRecordings.reduce(
        (sum, r) => sum + (r.feedback?.overallScore || 0),
        0,
      ) / totalRecordings;

    const averageDuration =
      recentRecordings.reduce(
        (sum, r) => sum + (r.recording.durationSeconds || 0),
        0,
      ) / totalRecordings;

    // Identify common issues
    const commonIssues = this.identifyCommonIssues(recentRecordings);

    // Calculate improvement trend
    const improvementTrend = this.calculateImprovementTrend(recentRecordings);

    return {
      totalRecordings,
      averageConfidence,
      averageScore,
      averageDuration,
      commonIssues,
      improvementTrend,
      recentPerformance: recentRecordings.slice(0, 10),
    };
  }

  private base64ToBlob(base64: string, mimeType: string): Blob {
    const byteCharacters = atob(base64.split(",")[1]);
    const byteNumbers = new Array(byteCharacters.length);
    for (let i = 0; i < byteCharacters.length; i++) {
      byteNumbers[i] = byteCharacters.charCodeAt(i);
    }
    const byteArray = new Uint8Array(byteNumbers);
    return new Blob([byteArray], { type: mimeType });
  }

  private identifyCommonIssues(recordings: any[]): string[] {
    const issues: { [key: string]: number } = {};

    recordings.forEach((recording) => {
      if (recording.feedback?.areasForImprovement) {
        recording.feedback.areasForImprovement.forEach((issue: string) => {
          issues[issue] = (issues[issue] || 0) + 1;
        });
      }
    });

    // Return top 3 most common issues
    return Object.entries(issues)
      .sort(([, a], [, b]) => b - a)
      .slice(0, 3)
      .map(([issue]) => issue);
  }

  private calculateImprovementTrend(
    recordings: any[],
  ): "improving" | "declining" | "stable" {
    if (recordings.length < 5) return "stable";

    const recent = recordings.slice(0, 5);
    const older = recordings.slice(5, 10);

    const recentAvg =
      recent.reduce((sum, r) => sum + (r.feedback?.overallScore || 0), 0) /
      recent.length;

    const olderAvg =
      older.length > 0
        ? older.reduce((sum, r) => sum + (r.feedback?.overallScore || 0), 0) /
          older.length
        : recentAvg;

    if (recentAvg > olderAvg + 5) return "improving";
    if (recentAvg < olderAvg - 5) return "declining";
    return "stable";
  }
}
```

#### 2.2 AI Integration for Audio Processing

```typescript
// apps/api/src/services/ai-gateway-client.ts
export class AIGatewayClient {
  private baseUrl: string;

  constructor() {
    this.baseUrl = process.env.AI_GATEWAY_URL || "http://localhost:8001";
  }

  async speechToText(audioData: string): Promise<any> {
    const response = await fetch(`${this.baseUrl}/stt/transcribe`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        audio_data: audioData,
        format: "webm",
      }),
    });

    if (!response.ok) {
      throw new Error("Speech-to-text failed");
    }

    return await response.json();
  }

  async textToSpeech(text: string): Promise<any> {
    const response = await fetch(`${this.baseUrl}/tts/speak`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        text,
        voice: "alloy",
      }),
    });

    if (!response.ok) {
      throw new Error("Text-to-speech failed");
    }

    return await response.json();
  }

  async analyzePronunciation(params: {
    userSpeech: string;
    targetText: string;
    language: string;
  }): Promise<any> {
    const response = await fetch(`${this.baseUrl}/llm/analyze-pronunciation`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        user_speech: params.userSpeech,
        target_text: params.targetText,
        language: params.language,
      }),
    });

    if (!response.ok) {
      throw new Error("Pronunciation analysis failed");
    }

    return await response.json();
  }

  async generateConversationResponse(params: {
    userText: string;
    context: any;
    conversationContext: any;
    userRole: string;
    turnNumber: number;
  }): Promise<any> {
    const response = await fetch(`${this.baseUrl}/llm/conversation-response`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(params),
    });

    if (!response.ok) {
      throw new Error("Conversation response generation failed");
    }

    return await response.json();
  }
}
```

### Step 3: Audio Processing tRPC Router

#### 3.1 Audio Processing API Endpoints

```typescript
// apps/api/src/router/audio.ts
import { router, protectedProcedure } from "./trpc";
import { z } from "zod";
import { TRPCError } from "@trpc/server";
import { AudioProcessingService } from "../services/audio-processing-service";

export const audioRouter = router({
  // Process audio recording
  processRecording: protectedProcedure
    .input(
      z.object({
        audioRecordingId: z.string().uuid(),
        audioData: z.string(), // Base64 encoded audio
      }),
    )
    .mutation(async ({ input, ctx }) => {
      try {
        const audioService = new AudioProcessingService();
        const result = await audioService.processAudio(
          input.audioRecordingId,
          input.audioData,
        );

        return result;
      } catch (error) {
        console.error("Audio processing failed:", error);
        throw new TRPCError({
          code: "INTERNAL_SERVER_ERROR",
          message: "Failed to process audio",
        });
      }
    }),

  // Get audio with feedback
  getRecordingWithFeedback: protectedProcedure
    .input(z.object({ audioRecordingId: z.string().uuid() }))
    .query(async ({ input, ctx }) => {
      const audioService = new AudioProcessingService();
      const result = await audioService.getAudioWithFeedback(
        input.audioRecordingId,
        ctx.user.id,
      );

      if (!result) {
        throw new TRPCError({
          code: "NOT_FOUND",
          message: "Audio recording not found",
        });
      }

      return result;
    }),

  // Analyze speech patterns
  analyzeSpeechPatterns: protectedProcedure
    .input(
      z.object({
        limit: z.number().min(10).max(100).default(50),
      }),
    )
    .query(async ({ input, ctx }) => {
      const audioService = new AudioProcessingService();
      return await audioService.analyzeSpeechPatterns(ctx.user.id, input.limit);
    }),

  // Get audio statistics
  getAudioStats: protectedProcedure
    .input(
      z.object({
        period: z.enum(["day", "week", "month"]).default("week"),
      }),
    )
    .query(async ({ input, ctx }) => {
      // Implementation for audio statistics
      return {
        totalRecordings: 0,
        totalDuration: 0,
        averageScore: 0,
        improvement: 0,
      };
    }),
});
```

## Testing Strategy

### Audio Processing Tests

```typescript
// apps/api/src/__tests__/audio-processing.test.ts
import { describe, it, expect, beforeEach } from "vitest";
import { AudioProcessingService } from "../services/audio-processing-service";

describe("Audio Processing", () => {
  let audioService: AudioProcessingService;

  beforeEach(() => {
    audioService = new AudioProcessingService();
  });

  it("should process audio and generate feedback", async () => {
    // Mock audio data
    const mockAudioData = "data:audio/webm;base64,mock-base64-data";

    const result = await audioService.processAudio(
      "test-recording-id",
      mockAudioData,
    );

    expect(result.success).toBe(true);
    expect(result.transcription).toBeDefined();
    expect(result.feedback).toBeDefined();
    expect(result.confidenceScore).toBeGreaterThan(0);
  });

  it("should analyze speech patterns correctly", async () => {
    const patterns = await audioService.analyzeSpeechPatterns(
      "test-user-id",
      10,
    );

    expect(patterns).toHaveProperty("totalRecordings");
    expect(patterns).toHaveProperty("averageScore");
    expect(patterns).toHaveProperty("improvementTrend");
    expect(["improving", "declining", "stable"]).toContain(
      patterns.improvementTrend,
    );
  });
});
```

### Frontend Audio Tests

```bash
# Test audio recording functionality
# Note: These tests need to be run in a browser environment

# Test audio playback
npm run test:audio

# Test audio file upload
curl -X POST http://localhost:4000/api/audio/process-recording \
  -H "Content-Type: application/json" \
  -d '{"audioRecordingId": "test-id", "audioData": "base64-data"}'
```

## Estimated Timeline: 1 Week

### Day 1-2: Frontend Audio Components

- Build audio recorder component
- Create audio player with controls
- Add waveform visualization

### Day 3-4: Backend Audio Processing

- Implement audio processing service
- Add STT/TTS integration
- Build pronunciation feedback system

### Day 5: Integration and Testing

- Connect frontend and backend
- Test audio pipeline end-to-end
- Optimize performance and quality

## Success Criteria

- [ ] Browser-based audio recording working
- [ ] Multiple audio format support
- [ ] Audio quality optimization
- [ ] Speech-to-text conversion functional
- [ ] Text-to-speech generation working
- [ ] Pronunciation feedback analysis
- [ ] Audio storage and retrieval
- [ ] Audio playback functionality
- [ ] Real-time audio level monitoring
- [ ] Speech pattern analysis
- [ ] Audio download features
- [ ] All audio features tested

This comprehensive audio processing pipeline provides high-quality recording, processing, and analysis capabilities that enable effective pronunciation practice with detailed feedback and progress tracking.
