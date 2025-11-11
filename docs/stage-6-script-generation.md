# Stage 6: Script Generation System

## Stage Overview

This stage implements the AI-powered script generation system that converts uploaded documents into conversational scripts for pronunciation practice. The system includes topic-based generation, document-based generation, script templates, and quality validation.

## Observable Outcomes

- ✅ Document-to-script conversion pipeline working
- ✅ Topic-based script generation functional
- ✅ Script templates and customization options
- ✅ Script quality validation and feedback
- ✅ Script management and editing interface
- ✅ Script metadata and organization features
- ✅ Batch processing capabilities

## Technical Requirements

### Script Generation Features
- Document-based script generation
- Topic-based script generation
- Script template system
- Customizable difficulty levels
- Target duration control
- Language selection
- Pronunciation focus areas

### Script Management
- Script versioning and history
- Script editing and customization
- Script metadata and categorization
- Script sharing and templates
- Script quality scoring
- Script analytics and usage tracking

## Implementation Details

### Step 1: Script Generation Service

#### 1.1 Script Generation tRPC Router
```typescript
// apps/api/src/router/scripts.ts
import { router, protectedProcedure } from "./trpc";
import { z } from "zod";
import { TRPCError } from "@trpc/server";
import { ScriptService } from "../services/script-service";
import { AIIntegrationService } from "../services/ai-integration-service";

export const scriptsRouter = router({
  // Generate script from document
  generateFromDocument: protectedProcedure
    .input(z.object({
      documentId: z.string().uuid(),
      difficultyLevel: z.enum(["BEGINNER", "INTERMEDIATE", "ADVANCED"]).default("INTERMEDIATE"),
      targetDurationMinutes: z.number().min(5).max(30).default(10),
      language: z.string().default("en"),
      focusAreas: z.array(z.enum(["PRONUNCIATION", "FLUENCY", "RHYTHM", "INTONATION"])).default(["PRONUNCIATION"]),
      customInstructions: z.string().optional(),
    }))
    .mutation(async ({ input, ctx }) => {
      try {
        const scriptService = new ScriptService();
        const aiService = new AIIntegrationService();

        // Get document
        const document = await scriptService.getDocument(input.documentId, ctx.user.id);
        if (!document) {
          throw new TRPCError({
            code: "NOT_FOUND",
            message: "Document not found",
          });
        }

        if (document.status !== "READY") {
          throw new TRPCError({
            code: "BAD_REQUEST",
            message: "Document is not ready for script generation",
          });
        }

        // Generate script using AI service
        const scriptContent = await aiService.generateScriptFromDocument({
          content: document.content!,
          title: document.title,
          difficultyLevel: input.difficultyLevel,
          targetDurationMinutes: input.targetDurationMinutes,
          language: input.language,
          focusAreas: input.focusAreas,
          customInstructions: input.customInstructions,
        });

        // Create script record
        const script = await scriptService.createScript({
          userId: ctx.user.id,
          documentId: input.documentId,
          title: `Script based on ${document.title}`,
          scriptContent,
          scriptGenerationMode: "DOCUMENT_BASED",
          language: input.language,
          difficultyLevel: input.difficultyLevel,
          estimatedDurationMinutes: input.targetDurationMinutes,
          sourceDocumentHash: document.contentHash,
        });

        return { script };
      } catch (error) {
        console.error("Script generation error:", error);
        throw new TRPCError({
          code: "INTERNAL_SERVER_ERROR",
          message: "Failed to generate script",
        });
      }
    }),

  // Generate script from topic
  generateFromTopic: protectedProcedure
    .input(z.object({
      topic: z.string().min(5).max(500),
      title: z.string().min(1).max(255),
      description: z.string().optional(),
      difficultyLevel: z.enum(["BEGINNER", "INTERMEDIATE", "ADVANCED"]).default("INTERMEDIATE"),
      targetDurationMinutes: z.number().min(5).max(30).default(10),
      language: z.string().default("en"),
      focusAreas: z.array(z.enum(["PRONUNCIATION", "FLUENCY", "RHYTHM", "INTONATION"])).default(["PRONUNCIATION"]),
      tags: z.array(z.string()).default([]),
      customInstructions: z.string().optional(),
    }))
    .mutation(async ({ input, ctx }) => {
      try {
        const scriptService = new ScriptService();
        const aiService = new AIIntegrationService();

        // Generate script using AI service
        const scriptContent = await aiService.generateScriptFromTopic({
          topic: input.topic,
          title: input.title,
          description: input.description,
          difficultyLevel: input.difficultyLevel,
          targetDurationMinutes: input.targetDurationMinutes,
          language: input.language,
          focusAreas: input.focusAreas,
          customInstructions: input.customInstructions,
        });

        // Create script record
        const script = await scriptService.createScript({
          userId: ctx.user.id,
          title: input.title,
          description: input.description,
          scriptContent,
          scriptGenerationMode: "TOPIC_BASED",
          language: input.language,
          difficultyLevel: input.difficultyLevel,
          estimatedDurationMinutes: input.targetDurationMinutes,
          tags: input.tags,
        });

        return { script };
      } catch (error) {
        console.error("Topic script generation error:", error);
        throw new TRPCError({
          code: "INTERNAL_SERVER_ERROR",
          message: "Failed to generate script from topic",
        });
      }
    }),

  // Get user scripts
  getAll: protectedProcedure
    .input(z.object({
      page: z.number().min(1).default(1),
      limit: z.number().min(1).max(50).default(20),
      search: z.string().optional(),
      tags: z.array(z.string()).optional(),
      difficultyLevel: z.enum(["BEGINNER", "INTERMEDIATE", "ADVANCED"]).optional(),
      isTemplate: z.boolean().optional(),
      sortBy: z.enum(["createdAt", "updatedAt", "title", "difficultyLevel"]).default("createdAt"),
      sortOrder: z.enum(["asc", "desc"]).default("desc"),
    }))
    .query(async ({ input, ctx }) => {
      const scriptService = new ScriptService();
      return await scriptService.getUserScripts(ctx.user.id, input);
    }),

  // Get single script
  getById: protectedProcedure
    .input(z.object({ id: z.string().uuid() }))
    .query(async ({ input, ctx }) => {
      const scriptService = new ScriptService();
      const script = await scriptService.getScriptById(input.id, ctx.user.id);

      if (!script) {
        throw new TRPCError({
          code: "NOT_FOUND",
          message: "Script not found",
        });
      }

      return script;
    }),

  // Update script
  update: protectedProcedure
    .input(z.object({
      id: z.string().uuid(),
      title: z.string().min(1).max(255),
      description: z.string().optional(),
      scriptContent: z.any(), // JSON structure
      tags: z.array(z.string()).optional(),
      difficultyLevel: z.enum(["BEGINNER", "INTERMEDIATE", "ADVANCED"]).optional(),
    }))
    .mutation(async ({ input, ctx }) => {
      const scriptService = new ScriptService();
      const script = await scriptService.updateScript(
        input.id,
        ctx.user.id,
        {
          title: input.title,
          description: input.description,
          scriptContent: input.scriptContent,
          tags: input.tags,
          difficultyLevel: input.difficultyLevel,
        }
      );

      if (!script) {
        throw new TRPCError({
          code: "NOT_FOUND",
          message: "Script not found",
        });
      }

      return script;
    }),

  // Delete script
  delete: protectedProcedure
    .input(z.object({ id: z.string().uuid() }))
    .mutation(async ({ input, ctx }) => {
      const scriptService = new ScriptService();
      const success = await scriptService.deleteScript(input.id, ctx.user.id);

      if (!success) {
        throw new TRPCError({
          code: "NOT_FOUND",
          message: "Script not found",
        });
      }

      return { success: true };
    }),

  // Duplicate script
  duplicate: protectedProcedure
    .input(z.object({
      id: z.string().uuid(),
      newTitle: z.string().min(1).max(255),
    }))
    .mutation(async ({ input, ctx }) => {
      const scriptService = new ScriptService();
      const duplicatedScript = await scriptService.duplicateScript(
        input.id,
        ctx.user.id,
        input.newTitle
      );

      if (!duplicatedScript) {
        throw new TRPCError({
          code: "NOT_FOUND",
          message: "Original script not found",
        });
      }

      return { script: duplicatedScript };
    }),

  // Get script templates
  getTemplates: protectedProcedure
    .input(z.object({
      category: z.string().optional(),
      difficultyLevel: z.enum(["BEGINNER", "INTERMEDIATE", "ADVANCED"]).optional(),
      limit: z.number().min(1).max(20).default(10),
    }))
    .query(async ({ input, ctx }) => {
      const scriptService = new ScriptService();
      return await scriptService.getScriptTemplates(ctx.user.id, input);
    }),

  // Create script from template
  createFromTemplate: protectedProcedure
    .input(z.object({
      templateId: z.string().uuid(),
      customTitle: z.string().min(1).max(255),
      customizations: z.any().optional(), // Custom modifications to the script
    }))
    .mutation(async ({ input, ctx }) => {
      const scriptService = new ScriptService();
      const script = await scriptService.createFromTemplate(
        input.templateId,
        ctx.user.id,
        input.customTitle,
        input.customizations
      );

      if (!script) {
        throw new TRPCError({
          code: "NOT_FOUND",
          message: "Template not found",
        });
      }

      return { script };
    }),

  // Validate script quality
  validateScript: protectedProcedure
    .input(z.object({
      scriptContent: z.any(), // JSON structure
      difficultyLevel: z.enum(["BEGINNER", "INTERMEDIATE", "ADVANCED"]),
      language: z.string().default("en"),
    }))
    .mutation(async ({ input, ctx }) => {
      const aiService = new AIIntegrationService();
      const validation = await aiService.validateScriptQuality({
        scriptContent: input.scriptContent,
        difficultyLevel: input.difficultyLevel,
        language: input.language,
      });

      return validation;
    }),
});
```

#### 1.2 Script Service Implementation
```typescript
// apps/api/src/services/script-service.ts
import { db } from "@repo/database";
import {
  conversations,
  documents,
  conversationSessions,
  audioRecordings
} from "@repo/database/src/schema";
import { eq, and, isNull, desc, asc, sql, ilike, arrayContains } from "drizzle-orm";
import { v4 as uuidv4 } from "uuid";

export class ScriptService {
  async createScript(data: {
    userId: string;
    title: string;
    description?: string;
    scriptContent: any;
    scriptGenerationMode: string;
    documentId?: string;
    language: string;
    difficultyLevel: string;
    estimatedDurationMinutes: number;
    tags?: string[];
    sourceDocumentHash?: string;
    generationPrompt?: string;
  }) {
    const [script] = await db.insert(conversations).values({
      userId: data.userId,
      documentId: data.documentId,
      title: data.title,
      description: data.description,
      scriptContent: data.scriptContent,
      scriptGenerationMode: data.scriptGenerationMode,
      language: data.language,
      difficultyLevel: data.difficultyLevel,
      estimatedDurationMinutes: data.estimatedDurationMinutes,
      tags: data.tags || [],
      sourceDocumentHash: data.sourceDocumentHash,
      generationPrompt: data.generationPrompt,
      status: "ACTIVE",
      totalTurns: this.calculateTotalTurns(data.scriptContent),
    }).returning();

    return script;
  }

  async getUserScripts(userId: string, filters: {
    page: number;
    limit: number;
    search?: string;
    tags?: string[];
    difficultyLevel?: string;
    isTemplate?: boolean;
    sortBy: string;
    sortOrder: "asc" | "desc";
  }) {
    const offset = (filters.page - 1) * filters.limit;

    let query = db
      .select({
        id: conversations.id,
        title: conversations.title,
        description: conversations.description,
        scriptGenerationMode: conversations.scriptGenerationMode,
        language: conversations.language,
        difficultyLevel: conversations.difficultyLevel,
        estimatedDurationMinutes: conversations.estimatedDurationMinutes,
        totalTurns: conversations.totalTurns,
        tags: conversations.tags,
        isTemplate: conversations.isTemplate,
        usageCount: conversations.usageCount,
        rating: conversations.rating,
        createdAt: conversations.createdAt,
        updatedAt: conversations.updatedAt,
        documentTitle: documents.title,
      })
      .from(conversations)
      .leftJoin(documents, eq(conversations.documentId, documents.id))
      .where(and(
        eq(conversations.userId, userId),
        isNull(conversations.deletedAt)
      ));

    // Apply filters
    if (filters.search) {
      query = query.where(
        or(
          ilike(conversations.title, `%${filters.search}%`),
          ilike(conversations.description, `%${filters.search}%`)
        )
      );
    }

    if (filters.difficultyLevel) {
      query = query.where(eq(conversations.difficultyLevel, filters.difficultyLevel));
    }

    if (filters.tags && filters.tags.length > 0) {
      query = query.where(
        sql`${conversations.tags} && ${JSON.stringify(filters.tags)}`
      );
    }

    if (filters.isTemplate !== undefined) {
      query = query.where(eq(conversations.isTemplate, filters.isTemplate));
    }

    // Apply sorting
    const sortColumn = conversations[filters.sortBy as keyof typeof conversations];
    if (sortColumn) {
      query = filters.sortOrder === "asc"
        ? query.orderBy(asc(sortColumn))
        : query.orderBy(desc(sortColumn));
    }

    // Get total count
    const totalCountQuery = db
      .select({ count: sql<number>`count(*)` })
      .from(conversations)
      .where(and(
        eq(conversations.userId, userId),
        isNull(conversations.deletedAt)
      ));

    const [{ count: totalCount }] = await totalCountQuery;

    // Get paginated results
    const scriptsList = await query
      .limit(filters.limit)
      .offset(offset);

    return {
      scripts: scriptsList,
      totalCount,
      currentPage: filters.page,
      totalPages: Math.ceil(totalCount / filters.limit),
    };
  }

  async getScriptById(scriptId: string, userId: string) {
    const script = await db
      .select({
        id: conversations.id,
        title: conversations.title,
        description: conversations.description,
        scriptContent: conversations.scriptContent,
        scriptGenerationMode: conversations.scriptGenerationMode,
        language: conversations.language,
        difficultyLevel: conversations.difficultyLevel,
        estimatedDurationMinutes: conversations.estimatedDurationMinutes,
        totalTurns: conversations.totalTurns,
        tags: conversations.tags,
        isTemplate: conversations.isTemplate,
        isPublic: conversations.isPublic,
        usageCount: conversations.usageCount,
        rating: conversations.rating,
        feedback: conversations.feedback,
        createdAt: conversations.createdAt,
        updatedAt: conversations.updatedAt,
        document: {
          id: documents.id,
          title: documents.title,
          originalFilename: documents.originalFilename,
        },
      })
      .from(conversations)
      .leftJoin(documents, eq(conversations.documentId, documents.id))
      .where(and(
        eq(conversations.id, scriptId),
        eq(conversations.userId, userId),
        isNull(conversations.deletedAt)
      ))
      .limit(1);

    return script[0] || null;
  }

  async updateScript(
    scriptId: string,
    userId: string,
    updates: {
      title?: string;
      description?: string;
      scriptContent?: any;
      tags?: string[];
      difficultyLevel?: string;
    }
  ) {
    const [script] = await db
      .update(conversations)
      .set({
        ...updates,
        updatedAt: new Date(),
        totalTurns: updates.scriptContent
          ? this.calculateTotalTurns(updates.scriptContent)
          : undefined,
      })
      .where(and(
        eq(conversations.id, scriptId),
        eq(conversations.userId, userId)
      ))
      .returning();

    return script;
  }

  async deleteScript(scriptId: string, userId: string) {
    const result = await db
      .update(conversations)
      .set({
        deletedAt: new Date(),
        updatedAt: new Date(),
      })
      .where(and(
        eq(conversations.id, scriptId),
        eq(conversations.userId, userId)
      ));

    return result.rowCount > 0;
  }

  async duplicateScript(
    scriptId: string,
    userId: string,
    newTitle: string
  ) {
    const originalScript = await this.getScriptById(scriptId, userId);
    if (!originalScript) {
      return null;
    }

    const [duplicatedScript] = await db.insert(conversations).values({
      userId,
      title: newTitle,
      description: originalScript.description,
      scriptContent: originalScript.scriptContent,
      scriptGenerationMode: originalScript.scriptGenerationMode,
      language: originalScript.language,
      difficultyLevel: originalScript.difficultyLevel,
      estimatedDurationMinutes: originalScript.estimatedDurationMinutes,
      tags: originalScript.tags,
      totalTurns: originalScript.totalTurns,
      status: "ACTIVE",
    }).returning();

    return duplicatedScript;
  }

  async getScriptTemplates(userId: string, filters: {
    category?: string;
    difficultyLevel?: string;
    limit: number;
  }) {
    let query = db
      .select({
        id: conversations.id,
        title: conversations.title,
        description: conversations.description,
        scriptContent: conversations.scriptContent,
        difficultyLevel: conversations.difficultyLevel,
        estimatedDurationMinutes: conversations.estimatedDurationMinutes,
        totalTurns: conversations.totalTurns,
        tags: conversations.tags,
        usageCount: conversations.usageCount,
        rating: conversations.rating,
      })
      .from(conversations)
      .where(and(
        eq(conversations.isTemplate, true),
        eq(conversations.isPublic, true),
        isNull(conversations.deletedAt)
      ));

    if (filters.difficultyLevel) {
      query = query.where(eq(conversations.difficultyLevel, filters.difficultyLevel));
    }

    if (filters.category) {
      query = query.where(
        sql`${conversations.tags} && ${JSON.stringify([filters.category])}`
      );
    }

    return await query
      .orderBy(desc(conversations.usageCount))
      .limit(filters.limit);
  }

  async createFromTemplate(
    templateId: string,
    userId: string,
    customTitle: string,
    customizations?: any
  ) {
    // Get template
    const template = await db
      .select()
      .from(conversations)
      .where(and(
        eq(conversations.id, templateId),
        eq(conversations.isTemplate, true),
        eq(conversations.isPublic, true)
      ))
      .limit(1);

    if (!template[0]) {
      return null;
    }

    const templateData = template[0];

    // Apply customizations if provided
    let scriptContent = templateData.scriptContent;
    if (customizations) {
      scriptContent = this.applyCustomizations(scriptContent, customizations);
    }

    // Create new script from template
    const [script] = await db.insert(conversations).values({
      userId,
      title: customTitle,
      description: `Created from template: ${templateData.title}`,
      scriptContent,
      scriptGenerationMode: "TEMPLATE_BASED",
      language: templateData.language,
      difficultyLevel: templateData.difficultyLevel,
      estimatedDurationMinutes: templateData.estimatedDurationMinutes,
      tags: templateData.tags,
      totalTurns: templateData.totalTurns,
      status: "ACTIVE",
    }).returning();

    return script;
  }

  async getDocument(documentId: string, userId: string) {
    const document = await db
      .select()
      .from(documents)
      .where(and(
        eq(documents.id, documentId),
        eq(documents.userId, userId),
        isNull(documents.deletedAt)
      ))
      .limit(1);

    return document[0] || null;
  }

  private calculateTotalTurns(scriptContent: any): number {
    if (!scriptContent || !scriptContent.dialogue) {
      return 0;
    }

    return Array.isArray(scriptContent.dialogue)
      ? scriptContent.dialogue.length
      : 0;
  }

  private applyCustomizations(scriptContent: any, customizations: any): any {
    // Apply customizations to script content
    // This could include modifying dialogue, adding/removing turns, etc.
    return {
      ...scriptContent,
      ...customizations,
    };
  }
}
```

### Step 2: AI Integration Service

#### 2.1 Script Generation AI Service
```typescript
// apps/api/src/services/ai-integration-service.ts
import { AIGatewayClient } from "./ai-gateway-client";

export class AIIntegrationService {
  private aiClient: AIGatewayClient;

  constructor() {
    this.aiClient = new AIGatewayClient();
  }

  async generateScriptFromDocument(params: {
    content: string;
    title: string;
    difficultyLevel: string;
    targetDurationMinutes: number;
    language: string;
    focusAreas: string[];
    customInstructions?: string;
  }) {
    const prompt = this.buildDocumentPrompt(params);

    try {
      const response = await this.aiClient.generateScript({
        prompt,
        difficultyLevel: params.difficultyLevel,
        targetDurationMinutes: params.targetDurationMinutes,
        language: params.language,
        focusAreas: params.focusAreas,
      });

      return this.parseScriptResponse(response);
    } catch (error) {
      console.error("AI script generation failed:", error);
      throw new Error("Failed to generate script using AI");
    }
  }

  async generateScriptFromTopic(params: {
    topic: string;
    title: string;
    description?: string;
    difficultyLevel: string;
    targetDurationMinutes: number;
    language: string;
    focusAreas: string[];
    customInstructions?: string;
  }) {
    const prompt = this.buildTopicPrompt(params);

    try {
      const response = await this.aiClient.generateScript({
        prompt,
        difficultyLevel: params.difficultyLevel,
        targetDurationMinutes: params.targetDurationMinutes,
        language: params.language,
        focusAreas: params.focusAreas,
      });

      return this.parseScriptResponse(response);
    } catch (error) {
      console.error("AI topic script generation failed:", error);
      throw new Error("Failed to generate script from topic");
    }
  }

  async validateScriptQuality(params: {
    scriptContent: any;
    difficultyLevel: string;
    language: string;
  }) {
    const prompt = this.buildValidationPrompt(params);

    try {
      const response = await this.aiClient.validateScript({
        prompt,
        scriptContent: params.scriptContent,
        difficultyLevel: params.difficultyLevel,
        language: params.language,
      });

      return this.parseValidationResponse(response);
    } catch (error) {
      console.error("Script validation failed:", error);
      throw new Error("Failed to validate script quality");
    }
  }

  private buildDocumentPrompt(params: {
    content: string;
    title: string;
    difficultyLevel: string;
    targetDurationMinutes: number;
    language: string;
    focusAreas: string[];
    customInstructions?: string;
  }): string {
    const focusAreasText = params.focusAreas.join(", ");

    return `
You are an expert English pronunciation teacher and curriculum designer. Create a conversational script for English pronunciation practice based on the provided document.

DOCUMENT:
Title: ${params.title}
Content: ${params.content.substring(0, 2000)}... (truncated for length)

REQUIREMENTS:
- Difficulty Level: ${params.difficultyLevel}
- Target Duration: ${params.targetDurationMinutes} minutes
- Language: ${params.language}
- Focus Areas: ${focusAreasText}
${params.customInstructions ? `Custom Instructions: ${params.customInstructions}` : ""}

Create a natural, engaging conversation between two people (Person A and Person B) that:

1. Incorporates key vocabulary and concepts from the document
2. Provides pronunciation practice relevant to the document's content
3. Uses language appropriate for ${params.difficultyLevel} level
4. Includes pronunciation challenges and teaching moments
5. Has a natural flow and practical context
6. Targets a conversation length of approximately ${params.targetDurationMinutes} minutes

FORMAT the response as JSON:
{
  "title": "Conversation Title",
  "description": "Brief description of the conversation",
  "estimatedDurationMinutes": ${params.targetDurationMinutes},
  "difficultyLevel": "${params.difficultyLevel}",
  "focusAreas": ["${focusAreasText}"],
  "dialogue": [
    {
      "speaker": "Person A",
      "text": "Hello, how are you today?",
      "pronunciationNotes": "Focus on clear 'o' sound in 'hello'",
      "teachingPoints": ["Vowel sounds", "Greetings"],
      "difficulty": "Easy"
    },
    {
      "speaker": "Person B",
      "text": "I'm doing well, thank you!",
      "pronunciationNotes": "Practice the 'th' sound in 'thank'",
      "teachingPoints": ["Consonant clusters", "Expressions"],
      "difficulty": "Easy"
    }
  ],
  "learningObjectives": ["Practice greetings", "Improve vowel clarity"],
  "vocabularyHighlights": ["hello", "thank you", "well"],
  "pronunciationChallenges": ["'th' sound", "vowel length"]
}
`;
  }

  private buildTopicPrompt(params: {
    topic: string;
    title: string;
    description?: string;
    difficultyLevel: string;
    targetDurationMinutes: number;
    language: string;
    focusAreas: string[];
    customInstructions?: string;
  }): string {
    const focusAreasText = params.focusAreas.join(", ");

    return `
You are an expert English pronunciation teacher and curriculum designer. Create a conversational script for English pronunciation practice based on the given topic.

TOPIC: ${params.topic}
${params.description ? `Description: ${params.description}` : ""}

REQUIREMENTS:
- Title: ${params.title}
- Difficulty Level: ${params.difficultyLevel}
- Target Duration: ${params.targetDurationMinutes} minutes
- Language: ${params.language}
- Focus Areas: ${focusAreasText}
${params.customInstructions ? `Custom Instructions: ${params.customInstructions}` : ""}

Create a natural, engaging conversation between two people (Person A and Person B) that:

1. Explores the topic in depth and naturally
2. Provides relevant pronunciation practice opportunities
3. Uses language appropriate for ${params.difficultyLevel} level
4. Includes pronunciation challenges and teaching moments
5. Has practical, real-world context
6. Targets a conversation length of approximately ${params.targetDurationMinutes} minutes

FORMAT the response as JSON following the same structure as the document-based scripts.
Include specific pronunciation challenges relevant to the topic and difficulty level.
`;
  }

  private buildValidationPrompt(params: {
    scriptContent: any;
    difficultyLevel: string;
    language: string;
  }): string {
    return `
You are an expert English pronunciation teacher. Evaluate the quality of this conversation script for ${params.difficultyLevel} level learners.

SCRIPT CONTENT:
${JSON.stringify(params.scriptContent, null, 2)}

Evaluate the script on these criteria:

1. **Language Appropriateness**: Is the language level appropriate for ${params.difficultyLevel}?
2. **Pronunciation Value**: Does the script provide good pronunciation practice?
3. **Natural Flow**: Does the conversation sound natural and realistic?
4. **Educational Value**: Are there clear learning objectives and teaching points?
5. **Engagement**: Is the conversation interesting and engaging?
6. **Structure**: Is the script well-structured and complete?
7. **Accuracy**: Are the pronunciation notes and teaching points accurate?

FORMAT your response as JSON:
{
  "overallScore": 85.5,
  "scores": {
    "languageAppropriateness": 90,
    "pronunciationValue": 80,
    "naturalFlow": 85,
    "educationalValue": 88,
    "engagement": 82,
    "structure": 90,
    "accuracy": 85
  },
  "strengths": [
    "Natural dialogue flow",
    "Good variety of pronunciation challenges",
    "Clear learning objectives"
  ],
  "improvements": [
    "Add more challenging vocabulary",
    "Include specific rhythm exercises",
    "Provide more detailed pronunciation notes"
  ],
  "recommendations": [
    "Consider adding cultural context notes",
    "Include stress pattern indicators",
    "Add more interactive elements"
  ],
  "difficultyAssessment": {
    "actualLevel": "INTERMEDIATE",
    "recommendedAdjustments": "Add some advanced vocabulary for upper-intermediate practice"
  }
}

Provide scores from 0-100 and specific, actionable feedback.
`;
  }

  private parseScriptResponse(response: any): any {
    try {
      // Parse the JSON response from the AI
      if (typeof response === 'string') {
        return JSON.parse(response);
      } else if (response.text) {
        return JSON.parse(response.text);
      } else if (response.data && response.data.text) {
        return JSON.parse(response.data.text);
      } else {
        return response;
      }
    } catch (error) {
      console.error("Failed to parse AI script response:", error);
      // Return a basic structure if parsing fails
      return {
        title: "Generated Script",
        dialogue: response.dialogue || [],
        error: "Failed to parse AI response completely"
      };
    }
  }

  private parseValidationResponse(response: any): any {
    try {
      if (typeof response === 'string') {
        return JSON.parse(response);
      } else if (response.text) {
        return JSON.parse(response.text);
      } else if (response.data && response.data.text) {
        return JSON.parse(response.data.text);
      } else {
        return response;
      }
    } catch (error) {
      console.error("Failed to parse AI validation response:", error);
      return {
        overallScore: 70,
        scores: {},
        strengths: [],
        improvements: ["Could not parse validation response"],
        recommendations: []
      };
    }
  }
}
```

### Step 3: Frontend Script Management UI

#### 3.1 Script Generation Form
```typescript
// apps/app/src/components/scripts/ScriptGenerationForm.tsx
import React, { useState } from "react";
import { useForm } from "react-hook-form";
import { Button } from "@repo/ui/components/button";
import { Input } from "@repo/ui/components/input";
import { Textarea } from "@repo/ui/components/textarea";
import { Card, CardContent, CardHeader, CardTitle } from "@repo/ui/components/card";
import { Badge } from "@repo/ui/components/badge";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@repo/ui/components/select";
import { Checkbox } from "@repo/ui/components/checkbox";
import { Loader2, Wand2, FileText, Tag } from "lucide-react";
import { trpc } from "../../utils/trpc";

interface ScriptGenerationFormProps {
  documentId?: string;
  onSuccess?: (script: any) => void;
}

export const ScriptGenerationForm: React.FC<ScriptGenerationFormProps> = ({
  documentId,
  onSuccess
}) => {
  const [generationMode, setGenerationMode] = useState<"document" | "topic">("document");
  const [selectedFocusAreas, setSelectedFocusAreas] = useState<string[]>(["PRONUNCIATION"]);
  const [isGenerating, setIsGenerating] = useState(false);

  const { register, handleSubmit, watch, setValue, formState: { errors } } = useForm({
    defaultValues: {
      difficultyLevel: "INTERMEDIATE",
      targetDurationMinutes: 10,
      language: "en",
      customInstructions: "",
      topic: "",
      title: "",
      description: "",
      tags: [],
    }
  });

  const generateFromDocumentMutation = trpc.scripts.generateFromDocument.useMutation();
  const generateFromTopicMutation = trpc.scripts.generateFromTopic.useMutation();

  const difficultyLevel = watch("difficultyLevel");
  const targetDurationMinutes = watch("targetDurationMinutes");

  const focusAreaOptions = [
    { id: "PRONUNCIATION", label: "Pronunciation", description: "Sound accuracy and clarity" },
    { id: "FLUENCY", label: "Fluency", description: "Smooth speech flow and rhythm" },
    { id: "RHYTHM", label: "Rhythm", description: "Stress and intonation patterns" },
    { id: "INTONATION", label: "Intonation", description: "Melody and pitch variation" },
  ];

  const handleFocusAreaToggle = (areaId: string) => {
    setSelectedFocusAreas(prev =>
      prev.includes(areaId)
        ? prev.filter(id => id !== areaId)
        : [...prev, areaId]
    );
  };

  const onSubmit = async (data: any) => {
    try {
      setIsGenerating(true);

      let result;
      if (generationMode === "document" && documentId) {
        result = await generateFromDocumentMutation.mutateAsync({
          documentId,
          difficultyLevel: data.difficultyLevel,
          targetDurationMinutes: data.targetDurationMinutes,
          language: data.language,
          focusAreas: selectedFocusAreas,
          customInstructions: data.customInstructions,
        });
      } else {
        result = await generateFromTopicMutation.mutateAsync({
          topic: data.topic,
          title: data.title,
          description: data.description,
          difficultyLevel: data.difficultyLevel,
          targetDurationMinutes: data.targetDurationMinutes,
          language: data.language,
          focusAreas: selectedFocusAreas,
          tags: data.tags,
          customInstructions: data.customInstructions,
        });
      }

      onSuccess?.(result.script);

      // Reset form
      setSelectedFocusAreas(["PRONUNCIATION"]);

    } catch (error) {
      console.error("Script generation failed:", error);
    } finally {
      setIsGenerating(false);
    }
  };

  return (
    <Card className="w-full max-w-4xl mx-auto">
      <CardHeader>
        <CardTitle className="flex items-center space-x-2">
          <Wand2 className="h-5 w-5" />
          <span>Generate Script</span>
        </CardTitle>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
          {/* Generation Mode Selection */}
          <div>
            <label className="block text-sm font-medium mb-2">Generation Mode</label>
            <div className="grid grid-cols-2 gap-4">
              <Button
                type="button"
                variant={generationMode === "document" ? "default" : "outline"}
                className="flex items-center space-x-2"
                onClick={() => setGenerationMode("document")}
                disabled={!documentId}
              >
                <FileText className="h-4 w-4" />
                <span>From Document</span>
              </Button>
              <Button
                type="button"
                variant={generationMode === "topic" ? "default" : "outline"}
                className="flex items-center space-x-2"
                onClick={() => setGenerationMode("topic")}
              >
                <Tag className="h-4 w-4" />
                <span>From Topic</span>
              </Button>
            </div>
          </div>

          {/* Document-based inputs */}
          {generationMode === "document" && documentId && (
            <div className="p-4 bg-blue-50 rounded-lg">
              <p className="text-sm text-blue-800">
                Generating script based on the selected document.
              </p>
            </div>
          )}

          {/* Topic-based inputs */}
          {generationMode === "topic" && (
            <div className="space-y-4">
              <div>
                <label htmlFor="topic" className="block text-sm font-medium mb-1">
                  Topic *
                </label>
                <Textarea
                  id="topic"
                  placeholder="Describe the topic for the conversation script..."
                  {...register("topic", { required: "Topic is required" })}
                  rows={3}
                />
                {errors.topic && (
                  <p className="text-red-600 text-sm mt-1">{errors.topic.message}</p>
                )}
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label htmlFor="title" className="block text-sm font-medium mb-1">
                    Script Title *
                  </label>
                  <Input
                    id="title"
                    placeholder="Enter script title"
                    {...register("title", { required: "Title is required" })}
                  />
                  {errors.title && (
                    <p className="text-red-600 text-sm mt-1">{errors.title.message}</p>
                  )}
                </div>

                <div>
                  <label htmlFor="description" className="block text-sm font-medium mb-1">
                    Description
                  </label>
                  <Input
                    id="description"
                    placeholder="Brief description of the script"
                    {...register("description")}
                  />
                </div>
              </div>
            </div>
          )}

          {/* Configuration Options */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label htmlFor="difficultyLevel" className="block text-sm font-medium mb-1">
                Difficulty Level
              </label>
              <Select value={difficultyLevel} onValueChange={(value) => setValue("difficultyLevel", value)}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="BEGINNER">Beginner</SelectItem>
                  <SelectItem value="INTERMEDIATE">Intermediate</SelectItem>
                  <SelectItem value="ADVANCED">Advanced</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div>
              <label htmlFor="targetDuration" className="block text-sm font-medium mb-1">
                Target Duration (minutes)
              </label>
              <Input
                id="targetDuration"
                type="number"
                min="5"
                max="30"
                {...register("targetDurationMinutes", {
                  valueAsNumber: true,
                  min: 5,
                  max: 30
                })}
              />
            </div>

            <div>
              <label htmlFor="language" className="block text-sm font-medium mb-1">
                Language
              </label>
              <Select value={watch("language")} onValueChange={(value) => setValue("language", value)}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="en">English</SelectItem>
                  <SelectItem value="es">Spanish</SelectItem>
                  <SelectItem value="fr">French</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>

          {/* Focus Areas */}
          <div>
            <label className="block text-sm font-medium mb-2">Focus Areas</label>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              {focusAreaOptions.map((area) => (
                <div key={area.id} className="flex items-start space-x-2">
                  <Checkbox
                    id={area.id}
                    checked={selectedFocusAreas.includes(area.id)}
                    onCheckedChange={() => handleFocusAreaToggle(area.id)}
                  />
                  <div className="flex-1">
                    <label htmlFor={area.id} className="text-sm font-medium cursor-pointer">
                      {area.label}
                    </label>
                    <p className="text-xs text-gray-500">{area.description}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Custom Instructions */}
          <div>
            <label htmlFor="customInstructions" className="block text-sm font-medium mb-1">
              Custom Instructions (optional)
            </label>
            <Textarea
              id="customInstructions"
              placeholder="Any specific requirements or preferences for the script..."
              {...register("customInstructions")}
              rows={3}
            />
          </div>

          {/* Preview Settings */}
          <div className="p-4 bg-gray-50 rounded-lg">
            <h4 className="font-medium mb-2">Script Preview</h4>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
              <div>
                <span className="text-gray-600">Level:</span>
                <Badge variant="secondary" className="ml-1">{difficultyLevel}</Badge>
              </div>
              <div>
                <span className="text-gray-600">Duration:</span>
                <span className="ml-1">{targetDurationMinutes} min</span>
              </div>
              <div>
                <span className="text-gray-600">Language:</span>
                <span className="ml-1">{watch("language")?.toUpperCase()}</span>
              </div>
              <div>
                <span className="text-gray-600">Focus:</span>
                <span className="ml-1">{selectedFocusAreas.length} areas</span>
              </div>
            </div>
          </div>

          {/* Submit Button */}
          <Button
            type="submit"
            className="w-full"
            disabled={isGenerating || (generationMode === "document" && !documentId)}
          >
            {isGenerating ? (
              <>
                <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                Generating Script...
              </>
            ) : (
              <>
                <Wand2 className="h-4 w-4 mr-2" />
                Generate Script
              </>
            )}
          </Button>

          {/* Error Display */}
          {(generateFromDocumentMutation.error || generateFromTopicMutation.error) && (
            <div className="p-3 bg-red-50 border border-red-200 rounded-lg">
              <p className="text-red-800 text-sm">
                {generateFromDocumentMutation.error?.message ||
                 generateFromTopicMutation.error?.message}
              </p>
            </div>
          )}
        </form>
      </CardContent>
    </Card>
  );
};
```

## Testing Strategy

### Script Generation Tests
```typescript
// apps/api/src/__tests__/script-generation.test.ts
import { describe, it, expect, beforeEach } from "vitest";
import { ScriptService } from "../services/script-service";
import { AIIntegrationService } from "../services/ai-integration-service";

describe("Script Generation", () => {
  let scriptService: ScriptService;
  let aiService: AIIntegrationService;

  beforeEach(() => {
    scriptService = new ScriptService();
    aiService = new AIIntegrationService();
  });

  it("should create script from document", async () => {
    // Mock document content
    const mockDocument = {
      id: "test-doc-id",
      content: "This is a test document about renewable energy.",
      title: "Renewable Energy Guide",
    };

    // Mock AI response
    const mockAIResponse = {
      title: "Renewable Energy Conversation",
      dialogue: [
        {
          speaker: "Person A",
          text: "What do you think about renewable energy?",
          pronunciationNotes: "Focus on 'renewable' syllable stress"
        }
      ]
    };

    const script = await scriptService.createScript({
      userId: "test-user",
      title: "Generated Script",
      scriptContent: mockAIResponse,
      scriptGenerationMode: "DOCUMENT_BASED",
      language: "en",
      difficultyLevel: "INTERMEDIATE",
      estimatedDurationMinutes: 10,
      documentId: mockDocument.id,
    });

    expect(script).toBeDefined();
    expect(script.title).toBe("Generated Script");
    expect(script.scriptGenerationMode).toBe("DOCUMENT_BASED");
  });

  it("should generate script from topic", async () => {
    const topic = "Climate Change Discussion";

    const scriptContent = await aiService.generateScriptFromTopic({
      topic,
      title: "Climate Change Conversation",
      difficultyLevel: "INTERMEDIATE",
      targetDurationMinutes: 10,
      language: "en",
      focusAreas: ["PRONUNCIATION", "FLUENCY"],
    });

    expect(scriptContent).toHaveProperty("dialogue");
    expect(scriptContent.dialogue).toBeInstanceOf(Array);
    expect(scriptContent.dialogue.length).toBeGreaterThan(0);
  });
});
```

## Estimated Timeline: 1 Week

### Day 1-2: Backend Script Generation
- Create script generation tRPC endpoints
- Implement AI integration service
- Build script management service

### Day 3-4: Script Templates and Validation
- Add script template system
- Implement script quality validation
- Create script versioning and history

### Day 5: Frontend UI
- Build script generation form
- Create script management interface
- Add script editing and customization

## Success Criteria

- [ ] Document-based script generation working
- [ ] Topic-based script generation functional
- [ ] Script templates available
- [ ] Script quality validation operational
- [ ] Script editing and customization working
- [ ] Script metadata and organization complete
- [ ] Script versioning implemented
- [ ] Script search and filtering working
- [ ] Script duplication functionality
- [ ] Focus area customization working
- [ ] Difficulty level enforcement
- [ ] All script CRUD operations tested

This script generation system provides comprehensive AI-powered content creation with extensive customization options and quality validation to ensure effective pronunciation practice materials.