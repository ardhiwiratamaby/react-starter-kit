# Comprehensive Design Plan: AI-Powered Pronunciation Assistant

## 1. Executive Summary

This document details the design and implementation of a premier, multi-user, and architecturally flexible English Pronunciation Assistant. The platform is designed to provide a holistic learning experience, covering everything from single-word pronunciation to conversational fluency.

Its core architecture is built around a powerful AI Service Gateway, which abstracts all AI operations. This allows the platform to dynamically switch between high-performance self-hosted AI engines (running on ROCm GPUs and served with vLLM) and a variety of leading commercial services (e.g., Google, Amazon, OpenAI, Deepgram, Qwen).

The standout feature is the Interactive AI Conversation Practice, where users engage in turn-based spoken dialogues with an AI. To ensure high-quality, contextually relevant scripts for these conversations, all user-uploaded documents (DOCX, PDF) are first converted into structured Markdown using a high-fidelity library like Microsoft's Mark-It-Down.

The platform is a full-featured multi-user application with secure authentication, role-based access control (RBAC), and strict data isolation, making it a robust, scalable, and production-ready solution.

## 2. Project Goals and Objectives

**Primary Goal:** To create a holistic, interactive, and adaptable platform for English language learners that is powerful, secure, and cost-effective.

**Core Objectives:**

- To provide a secure, multi-user environment with distinct User and Admin roles and personalized workspaces.
- To standardize all document inputs into high-quality Markdown to serve as a clean, structured context for AI processing.
- To implement an AI Service Gateway that allows for dynamic provider selection for all AI tasks: Text-to-Speech (TTS), Speech-to-Text (STT), and Language Model (LLM) script generation.
- To offer an Interactive Conversation Practice Mode with turn-based dialogue, role-swapping, and a "push-to-talk" interface.
- To record all user-AI conversations, making them available for user playback and download.
- To provide a comprehensive administrative dashboard for managing users and configuring AI service providers.

## 3. System Architecture

The system is a decoupled, microservices-oriented architecture designed for scalability and maintainability.

### 3.1. Architectural Diagram

```
+----------------+      +---------------------------------+      +-----------------------------+
|                |      |                                 |      |                             |
|   User Client  |----->|     Web Application Backend     |----->|    AI Service Gateway       |
| (React SPA)    |<-----| (GraphQL API, Convo Logic)      |<-----|   (Central AI Router)       |
|                |      |                                 |      |                             |
+----------------+      +----------------+----------------+      +--------------+--------------+
                                         |                                     |
                          +--------------+--------------+      +---------------+---------------+
                          | (Orchestrates Conversation) |      |                               |
                          v                             v      v                               v
+----------------+      +----------------+----------------+      +-------------------------+      +-------------------------+
|                |      |                                 |      | Self-Hosted AI Services |      | Commercial AI Services  |
|   File Storage |<---->|            Database             |      | - TTS/STT (ROCm)        |      | - TTS/STT (Google, AWS) |
|   (S3, etc.)   |      | (Users, Scripts, API Config)   |      | - LLM (vLLM)            |      | - LLM (OpenAI, Qwen)    |
|                |      |                                 |      +-------------------------+      +-------------------------+
+----------------+      +---------------------------------+
```

### 3.2. Service Breakdown

- **Frontend (React SPA):** The user-facing application built with React, Apollo Client, and Material UI. Handles user interactions, displays conversation scripts, and manages the recording interface.
- **Backend (Node.js/Express):** The central application server. It provides a GraphQL API for the frontend, manages user authentication and authorization, handles file uploads (DOCX, PDF), stores documents and conversation history in the database, and acts as a proxy to the AI Gateway.
- **AI Service Gateway (Python/FastAPI):** An abstraction layer for AI services. It receives requests from the backend for TTS, STT, and script generation, routes them to the appropriate provider (NVIDIA, OpenAI, Google, Amazon), and returns the results. This allows for easy switching between providers.
- **Database (PostgreSQL):** Stores user accounts, documents, conversation history, and system configuration.
- **File Storage (MinIO):** S3-compatible storage for uploaded documents and potentially processed audio files.

## 4. Functional Requirements

### 4.1. Multi-User Platform Features

- **Authentication:** Secure registration (with email verification), login, social logins, and password reset.
- **Role-Based Access Control (RBAC):**
  - **User Role:** Standard access to personal workspace, document management, and practice tools.
  - **Admin Role:** Access to an administrative dashboard for managing users and configuring AI services.
- **Data Isolation:** User data (documents, recordings, profile) is strictly segregated and private.

### 4.2. Document Processing & Script Generation

- **High-Fidelity Conversion:** All uploaded documents (DOCX, PDF) are converted into structured Markdown using the Microsoft Mark-It-Down library (simulated in this implementation).
- **Script Generation:** Users can generate a conversation script from their uploaded (now Markdown) documents or by providing a custom topic/script via GraphQL mutations.

### 4.3. Interactive Conversation Practice

- **Turn-Based Dialogue:** A chat-like UI where the user and AI take turns speaking lines from the script.
- **Role Selection:** Users can choose to play "Person A" or "Person B" in the dialogue.
- **Push-to-Talk Interface:** A "Hold to Speak" button for a controlled and intuitive speaking experience.
- **Conversation Recording:** The frontend captures user audio, sends it to the backend for STT processing via the AI Gateway, and simulates AI responses.

### 4.4. AI Provider Management (Admin Dashboard)

A centralized settings panel for administrators to select the active provider for each AI task:

- **TTS Provider:** Self-Hosted, Google Cloud, Amazon Polly, etc.
- **STT Provider:** Self-Hosted, Deepgram, AssemblyAI, etc. (Currently implemented with OpenAI Whisper)
- **Script Generation (LLM) Provider:** Self-Hosted (vLLM), OpenAI, Qwen, etc.
  Secure, encrypted storage for all third-party API credentials.

## 5. Key Workflow: Document-to-Conversation Script

1. **Upload:** User uploads report.docx via the frontend.
2. **Convert:** The Web Backend receives the file, processes it (simulated conversion to Markdown), and stores the content in the database.
3. **Initiate:** User requests to generate a script from the document via a GraphQL mutation.
4. **Route:** The Web Backend sends the Markdown content to the AI Service Gateway via a REST API call.
5. **Generate:** The Gateway forwards the request to the currently configured LLM provider (e.g., NVIDIA Qwen).
6. **Store:** The LLM generates a script, which is returned and saved in the database, ready for the user to start a conversation.

## 6. API Design

### 6.1. Public API (Frontend <-> Backend - GraphQL)

**Queries:**

- `me`: Get the current user's information.
- `users`: Get a list of all users (Admin only).
- `documents`: Get the current user's documents.
- `document(id: ID!)`: Get a specific document by ID.
- `conversations`: Get the current user's conversations.
- `conversation(id: ID!)`: Get a specific conversation by ID.

**Mutations:**

- `signup(email: String!, password: String!, name: String!)`: Create a new user account.
- `login(email: String!, password: String!)`: Authenticate a user.
- `logout`: Log out the current user.
- `createDocument(title: String!, content: String!)`: Upload a new document.
- `updateDocument(id: ID!, title: String!, content: String!)`: Update an existing document.
- `deleteDocument(id: ID!)`: Delete a document.
- `createConversation(title: String!, content: String!)`: Create a new conversation.
- `updateConversation(id: ID!, title: String!, content: String!)`: Update an existing conversation.
- `deleteConversation(id: ID!)`: Delete a conversation.
- `generateScriptFromDocument(documentId: ID!)`: Generate a conversation script from a document.
- `generateScriptFromTopic(topic: String!)`: Generate a conversation script from a topic.

### 6.2. Internal API (Backend -> Gateway - REST)

- `POST /tts`: Convert text to speech.
- `POST /stt`: Convert speech to text (with file upload).
- `POST /generate-script`: Generate a conversation script.

## 7. Technology Stack

### Frontend

- **Framework:** React
- **State Management:** Apollo Client (GraphQL)
- **UI Library:** Material UI
- **Routing:** React Router DOM
- **HTTP Client:** Axios

### Web Application Backend

- **Framework:** Node.js with Express
- **GraphQL Server:** Apollo Server
- **Database Client:** Prisma Client
- **Authentication:** JSON Web Tokens (JWT)
- **Password Hashing:** bcryptjs
- **File Upload:** multer
- **HTTP Client:** axios
- **Document Processing:** mammoth (for DOCX), pdf-parse (for PDF)

### AI Service Gateway

- **Framework:** Python with FastAPI
- **HTTP Client:** httpx
- **AI Client Libraries:** openai, google-cloud-texttospeech, google-cloud-speech, boto3
- **Data Validation:** pydantic

### Database

- **Database:** PostgreSQL
- **ORM:** Prisma

### Containerization & Orchestration

- **Container Runtime:** Docker
- **Orchestration:** Docker Compose

## 8. Database Schema

The database schema is defined using Prisma's schema language:

```prisma
model User {
  id        Int       @id @default(autoincrement())
  email     String    @unique
  name      String
  password String
  role      String    @default("USER")
  createdAt DateTime  @default(now())
  updatedAt DateTime  @updatedAt

  documents     Document[]
  conversations Conversation[]
}

model Document {
  id        Int      @id @default(autoincrement())
  title     String
  content   String
  userId    Int
  user      User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  conversations Conversation[]
}

model Conversation {
  id         Int      @id @default(autoincrement())
  title      String
  content    String
  userId     Int
  user       User     @relation(fields: [userId], references: [id], onDelete: Cascade)
 documentId Int?
  document   Document? @relation(fields: [documentId], references: [id], onDelete: SetNull)
  createdAt DateTime @default(now())
  updatedAt  DateTime @updatedAt
}
```

## 9. User Interface (UI) Overview

### 9.1. Login/Signup

A secure authentication screen with form validation for email, password, and name.

### 9.2. Dashboard

A central hub displaying user documents, recent conversations, and quick access to main features.

### 9.3. Document Upload

A component allowing users to upload DOCX/PDF files or enter text manually, with options for script generation.

### 9.4. Conversation Practice

The core practice interface featuring:

- A script display area.
- Role selection (Person A/B).
- A "Hold to Speak" button with recording status.
- A conversation history log showing user and AI turns.
- A text input alternative to voice recording.

### 9.5. Admin Panel

An administrative interface with tabs for:

- User Management (view, edit, delete users).
- AI Provider Settings (configure and toggle providers).
- System Status (health checks for services).

## 10. Phased Development Roadmap

### Phase 1: Platform Foundation & Core MVP (5-6 months)

- Multi-user authentication and RBAC.
- Document upload and conversion (Mark-It-Down - simulated).
- AI Service Gateway stub.
- Basic frontend and admin dashboard.
- GraphQL API for core data operations.

### Phase 2: Commercial Integration (2-3 months)

- Integration of commercial AI providers (NVIDIA, Google, Amazon, OpenAI).
- Admin configuration for AI providers.
- Full implementation of the AI Gateway with provider abstraction.

### Phase 3: Feedback & Enhancement (2-3 months)

- Pronunciation feedback UI (simulated).
- User testing and iteration.

### Phase 4: Interactive Conversation (3-4 months)

- Turn-based conversation practice implementation.
- Audio recording and processing pipeline (frontend and backend).
- Full integration with STT and TTS services.
- Conversation history and playback features.

## 11. Local Development Setup

### Prerequisites

- Docker
- Docker Compose

### Steps

1. Clone the repository.
2. Create a `.env` file based on `.env.example` and add your API keys:
   ```bash
   cp .env.example .env
   ```
3. Update the `.env` file with your actual API keys and configuration values.
4. Start the application in development mode:
   ```bash
   docker-compose -f docker-compose.dev.yml up --build
   ```
5. Access the services:
   - Frontend: http://localhost:3000
   - Backend GraphQL API: http://localhost:4000/graphql
   - AI Gateway: http://localhost:8001

This will start all the services (frontend, backend, gateway, postgres, redis, minio) as defined in the `docker-compose.dev.yml` file.
