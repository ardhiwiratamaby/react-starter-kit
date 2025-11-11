# Stage 7: Conversation Practice Interface

## Stage Overview

This stage implements the interactive conversation practice system that allows users to engage in turn-based spoken dialogues with AI. The system includes role selection, script highlighting, progress tracking, conversation history, and both voice and text input options.

## Observable Outcomes

- ✅ Interactive conversation practice interface
- ✅ Turn-based dialogue system with role selection
- ✅ Script display and highlighting functionality
- ✅ Conversation history and progress tracking
- ✅ Text-based practice fallback option
- ✅ Real-time conversation progress visualization
- ✅ Session management and analytics
- ✅ Conversation replay and review features

## Technical Requirements

### Core Practice Features
- Turn-based conversation flow
- Role selection (Person A/Person B)
- Script highlighting and current turn indication
- Progress tracking and session analytics
- Conversation history storage
- Text input alternative to voice recording

### User Experience
- Intuitive interface with clear turn indicators
- Visual feedback for speaking and listening
- Conversation context and hints
- Practice statistics and improvement tracking
- Mobile-responsive design
- Real-time status updates

### Session Management
- Conversation session creation and tracking
- Turn completion monitoring
- Session persistence and recovery
- Performance metrics collection
- Progress analytics

## Implementation Details

### Step 1: Conversation Practice tRPC Router

#### 1.1 Session Management API
```typescript
// apps/api/src/router/conversations.ts
import { router, protectedProcedure } from "./trpc";
import { z } from "zod";
import { TRPCError } from "@trpc/server";
import { ConversationService } from "../services/conversation-service";

export const conversationsRouter = router({
  // Start new conversation session
  startSession: protectedProcedure
    .input(z.object({
      scriptId: z.string().uuid(),
      userRole: z.enum(["PERSON_A", "PERSON_B"]),
    }))
    .mutation(async ({ input, ctx }) => {
      try {
        const conversationService = new ConversationService();
        const session = await conversationService.startConversationSession(
          ctx.user.id,
          input.scriptId,
          input.userRole
        );

        return { session };
      } catch (error) {
        console.error("Failed to start conversation session:", error);
        throw new TRPCError({
          code: "INTERNAL_SERVER_ERROR",
          message: "Failed to start conversation session",
        });
      }
    }),

  // Get conversation session details
  getSession: protectedProcedure
    .input(z.object({ sessionId: z.string().uuid() }))
    .query(async ({ input, ctx }) => {
      const conversationService = new ConversationService();
      const session = await conversationService.getConversationSession(
        input.sessionId,
        ctx.user.id
      );

      if (!session) {
        throw new TRPCError({
          code: "NOT_FOUND",
          message: "Conversation session not found",
        });
      }

      return session;
    }),

  // Get current turn details
  getCurrentTurn: protectedProcedure
    .input(z.object({ sessionId: z.string().uuid() }))
    .query(async ({ input, ctx }) => {
      const conversationService = new ConversationService();
      const turn = await conversationService.getCurrentTurn(
        input.sessionId,
        ctx.user.id
      );

      if (!turn) {
        throw new TRPCError({
          code: "NOT_FOUND",
          message: "No active turn found",
        });
      }

      return turn;
    }),

  // Submit user turn (text or audio)
  submitTurn: protectedProcedure
    .input(z.object({
      sessionId: z.string().uuid(),
      turnData: z.object({
        type: z.enum(["TEXT", "AUDIO"]),
        content: z.string(), // Text content or audio file URL
        audioMetadata: z.object({
          duration: z.number(),
          format: z.string(),
          size: z.number(),
        }).optional(),
      }),
    }))
    .mutation(async ({ input, ctx }) => {
      try {
        const conversationService = new ConversationService();
        const result = await conversationService.submitUserTurn(
          ctx.user.id,
          input.sessionId,
          input.turnData
        );

        return result;
      } catch (error) {
        console.error("Failed to submit turn:", error);
        throw new TRPCError({
          code: "INTERNAL_SERVER_ERROR",
          message: "Failed to submit turn",
        });
      }
    }),

  // Get AI response for current turn
  getAIResponse: protectedProcedure
    .input(z.object({
      sessionId: z.string().uuid(),
      userTurnId: z.string().uuid(),
    }))
    .mutation(async ({ input, ctx }) => {
      try {
        const conversationService = new ConversationService();
        const response = await conversationService.getAIResponse(
          ctx.user.id,
          input.sessionId,
          input.userTurnId
        );

        return response;
      } catch (error) {
        console.error("Failed to get AI response:", error);
        throw new TRPCError({
          code: "INTERNAL_SERVER_ERROR",
          message: "Failed to get AI response",
        });
      }
    }),

  // Complete conversation session
  completeSession: protectedProcedure
    .input(z.object({
      sessionId: z.string().uuid(),
      feedback: z.string().optional(),
      rating: z.number().min(1).max(5).optional(),
    }))
    .mutation(async ({ input, ctx }) => {
      try {
        const conversationService = new ConversationService();
        const result = await conversationService.completeConversationSession(
          ctx.user.id,
          input.sessionId,
          input.feedback,
          input.rating
        );

        return result;
      } catch (error) {
        console.error("Failed to complete session:", error);
        throw new TRPCError({
          code: "INTERNAL_SERVER_ERROR",
          message: "Failed to complete session",
        });
      }
    }),

  // Get conversation history
  getHistory: protectedProcedure
    .input(z.object({
      page: z.number().min(1).default(1),
      limit: z.number().min(1).max(20).default(10),
      scriptId: z.string().uuid().optional(),
      status: z.enum(["ACTIVE", "COMPLETED", "PAUSED"]).optional(),
    }))
    .query(async ({ input, ctx }) => {
      const conversationService = new ConversationService();
      return await conversationService.getConversationHistory(ctx.user.id, input);
    }),

  // Get conversation session statistics
  getSessionStats: protectedProcedure
    .input(z.object({ sessionId: z.string().uuid() }))
    .query(async ({ input, ctx }) => {
      const conversationService = new ConversationService();
      const stats = await conversationService.getSessionStatistics(
        input.sessionId,
        ctx.user.id
      );

      if (!stats) {
        throw new TRPCError({
          code: "NOT_FOUND",
          message: "Session not found",
        });
      }

      return stats;
    }),

  // Pause conversation session
  pauseSession: protectedProcedure
    .input(z.object({ sessionId: z.string().uuid() }))
    .mutation(async ({ input, ctx }) => {
      const conversationService = new ConversationService();
      const success = await conversationService.pauseConversationSession(
        input.sessionId,
        ctx.user.id
      );

      return { success };
    }),

  // Resume conversation session
  resumeSession: protectedProcedure
    .input(z.object({ sessionId: z.string().uuid() }))
    .mutation(async ({ input, ctx }) => {
      const conversationService = new ConversationService();
      const session = await conversationService.resumeConversationSession(
        input.sessionId,
        ctx.user.id
      );

      if (!session) {
        throw new TRPCError({
          code: "NOT_FOUND",
          message: "Session not found",
        });
      }

      return { session };
    }),
});
```

#### 1.2 Conversation Service Implementation
```typescript
// apps/api/src/services/conversation-service.ts
import { db } from "@repo/database";
import {
  conversations,
  conversationSessions,
  audioRecordings,
  audioProcessingResults
} from "@repo/database/src/schema";
import { eq, and, isNull, desc, asc, sql } from "drizzle-orm";
import { v4 as uuidv4 } from "uuid";
import { AIIntegrationService } from "./ai-integration-service";
import { AudioProcessingService } from "./audio-processing-service";

export class ConversationService {
  private aiService: AIIntegrationService;
  private audioService: AudioProcessingService;

  constructor() {
    this.aiService = new AIIntegrationService();
    this.audioService = new AudioProcessingService();
  }

  async startConversationSession(
    userId: string,
    scriptId: string,
    userRole: "PERSON_A" | "PERSON_B"
  ) {
    // Get script details
    const script = await db.query.conversations.findFirst({
      where: and(
        eq(conversations.id, scriptId),
        eq(conversations.userId, userId),
        isNull(conversations.deletedAt)
      )
    });

    if (!script) {
      throw new Error("Script not found");
    }

    // Create session
    const [session] = await db.insert(conversationSessions).values({
      id: uuidv4(),
      conversationId: scriptId,
      userId,
      startedAt: new Date(),
      userRole,
      status: "ACTIVE",
      completedTurns: 0,
      totalTurns: script.totalTurns || 0,
      completionPercentage: 0,
    }).returning();

    return {
      session,
      script: {
        id: script.id,
        title: script.title,
        scriptContent: script.scriptContent,
        totalTurns: script.totalTurns,
        estimatedDurationMinutes: script.estimatedDurationMinutes,
      },
      currentTurn: this.calculateCurrentTurn(script.scriptContent, 0, userRole),
    };
  }

  async getConversationSession(sessionId: string, userId: string) {
    const session = await db
      .select({
        id: conversationSessions.id,
        status: conversationSessions.status,
        userRole: conversationSessions.userRole,
        completedTurns: conversationSessions.completedTurns,
        totalTurns: conversationSessions.totalTurns,
        completionPercentage: conversationSessions.completionPercentage,
        startedAt: conversationSessions.startedAt,
        endedAt: conversationSessions.endedAt,
        durationSeconds: conversationSessions.durationSeconds,
        overallScore: conversationSessions.overallScore,
        notes: conversationSessions.notes,
        conversation: {
          id: conversations.id,
          title: conversations.title,
          scriptContent: conversations.scriptContent,
          estimatedDurationMinutes: conversations.estimatedDurationMinutes,
        }
      })
      .from(conversationSessions)
      .innerJoin(conversations, eq(conversationSessions.conversationId, conversations.id))
      .where(and(
        eq(conversationSessions.id, sessionId),
        eq(conversationSessions.userId, userId)
      ))
      .limit(1);

    if (!session[0]) {
      return null;
    }

    const sessionData = session[0];
    const currentTurn = this.calculateCurrentTurn(
      sessionData.conversation.scriptContent,
      sessionData.completedTurns,
      sessionData.userRole
    );

    return {
      ...sessionData,
      currentTurn,
    };
  }

  async getCurrentTurn(sessionId: string, userId: string) {
    const session = await this.getConversationSession(sessionId, userId);
    if (!session) {
      return null;
    }

    return session.currentTurn;
  }

  async submitUserTurn(
    userId: string,
    sessionId: string,
    turnData: {
      type: "TEXT" | "AUDIO";
      content: string;
      audioMetadata?: {
        duration: number;
        format: string;
        size: number;
      };
    }
  ) {
    const session = await this.getConversationSession(sessionId, userId);
    if (!session) {
      throw new Error("Session not found");
    }

    if (session.status !== "ACTIVE") {
      throw new Error("Session is not active");
    }

    // Create audio recording record
    const [audioRecording] = await db.insert(audioRecordings).values({
      id: uuidv4(),
      userId,
      conversationSessionId: sessionId,
      conversationId: session.conversation.id,
      turnNumber: session.completedTurns + 1,
      scriptLine: session.currentTurn.scriptLine,
      originalFilename: turnData.type === "AUDIO" ? `turn_${session.completedTurns + 1}` : null,
      audioFormat: turnData.audioMetadata?.format || "text",
      durationSeconds: turnData.audioMetadata?.duration || 0,
      fileSize: turnData.audioMetadata?.size || 0,
      recordingQuality: "STANDARD",
      storageProvider: "DATABASE", // For text content
      filePath: turnData.content, // Store content directly for now
    }).returning();

    // Process audio if needed
    if (turnData.type === "AUDIO") {
      await this.audioService.processAudio(audioRecording.id, turnData.content);
    }

    // Update session
    await db.update(conversationSessions)
      .set({
        completedTurns: session.completedTurns + 1,
        completionPercentage: ((session.completedTurns + 1) / session.totalTurns) * 100,
        updatedAt: new Date(),
      })
      .where(eq(conversationSessions.id, sessionId));

    return {
      audioRecording,
      nextTurn: this.calculateCurrentTurn(
        session.conversation.scriptContent,
        session.completedTurns + 1,
        session.userRole
      ),
    };
  }

  async getAIResponse(userId: string, sessionId: string, userTurnId: string) {
    const session = await this.getConversationSession(sessionId, userId);
    if (!session) {
      throw new Error("Session not found");
    }

    // Get user turn data
    const userTurn = await db.query.audioRecordings.findFirst({
      where: eq(audioRecordings.id, userTurnId),
    });

    if (!userTurn) {
      throw new Error("User turn not found");
    }

    // Generate AI response
    const aiResponse = await this.aiService.generateConversationResponse({
      userText: userTurn.filePath, // This would be processed text
      context: session.currentTurn,
      conversationContext: session.conversation.scriptContent,
      userRole: session.userRole,
      turnNumber: session.completedTurns,
    });

    // Convert to speech if needed
    let audioData = null;
    if (aiResponse.audio) {
      audioData = await this.aiService.textToSpeech(aiResponse.text);
    }

    return {
      text: aiResponse.text,
      audioData,
      pronunciationNotes: aiResponse.pronunciationNotes,
      nextTurn: this.calculateCurrentTurn(
        session.conversation.scriptContent,
        session.completedTurns,
        session.userRole
      ),
    };
  }

  async completeConversationSession(
    userId: string,
    sessionId: string,
    feedback?: string,
    rating?: number
  ) {
    const session = await this.getConversationSession(sessionId, userId);
    if (!session) {
      throw new Error("Session not found");
    }

    const endedAt = new Date();
    const durationSeconds = session.startedAt
      ? Math.floor((endedAt.getTime() - session.startedAt.getTime()) / 1000)
      : 0;

    // Calculate overall score based on performance
    const overallScore = await this.calculateSessionScore(sessionId);

    await db.update(conversationSessions)
      .set({
        status: "COMPLETED",
        endedAt,
        durationSeconds,
        completionPercentage: 100,
        overallScore,
        notes: feedback,
        updatedAt: endedAt,
      })
      .where(eq(conversationSessions.id, sessionId));

    // Update conversation usage count
    await db.update(conversations)
      .set({
        usageCount: sql`${conversations.usageCount} + 1`,
        rating: rating || conversations.rating, // Update average rating
        updatedAt: new Date(),
      })
      .where(eq(conversations.id, session.conversation.id));

    return {
      success: true,
      durationSeconds,
      completedTurns: session.completedTurns,
      overallScore,
    };
  }

  async getConversationHistory(userId: string, filters: {
    page: number;
    limit: number;
    scriptId?: string;
    status?: string;
  }) {
    const offset = (filters.page - 1) * filters.limit;

    let query = db
      .select({
        id: conversationSessions.id,
        status: conversationSessions.status,
        completedTurns: conversationSessions.completedTurns,
        totalTurns: conversationSessions.totalTurns,
        completionPercentage: conversationSessions.completionPercentage,
        overallScore: conversationSessions.overallScore,
        durationSeconds: conversationSessions.durationSeconds,
        startedAt: conversationSessions.startedAt,
        endedAt: conversationSessions.endedAt,
        conversation: {
          id: conversations.id,
          title: conversations.title,
          difficultyLevel: conversations.difficultyLevel,
          estimatedDurationMinutes: conversations.estimatedDurationMinutes,
        }
      })
      .from(conversationSessions)
      .innerJoin(conversations, eq(conversationSessions.conversationId, conversations.id))
      .where(eq(conversationSessions.userId, userId));

    // Apply filters
    if (filters.scriptId) {
      query = query.where(eq(conversationSessions.conversationId, filters.scriptId));
    }

    if (filters.status) {
      query = query.where(eq(conversationSessions.status, filters.status));
    }

    // Get total count
    const totalCountQuery = db
      .select({ count: sql<number>`count(*)` })
      .from(conversationSessions)
      .where(eq(conversationSessions.userId, userId));

    const [{ count: totalCount }] = await totalCountQuery;

    // Get paginated results
    const sessionsList = await query
      .orderBy(desc(conversationSessions.startedAt))
      .limit(filters.limit)
      .offset(offset);

    return {
      sessions: sessionsList,
      totalCount,
      currentPage: filters.page,
      totalPages: Math.ceil(totalCount / filters.limit),
    };
  }

  async getSessionStatistics(sessionId: string, userId: string) {
    const session = await this.getConversationSession(sessionId, userId);
    if (!session) {
      return null;
    }

    // Get detailed performance metrics
    const audioRecordings = await db.query.audioRecordings.findMany({
      where: eq(audioRecordings.conversationSessionId, sessionId),
      orderBy: asc(audioRecordings.turnNumber),
    });

    const processingResults = await db.query.audioProcessingResults.findMany({
      where: eq(audioProcessingResults.audioRecordingId, sql`ANY(${audioRecordings.map(ar => ar.id)})`),
    });

    return {
      session,
      audioRecordings,
      processingResults,
      averageConfidence: processingResults.reduce((sum, result) => sum + (result.confidenceScore || 0), 0) / processingResults.length,
      totalProcessingTime: processingResults.reduce((sum, result) => sum + (result.processingTimeMs || 0), 0),
      completedTurns: session.completedTurns,
      completionPercentage: session.completionPercentage,
      averageScore: session.overallScore,
    };
  }

  async pauseConversationSession(sessionId: string, userId: string) {
    const result = await db.update(conversationSessions)
      .set({
        status: "PAUSED",
        updatedAt: new Date(),
      })
      .where(and(
        eq(conversationSessions.id, sessionId),
        eq(conversationSessions.userId, userId)
      ));

    return result.rowCount > 0;
  }

  async resumeConversationSession(sessionId: string, userId: string) {
    const result = await db.update(conversationSessions)
      .set({
        status: "ACTIVE",
        updatedAt: new Date(),
      })
      .where(and(
        eq(conversationSessions.id, sessionId),
        eq(conversationSessions.userId, userId)
      ));

    if (result.rowCount === 0) {
      return null;
    }

    return await this.getConversationSession(sessionId, userId);
  }

  private calculateCurrentTurn(
    scriptContent: any,
    completedTurns: number,
    userRole: "PERSON_A" | "PERSON_B"
  ) {
    if (!scriptContent || !scriptContent.dialogue) {
      return {
        turnNumber: 1,
        speaker: userRole,
        scriptLine: "No script available",
        isUserTurn: true,
        pronunciationNotes: "",
      };
    }

    const dialogue = scriptContent.dialogue;
    const currentTurnIndex = completedTurns;

    if (currentTurnIndex >= dialogue.length) {
      return {
        turnNumber: currentTurnIndex + 1,
        speaker: "CONVERSATION_COMPLETE",
        scriptLine: "Conversation completed",
        isUserTurn: false,
        pronunciationNotes: "",
      };
    }

    const currentTurn = dialogue[currentTurnIndex];
    const isUserTurn = currentTurn.speaker === userRole;

    return {
      turnNumber: currentTurnIndex + 1,
      speaker: currentTurn.speaker,
      scriptLine: currentTurn.text,
      isUserTurn,
      pronunciationNotes: currentTurn.pronunciationNotes || "",
      teachingPoints: currentTurn.teachingPoints || [],
      difficulty: currentTurn.difficulty || "MEDIUM",
    };
  }

  private async calculateSessionScore(sessionId: string): Promise<number> {
    // Get all audio processing results for this session
    const audioRecordings = await db.query.audioRecordings.findMany({
      where: eq(audioRecordings.conversationSessionId, sessionId),
    });

    if (audioRecordings.length === 0) {
      return 0;
    }

    // Get processing results to calculate average score
    const results = await db.query.audioProcessingResults.findMany({
      where: sql`audio_recording_id = ANY(${audioRecordings.map(ar => ar.id)})`,
    });

    if (results.length === 0) {
      return 50; // Default score if no processing results
    }

    // Calculate weighted average score
    const totalScore = results.reduce((sum, result) => {
      // Simple scoring based on confidence and other factors
      const confidenceScore = result.confidenceScore || 0;
      const accuracyScore = 85; // Placeholder for pronunciation accuracy
      return sum + (confidenceScore * 100 + accuracyScore) / 2;
    }, 0);

    return Math.round(totalScore / results.length);
  }
}
```

### Step 2: Frontend Conversation Practice Interface

#### 2.1 Conversation Practice Component
```typescript
// apps/app/src/components/conversations/ConversationPractice.tsx
import React, { useState, useEffect, useRef } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { Button } from "@repo/ui/components/button";
import { Card, CardContent, CardHeader, CardTitle } from "@repo/ui/components/card";
import { Badge } from "@repo/ui/components/badge";
import { Progress } from "@repo/ui/components/progress";
import { Textarea } from "@repo/ui/components/textarea";
import {
  Mic,
  MicOff,
  Square,
  Play,
  Pause,
  Volume2,
  MessageSquare,
  Clock,
  Target,
  RotateCcw,
  CheckCircle,
  User,
  Bot
} from "lucide-react";
import { trpc } from "../../utils/trpc";
import { AudioRecorder } from "./AudioRecorder";

interface ConversationPracticeProps {
  scriptId: string;
  onSessionComplete?: (sessionId: string) => void;
}

export const ConversationPractice: React.FC<ConversationPracticeProps> = ({
  scriptId,
  onSessionComplete
}) => {
  const { sessionId: paramSessionId } = useParams();
  const navigate = useNavigate();

  const [sessionId, setSessionId] = useState<string | null>(paramSessionId || null);
  const [currentTurn, setCurrentTurn] = useState<any>(null);
  const [session, setSession] = useState<any>(null);
  const [isRecording, setIsRecording] = useState(false);
  const [isSpeaking, setIsSpeaking] = useState(false);
  const [textInput, setTextInput] = useState("");
  const [inputMode, setInputMode] = useState<"voice" | "text">("voice");
  const [conversationHistory, setConversationHistory] = useState<any[]>([]);
  const [isProcessing, setIsProcessing] = useState(false);
  const [showFeedback, setShowFeedback] = useState(false);

  const startSessionMutation = trpc.conversations.startSession.useMutation();
  const submitTurnMutation = trpc.conversations.submitTurn.useMutation();
  const getAIResponseMutation = trpc.conversations.getAIResponse.useMutation();
  const completeSessionMutation = trpc.conversations.completeSession.useMutation();
  const getSessionQuery = trpc.conversations.getSession.useQuery(
    { sessionId: sessionId! },
    { enabled: !!sessionId }
  );

  const audioRecorderRef = useRef<AudioRecorder>(null);

  useEffect(() => {
    if (!sessionId && scriptId) {
      startNewSession();
    }
  }, [scriptId]);

  useEffect(() => {
    if (getSessionQuery.data) {
      setSession(getSessionQuery.data);
      setCurrentTurn(getSessionQuery.data.currentTurn);
    }
  }, [getSessionQuery.data]);

  const startNewSession = async () => {
    try {
      const result = await startSessionMutation.mutateAsync({
        scriptId,
        userRole: "PERSON_A", // Could be configurable
      });

      setSessionId(result.session.id);
      setCurrentTurn(result.currentTurn);
      navigate(`/conversations/${result.session.id}`, { replace: true });
    } catch (error) {
      console.error("Failed to start session:", error);
    }
  };

  const handleRecordingComplete = async (audioData: Blob) => {
    setIsRecording(false);
    setIsProcessing(true);

    try {
      // Convert audio to base64 or upload to storage
      const audioContent = await audioBlobToBase64(audioData);

      // Submit user turn
      const turnResult = await submitTurnMutation.mutateAsync({
        sessionId: sessionId!,
        turnData: {
          type: "AUDIO",
          content: audioContent,
          audioMetadata: {
            duration: audioData.size / 16000, // Approximate duration
            format: "webm",
            size: audioData.size,
          },
        },
      });

      // Add to conversation history
      setConversationHistory(prev => [
        ...prev,
        {
          speaker: "You",
          type: "AUDIO",
          content: audioContent,
          timestamp: new Date(),
        }
      ]);

      // Get AI response
      const aiResponse = await getAIResponseMutation.mutateAsync({
        sessionId: sessionId!,
        userTurnId: turnResult.audioRecording.id,
      });

      // Add AI response to history
      setConversationHistory(prev => [
        ...prev,
        {
          speaker: "AI",
          type: "TEXT",
          content: aiResponse.text,
          audioData: aiResponse.audioData,
          pronunciationNotes: aiResponse.pronunciationNotes,
          timestamp: new Date(),
        }
      ]);

      // Update current turn
      setCurrentTurn(aiResponse.nextTurn);

      // Play AI response if available
      if (aiResponse.audioData) {
        await playAudioResponse(aiResponse.audioData);
      }

      // Check if conversation is complete
      if (aiResponse.nextTurn.speaker === "CONVERSATION_COMPLETE") {
        await completeSession();
      }

    } catch (error) {
      console.error("Failed to process recording:", error);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleTextSubmit = async () => {
    if (!textInput.trim()) return;

    setIsProcessing(true);

    try {
      // Submit text turn
      const turnResult = await submitTurnMutation.mutateAsync({
        sessionId: sessionId!,
        turnData: {
          type: "TEXT",
          content: textInput,
        },
      });

      // Add to conversation history
      setConversationHistory(prev => [
        ...prev,
        {
          speaker: "You",
          type: "TEXT",
          content: textInput,
          timestamp: new Date(),
        }
      ]);

      setTextInput("");

      // Get AI response
      const aiResponse = await getAIResponseMutation.mutateAsync({
        sessionId: sessionId!,
        userTurnId: turnResult.audioRecording.id,
      });

      // Add AI response to history
      setConversationHistory(prev => [
        ...prev,
        {
          speaker: "AI",
          type: "TEXT",
          content: aiResponse.text,
          audioData: aiResponse.audioData,
          pronunciationNotes: aiResponse.pronunciationNotes,
          timestamp: new Date(),
        }
      ]);

      // Update current turn
      setCurrentTurn(aiResponse.nextTurn);

      // Play AI response if available
      if (aiResponse.audioData) {
        await playAudioResponse(aiResponse.audioData);
      }

      // Check if conversation is complete
      if (aiResponse.nextTurn.speaker === "CONVERSATION_COMPLETE") {
        await completeSession();
      }

    } catch (error) {
      console.error("Failed to process text input:", error);
    } finally {
      setIsProcessing(false);
    }
  };

  const completeSession = async () => {
    try {
      const result = await completeSessionMutation.mutateAsync({
        sessionId: sessionId!,
        feedback: "Good practice session",
        rating: 4,
      });

      setShowFeedback(true);
      onSessionComplete?.(sessionId!);

    } catch (error) {
      console.error("Failed to complete session:", error);
    }
  };

  const playAudioResponse = async (audioData: string) => {
    setIsSpeaking(true);
    try {
      const audio = new Audio(`data:audio/mp3;base64,${audioData}`);
      await audio.play();
    } catch (error) {
      console.error("Failed to play audio:", error);
    } finally {
      setIsSpeaking(false);
    }
  };

  const audioBlobToBase64 = (blob: Blob): Promise<string> => {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result as string);
      reader.onerror = reject;
      reader.readAsDataURL(blob);
    });
  };

  if (!session || !currentTurn) {
    return (
      <div className="flex items-center justify-center min-h-96">
        <div className="text-center">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p>Loading conversation...</p>
        </div>
      </div>
    );
  }

  if (showFeedback) {
    return (
      <Card className="w-full max-w-4xl mx-auto">
        <CardContent className="text-center py-12">
          <CheckCircle className="h-16 w-16 text-green-600 mx-auto mb-4" />
          <h2 className="text-2xl font-bold mb-2">Conversation Complete!</h2>
          <p className="text-gray-600 mb-6">
            Great job! You've completed the conversation practice session.
          </p>
          <div className="flex justify-center space-x-4">
            <Button onClick={() => navigate("/conversations")}>
              Back to Conversations
            </Button>
            <Button variant="outline" onClick={() => startNewSession()}>
              Start New Session
            </Button>
          </div>
        </CardContent>
      </Card>
    );
  }

  const progressPercentage = (currentTurn.turnNumber / (session.conversation.totalTurns || 1)) * 100;

  return (
    <div className="w-full max-w-4xl mx-auto space-y-6">
      {/* Session Header */}
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle className="flex items-center space-x-2">
              <MessageSquare className="h-5 w-5" />
              <span>{session.conversation.title}</span>
            </CardTitle>
            <div className="flex items-center space-x-4">
              <div className="flex items-center space-x-2 text-sm text-gray-600">
                <Clock className="h-4 w-4" />
                <span>Turn {currentTurn.turnNumber} of {session.conversation.totalTurns}</span>
              </div>
              <Badge variant="secondary">
                {session.userRole}
              </Badge>
            </div>
          </div>
          <Progress value={progressPercentage} className="mt-2" />
        </CardHeader>
      </Card>

      {/* Current Turn */}
      {currentTurn.speaker !== "CONVERSATION_COMPLETE" && (
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center space-x-2">
              {currentTurn.isUserTurn ? (
                <User className="h-5 w-5 text-blue-600" />
              ) : (
                <Bot className="h-5 w-5 text-green-600" />
              )}
              <span>
                {currentTurn.speaker}'s Turn
                {currentTurn.isUserTurn && " (Your turn to speak)"}
              </span>
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              <div className="p-4 bg-gray-50 rounded-lg">
                <p className="text-lg font-medium">{currentTurn.scriptLine}</p>
              </div>

              {currentTurn.pronunciationNotes && (
                <div className="p-3 bg-blue-50 border border-blue-200 rounded-lg">
                  <p className="text-sm text-blue-800">
                    <strong>Pronunciation Tips:</strong> {currentTurn.pronunciationNotes}
                  </p>
                </div>
              )}

              {currentTurn.teachingPoints && currentTurn.teachingPoints.length > 0 && (
                <div className="flex flex-wrap gap-2">
                  {currentTurn.teachingPoints.map((point: string, index: number) => (
                    <Badge key={index} variant="outline">
                      {point}
                    </Badge>
                  ))}
                </div>
              )}
            </div>
          </CardContent>
        </Card>
      )}

      {/* User Input */}
      {currentTurn.isUserTurn && (
        <Card>
          <CardHeader>
            <CardTitle>Your Response</CardTitle>
            <div className="flex space-x-2">
              <Button
                variant={inputMode === "voice" ? "default" : "outline"}
                onClick={() => setInputMode("voice")}
                disabled={isProcessing}
              >
                <Mic className="h-4 w-4 mr-2" />
                Voice
              </Button>
              <Button
                variant={inputMode === "text" ? "default" : "outline"}
                onClick={() => setInputMode("text")}
                disabled={isProcessing}
              >
                <MessageSquare className="h-4 w-4 mr-2" />
                Text
              </Button>
            </div>
          </CardHeader>
          <CardContent>
            {inputMode === "voice" ? (
              <div className="text-center space-y-4">
                <AudioRecorder
                  onRecordingComplete={handleRecordingComplete}
                  disabled={isProcessing}
                />
                <p className="text-sm text-gray-600">
                  Click the microphone button and say your line clearly
                </p>
              </div>
            ) : (
              <div className="space-y-4">
                <Textarea
                  value={textInput}
                  onChange={(e) => setTextInput(e.target.value)}
                  placeholder="Type your response here..."
                  rows={3}
                  disabled={isProcessing}
                />
                <Button
                  onClick={handleTextSubmit}
                  disabled={!textInput.trim() || isProcessing}
                  className="w-full"
                >
                  {isProcessing ? (
                    <>
                      <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></div>
                      Processing...
                    </>
                  ) : (
                    "Submit Response"
                  )}
                </Button>
              </div>
            )}
          </CardContent>
        </Card>
      )}

      {/* Conversation History */}
      {conversationHistory.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle>Conversation History</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-4 max-h-64 overflow-y-auto">
              {conversationHistory.map((entry, index) => (
                <div key={index} className={`flex ${entry.speaker === "You" ? "justify-end" : "justify-start"}`}>
                  <div className={`max-w-xs px-4 py-2 rounded-lg ${
                    entry.speaker === "You"
                      ? "bg-blue-600 text-white"
                      : "bg-gray-200 text-gray-900"
                  }`}>
                    <div className="flex items-center space-x-2 mb-1">
                      {entry.speaker === "You" ? (
                        <User className="h-4 w-4" />
                      ) : (
                        <Bot className="h-4 w-4" />
                      )}
                      <span className="text-sm font-medium">{entry.speaker}</span>
                    </div>
                    <p>{entry.content}</p>
                    {entry.audioData && (
                      <Button
                        variant="ghost"
                        size="sm"
                        className="mt-2 text-white hover:bg-blue-700"
                        onClick={() => playAudioResponse(entry.audioData)}
                      >
                        <Volume2 className="h-4 w-4 mr-1" />
                        Play
                      </Button>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}

      {/* Session Controls */}
      <Card>
        <CardContent className="pt-6">
          <div className="flex justify-between">
            <Button
              variant="outline"
              onClick={() => navigate("/conversations")}
              disabled={isProcessing}
            >
              Exit Session
            </Button>
            <div className="flex space-x-2">
              <Button
                variant="outline"
                onClick={() => setShowFeedback(true)}
                disabled={isProcessing}
              >
                End Session
              </Button>
              <Button
                variant="outline"
                onClick={() => window.location.reload()}
                disabled={isProcessing}
              >
                <RotateCcw className="h-4 w-4 mr-2" />
                Restart
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
};
```

## Testing Strategy

### Conversation Flow Tests
```typescript
// apps/api/src/__tests__/conversations.test.ts
import { describe, it, expect, beforeEach } from "vitest";
import { ConversationService } from "../services/conversation-service";

describe("Conversation Practice", () => {
  let conversationService: ConversationService;

  beforeEach(() => {
    conversationService = new ConversationService();
  });

  it("should start a new conversation session", async () => {
    const session = await conversationService.startConversationSession(
      "test-user-id",
      "test-script-id",
      "PERSON_A"
    );

    expect(session).toBeDefined();
    expect(session.session.status).toBe("ACTIVE");
    expect(session.currentTurn).toBeDefined();
    expect(session.currentTurn.isUserTurn).toBe(true);
  });

  it("should submit user turn correctly", async () => {
    const session = await conversationService.startConversationSession(
      "test-user-id",
      "test-script-id",
      "PERSON_A"
    );

    const result = await conversationService.submitUserTurn(
      "test-user-id",
      session.session.id,
      {
        type: "TEXT",
        content: "Hello, how are you?",
      }
    );

    expect(result.audioRecording).toBeDefined();
    expect(result.nextTurn).toBeDefined();
  });

  it("should complete session with score calculation", async () => {
    const session = await conversationService.startConversationSession(
      "test-user-id",
      "test-script-id",
      "PERSON_A"
    );

    const result = await conversationService.completeConversationSession(
      "test-user-id",
      session.session.id,
      "Great session!",
      5
    );

    expect(result.success).toBe(true);
    expect(result.durationSeconds).toBeGreaterThan(0);
    expect(result.overallScore).toBeGreaterThanOrEqual(0);
  });
});
```

## Estimated Timeline: 1 Week

### Day 1-2: Conversation API
- Create conversation session management
- Implement turn submission and processing
- Build conversation history tracking

### Day 3-4: AI Integration
- Integrate AI response generation
- Add conversation context handling
- Implement session completion logic

### Day 5: Frontend Interface
- Build conversation practice UI
- Add audio recording integration
- Create conversation history display

## Success Criteria

- [ ] Conversation session creation working
- [ ] Turn-based dialogue system functional
- [ ] Role selection implementation
- [ ] Script display and highlighting working
- [ ] Text and voice input support
- [ ] AI response generation functional
- [ ] Progress tracking operational
- [ ] Session management complete
- [ ] Conversation history display
- [ ] Real-time status updates
- [ ] Mobile-responsive design
- [ ] All conversation features tested

This conversation practice system provides an immersive and interactive environment for users to practice their English pronunciation through realistic dialogues with AI partners.