# Stage 9: Admin Dashboard Extensions

## Stage Overview

This stage implements the comprehensive admin dashboard that extends the React Starter Kit's admin functionality with pronunciation assistant-specific features. The dashboard includes user management, AI provider configuration, system monitoring, analytics, and content moderation.

## Observable Outcomes

- ✅ Enhanced admin interface for pronunciation features
- ✅ User management with detailed analytics
- ✅ AI provider configuration dashboard
- ✅ System health monitoring and status
- ✅ Usage analytics and reporting
- ✅ Content moderation tools
- ✅ Performance monitoring and optimization
- ✅ Backup and restore functionality

## Technical Requirements

### Admin Features
- User management and analytics
- AI provider configuration and monitoring
- System health and performance monitoring
- Usage statistics and reporting
- Content moderation and approval
- Backup and disaster recovery
- Security audit logs
- System configuration management

### Analytics & Monitoring
- Real-time usage metrics
- User behavior analytics
- AI service performance tracking
- Cost analysis and optimization
- Error rate monitoring
- System resource utilization
- Custom report generation

### Security & Compliance
- Access control and permissions
- Audit logging and tracking
- Data privacy controls
- Security vulnerability scanning
- Compliance reporting
- User data management

## Implementation Details

### Step 1: Admin Dashboard Router

#### 1.1 Admin tRPC Router
```typescript
// apps/api/src/router/admin.ts
import { router, protectedProcedure } from "./trpc";
import { z } from "zod";
import { TRPCError } from "@trpc/server";
import { enforceAdmin } from "../middleware/auth";
import { AdminService } from "../services/admin-service";
import { AnalyticsService } from "../services/analytics-service";
import { SystemMonitorService } from "../services/system-monitor-service";

export const adminRouter = router({
  // User Management
  getUsers: protectedProcedure
    .use(enforceAdmin)
    .input(z.object({
      page: z.number().min(1).default(1),
      limit: z.number().min(1).max(100).default(20),
      search: z.string().optional(),
      status: z.enum(["ACTIVE", "INACTIVE", "SUSPENDED"]).optional(),
      role: z.enum(["USER", "ADMIN"]).optional(),
      sortBy: z.enum(["createdAt", "lastLogin", "usageCount"]).default("createdAt"),
      sortOrder: z.enum(["asc", "desc"]).default("desc"),
    }))
    .query(async ({ input }) => {
      const adminService = new AdminService();
      return await adminService.getUsers(input);
    }),

  getUserDetails: protectedProcedure
    .use(enforceAdmin)
    .input(z.object({ userId: z.string().uuid() }))
    .query(async ({ input }) => {
      const adminService = new AdminService();
      const user = await adminService.getUserDetails(input.userId);

      if (!user) {
        throw new TRPCError({
          code: "NOT_FOUND",
          message: "User not found",
        });
      }

      return user;
    }),

  updateUserRole: protectedProcedure
    .use(enforceAdmin)
    .input(z.object({
      userId: z.string().uuid(),
      role: z.enum(["USER", "ADMIN"]),
    }))
    .mutation(async ({ input }) => {
      const adminService = new AdminService();
      const success = await adminService.updateUserRole(input.userId, input.role);

      if (!success) {
        throw new TRPCError({
          code: "NOT_FOUND",
          message: "User not found",
        });
      }

      return { success: true };
    }),

  suspendUser: protectedProcedure
    .use(enforceAdmin)
    .input(z.object({
      userId: z.string().uuid(),
      reason: z.string().min(1),
      duration: z.number().min(1).max(365), // days
    }))
    .mutation(async ({ input }) => {
      const adminService = new AdminService();
      const success = await adminService.suspendUser(
        input.userId,
        input.reason,
        input.duration
      );

      return { success };
    }),

  // AI Provider Management
  getAIProviders: protectedProcedure
    .use(enforceAdmin)
    .query(async () => {
      const adminService = new AdminService();
      return await adminService.getAIProviders();
    }),

  updateAIProviderConfig: protectedProcedure
    .use(enforceAdmin)
    .input(z.object({
      providerId: z.string().uuid(),
      serviceType: z.enum(["TTS", "STT", "LLM"]),
      configuration: z.any(),
      isActive: z.boolean(),
      priority: z.number().min(1).max(10),
    }))
    .mutation(async ({ input }) => {
      const adminService = new AdminService();
      return await adminService.updateAIProviderConfig(input);
    }),

  testAIProvider: protectedProcedure
    .use(enforceAdmin)
    .input(z.object({
      providerId: z.string().uuid(),
      serviceType: z.enum(["TTS", "STT", "LLM"]),
      testInput: z.string(),
    }))
    .mutation(async ({ input }) => {
      const adminService = new AdminService();
      return await adminService.testAIProvider(input);
    }),

  // System Monitoring
  getSystemHealth: protectedProcedure
    .use(enforceAdmin)
    .query(async () => {
      const systemMonitor = new SystemMonitorService();
      return await systemMonitor.getSystemHealth();
    }),

  getSystemMetrics: protectedProcedure
    .use(enforceAdmin)
    .input(z.object({
      timeRange: z.enum(["1h", "24h", "7d", "30d"]).default("24h"),
    }))
    .query(async ({ input }) => {
      const systemMonitor = new SystemMonitorService();
      return await systemMonitor.getSystemMetrics(input.timeRange);
    }),

  // Analytics
  getUsageAnalytics: protectedProcedure
    .use(enforceAdmin)
    .input(z.object({
      timeRange: z.enum(["7d", "30d", "90d"]).default("30d"),
      groupBy: z.enum(["day", "week", "month"]).default("day"),
    }))
    .query(async ({ input }) => {
      const analyticsService = new AnalyticsService();
      return await analyticsService.getUsageAnalytics(input.timeRange, input.groupBy);
    }),

  getUserAnalytics: protectedProcedure
    .use(enforceAdmin)
    .input(z.object({
      timeRange: z.enum(["7d", "30d", "90d"]).default("30d"),
    }))
    .query(async ({ input }) => {
      const analyticsService = new AnalyticsService();
      return await analyticsService.getUserAnalytics(input.timeRange);
    }),

  getCostAnalytics: protectedProcedure
    .use(enforceAdmin)
    .input(z.object({
      timeRange: z.enum(["7d", "30d", "90d"]).default("30d"),
    }))
    .query(async ({ input }) => {
      const analyticsService = new AnalyticsService();
      return await analyticsService.getCostAnalytics(input.timeRange);
    }),

  // Content Moderation
  getPendingContent: protectedProcedure
    .use(enforceAdmin)
    .input(z.object({
      contentType: z.enum(["SCRIPTS", "DOCUMENTS"]).default("SCRIPTS"),
      page: z.number().min(1).default(1),
      limit: z.number().min(1).max(50).default(20),
    }))
    .query(async ({ input }) => {
      const adminService = new AdminService();
      return await adminService.getPendingContent(input.contentType, input.page, input.limit);
    }),

  approveContent: protectedProcedure
    .use(enforceAdmin)
    .input(z.object({
      contentId: z.string().uuid(),
      contentType: z.enum(["SCRIPTS", "DOCUMENTS"]),
    }))
    .mutation(async ({ input }) => {
      const adminService = new AdminService();
      return await adminService.approveContent(input.contentId, input.contentType);
    }),

  rejectContent: protectedProcedure
    .use(enforceAdmin)
    .input(z.object({
      contentId: z.string().uuid(),
      contentType: z.enum(["SCRIPTS", "DOCUMENTS"]),
      reason: z.string().min(1),
    }))
    .mutation(async ({ input }) => {
      const adminService = new AdminService();
      return await adminService.rejectContent(input.contentId, input.contentType, input.reason);
    }),

  // System Configuration
  getSystemSettings: protectedProcedure
    .use(enforceAdmin)
    .query(async () => {
      const adminService = new AdminService();
      return await adminService.getSystemSettings();
    }),

  updateSystemSettings: protectedProcedure
    .use(enforceAdmin)
    .input(z.object({
      settings: z.record(z.any()),
    }))
    .mutation(async ({ input }) => {
      const adminService = new AdminService();
      return await adminService.updateSystemSettings(input.settings);
    }),

  // Backup and Restore
  createBackup: protectedProcedure
    .use(enforceAdmin)
    .input(z.object({
      includeUserData: z.boolean().default(true),
      includeAudioFiles: z.boolean().default(false),
    }))
    .mutation(async ({ input }) => {
      const adminService = new AdminService();
      return await adminService.createBackup(input);
    }),

  restoreBackup: protectedProcedure
    .use(enforceAdmin)
    .input(z.object({
      backupId: z.string().uuid(),
      confirmRestore: z.boolean(),
    }))
    .mutation(async ({ input }) => {
      if (!input.confirmRestore) {
        throw new TRPCError({
          code: "BAD_REQUEST",
          message: "Restore confirmation required",
        });
      }

      const adminService = new AdminService();
      return await adminService.restoreBackup(input.backupId);
    }),
});
```

#### 1.2 Admin Service Implementation
```typescript
// apps/api/src/services/admin-service.ts
import { db } from "@repo/database";
import {
  users,
  aiProviders,
  aiProviderConfigs,
  documents,
  conversations,
  systemSettings,
  apiUsageLogs
} from "@repo/database/src/schema";
import { eq, and, isNull, desc, asc, sql, ilike } from "drizzle-orm";
import { AIGatewayClient } from "./ai-gateway-client";

export class AdminService {
  private aiClient: AIGatewayClient;

  constructor() {
    this.aiClient = new AIGatewayClient();
  }

  // User Management
  async getUsers(filters: {
    page: number;
    limit: number;
    search?: string;
    status?: string;
    role?: string;
    sortBy: string;
    sortOrder: "asc" | "desc";
  }) {
    const offset = (filters.page - 1) * filters.limit;

    let query = db
      .select({
        id: users.id,
        email: users.email,
        name: users.name,
        role: users.role,
        emailVerified: users.emailVerified,
        createdAt: users.createdAt,
        lastLogin: users.lastLogin,
        loginCount: users.loginCount,
        subscriptionTier: users.subscriptionTier,
        apiUsageQuota: users.apiUsageQuota,
        apiUsageCurrent: users.apiUsageCurrent,
        documentCount: sql<number>`(
          SELECT COUNT(*) FROM documents
          WHERE documents.user_id = users.id AND documents.deleted_at IS NULL
        )`.as("documentCount"),
        conversationCount: sql<number>`(
          SELECT COUNT(*) FROM conversation_sessions
          WHERE conversation_sessions.user_id = users.id
        )`.as("conversationCount"),
        totalUsage: sql<number>`(
          SELECT COALESCE(SUM(cost), 0) FROM api_usage_logs
          WHERE api_usage_logs.user_id = users.id
        )`.as("totalUsage"),
      })
      .from(users);

    // Apply filters
    if (filters.search) {
      query = query.where(
        or(
          ilike(users.email, `%${filters.search}%`),
          ilike(users.name, `%${filters.search}%`)
        )
      );
    }

    if (filters.role) {
      query = query.where(eq(users.role, filters.role));
    }

    // Apply sorting
    const sortColumn = users[filters.sortBy as keyof typeof users];
    if (sortColumn) {
      query = filters.sortOrder === "asc"
        ? query.orderBy(asc(sortColumn))
        : query.orderBy(desc(sortColumn));
    }

    // Get total count
    const totalCountQuery = db
      .select({ count: sql<number>`count(*)` })
      .from(users);

    const [{ count: totalCount }] = await totalCountQuery;

    // Get paginated results
    const usersList = await query
      .limit(filters.limit)
      .offset(offset);

    return {
      users: usersList,
      totalCount,
      currentPage: filters.page,
      totalPages: Math.ceil(totalCount / filters.limit),
    };
  }

  async getUserDetails(userId: string) {
    const userDetails = await db
      .select({
        user: {
          id: users.id,
          email: users.email,
          name: users.name,
          role: users.role,
          avatarUrl: users.avatarUrl,
          emailVerified: users.emailVerified,
          createdAt: users.createdAt,
          lastLogin: users.lastLogin,
          loginCount: users.loginCount,
          subscriptionTier: users.subscriptionTier,
          subscriptionExpires: users.subscriptionExpires,
          apiUsageQuota: users.apiUsageQuota,
          apiUsageCurrent: users.apiUsageCurrent,
          preferences: users.preferences,
        },
        documentCount: sql<number>`(
          SELECT COUNT(*) FROM documents
          WHERE documents.user_id = ${userId} AND documents.deleted_at IS NULL
        )`.as("documentCount"),
        conversationCount: sql<number>`(
          SELECT COUNT(*) FROM conversation_sessions
          WHERE conversation_sessions.user_id = ${userId}
        )`.as("conversationCount"),
        totalRecordingTime: sql<number>`(
          SELECT COALESCE(SUM(duration_seconds), 0) FROM audio_recordings
          WHERE audio_recordings.user_id = ${userId}
        )`.as("totalRecordingTime"),
        averageScore: sql<number>`(
          SELECT COALESCE(AVG(overall_score), 0) FROM conversation_sessions
          WHERE conversation_sessions.user_id = ${userId}
          AND conversation_sessions.overall_score IS NOT NULL
        )`.as("averageScore"),
      })
      .from(users)
      .where(eq(users.id, userId))
      .limit(1);

    if (!userDetails[0]) {
      return null;
    }

    // Get recent activity
    const recentActivity = await db
      .select({
        type: sql<string>`CASE
          WHEN documents.id IS NOT NULL THEN 'document_upload'
          WHEN conversation_sessions.id IS NOT NULL THEN 'conversation_session'
          ELSE 'unknown'
        END`.as("type"),
        id: sql<string>`COALESCE(documents.id::text, conversation_sessions.id::text)`.as("id"),
        title: sql<string>`COALESCE(documents.title, conversations.title)`.as("title"),
        createdAt: sql<Date>`COALESCE(documents.created_at, conversation_sessions.started_at)`.as("createdAt"),
      })
      .from(users)
      .leftJoin(documents, eq(users.id, documents.userId))
      .leftJoin(conversations, eq(users.id, conversations.userId))
      .leftJoin(
        conversationSessions,
        eq(conversations.id, conversationSessions.conversationId)
      )
      .where(eq(users.id, userId))
      .orderBy(desc(sql`COALESCE(documents.created_at, conversation_sessions.started_at)`))
      .limit(10);

    // Get usage statistics
    const usageStats = await db
      .select({
        date: sql<Date>`DATE(created_at)`.as("date"),
        usageCount: sql<number>`COUNT(*)`.as("usageCount"),
        totalCost: sql<number>`COALESCE(SUM(cost), 0)`.as("totalCost"),
      })
      .from(apiUsageLogs)
      .where(eq(apiUsageLogs.userId, userId))
      .groupBy(sql`DATE(created_at)`)
      .orderBy(desc(sql`DATE(created_at)`))
      .limit(30);

    return {
      ...userDetails[0],
      recentActivity,
      usageStats,
    };
  }

  async updateUserRole(userId: string, newRole: "USER" | "ADMIN") {
    const result = await db
      .update(users)
      .set({
        role: newRole,
        updatedAt: new Date(),
      })
      .where(eq(users.id, userId));

    return result.rowCount > 0;
  }

  async suspendUser(userId: string, reason: string, durationDays: number) {
    const suspensionEnds = new Date();
    suspensionEnds.setDate(suspensionEnds.getDate() + durationDays);

    const result = await db
      .update(users)
      .set({
        role: "SUSPENDED",
        updatedAt: new Date(),
        // Note: You might want to add a suspension_end_date field to the users table
      })
      .where(eq(users.id, userId));

    // Log the suspension
    await this.logAdminAction("USER_SUSPENDED", {
      userId,
      reason,
      durationDays,
      suspensionEnds,
    });

    return result.rowCount > 0;
  }

  // AI Provider Management
  async getAIProviders() {
    const providers = await db.query.aiProviders.findMany({
      orderBy: asc(aiProviders.name),
    });

    const configs = await db.query.aiProviderConfigs.findMany();

    // Group configs by provider
    const providerConfigs = configs.reduce((acc, config) => {
      if (!acc[config.providerId]) {
        acc[config.providerId] = [];
      }
      acc[config.providerId].push(config);
      return acc;
    }, {} as Record<string, any[]>);

    return providers.map(provider => ({
      ...provider,
      configs: providerConfigs[provider.id] || [],
    }));
  }

  async updateAIProviderConfig(data: {
    providerId: string;
    serviceType: string;
    configuration: any;
    isActive: boolean;
    priority: number;
  }) {
    // Check if config exists
    const existingConfig = await db.query.aiProviderConfigs.findFirst({
      where: and(
        eq(aiProviderConfigs.providerId, data.providerId),
        eq(aiProviderConfigs.serviceType, data.serviceType)
      ),
    });

    if (existingConfig) {
      // Update existing config
      await db
        .update(aiProviderConfigs)
        .set({
          configuration: data.configuration,
          isActive: data.isActive,
          priority: data.priority,
          updatedAt: new Date(),
        })
        .where(eq(aiProviderConfigs.id, existingConfig.id));
    } else {
      // Create new config
      await db.insert(aiProviderConfigs).values({
        providerId: data.providerId,
        serviceType: data.serviceType,
        configuration: data.configuration,
        isActive: data.isActive,
        priority: data.priority,
      });
    }

    await this.logAdminAction("AI_PROVIDER_CONFIG_UPDATED", {
      providerId: data.providerId,
      serviceType: data.serviceType,
      isActive: data.isActive,
    });

    return { success: true };
  }

  async testAIProvider(data: {
    providerId: string;
    serviceType: string;
    testInput: string;
  }) {
    try {
      let result;

      switch (data.serviceType) {
        case "TTS":
          result = await this.aiClient.textToSpeech(data.testInput);
          break;
        case "STT":
          // For STT, we'd need actual audio data
          result = { message: "STT test requires audio data" };
          break;
        case "LLM":
          result = await this.aiClient.generateScript({
            prompt: data.testInput,
            difficultyLevel: "INTERMEDIATE",
            targetDurationMinutes: 5,
            language: "en",
            focusAreas: ["PRONUNCIATION"],
          });
          break;
        default:
          throw new Error(`Unknown service type: ${data.serviceType}`);
      }

      return {
        success: true,
        result,
        testedAt: new Date(),
      };

    } catch (error) {
      return {
        success: false,
        error: error instanceof Error ? error.message : "Test failed",
        testedAt: new Date(),
      };
    }
  }

  // Content Moderation
  async getPendingContent(contentType: "SCRIPTS" | "DOCUMENTS", page: number, limit: number) {
    const offset = (page - 1) * limit;

    let query;

    if (contentType === "SCRIPTS") {
      query = db
        .select()
        .from(conversations)
        .where(and(
          eq(conversations.isTemplate, true),
          eq(conversations.isPublic, false) // Pending approval
        ))
        .orderBy(desc(conversations.createdAt));
    } else {
      query = db
        .select()
        .from(documents)
        .where(and(
          eq(documents.isPublic, false), // Pending approval
          eq(documents.status, "READY")
        ))
        .orderBy(desc(documents.createdAt));
    }

    const content = await query
      .limit(limit)
      .offset(offset);

    // Get total count
    const totalCountQuery = contentType === "SCRIPTS"
      ? db
          .select({ count: sql<number>`count(*)` })
          .from(conversations)
          .where(and(
            eq(conversations.isTemplate, true),
            eq(conversations.isPublic, false)
          ))
      : db
          .select({ count: sql<number>`count(*)` })
          .from(documents)
          .where(and(
            eq(documents.isPublic, false),
            eq(documents.status, "READY")
          ));

    const [{ count: totalCount }] = await totalCountQuery;

    return {
      content,
      totalCount,
      currentPage: page,
      totalPages: Math.ceil(totalCount / limit),
    };
  }

  async approveContent(contentId: string, contentType: "SCRIPTS" | "DOCUMENTS") {
    if (contentType === "SCRIPTS") {
      await db
        .update(conversations)
        .set({
          isPublic: true,
          updatedAt: new Date(),
        })
        .where(eq(conversations.id, contentId));
    } else {
      await db
        .update(documents)
        .set({
          isPublic: true,
          updatedAt: new Date(),
        })
        .where(eq(documents.id, contentId));
    }

    await this.logAdminAction("CONTENT_APPROVED", {
      contentId,
      contentType,
    });

    return { success: true };
  }

  async rejectContent(contentId: string, contentType: "SCRIPTS" | "DOCUMENTS", reason: string) {
    if (contentType === "SCRIPTS") {
      await db
        .update(conversations)
        .set({
          isTemplate: false, // Remove from template consideration
          updatedAt: new Date(),
        })
        .where(eq(conversations.id, contentId));
    } else {
      await db
        .update(documents)
        .set({
          status: "ERROR",
          processingError: `Rejected by admin: ${reason}`,
          updatedAt: new Date(),
        })
        .where(eq(documents.id, contentId));
    }

    await this.logAdminAction("CONTENT_REJECTED", {
      contentId,
      contentType,
      reason,
    });

    return { success: true };
  }

  // System Settings
  async getSystemSettings() {
    return await db.query.systemSettings.findMany({
      orderBy: asc(systemSettings.category),
    });
  }

  async updateSystemSettings(settings: Record<string, any>) {
    const updatePromises = Object.entries(settings).map(([key, value]) =>
      db
        .update(systemSettings)
        .set({
          value,
          updatedAt: new Date(),
        })
        .where(eq(systemSettings.key, key))
    );

    await Promise.all(updatePromises);

    await this.logAdminAction("SYSTEM_SETTINGS_UPDATED", {
      updatedKeys: Object.keys(settings),
    });

    return { success: true };
  }

  // Backup and Restore
  async createBackup(options: {
    includeUserData: boolean;
    includeAudioFiles: boolean;
  }) {
    // This is a simplified implementation
    // In production, you'd want to:
    // 1. Create database dump
    // 2. Backup file storage if requested
    // 3. Store backup in secure location
    // 4. Create backup record in database

    const backupId = `backup_${Date.now()}`;

    await this.logAdminAction("BACKUP_CREATED", {
      backupId,
      options,
    });

    return {
      backupId,
      createdAt: new Date(),
      size: 0, // Would be calculated from actual backup
      includesUserData: options.includeUserData,
      includesAudioFiles: options.includeAudioFiles,
    };
  }

  async restoreBackup(backupId: string) {
    // This is a simplified implementation
    // In production, you'd want to:
    // 1. Validate backup integrity
    // 2. Create system restore point
    // 3. Restore database from backup
    // 4. Restore files if included
    // 5. Verify restore integrity

    await this.logAdminAction("BACKUP_RESTORED", {
      backupId,
    });

    return { success: true };
  }

  private async logAdminAction(action: string, details: any) {
    // Log admin actions for audit trail
    console.log(`Admin action: ${action}`, {
      timestamp: new Date(),
      details,
    });

    // In production, you'd store this in a dedicated admin_logs table
  }
}
```

### Step 2: Frontend Admin Dashboard Components

#### 2.1 Admin Dashboard Layout
```typescript
// apps/app/src/pages/admin/Dashboard.tsx
import React, { useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@repo/ui/components/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@repo/ui/components/tabs";
import { Badge } from "@repo/ui/components/badge";
import {
  Users,
  FileText,
  Settings,
  Activity,
  DollarSign,
  Shield,
  Database,
  Cpu,
  TrendingUp,
  AlertTriangle
} from "lucide-react";
import { ProtectedRoute } from "../../components/auth/ProtectedRoute";
import { UserManagement } from "../../components/admin/UserManagement";
import { AIProviderConfig } from "../../components/admin/AIProviderConfig";
import { SystemHealth } from "../../components/admin/SystemHealth";
import { UsageAnalytics } from "../../components/admin/UsageAnalytics";
import { ContentModeration } from "../../components/admin/ContentModeration";

export const AdminDashboard: React.FC = () => {
  const [activeTab, setActiveTab] = useState("overview");

  return (
    <ProtectedRoute adminOnly>
      <div className="min-h-screen bg-gray-50">
        {/* Header */}
        <div className="bg-white shadow-sm border-b">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="flex items-center justify-between h-16">
              <div className="flex items-center space-x-3">
                <Shield className="h-8 w-8 text-blue-600" />
                <h1 className="text-xl font-semibold text-gray-900">
                  Admin Dashboard
                </h1>
              </div>
              <div className="flex items-center space-x-4">
                <Badge variant="outline" className="text-green-600">
                  System Online
                </Badge>
              </div>
            </div>
          </div>
        </div>

        {/* Main Content */}
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <Tabs value={activeTab} onValueChange={setActiveTab} className="space-y-6">
            <TabsList className="grid w-full grid-cols-6 lg:w-auto lg:flex">
              <TabsTrigger value="overview" className="flex items-center space-x-2">
                <Activity className="h-4 w-4" />
                <span className="hidden sm:inline">Overview</span>
              </TabsTrigger>
              <TabsTrigger value="users" className="flex items-center space-x-2">
                <Users className="h-4 w-4" />
                <span className="hidden sm:inline">Users</span>
              </TabsTrigger>
              <TabsTrigger value="ai-providers" className="flex items-center space-x-2">
                <Cpu className="h-4 w-4" />
                <span className="hidden sm:inline">AI</span>
              </TabsTrigger>
              <TabsTrigger value="analytics" className="flex items-center space-x-2">
                <TrendingUp className="h-4 w-4" />
                <span className="hidden sm:inline">Analytics</span>
              </TabsTrigger>
              <TabsTrigger value="content" className="flex items-center space-x-2">
                <FileText className="h-4 w-4" />
                <span className="hidden sm:inline">Content</span>
              </TabsTrigger>
              <TabsTrigger value="system" className="flex items-center space-x-2">
                <Settings className="h-4 w-4" />
                <span className="hidden sm:inline">System</span>
              </TabsTrigger>
            </TabsList>

            <TabsContent value="overview" className="space-y-6">
              <OverviewStats />
              <SystemHealth />
            </TabsContent>

            <TabsContent value="users">
              <UserManagement />
            </TabsContent>

            <TabsContent value="ai-providers">
              <AIProviderConfig />
            </TabsContent>

            <TabsContent value="analytics">
              <UsageAnalytics />
            </TabsContent>

            <TabsContent value="content">
              <ContentModeration />
            </TabsContent>

            <TabsContent value="system">
              <SystemSettings />
            </TabsContent>
          </Tabs>
        </div>
      </div>
    </ProtectedRoute>
  );
};

// Overview Stats Component
const OverviewStats: React.FC = () => {
  // Mock data - replace with actual API calls
  const stats = {
    totalUsers: 1234,
    activeUsers: 856,
    totalConversations: 5678,
    todayUsage: 234,
    systemUptime: "99.9%",
    monthlyCost: 1234.56,
  };

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle className="text-sm font-medium">Total Users</CardTitle>
          <Users className="h-4 w-4 text-muted-foreground" />
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold">{stats.totalUsers.toLocaleString()}</div>
          <p className="text-xs text-muted-foreground">
            +{stats.activeUsers} active this week
          </p>
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle className="text-sm font-medium">Conversations</CardTitle>
          <FileText className="h-4 w-4 text-muted-foreground" />
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold">{stats.totalConversations.toLocaleString()}</div>
          <p className="text-xs text-muted-foreground">
            +{stats.todayUsage} today
          </p>
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle className="text-sm font-medium">System Health</CardTitle>
          <Activity className="h-4 w-4 text-muted-foreground" />
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold text-green-600">{stats.systemUptime}</div>
          <p className="text-xs text-muted-foreground">
            All systems operational
          </p>
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle className="text-sm font-medium">Monthly Cost</CardTitle>
          <DollarSign className="h-4 w-4 text-muted-foreground" />
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold">${stats.monthlyCost.toFixed(2)}</div>
          <p className="text-xs text-muted-foreground">
            +12% from last month
          </p>
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle className="text-sm font-medium">Storage Used</CardTitle>
          <Database className="h-4 w-4 text-muted-foreground" />
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold">45.2 GB</div>
          <p className="text-xs text-muted-foreground">
            90% of 50 GB quota
          </p>
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle className="text-sm font-medium">AI Services</CardTitle>
          <Cpu className="h-4 w-4 text-muted-foreground" />
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold">3/3</div>
          <p className="text-xs text-muted-foreground">
            All providers online
          </p>
        </CardContent>
      </Card>
    </div>
  );
};

// System Settings Component
const SystemSettings: React.FC = () => {
  return (
    <Card>
      <CardHeader>
        <CardTitle>System Settings</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="text-center py-8 text-gray-500">
          <Settings className="h-12 w-12 mx-auto mb-4 opacity-50" />
          <p>System settings management coming soon</p>
        </div>
      </CardContent>
    </Card>
  );
};
```

## Testing Strategy

### Admin Dashboard Tests
```typescript
// apps/api/src/__tests__/admin.test.ts
import { describe, it, expect, beforeEach } from "vitest";
import { AdminService } from "../services/admin-service";

describe("Admin Dashboard", () => {
  let adminService: AdminService;

  beforeEach(() => {
    adminService = new AdminService();
  });

  it("should retrieve paginated users", async () => {
    const result = await adminService.getUsers({
      page: 1,
      limit: 10,
      sortBy: "createdAt",
      sortOrder: "desc",
    });

    expect(result.users).toBeDefined();
    expect(result.totalCount).toBeGreaterThanOrEqual(0);
    expect(result.currentPage).toBe(1);
  });

  it("should get AI providers with configs", async () => {
    const providers = await adminService.getAIProviders();

    expect(Array.isArray(providers)).toBe(true);
    providers.forEach(provider => {
      expect(provider).toHaveProperty("id");
      expect(provider).toHaveProperty("name");
      expect(provider).toHaveProperty("configs");
    });
  });

  it("should update AI provider configuration", async () => {
    const result = await adminService.updateAIProviderConfig({
      providerId: "test-provider-id",
      serviceType: "TTS",
      configuration: { enabled: true },
      isActive: true,
      priority: 1,
    });

    expect(result.success).toBe(true);
  });
});
```

## Estimated Timeline: 1 Week

### Day 1-2: Admin API Services
- Create admin service implementation
- Build user management endpoints
- Implement AI provider configuration

### Day 3-4: Analytics and Monitoring
- Add usage analytics service
- Build system monitoring
- Create content moderation tools

### Day 5: Frontend Dashboard
- Build admin dashboard UI
- Create management interfaces
- Add real-time updates

## Success Criteria

- [ ] User management interface working
- [ ] AI provider configuration functional
- [ ] System health monitoring operational
- [ ] Usage analytics and reporting
- [ ] Content moderation tools working
- [ ] Admin authentication and permissions
- [ ] Backup and restore functionality
- [ ] Real-time system monitoring
- [ ] Security audit logging
- [ ] Performance metrics collection
- [ ] Cost analysis and optimization
- [ ] All admin features tested

This comprehensive admin dashboard provides full control over the pronunciation assistant system with detailed monitoring, user management, and system configuration capabilities.