# Stage 4: Document Management System

## Stage Overview

This stage implements the complete document management pipeline for the pronunciation assistant, including file upload, document conversion (DOCX/PDF → Markdown), storage management, and a comprehensive UI for document organization and metadata handling.

## Observable Outcomes

- ✅ File upload API with support for DOCX, PDF, and TXT files
- ✅ Document conversion to Markdown using Microsoft Mark-It-Down
- ✅ MinIO integration for file storage with proper bucket organization
- ✅ Document management UI with upload, preview, and CRUD operations
- ✅ Document metadata and organization features
- ✅ File processing pipeline with progress tracking
- ✅ Document search and filtering functionality

## Technical Requirements

### File Processing
- Support for DOCX, PDF, and TXT file formats
- High-fidelity document conversion to Markdown
- File size and type validation
- Duplicate content detection using hashing
- Processing status tracking and error handling
- Temporary file cleanup

### Storage Management
- MinIO S3-compatible storage integration
- Organized bucket structure for different file types
- Automatic backup and redundancy
- File access control and permissions
- Storage usage monitoring and quotas

### User Interface
- Drag-and-drop file upload interface
- Document preview and editing capabilities
- Search and filtering system
- Bulk operations support
- Responsive design for mobile devices

## Implementation Details

### Step 1: Document Upload API

#### 1.1 File Upload tRPC Router
```typescript
// apps/api/src/router/documents.ts
import { router, protectedProcedure } from "./trpc";
import { z } from "zod";
import { TRPCError } from "@trpc/server";
import { DocumentService } from "../services/document-service";
import { FileService } from "../services/file-service";

export const documentsRouter = router({
  // Upload document
  upload: protectedProcedure
    .input(z.object({
      file: z.any(), // Will be processed as multipart form
      title: z.string().min(1).max(255),
      description: z.string().optional(),
      tags: z.array(z.string()).optional(),
    }))
    .mutation(async ({ input, ctx }) => {
      try {
        const documentService = new DocumentService();
        const fileService = new FileService();

        // Validate file
        const file = input.file;
        if (!file) {
          throw new TRPCError({
            code: "BAD_REQUEST",
            message: "No file provided",
          });
        }

        // Check file type and size
        const allowedTypes = [
          "application/pdf",
          "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
          "text/plain",
        ];

        if (!allowedTypes.includes(file.type)) {
          throw new TRPCError({
            code: "BAD_REQUEST",
            message: "Invalid file type. Only PDF, DOCX, and TXT files are allowed.",
          });
        }

        const maxSize = 50 * 1024 * 1024; // 50MB
        if (file.size > maxSize) {
          throw new TRPCError({
            code: "BAD_REQUEST",
            message: "File size too large. Maximum size is 50MB.",
          });
        }

        // Store file in MinIO
        const fileUrl = await fileService.storeFile(file, ctx.user.id);

        // Create document record
        const document = await documentService.createDocument({
          userId: ctx.user.id,
          title: input.title,
          description: input.description,
          originalFilename: file.name,
          fileSize: file.size,
          fileMimeType: file.type,
          filePath: fileUrl,
          tags: input.tags || [],
        });

        // Start document processing (conversion to Markdown)
        await documentService.processDocument(document.id);

        return { document };
      } catch (error) {
        console.error("Document upload error:", error);
        throw new TRPCError({
          code: "INTERNAL_SERVER_ERROR",
          message: "Failed to upload document",
        });
      }
    }),

  // Get user documents with pagination
  getAll: protectedProcedure
    .input(z.object({
      page: z.number().min(1).default(1),
      limit: z.number().min(1).max(50).default(20),
      search: z.string().optional(),
      tags: z.array(z.string()).optional(),
      status: z.enum(["UPLOADING", "PROCESSING", "READY", "ERROR"]).optional(),
      sortBy: z.enum(["createdAt", "updatedAt", "title", "fileSize"]).default("createdAt"),
      sortOrder: z.enum(["asc", "desc"]).default("desc"),
    }))
    .query(async ({ input, ctx }) => {
      const documentService = new DocumentService();
      return await documentService.getUserDocuments(ctx.user.id, input);
    }),

  // Get single document
  getById: protectedProcedure
    .input(z.object({ id: z.string().uuid() }))
    .query(async ({ input, ctx }) => {
      const documentService = new DocumentService();
      const document = await documentService.getDocumentById(input.id, ctx.user.id);

      if (!document) {
        throw new TRPCError({
          code: "NOT_FOUND",
          message: "Document not found",
        });
      }

      return document;
    }),

  // Update document metadata
  update: protectedProcedure
    .input(z.object({
      id: z.string().uuid(),
      title: z.string().min(1).max(255),
      description: z.string().optional(),
      tags: z.array(z.string()).optional(),
    }))
    .mutation(async ({ input, ctx }) => {
      const documentService = new DocumentService();
      const document = await documentService.updateDocument(
        input.id,
        ctx.user.id,
        {
          title: input.title,
          description: input.description,
          tags: input.tags,
        }
      );

      if (!document) {
        throw new TRPCError({
          code: "NOT_FOUND",
          message: "Document not found",
        });
      }

      return document;
    }),

  // Delete document
  delete: protectedProcedure
    .input(z.object({ id: z.string().uuid() }))
    .mutation(async ({ input, ctx }) => {
      const documentService = new DocumentService();
      const fileService = new FileService();

      const document = await documentService.getDocumentById(input.id, ctx.user.id);
      if (!document) {
        throw new TRPCError({
          code: "NOT_FOUND",
          message: "Document not found",
        });
      }

      // Delete file from storage
      if (document.filePath) {
        await fileService.deleteFile(document.filePath);
      }

      // Delete document record
      await documentService.deleteDocument(input.id, ctx.user.id);

      return { success: true };
    }),

  // Get document processing status
  getProcessingStatus: protectedProcedure
    .input(z.object({ id: z.string().uuid() }))
    .query(async ({ input, ctx }) => {
      const documentService = new DocumentService();
      const status = await documentService.getDocumentProcessingStatus(input.id, ctx.user.id);

      if (!status) {
        throw new TRPCError({
          code: "NOT_FOUND",
          message: "Document not found",
        });
      }

      return status;
    }),

  // Search documents
  search: protectedProcedure
    .input(z.object({
      query: z.string().min(1),
      page: z.number().min(1).default(1),
      limit: z.number().min(1).max(20).default(10),
    }))
    .query(async ({ input, ctx }) => {
      const documentService = new DocumentService();
      return await documentService.searchDocuments(ctx.user.id, input);
    }),
});
```

#### 1.2 Document Service Implementation
```typescript
// apps/api/src/services/document-service.ts
import { db } from "@repo/database";
import { documents, documentVersions } from "@repo/database/src/schema";
import { DocumentConverter } from "./document-converter";
import { createHash } from "crypto";

export class DocumentService {
  async createDocument(data: {
    userId: string;
    title: string;
    description?: string;
    originalFilename: string;
    fileSize: number;
    fileMimeType: string;
    filePath: string;
    tags: string[];
  }) {
    const [document] = await db.insert(documents).values({
      userId: data.userId,
      title: data.title,
      description: data.description,
      originalFilename: data.originalFilename,
      fileSize: data.fileSize,
      fileMimeType: data.fileMimeType,
      filePath: data.filePath,
      status: "UPLOADING",
      tags: data.tags,
    }).returning();

    return document;
  }

  async processDocument(documentId: string) {
    // Update status to processing
    await db.update(documents)
      .set({
        status: "PROCESSING",
        processingProgress: 0,
        updatedAt: new Date()
      })
      .where(eq(documents.id, documentId));

    try {
      const document = await db.query.documents.findFirst({
        where: eq(documents.id, documentId),
      });

      if (!document) {
        throw new Error("Document not found");
      }

      // Update progress
      await db.update(documents)
        .set({ processingProgress: 25 })
        .where(eq(documents.id, documentId));

      // Convert document to Markdown
      const converter = new DocumentConverter();
      const markdownContent = await converter.convertToMarkdown(
        document.filePath,
        document.fileMimeType
      );

      // Update progress
      await db.update(documents)
        .set({ processingProgress: 75 })
        .where(eq(documents.id, documentId));

      // Calculate content hash
      const contentHash = createHash("sha256").update(markdownContent).digest("hex");

      // Calculate word count and reading time
      const wordCount = markdownContent.split(/\s+/).length;
      const readingTimeMinutes = Math.ceil(wordCount / 200); // Average reading speed

      // Update document with processed content
      await db.update(documents)
        .set({
          content: markdownContent,
          contentHash,
          wordCount,
          readingTimeMinutes,
          status: "READY",
          processingProgress: 100,
          updatedAt: new Date(),
        })
        .where(eq(documents.id, documentId));

      // Create initial version
      await db.insert(documentVersions).values({
        documentId,
        versionNumber: 1,
        content: markdownContent,
        changeSummary: "Initial version from file upload",
        createdAt: new Date(),
      });

    } catch (error) {
      console.error("Document processing failed:", error);
      await db.update(documents)
        .set({
          status: "ERROR",
          processingError: error instanceof Error ? error.message : "Unknown error",
          updatedAt: new Date(),
        })
        .where(eq(documents.id, documentId));
    }
  }

  async getUserDocuments(userId: string, filters: {
    page: number;
    limit: number;
    search?: string;
    tags?: string[];
    status?: string;
    sortBy: string;
    sortOrder: "asc" | "desc";
  }) {
    const offset = (filters.page - 1) * filters.limit;

    let query = db
      .select({
        id: documents.id,
        title: documents.title,
        description: documents.description,
        originalFilename: documents.originalFilename,
        fileSize: documents.fileSize,
        fileMimeType: documents.fileMimeType,
        status: documents.status,
        processingProgress: documents.processingProgress,
        wordCount: documents.wordCount,
        readingTimeMinutes: documents.readingTimeMinutes,
        tags: documents.tags,
        createdAt: documents.createdAt,
        updatedAt: documents.updatedAt,
      })
      .from(documents)
      .where(and(
        eq(documents.userId, userId),
        isNull(documents.deletedAt)
      ));

    // Apply filters
    if (filters.search) {
      query = query.where(
        or(
          ilike(documents.title, `%${filters.search}%`),
          ilike(documents.description, `%${filters.search}%`),
          ilike(documents.content, `%${filters.search}%`)
        )
      );
    }

    if (filters.status) {
      query = query.where(eq(documents.status, filters.status));
    }

    if (filters.tags && filters.tags.length > 0) {
      query = query.where(
        sql`${documents.tags} && ${JSON.stringify(filters.tags)}`
      );
    }

    // Apply sorting
    const sortColumn = documents[filters.sortBy as keyof typeof documents];
    if (sortColumn) {
      query = filters.sortOrder === "asc"
        ? query.orderBy(asc(sortColumn))
        : query.orderBy(desc(sortColumn));
    }

    // Get total count
    const totalCountQuery = db
      .select({ count: count() })
      .from(documents)
      .where(and(
        eq(documents.userId, userId),
        isNull(documents.deletedAt)
      ));

    const [{ count: totalCount }] = await totalCountQuery;

    // Get paginated results
    const documentsList = await query
      .limit(filters.limit)
      .offset(offset);

    return {
      documents: documentsList,
      totalCount,
      currentPage: filters.page,
      totalPages: Math.ceil(totalCount / filters.limit),
    };
  }

  async searchDocuments(userId: string, params: {
    query: string;
    page: number;
    limit: number;
  }) {
    const offset = (params.page - 1) * params.limit;

    // Use PostgreSQL full-text search
    const searchResults = await db
      .select({
        id: documents.id,
        title: documents.title,
        description: documents.description,
        content: documents.content,
        rank: sql`ts_rank_cd(to_tsvector('english', ${documents.content} || ' ' || ${documents.title}), plainto_tsquery('english', ${params.query}))`.as("rank"),
        createdAt: documents.createdAt,
        updatedAt: documents.updatedAt,
      })
      .from(documents)
      .where(and(
        eq(documents.userId, userId),
        eq(documents.status, "READY"),
        isNull(documents.deletedAt),
        sql`to_tsvector('english', ${documents.content} || ' ' || ${documents.title}) @@ plainto_tsquery('english', ${params.query})`
      ))
      .orderBy(desc(sql`rank`))
      .limit(params.limit)
      .offset(offset);

    return {
      documents: searchResults,
      query: params.query,
      page: params.page,
    };
  }

  async updateDocument(documentId: string, userId: string, updates: {
    title?: string;
    description?: string;
    tags?: string[];
  }) {
    const [document] = await db
      .update(documents)
      .set({
        ...updates,
        updatedAt: new Date(),
      })
      .where(and(
        eq(documents.id, documentId),
        eq(documents.userId, userId)
      ))
      .returning();

    return document;
  }

  async deleteDocument(documentId: string, userId: string) {
    // Soft delete
    await db
      .update(documents)
      .set({
        deletedAt: new Date(),
        updatedAt: new Date(),
      })
      .where(and(
        eq(documents.id, documentId),
        eq(documents.userId, userId)
      ));
  }

  async getDocumentById(documentId: string, userId: string) {
    const document = await db.query.documents.findFirst({
      where: and(
        eq(documents.id, documentId),
        eq(documents.userId, userId),
        isNull(documents.deletedAt)
      ),
    });

    return document;
  }

  async getDocumentProcessingStatus(documentId: string, userId: string) {
    const document = await db.query.documents.findFirst({
      where: and(
        eq(documents.id, documentId),
        eq(documents.userId, userId)
      ),
      columns: {
        id: true,
        status: true,
        processingProgress: true,
        processingError: true,
      },
    });

    return document;
  }
}
```

### Step 2: Document Conversion Service

#### 2.1 Mark-It-Down Integration
```typescript
// apps/api/src/services/document-converter.ts
import { MinioService } from "./minio-service";
import mammoth from "mammoth"; // For DOCX files
import pdf from "pdf-parse"; // For PDF files
import { Readable } from "stream";

export class DocumentConverter {
  private minioService: MinioService;

  constructor() {
    this.minioService = new MinioService();
  }

  async convertToMarkdown(filePath: string, mimeType: string): Promise<string> {
    try {
      // Download file from MinIO
      const fileBuffer = await this.minioService.getFile(filePath);

      let text: string;

      switch (mimeType) {
        case "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
          text = await this.convertDocxToMarkdown(fileBuffer);
          break;
        case "application/pdf":
          text = await this.convertPdfToMarkdown(fileBuffer);
          break;
        case "text/plain":
          text = fileBuffer.toString("utf-8");
          break;
        default:
          throw new Error(`Unsupported file type: ${mimeType}`);
      }

      // Convert to high-quality Markdown
      return this.formatAsMarkdown(text, mimeType);
    } catch (error) {
      console.error("Document conversion error:", error);
      throw new Error(`Failed to convert document: ${error instanceof Error ? error.message : "Unknown error"}`);
    }
  }

  private async convertDocxToMarkdown(buffer: Buffer): Promise<string> {
    try {
      const result = await mammoth.convertToMarkdown(buffer);
      return result.value;
    } catch (error) {
      throw new Error(`DOCX conversion failed: ${error instanceof Error ? error.message : "Unknown error"}`);
    }
  }

  private async convertPdfToMarkdown(buffer: Buffer): Promise<string> {
    try {
      const data = await pdf(buffer);
      return this.formatPdfTextAsMarkdown(data.text);
    } catch (error) {
      throw new Error(`PDF conversion failed: ${error instanceof Error ? error.message : "Unknown error"}`);
    }
  }

  private formatPdfTextAsMarkdown(text: string): string {
    // Split text into paragraphs and format as Markdown
    return text
      .split(/\n\s*\n/)
      .map(paragraph => {
        // Detect headings (lines with fewer words and often centered or larger)
        const lines = paragraph.split('\n');
        if (lines.length === 1 && lines[0].trim().length < 100) {
          // Likely a heading
          return `## ${lines[0].trim()}\n`;
        }
        // Regular paragraph
        return `${paragraph.trim()}\n`;
      })
      .join('\n');
  }

  private formatAsMarkdown(text: string, sourceType: string): string {
    let markdown = text;

    // Clean up common formatting issues
    markdown = markdown.replace(/\r\n/g, '\n'); // Normalize line endings
    markdown = markdown.replace(/\n{3,}/g, '\n\n'); // Remove excessive blank lines
    markdown = markdown.trim();

    // Add metadata header
    const metadata = `---
source: ${sourceType}
processed: ${new Date().toISOString()}
---

`;

    return metadata + markdown;
  }
}
```

### Step 3: File Storage Service

#### 3.1 MinIO Integration
```typescript
// apps/api/src/services/minio-service.ts
import { Client } from "minio";
import { Readable } from "stream";
import { v4 as uuidv4 } from "uuid";

export class MinioService {
  private client: Client;

  constructor() {
    this.client = new Client({
      endPoint: process.env.MINIO_HOST || "localhost",
      port: parseInt(process.env.MINIO_PORT || "9000"),
      useSSL: process.env.MINIO_USE_SSL === "true",
      accessKey: process.env.MINIO_ACCESS_KEY!,
      secretKey: process.env.MINIO_SECRET_KEY!,
    });
  }

  async storeFile(
    file: Buffer,
    userId: string,
    originalFilename: string,
    mimeType: string
  ): Promise<string> {
    // Generate unique filename
    const fileExtension = originalFilename.split('.').pop() || "bin";
    const uniqueFilename = `${uuidv4()}.${fileExtension}`;

    // Organize files by user and type
    const bucketName = "documents";
    const objectName = `users/${userId}/${uniqueFilename}`;

    try {
      // Ensure bucket exists
      const bucketExists = await this.client.bucketExists(bucketName);
      if (!bucketExists) {
        await this.client.makeBucket(bucketName);
        // Set bucket policy for user access
        await this.setBucketPolicy(bucketName);
      }

      // Upload file
      await this.client.putObject(
        bucketName,
        objectName,
        file,
        undefined,
        {
          "Content-Type": mimeType,
          "X-Amz-Meta-Original-Filename": originalFilename,
          "X-Amz-Meta-Uploader-Id": userId,
          "X-Amz-Meta-Upload-Time": new Date().toISOString(),
        }
      );

      return `${bucketName}/${objectName}`;
    } catch (error) {
      console.error("MinIO upload error:", error);
      throw new Error("Failed to store file");
    }
  }

  async getFile(filePath: string): Promise<Buffer> {
    try {
      const [bucketName, ...objectPathParts] = filePath.split('/');
      const objectName = objectPathParts.join('/');

      const stream = await this.client.getObject(bucketName, objectName);
      return await this.streamToBuffer(stream);
    } catch (error) {
      console.error("MinIO download error:", error);
      throw new Error("Failed to retrieve file");
    }
  }

  async deleteFile(filePath: string): Promise<void> {
    try {
      const [bucketName, ...objectPathParts] = filePath.split('/');
      const objectName = objectPathParts.join('/');

      await this.client.removeObject(bucketName, objectName);
    } catch (error) {
      console.error("MinIO delete error:", error);
      throw new Error("Failed to delete file");
    }
  }

  async getFileUrl(filePath: string, expiresIn: number = 3600): Promise<string> {
    try {
      const [bucketName, ...objectPathParts] = filePath.split('/');
      const objectName = objectPathParts.join('/');

      return await this.client.presignedGetObject(bucketName, objectName, expiresIn);
    } catch (error) {
      console.error("MinIO URL generation error:", error);
      throw new Error("Failed to generate file URL");
    }
  }

  private async setBucketPolicy(bucketName: string): Promise<void> {
    const policy = {
      Version: "2012-10-17",
      Statement: [
        {
          Effect: "Allow",
          Principal: {
            AWS: ["*"],
          },
          Action: ["s3:GetObject"],
          Resource: [`arn:aws:s3:::${bucketName}/public/*`],
        },
      ],
    };

    await this.client.setBucketPolicy(bucketName, JSON.stringify(policy));
  }

  private async streamToBuffer(stream: Readable): Promise<Buffer> {
    return new Promise((resolve, reject) => {
      const chunks: Buffer[] = [];
      stream.on("data", (chunk) => chunks.push(chunk));
      stream.on("error", reject);
      stream.on("end", () => resolve(Buffer.concat(chunks)));
    });
  }
}
```

#### 3.2 File Upload Middleware
```typescript
// apps/api/src/middleware/upload.ts
import multer from "multer";
import { Request, Response, NextFunction } from "express";

// Configure multer for file uploads
const storage = multer.memoryStorage();

const upload = multer({
  storage,
  limits: {
    fileSize: 50 * 1024 * 1024, // 50MB
  },
  fileFilter: (req, file, cb) => {
    const allowedTypes = [
      "application/pdf",
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      "text/plain",
    ];

    if (allowedTypes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error("Invalid file type. Only PDF, DOCX, and TXT files are allowed."));
    }
  },
});

export const uploadSingle = upload.single("file");

export const handleUploadError = (
  err: any,
  req: Request,
  res: Response,
  next: NextFunction
) => {
  if (err instanceof multer.MulterError) {
    if (err.code === "LIMIT_FILE_SIZE") {
      return res.status(400).json({
        error: "File size too large. Maximum size is 50MB.",
      });
    }
    if (err.code === "LIMIT_FILE_COUNT") {
      return res.status(400).json({
        error: "Too many files uploaded.",
      });
    }
  }

  if (err.message.includes("Invalid file type")) {
    return res.status(400).json({
      error: err.message,
    });
  }

  next(err);
};
```

### Step 4: Frontend Document Management UI

#### 4.1 Document Upload Component
```typescript
// apps/app/src/components/documents/DocumentUpload.tsx
import React, { useState, useCallback } from "react";
import { useDropzone } from "react-dropzone";
import { Button } from "@repo/ui/components/button";
import { Card, CardContent, CardHeader, CardTitle } from "@repo/ui/components/card";
import { Input } from "@repo/ui/components/input";
import { Textarea } from "@repo/ui/components/textarea";
import { Badge } from "@repo/ui/components/badge";
import { Upload, FileText, X, CheckCircle, AlertCircle, Loader2 } from "lucide-react";
import { trpc } from "../../utils/trpc";

interface DocumentUploadProps {
  onUploadComplete?: (document: any) => void;
}

export const DocumentUpload: React.FC<DocumentUploadProps> = ({ onUploadComplete }) => {
  const [file, setFile] = useState<File | null>(null);
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [tags, setTags] = useState<string[]>([]);
  const [tagInput, setTagInput] = useState("");
  const [uploading, setUploading] = useState(false);

  const uploadMutation = trpc.documents.upload.useMutation();

  const onDrop = useCallback((acceptedFiles: File[]) => {
    if (acceptedFiles.length > 0) {
      const selectedFile = acceptedFiles[0];
      setFile(selectedFile);
      // Auto-populate title with filename (without extension)
      const titleWithoutExtension = selectedFile.name.replace(/\.[^/.]+$/, "");
      setTitle(titleWithoutExtension);
    }
  }, []);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: {
      "application/pdf": [".pdf"],
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document": [".docx"],
      "text/plain": [".txt"],
    },
    multiple: false,
    disabled: uploading,
  });

  const handleAddTag = () => {
    if (tagInput.trim() && !tags.includes(tagInput.trim())) {
      setTags([...tags, tagInput.trim()]);
      setTagInput("");
    }
  };

  const handleRemoveTag = (tagToRemove: string) => {
    setTags(tags.filter(tag => tag !== tagToRemove));
  };

  const handleUpload = async () => {
    if (!file || !title.trim()) {
      return;
    }

    try {
      setUploading(true);

      const formData = new FormData();
      formData.append("file", file);

      // Note: You'll need to handle multipart form data in your tRPC setup
      // This is a simplified version - you might need to use a different approach
      const result = await uploadMutation.mutateAsync({
        file,
        title: title.trim(),
        description: description.trim() || undefined,
        tags,
      });

      onUploadComplete?.(result.document);

      // Reset form
      setFile(null);
      setTitle("");
      setDescription("");
      setTags([]);

    } catch (error) {
      console.error("Upload failed:", error);
    } finally {
      setUploading(false);
    }
  };

  const formatFileSize = (bytes: number) => {
    if (bytes === 0) return "0 Bytes";
    const k = 1024;
    const sizes = ["Bytes", "KB", "MB", "GB"];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + " " + sizes[i];
  };

  return (
    <Card className="w-full max-w-2xl mx-auto">
      <CardHeader>
        <CardTitle>Upload Document</CardTitle>
      </CardHeader>
      <CardContent className="space-y-6">
        {/* File Drop Zone */}
        <div
          {...getRootProps()}
          className={`
            border-2 border-dashed rounded-lg p-8 text-center cursor-pointer transition-colors
            ${isDragActive ? "border-blue-500 bg-blue-50" : "border-gray-300 hover:border-gray-400"}
            ${file ? "border-green-500 bg-green-50" : ""}
            ${uploading ? "opacity-50 cursor-not-allowed" : ""}
          `}
        >
          <input {...getInputProps()} />
          {file ? (
            <div className="flex items-center justify-center space-x-2">
              <FileText className="h-8 w-8 text-green-600" />
              <div className="text-left">
                <p className="font-medium text-green-600">{file.name}</p>
                <p className="text-sm text-gray-600">{formatFileSize(file.size)}</p>
              </div>
            </div>
          ) : (
            <div className="space-y-2">
              <Upload className="h-12 w-12 text-gray-400 mx-auto" />
              <p className="text-lg font-medium">
                {isDragActive ? "Drop the file here" : "Drag and drop a file here, or click to select"}
              </p>
              <p className="text-sm text-gray-500">
                Supports PDF, DOCX, and TXT files up to 50MB
              </p>
            </div>
          )}
        </div>

        {/* Document Details */}
        <div className="space-y-4">
          <div>
            <label htmlFor="title" className="block text-sm font-medium mb-1">
              Title *
            </label>
            <Input
              id="title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="Enter document title"
              disabled={uploading}
            />
          </div>

          <div>
            <label htmlFor="description" className="block text-sm font-medium mb-1">
              Description
            </label>
            <Textarea
              id="description"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="Enter a brief description"
              rows={3}
              disabled={uploading}
            />
          </div>

          {/* Tags */}
          <div>
            <label htmlFor="tags" className="block text-sm font-medium mb-1">
              Tags
            </label>
            <div className="flex space-x-2 mb-2">
              <Input
                id="tags"
                value={tagInput}
                onChange={(e) => setTagInput(e.target.value)}
                placeholder="Add a tag"
                disabled={uploading}
                onKeyPress={(e) => {
                  if (e.key === "Enter") {
                    e.preventDefault();
                    handleAddTag();
                  }
                }}
              />
              <Button
                type="button"
                onClick={handleAddTag}
                disabled={uploading || !tagInput.trim()}
              >
                Add
              </Button>
            </div>

            {tags.length > 0 && (
              <div className="flex flex-wrap gap-2">
                {tags.map((tag) => (
                  <Badge key={tag} variant="secondary" className="flex items-center">
                    {tag}
                    <X
                      className="h-3 w-3 ml-1 cursor-pointer"
                      onClick={() => handleRemoveTag(tag)}
                    />
                  </Badge>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Upload Button */}
        <Button
          onClick={handleUpload}
          disabled={!file || !title.trim() || uploading}
          className="w-full"
        >
          {uploading ? (
            <>
              <Loader2 className="h-4 w-4 mr-2 animate-spin" />
              Uploading and Processing...
            </>
          ) : (
            <>
              <Upload className="h-4 w-4 mr-2" />
              Upload Document
            </>
          )}
        </Button>

        {/* Upload Status */}
        {uploadMutation.data && (
          <div className="flex items-center space-x-2 p-3 bg-green-50 border border-green-200 rounded-lg">
            <CheckCircle className="h-5 w-5 text-green-600" />
            <span className="text-green-800">
              Document uploaded successfully! Processing may take a few minutes.
            </span>
          </div>
        )}

        {uploadMutation.error && (
          <div className="flex items-center space-x-2 p-3 bg-red-50 border border-red-200 rounded-lg">
            <AlertCircle className="h-5 w-5 text-red-600" />
            <span className="text-red-800">
              {uploadMutation.error.message}
            </span>
          </div>
        )}
      </CardContent>
    </Card>
  );
};
```

#### 4.2 Document List Component
```typescript
// apps/app/src/components/documents/DocumentList.tsx
import React, { useState } from "react";
import { useQuery } from "@trpc/react-query";
import { trpc } from "../../utils/trpc";
import { Card, CardContent, CardHeader, CardTitle } from "@repo/ui/components/card";
import { Button } from "@repo/ui/components/button";
import { Input } from "@repo/ui/components/input";
import { Badge } from "@repo/ui/components/badge";
import {
  FileText,
  Download,
  Eye,
  Trash2,
  Search,
  Filter,
  Calendar,
  Clock,
  Tag,
  Loader2
} from "lucide-react";
import { formatDistance } from "date-fns";

export const DocumentList: React.FC = () => {
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);
  const [filters, setFilters] = useState({
    status: undefined as string | undefined,
    tags: [] as string[],
  });

  const { data, isLoading, refetch } = trpc.documents.getAll.useQuery({
    page,
    search: search.trim() || undefined,
    ...filters,
  });

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    setPage(1);
    refetch();
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case "READY":
        return "bg-green-100 text-green-800";
      case "PROCESSING":
        return "bg-yellow-100 text-yellow-800";
      case "UPLOADING":
        return "bg-blue-100 text-blue-800";
      case "ERROR":
        return "bg-red-100 text-red-800";
      default:
        return "bg-gray-100 text-gray-800";
    }
  };

  const formatFileSize = (bytes: number) => {
    if (bytes === 0) return "0 Bytes";
    const k = 1024;
    const sizes = ["Bytes", "KB", "MB", "GB"];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + " " + sizes[i];
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-96">
        <Loader2 className="h-8 w-8 animate-spin" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Search and Filters */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center space-x-2">
            <FileText className="h-5 w-5" />
            <span>My Documents</span>
          </CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSearch} className="flex space-x-2">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <Input
                type="text"
                placeholder="Search documents..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                className="pl-10"
              />
            </div>
            <Button type="submit">Search</Button>
          </form>
        </CardContent>
      </Card>

      {/* Documents Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {data?.documents.map((document) => (
          <Card key={document.id} className="hover:shadow-md transition-shadow">
            <CardHeader className="pb-3">
              <div className="flex items-start justify-between">
                <h3 className="font-semibold text-lg line-clamp-2">{document.title}</h3>
                <Badge className={getStatusColor(document.status)}>
                  {document.status}
                </Badge>
              </div>
              {document.description && (
                <p className="text-sm text-gray-600 line-clamp-2">{document.description}</p>
              )}
            </CardHeader>
            <CardContent className="space-y-4">
              {/* File Info */}
              <div className="flex items-center space-x-4 text-sm text-gray-500">
                <span className="flex items-center space-x-1">
                  <FileText className="h-4 w-4" />
                  <span>{formatFileSize(document.fileSize)}</span>
                </span>
                <span className="flex items-center space-x-1">
                  <Clock className="h-4 w-4" />
                  <span>{formatDistance(new Date(document.createdAt), new Date(), { addSuffix: true })}</span>
                </span>
              </div>

              {/* Processing Progress */}
              {document.status === "PROCESSING" && document.processingProgress !== undefined && (
                <div className="space-y-2">
                  <div className="flex justify-between text-sm">
                    <span>Processing...</span>
                    <span>{document.processingProgress}%</span>
                  </div>
                  <div className="w-full bg-gray-200 rounded-full h-2">
                    <div
                      className="bg-blue-600 h-2 rounded-full transition-all"
                      style={{ width: `${document.processingProgress}%` }}
                    />
                  </div>
                </div>
              )}

              {/* Tags */}
              {document.tags && document.tags.length > 0 && (
                <div className="flex flex-wrap gap-1">
                  {document.tags.slice(0, 3).map((tag) => (
                    <Badge key={tag} variant="outline" className="text-xs">
                      {tag}
                    </Badge>
                  ))}
                  {document.tags.length > 3 && (
                    <Badge variant="outline" className="text-xs">
                      +{document.tags.length - 3}
                    </Badge>
                  )}
                </div>
              )}

              {/* Actions */}
              <div className="flex space-x-2 pt-2">
                {document.status === "READY" && (
                  <Button size="sm" variant="outline" className="flex-1">
                    <Eye className="h-4 w-4 mr-1" />
                    View
                  </Button>
                )}
                <Button size="sm" variant="outline" className="flex-1">
                  <Download className="h-4 w-4 mr-1" />
                  Download
                </Button>
                <Button size="sm" variant="outline" className="text-red-600 hover:text-red-700">
                  <Trash2 className="h-4 w-4" />
                </Button>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>

      {/* Empty State */}
      {data?.documents.length === 0 && (
        <Card>
          <CardContent className="text-center py-12">
            <FileText className="h-12 w-12 text-gray-400 mx-auto mb-4" />
            <h3 className="text-lg font-semibold text-gray-900 mb-2">No documents found</h3>
            <p className="text-gray-600 mb-4">
              {search ? "Try adjusting your search criteria" : "Upload your first document to get started"}
            </p>
            {!search && (
              <Button>Upload Document</Button>
            )}
          </CardContent>
        </Card>
      )}

      {/* Pagination */}
      {data && data.totalPages > 1 && (
        <div className="flex justify-center space-x-2">
          <Button
            variant="outline"
            onClick={() => setPage(page - 1)}
            disabled={page === 1}
          >
            Previous
          </Button>
          <span className="flex items-center px-3">
            Page {data.currentPage} of {data.totalPages}
          </span>
          <Button
            variant="outline"
            onClick={() => setPage(page + 1)}
            disabled={page === data.totalPages}
          >
            Next
          </Button>
        </div>
      )}
    </div>
  );
};
```

## Testing Strategy

### Document Processing Tests
```typescript
// apps/api/src/__tests__/document-service.test.ts
import { describe, it, expect, beforeEach } from "vitest";
import { DocumentService } from "../services/document-service";
import { DocumentConverter } from "../services/document-converter";

describe("Document Management", () => {
  let documentService: DocumentService;
  let converter: DocumentConverter;

  beforeEach(() => {
    documentService = new DocumentService();
    converter = new DocumentConverter();
  });

  it("should create a document record", async () => {
    const document = await documentService.createDocument({
      userId: "test-user-id",
      title: "Test Document",
      originalFilename: "test.pdf",
      fileSize: 1024,
      fileMimeType: "application/pdf",
      filePath: "documents/test-user-id/test.pdf",
      tags: ["test", "sample"],
    });

    expect(document).toBeDefined();
    expect(document.title).toBe("Test Document");
    expect(document.status).toBe("UPLOADING");
  });

  it("should convert PDF to Markdown", async () => {
    // Mock PDF buffer
    const pdfBuffer = Buffer.from("mock PDF content");

    const markdown = await converter.convertToMarkdown(
      "test.pdf",
      "application/pdf"
    );

    expect(markdown).toContain("source: application/pdf");
    expect(markdown).toContain("processed:");
  });

  it("should search documents", async () => {
    const results = await documentService.searchDocuments("test-user-id", {
      query: "test query",
      page: 1,
      limit: 10,
    });

    expect(results).toHaveProperty("documents");
    expect(results).toHaveProperty("query");
  });
});
```

### File Upload Tests
```bash
# Test file upload endpoint
curl -X POST http://localhost:4000/api/documents/upload \
  -H "Content-Type: multipart/form-data" \
  -F "file=@test-document.pdf" \
  -F "title=Test Document" \
  -F "description=A test document"

# Test document retrieval
curl -X GET http://localhost:4000/api/documents

# Test MinIO connection
curl http://localhost:9000/minio/health/live
```

## Estimated Timeline: 1 Week

### Day 1-2: Backend Implementation
- Create document upload tRPC endpoints
- Implement document conversion service
- Set up MinIO integration

### Day 3-4: File Processing and Storage
- Implement file processing pipeline
- Add document management features
- Set up file cleanup and maintenance

### Day 5: Frontend UI
- Create document upload component
- Build document list interface
- Add search and filtering functionality

## Success Criteria

- [ ] File upload working for PDF, DOCX, and TXT files
- [ ] Document conversion to Markdown functional
- [ ] MinIO storage configured and accessible
- [ ] Document processing pipeline with progress tracking
- [ ] Document management UI complete
- [ ] Search and filtering working
- [ ] File download functionality operational
- [ ] Error handling for invalid files
- [ ] Duplicate content detection working
- [ ] Processing status updates in real-time
- [ ] Mobile-responsive design
- [ ] All document CRUD operations tested

## Troubleshooting

### Common Issues
1. **File size limits** - Check both frontend and backend size limits
2. **MIME type validation** - Ensure correct file type detection
3. **MinIO connection** - Verify container networking and credentials
4. **Document conversion** - Check converter library installation
5. **Processing timeouts** - Monitor for large file processing

### Debug Commands
```bash
# Check MinIO buckets
curl http://localhost:9001/minio/ui

# Monitor document processing
docker-compose -f docker-compose.dev.yml logs -f api | grep document

# Test file upload
docker-compose -f docker-compose.dev.yml exec api bun run test:upload

# Check storage usage
docker-compose -f docker-compose.dev.yml exec minio du -h /data
```

This comprehensive document management system provides robust file handling with conversion, storage, and management capabilities while maintaining security and performance standards.