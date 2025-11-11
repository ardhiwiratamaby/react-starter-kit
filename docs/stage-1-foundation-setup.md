# Stage 1: Foundation Setup with Docker

## Stage Overview

This stage focuses on establishing the complete Docker-based development environment by adapting the React Starter Kit for containerized deployment. We'll set up the foundational architecture that will support the entire pronunciation assistant application.

## Observable Outcomes

- ✅ Forked React Starter Kit with Docker configuration
- ✅ Working Docker Compose development environment
- ✅ All services containerized and communicating
- ✅ Development hot-reload functioning
- ✅ Project structure optimized for pronunciation features

## Technical Requirements

### Core Services to Containerize
1. **Frontend** - React app (apps/app) with development server
2. **Backend API** - tRPC/Hono server (apps/api)
3. **Database** - PostgreSQL with persistent storage
4. **File Storage** - MinIO S3-compatible storage
5. **Caching** - Redis for sessions and caching
6. **Email Service** - SMTP or Resend integration

### Development Tools
- Bun runtime for local development
- Hot reload for all services
- Volume mounts for live code changes
- Development database with seed data

## Implementation Details

### Step 1: Repository Setup

#### 1.1 Fork React Starter Kit
```bash
# Clone the starter kit
git clone https://github.com/kriasoft/react-starter-kit.git pronunciation-assistant
cd pronunciation-assistant

# Update package.json and project metadata
# Remove unnecessary starter-kit specific configurations
# Prepare for Docker-based deployment
```

#### 1.2 Project Structure Adaptation
```
pronunciation-assistant/
├── apps/
│   ├── app/              # React frontend (adapted from starter kit)
│   ├── api/              # tRPC backend (adapted from starter kit)
│   └── ai-gateway/       # New: AI service gateway
├── packages/
│   ├── ui/               # Shared UI components (from starter kit)
│   ├── core/             # Core business logic (adapted)
│   └── database/         # Database schemas and utilities
├── docker/               # Docker configurations
├── docs/                 # Documentation (stage plans)
├── scripts/              # Build and deployment scripts
├── docker-compose.dev.yml # Development environment
├── docker-compose.prod.yml # Production environment
└── README.md
```

### Step 2: Docker Configuration

#### 2.1 Frontend Dockerfile
```dockerfile
# apps/app/Dockerfile
FROM node:18-alpine AS base

# Install dependencies
FROM base AS deps
WORKDIR /app
COPY package*.json ./
RUN bun install --frozen-lockfile

# Build the application
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN bun run build

# Development stage
FROM base AS development
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
EXPOSE 3000
CMD ["bun", "run", "dev"]

# Production stage
FROM nginx:alpine AS production
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

#### 2.2 Backend API Dockerfile
```dockerfile
# apps/api/Dockerfile
FROM oven/bun:1-alpine AS base

WORKDIR /app
COPY package*.json ./
RUN bun install --frozen-lockfile

COPY . .

FROM base AS development
EXPOSE 4000
CMD ["bun", "run", "dev"]

FROM base AS production
RUN bun run build
EXPOSE 4000
CMD ["bun", "run", "start"]
```

#### 2.3 AI Gateway Dockerfile
```dockerfile
# apps/ai-gateway/Dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8001
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8001"]
```

### Step 3: Docker Compose Configuration

#### 3.1 Development Environment
```yaml
# docker-compose.dev.yml
version: '3.8'

services:
  # Frontend Development Server
  frontend:
    build:
      context: ./apps/app
      target: development
    ports:
      - "3000:3000"
    volumes:
      - ./apps/app:/app
      - /app/node_modules
    environment:
      - NODE_ENV=development
      - VITE_API_URL=http://localhost:4000
    depends_on:
      - api
    networks:
      - pronunciation-network

  # Backend API
  api:
    build:
      context: ./apps/api
      target: development
    ports:
      - "4000:4000"
    volumes:
      - ./apps/api:/app
      - /app/node_modules
    environment:
      - NODE_ENV=development
      - DATABASE_URL=postgresql://postgres:password@postgres:5432/pronunciation_assistant
      - REDIS_URL=redis://redis:6379
      - MINIO_URL=http://minio:9000
      - MINIO_ACCESS_KEY=minioadmin
      - MINIO_SECRET_KEY=minioadmin
      - BETTER_AUTH_SECRET=your-secret-key
      - BETTER_AUTH_URL=http://localhost:4000
    depends_on:
      - postgres
      - redis
      - minio
    networks:
      - pronunciation-network

  # AI Service Gateway
  ai-gateway:
    build:
      context: ./apps/ai-gateway
    ports:
      - "8001:8001"
    volumes:
      - ./apps/ai-gateway:/app
    environment:
      - ENVIRONMENT=development
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - GOOGLE_API_KEY=${GOOGLE_API_KEY}
      - AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
      - AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
    networks:
      - pronunciation-network

  # PostgreSQL Database
  postgres:
    image: postgres:15-alpine
    ports:
      - "5432:5432"
    environment:
      - POSTGRES_DB=pronunciation_assistant
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=password
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./database/init:/docker-entrypoint-initdb.d
    networks:
      - pronunciation-network

  # Redis Cache
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    networks:
      - pronunciation-network

  # MinIO Object Storage
  minio:
    image: minio/minio:latest
    ports:
      - "9000:9000"
      - "9001:9001"
    environment:
      - MINIO_ROOT_USER=minioadmin
      - MINIO_ROOT_PASSWORD=minioadmin
    volumes:
      - minio_data:/data
    command: server /data --console-address ":9001"
    networks:
      - pronunciation-network

  # PostgreSQL Admin Interface
  pgadmin:
    image: dpage/pgadmin4:latest
    ports:
      - "5050:80"
    environment:
      - PGADMIN_DEFAULT_EMAIL=admin@pronunciation.com
      - PGADMIN_DEFAULT_PASSWORD=admin
    depends_on:
      - postgres
    networks:
      - pronunciation-network

volumes:
  postgres_data:
  redis_data:
  minio_data:

networks:
  pronunciation-network:
    driver: bridge
```

#### 3.2 Production Environment
```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  # Nginx Reverse Proxy
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./nginx/ssl:/etc/nginx/ssl
      - static_files:/var/www/static
    depends_on:
      - frontend
      - api
    networks:
      - pronunciation-network

  # Frontend Production Build
  frontend:
    build:
      context: ./apps/app
      target: production
    volumes:
      - static_files:/var/www/static
    networks:
      - pronunciation-network

  # Backend API Production
  api:
    build:
      context: ./apps/api
      target: production
    environment:
      - NODE_ENV=production
      - DATABASE_URL=${DATABASE_URL}
      - REDIS_URL=${REDIS_URL}
      - MINIO_URL=${MINIO_URL}
      - MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY}
      - MINIO_SECRET_KEY=${MINIO_SECRET_KEY}
      - BETTER_AUTH_SECRET=${BETTER_AUTH_SECRET}
      - BETTER_AUTH_URL=${BETTER_AUTH_URL}
    depends_on:
      - postgres
      - redis
      - minio
    networks:
      - pronunciation-network

  # AI Gateway Production
  ai-gateway:
    build:
      context: ./apps/ai-gateway
    environment:
      - ENVIRONMENT=production
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - GOOGLE_API_KEY=${GOOGLE_API_KEY}
      - AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
      - AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
    networks:
      - pronunciation-network

  # Database (without exposed ports in production)
  postgres:
    image: postgres:15-alpine
    environment:
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - pronunciation-network

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    networks:
      - pronunciation-network

  minio:
    image: minio/minio:latest
    environment:
      - MINIO_ROOT_USER=${MINIO_ROOT_USER}
      - MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}
    volumes:
      - minio_data:/data
    command: server /data
    networks:
      - pronunciation-network

volumes:
  postgres_data:
  redis_data:
  minio_data:
  static_files:

networks:
  pronunciation-network:
    driver: bridge
```

### Step 4: Environment Configuration

#### 4.1 Environment Variables Template
```bash
# .env.example
# Database
DATABASE_URL=postgresql://postgres:password@localhost:5432/pronunciation_assistant
POSTGRES_DB=pronunciation_assistant
POSTGRES_USER=postgres
POSTGRES_PASSWORD=password

# Redis
REDIS_URL=redis://localhost:6379

# MinIO
MINIO_URL=http://localhost:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin

# Authentication
BETTER_AUTH_SECRET=your-super-secret-key-here
BETTER_AUTH_URL=http://localhost:4000

# AI Services
OPENAI_API_KEY=your-openai-api-key
GOOGLE_API_KEY=your-google-api-key
AWS_ACCESS_KEY_ID=your-aws-access-key
AWS_SECRET_ACCESS_KEY=your-aws-secret-key

# Email (optional)
RESEND_API_KEY=your-resend-api-key
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
```

### Step 5: Development Scripts

#### 5.1 Package.json Scripts
```json
{
  "scripts": {
    "dev": "docker-compose -f docker-compose.dev.yml up --build",
    "dev:detached": "docker-compose -f docker-compose.dev.yml up --build -d",
    "down": "docker-compose -f docker-compose.dev.yml down",
    "clean": "docker-compose -f docker-compose.dev.yml down -v",
    "logs": "docker-compose -f docker-compose.dev.yml logs -f",
    "db:migrate": "docker-compose -f docker-compose.dev.yml exec api bun run db:migrate",
    "db:seed": "docker-compose -f docker-compose.dev.yml exec api bun run db:seed",
    "prod:build": "docker-compose -f docker-compose.prod.yml build",
    "prod:up": "docker-compose -f docker-compose.prod.yml up -d",
    "prod:down": "docker-compose -f docker-compose.prod.yml down"
  }
}
```

## Database Schema

### Initial Tables (Stage 1)
```sql
-- Basic user schema (will be extended in Stage 2)
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  name VARCHAR(255) NOT NULL,
  role VARCHAR(50) DEFAULT 'USER',
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Basic session storage
CREATE TABLE sessions (
  id VARCHAR(255) PRIMARY KEY,
  user_id INTEGER REFERENCES users(id),
  expires_at TIMESTAMP NOT NULL,
  data JSONB
);
```

## API Endpoints

### Initial Health Checks
```typescript
// apps/api/src/routes/health.ts
export const healthRouter = router({
  check: procedure.query(() => ({
    status: 'ok',
    timestamp: new Date().toISOString(),
    services: {
      database: 'connected', // Will check actual connection
      redis: 'connected',
      minio: 'connected'
    }
  }))
})
```

## UI Components

### Basic Layout Structure
```typescript
// apps/app/src/components/layout/Layout.tsx
import React from 'react';
import { Header } from './Header';
import { Sidebar } from './Sidebar';

export const Layout: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  return (
    <div className="min-h-screen bg-gray-50">
      <Header />
      <div className="flex">
        <Sidebar />
        <main className="flex-1 p-6">
          {children}
        </main>
      </div>
    </div>
  );
};
```

## Integration Points

### Prerequisites for Next Stage
- Database connection established and tested
- Basic authentication endpoints accessible
- File storage system operational
- Development environment reproducible

## Testing Strategy

### Health Check Tests
```bash
# Test all services are running
curl http://localhost:3000  # Frontend
curl http://localhost:4000/health  # Backend API
curl http://localhost:8001/health  # AI Gateway
```

### Database Connection Test
```bash
# Verify database connectivity
docker-compose -f docker-compose.dev.yml exec api bun run db:check
```

## Estimated Timeline: 2 Weeks

### Week 1: Foundation
- Day 1-2: Repository setup and structure adaptation
- Day 3-4: Dockerfile creation and testing
- Day 5: Basic Docker Compose configuration

### Week 2: Integration and Testing
- Day 1-2: Service networking and environment setup
- Day 3-4: Development scripts and tooling
- Day 5: End-to-end testing and documentation

## Success Criteria

- [ ] All services start with `npm run dev`
- [ ] Frontend accessible at http://localhost:3000
- [ ] Backend API accessible at http://localhost:4000
- [ ] Database connection established
- [ ] Hot reload working for all services
- [ ] MinIO console accessible at http://localhost:9001
- [ ] Redis connection verified
- [ ] Production build completes successfully

## Troubleshooting

### Common Issues
1. **Port conflicts** - Ensure ports 3000, 4000, 5432, 6379, 9000, 9001 are available
2. **Permission issues** - Check Docker permissions and volume mounts
3. **Network issues** - Verify all containers are on the same Docker network
4. **Environment variables** - Ensure all required variables are set

### Debug Commands
```bash
# View logs for all services
npm run logs

# View logs for specific service
docker-compose -f docker-compose.dev.yml logs -f frontend

# Execute commands in container
docker-compose -f docker-compose.dev.yml exec api sh

# Rebuild specific service
docker-compose -f docker-compose.dev.yml up --build frontend
```

This foundation provides the containerized development environment needed for all subsequent stages of the pronunciation assistant development.