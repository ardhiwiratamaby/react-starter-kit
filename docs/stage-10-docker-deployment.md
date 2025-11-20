# Stage 10: Production Docker Deployment

## Stage Overview

This stage implements the complete production deployment configuration for the AI-powered pronunciation assistant using Docker, including production optimizations, security hardening, monitoring, backup strategies, and CI/CD pipelines for automated deployment.

## Observable Outcomes

- ✅ Production Docker Compose configuration
- ✅ Optimized Docker images for production
- ✅ SSL/TLS termination with Nginx
- ✅ Database backup and recovery strategies
- ✅ Monitoring and logging setup
- ✅ CI/CD pipeline configuration
- ✅ Security hardening implemented
- ✅ Performance optimization applied

## Technical Requirements

### Production Infrastructure

- Multi-stage Docker builds for optimization
- Environment-specific configuration management
- Load balancing and SSL termination
- Database replication and backup
- File storage with redundancy
- Container orchestration and scaling

### Security & Compliance

- SSL/TLS encryption everywhere
- Security headers and CSP
- Environment secrets management
- Network segmentation
- Access control and authentication
- Security scanning and vulnerability management

### Monitoring & Operations

- Application performance monitoring
- Log aggregation and analysis
- Health checks and alerting
- Backup and disaster recovery
- Resource usage optimization
- Automated updates and maintenance

## Implementation Details

### Step 1: Production Docker Configuration

#### 1.1 Production Docker Compose

```yaml
# docker-compose.prod.yml
version: "3.8"

services:
  # Nginx Reverse Proxy
  nginx:
    image: nginx:alpine
    container_name: pron-assist-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - static_files:/var/www/static:ro
      - ./nginx/logs:/var/log/nginx
    depends_on:
      - frontend
      - api
    networks:
      - pron-assist-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "nginx", "-t"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Frontend Production Build
  frontend:
    build:
      context: ./apps/app
      target: production
    container_name: pron-assist-frontend
    volumes:
      - static_files:/app/dist
    networks:
      - pron-assist-network
    restart: unless-stopped
    environment:
      - NODE_ENV=production

  # Backend API
  api:
    build:
      context: ./apps/api
      target: production
    container_name: pron-assist-api
    volumes:
      - ./logs/api:/app/logs
    environment:
      - NODE_ENV=production
      - DATABASE_URL=${DATABASE_URL}
      - REDIS_URL=${REDIS_URL}
      - MINIO_URL=${MINIO_URL}
      - MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY}
      - MINIO_SECRET_KEY=${MINIO_SECRET_KEY}
      - BETTER_AUTH_SECRET=${BETTER_AUTH_SECRET}
      - BETTER_AUTH_URL=${BETTER_AUTH_URL}
      - AI_GATEWAY_URL=${AI_GATEWAY_URL}
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
      minio:
        condition: service_healthy
    networks:
      - pron-assist-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  # AI Gateway
  ai-gateway:
    build:
      context: ./apps/ai-gateway
      target: production
    container_name: pron-assist-ai-gateway
    environment:
      - ENVIRONMENT=production
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - GOOGLE_API_KEY=${GOOGLE_API_KEY}
      - AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
      - AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
      - DEEPGRAM_API_KEY=${DEEPGRAM_API_KEY}
      - REDIS_URL=${REDIS_URL}
    networks:
      - pron-assist-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8001/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # PostgreSQL Database with Replica
  postgres-primary:
    image: postgres:15-alpine
    container_name: pron-assist-postgres-primary
    environment:
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_REPLICATION_USER=${POSTGRES_REPLICATION_USER}
      - POSTGRES_REPLICATION_PASSWORD=${POSTGRES_REPLICATION_PASSWORD}
    volumes:
      - postgres_primary_data:/var/lib/postgresql/data
      - postgres_backups:/backups
      - ./database/postgresql.conf:/etc/postgresql/postgresql.conf
      - ./database/pg_hba.conf:/etc/postgresql/pg_hba.conf
    networks:
      - pron-assist-network
    restart: unless-stopped
    command: >
      postgres
      -c config_file=/etc/postgresql/postgresql.conf
      -c max_wal_senders=3
      -c wal_level=replica

  postgres-replica:
    image: postgres:15-alpine
    container_name: pron-assist-postgres-replica
    environment:
      - PGUSER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_MASTER_HOST=postgres-primary
      - POSTGRES_REPLICATION_USER=${POSTGRES_REPLICATION_USER}
      - POSTGRES_REPLICATION_PASSWORD=${POSTGRES_REPLICATION_PASSWORD}
    volumes:
      - postgres_replica_data:/var/lib/postgresql/data
    networks:
      - pron-assist-network
    restart: unless-stopped
    command: >
      bash -c "
      if [ ! -f /var/lib/postgresql/data/PG_VERSION ]; then
        pg_basebackup -h postgres-primary -D /var/lib/postgresql/data -U ${POSTGRES_REPLICATION_USER} -v -P -W
        echo 'standby_mode = on' >> /var/lib/postgresql/data/recovery.conf
        echo 'primary_conninfo = ''host=postgres-primary port=5432 user=${POSTGRES_REPLICATION_USER}''' >> /var/lib/postgresql/data/recovery.conf
      fi
      postgres
      "
    depends_on:
      - postgres-primary

  # Redis Cluster
  redis-master:
    image: redis:7-alpine
    container_name: pron-assist-redis-master
    command: >
      redis-server
      --appendonly yes
      --replica-announce-ip redis-master
    volumes:
      - redis_master_data:/data
    networks:
      - pron-assist-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

  redis-replica:
    image: redis:7-alpine
    container_name: pron-assist-redis-replica
    command: >
      redis-server
      --appendonly yes
      --replicaof redis-master 6379
      --replica-announce-ip redis-replica
    volumes:
      - redis_replica_data:/data
    networks:
      - pron-assist-network
    restart: unless-stopped
    depends_on:
      - redis-master

  # MinIO Object Storage
  minio:
    image: minio/minio:latest
    container_name: pron-assist-minio
    command: server /data --console-address ":9001"
    environment:
      - MINIO_ROOT_USER=${MINIO_ROOT_USER}
      - MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}
    volumes:
      - minio_data:/data
    networks:
      - pron-assist-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 10s
      retries: 3

  # MinIO Setup and Bucket Creation
  minio-setup:
    image: minio/mc:latest
    container_name: pron-assist-minio-setup
    depends_on:
      - minio
    entrypoint: >
      /bin/sh -c "
      /usr/bin/mc alias set myminio http://minio:9000 ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD};
      /usr/bin/mc mb myminio/documents;
      /usr/bin/mc mb myminio/recordings;
      /usr/bin/mc mb myminio/backups;
      /usr/bin/mc mb myminio/temp;
      /usr/bin/mc policy set download myminio/temp;
      /usr/bin/mc admin user add myminio app-user ${MINIO_APP_USER_PASSWORD};
      /usr/bin/mc admin policy set myminio readwrite user=app-user;
      exit 0;
      "
    networks:
      - pron-assist-network
    profiles:
      - setup

  # Prometheus Monitoring
  prometheus:
    image: prom/prometheus:latest
    container_name: pron-assist-prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    command:
      - "--config.file=/etc/prometheus/prometheus.yml"
      - "--storage.tsdb.path=/prometheus"
      - "--web.console.libraries=/etc/prometheus/console_libraries"
      - "--web.console.templates=/etc/prometheus/consoles"
      - "--storage.tsdb.retention.time=200h"
      - "--web.enable-lifecycle"
    networks:
      - pron-assist-network
    restart: unless-stopped

  # Grafana Dashboard
  grafana:
    image: grafana/grafana:latest
    container_name: pron-assist-grafana
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana_data:/var/lib/grafana
      - ./monitoring/grafana/provisioning:/etc/grafana/provisioning
      - ./monitoring/grafana/dashboards:/var/lib/grafana/dashboards
    depends_on:
      - prometheus
    networks:
      - pron-assist-network
    restart: unless-stopped

  # Log Aggregation
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.1
    container_name: pron-assist-elasticsearch
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
      - xpack.security.enabled=false
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data
    networks:
      - pron-assist-network
    restart: unless-stopped

  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.1
    container_name: pron-assist-kibana
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    depends_on:
      - elasticsearch
    networks:
      - pron-assist-network
    restart: unless-stopped

  logstash:
    image: docker.elastic.co/logstash/logstash:8.11.1
    container_name: pron-assist-logstash
    volumes:
      - ./monitoring/logstash/pipeline:/usr/share/logstash/pipeline:ro
      - ./logs:/logs:ro
    depends_on:
      - elasticsearch
    networks:
      - pron-assist-network
    restart: unless-stopped

volumes:
  postgres_primary_data:
    driver: local
  postgres_replica_data:
    driver: local
  postgres_backups:
    driver: local
  redis_master_data:
    driver: local
  redis_replica_data:
    driver: local
  minio_data:
    driver: local
  prometheus_data:
    driver: local
  grafana_data:
    driver: local
  elasticsearch_data:
    driver: local
  static_files:
    driver: local

networks:
  pron-assist-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

#### 1.2 Production Nginx Configuration

```nginx
# nginx/nginx.conf
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging format
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    # Performance optimizations
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 100M;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin";

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;

    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Include site configurations
    include /etc/nginx/conf.d/*.conf;
}
```

```nginx
# nginx/conf.d/pron-assist.conf
server {
    listen 80;
    server_name pron-assist.yourdomain.com www.pron-assist.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name pron-assist.yourdomain.com www.pron-assist.yourdomain.com;

    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    ssl_trusted_certificate /etc/nginx/ssl/chain.pem;

    # Security
    limit_req zone=login burst=5 nodelay;

    # Frontend
    location / {
        root /var/www/static;
        index index.html index.htm;
        try_files $uri $uri/ /index.html;

        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }

        # Security for HTML files
        location ~* \.html$ {
            expires 1h;
            add_header Cache-Control "public, must-revalidate";
        }
    }

    # API
    location /api/ {
        limit_req zone=api burst=20 nodelay;

        proxy_pass http://api:4000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # AI Gateway (internal only)
    location /ai-gateway/ {
        # Restrict to internal access or specific IPs
        allow 127.0.0.1;
        allow 10.0.0.0/8;
        allow 172.16.0.0/12;
        allow 192.168.0.0/16;
        deny all;

        proxy_pass http://ai-gateway:8001/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Health checks
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
    }
}

# Monitoring endpoints (restricted access)
server {
    listen 443 ssl http2;
    server_name monitoring.pron-assist.yourdomain.com;

    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;

    # Restrict access to monitoring
    allow 127.0.0.1;
    allow 10.0.0.0/8;
    allow 172.16.0.0/12;
    allow 192.168.0.0/16;
    # Add your office IP here
    deny all;

    location /prometheus/ {
        proxy_pass http://prometheus:9090/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /grafana/ {
        proxy_pass http://grafana:3000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Step 2: Production Dockerfiles

#### 2.1 Optimized Frontend Dockerfile

```dockerfile
# apps/app/Dockerfile
# Multi-stage build for production optimization

# Base stage with shared dependencies
FROM node:18-alpine AS base
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Development stage
FROM base AS development
RUN npm ci
COPY . .
EXPOSE 3000
CMD ["npm", "run", "dev"]

# Build stage
FROM base AS builder
COPY . .
RUN npm ci
RUN npm run build

# Production stage with Nginx
FROM nginx:alpine AS production
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.prod.conf /etc/nginx/conf.d/default.conf

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

#### 2.2 Optimized Backend Dockerfile

```dockerfile
# apps/api/Dockerfile
FROM oven/bun:1-alpine AS base
WORKDIR /app

# Install production dependencies
FROM base AS deps
COPY package*.json bun.lockb ./
RUN bun install --frozen-lockfile --production

# Build stage
FROM base AS builder
COPY package*.json bun.lockb ./
RUN bun install --frozen-lockfile
COPY . .
RUN bun run build

# Production stage
FROM base AS production
RUN addgroup --system --gid 1001 bun
RUN adduser --system --uid 1001 bun

# Copy production dependencies
COPY --from=deps /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/drizzle ./drizzle

USER bun

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:4000/health || exit 1

EXPOSE 4000
CMD ["bun", "run", "start"]
```

#### 2.3 Optimized AI Gateway Dockerfile

```dockerfile
# apps/ai-gateway/Dockerfile
FROM python:3.11-slim AS base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies
FROM base AS deps
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
FROM base AS production
RUN useradd -m -u 1000 aiuser && chown -R aiuser:aiuser /app
USER aiuser

COPY --from=deps /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=deps /usr/local/bin /usr/local/bin

COPY . .

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8001/health || exit 1

EXPOSE 8001
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8001", "--workers", "4"]
```

### Step 3: Monitoring and Logging Configuration

#### 3.1 Prometheus Configuration

```yaml
# monitoring/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alert_rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - alertmanager:9093

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "pron-assist-api"
    static_configs:
      - targets: ["api:4000"]
    metrics_path: "/metrics"
    scrape_interval: 30s

  - job_name: "pron-assist-ai-gateway"
    static_configs:
      - targets: ["ai-gateway:8001"]
    metrics_path: "/metrics"
    scrape_interval: 30s

  - job_name: "nginx"
    static_configs:
      - targets: ["nginx:9113"]
    scrape_interval: 30s

  - job_name: "postgres"
    static_configs:
      - targets: ["postgres-exporter:9187"]
    scrape_interval: 30s

  - job_name: "redis"
    static_configs:
      - targets: ["redis-exporter:9121"]
    scrape_interval: 30s

  - job_name: "node"
    static_configs:
      - targets: ["node-exporter:9100"]
    scrape_interval: 30s
```

#### 3.2 Alert Rules

```yaml
# monitoring/alert_rules.yml
groups:
  - name: pron-assist-alerts
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value }} errors per second"

      - alert: HighResponseTime
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High response time detected"
          description: "95th percentile response time is {{ $value }} seconds"

      - alert: DatabaseDown
        expr: up{job="postgres"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Database is down"
          description: "PostgreSQL database has been down for more than 1 minute"

      - alert: RedisDown
        expr: up{job="redis"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Redis is down"
          description: "Redis cache has been down for more than 1 minute"

      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage"
          description: "Memory usage is {{ $value | humanizePercentage }}"

      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage"
          description: "CPU usage is {{ $value }}%"
```

### Step 4: CI/CD Pipeline Configuration

#### 4.1 GitHub Actions Workflow

```yaml
# .github/workflows/deploy.yml
name: Deploy to Production

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: pron-assist

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: test_db
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

    steps:
      - uses: actions/checkout@v4

      - name: Setup Bun
        uses: oven-sh/setup-bun@v1
        with:
          bun-version: latest

      - name: Install dependencies
        run: bun install --frozen-lockfile

      - name: Run tests
        run: bun run test
        env:
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test_db

      - name: Run linting
        run: bun run lint

  build:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'

    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}

      - name: Build and push Docker images
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  deploy:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    environment: production

    steps:
      - uses: actions/checkout@v4

      - name: Deploy to server
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.PROD_HOST }}
          username: ${{ secrets.PROD_USER }}
          key: ${{ secrets.PROD_SSH_KEY }}
          script: |
            cd /opt/pron-assistant
            docker-compose -f docker-compose.prod.yml pull
            docker-compose -f docker-compose.prod.yml up -d
            docker system prune -f

      - name: Run database migrations
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.PROD_HOST }}
          username: ${{ secrets.PROD_USER }}
          key: ${{ secrets.PROD_SSH_KEY }}
          script: |
            cd /opt/pron-assistant
            docker-compose -f docker-compose.prod.yml exec -T api bun run db:migrate

      - name: Health check
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.PROD_HOST }}
          username: ${{ secrets.PROD_USER }}
          key: ${{ secrets.PROD_SSH_KEY }}
          script: |
            sleep 30
            curl -f https://pron-assist.yourdomain.com/health || exit 1

  rollback:
    needs: deploy
    runs-on: ubuntu-latest
    if: failure() && github.ref == 'refs/heads/main'

    steps:
      - name: Rollback deployment
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.PROD_HOST }}
          username: ${{ secrets.PROD_USER }}
          key: ${{ secrets.PROD_SSH_KEY }}
          script: |
            cd /opt/pron-assistant
            docker-compose -f docker-compose.prod.yml down
            # Rollback to previous version logic here
            echo "Deployment failed, rolling back..."
            docker-compose -f docker-compose.prod.yml up -d
```

### Step 5: Backup and Recovery Scripts

#### 5.1 Automated Backup Script

```bash
#!/bin/bash
# scripts/backup.sh

set -e

# Configuration
BACKUP_DIR="/opt/backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

# Create backup directory
mkdir -p $BACKUP_DIR

echo "Starting backup process at $(date)"

# Database backup
echo "Creating database backup..."
docker-compose -f docker-compose.prod.yml exec -T postgres pg_dump -U $POSTGRES_USER $POSTGRES_DB | gzip > $BACKUP_DIR/db_backup_$DATE.sql.gz

# File storage backup
echo "Creating file storage backup..."
docker run --rm -v pron-assist_minio_data:/data -v $BACKUP_DIR:/backup alpine tar czf /backup/minio_backup_$DATE.tar.gz -C /data .

# Configuration backup
echo "Creating configuration backup..."
tar czf $BACKUP_DIR/config_backup_$DATE.tar.gz \
    docker-compose.prod.yml \
    .env.prod \
    nginx/ \
    monitoring/

# Clean old backups
echo "Cleaning up old backups..."
find $BACKUP_DIR -name "*.gz" -mtime +$RETENTION_DAYS -delete

# Upload to cloud storage (optional)
if [ ! -z "$AWS_BACKUP_BUCKET" ]; then
    echo "Uploading backups to cloud storage..."
    aws s3 cp $BACKUP_DIR/db_backup_$DATE.sql.gz s3://$AWS_BACKUP_BUCKET/database/
    aws s3 cp $BACKUP_DIR/minio_backup_$DATE.tar.gz s3://$AWS_BACKUP_BUCKET/files/
    aws s3 cp $BACKUP_DIR/config_backup_$DATE.tar.gz s3://$AWS_BACKUP_BUCKET/config/
fi

echo "Backup completed at $(date)"
echo "Backup files created:"
ls -la $BACKUP_DIR/*$DATE*

# Send notification (optional)
if [ ! -z "$SLACK_WEBHOOK_URL" ]; then
    curl -X POST -H 'Content-type: application/json' \
        --data '{"text":"Backup completed successfully for Pronunciation Assistant"}' \
        $SLACK_WEBHOOK_URL
fi
```

#### 5.2 Restore Script

```bash
#!/bin/bash
# scripts/restore.sh

set -e

if [ $# -ne 2 ]; then
    echo "Usage: $0 <backup_date> <backup_type>"
    echo "backup_type: db | files | config | all"
    exit 1
fi

BACKUP_DATE=$1
BACKUP_TYPE=$2
BACKUP_DIR="/opt/backups"

echo "Starting restore process at $(date)"
echo "Backup date: $BACKUP_DATE"
echo "Backup type: $BACKUP_TYPE"

# Database restore
if [ "$BACKUP_TYPE" == "db" ] || [ "$BACKUP_TYPE" == "all" ]; then
    echo "Restoring database..."
    gunzip -c $BACKUP_DIR/db_backup_$BACKUP_DATE.sql.gz | \
        docker-compose -f docker-compose.prod.yml exec -T postgres psql -U $POSTGRES_USER $POSTGRES_DB
fi

# Files restore
if [ "$BACKUP_TYPE" == "files" ] || [ "$BACKUP_TYPE" == "all" ]; then
    echo "Restoring file storage..."
    docker run --rm -v pron-assist_minio_data:/data -v $BACKUP_DIR:/backup alpine \
        tar xzf /backup/minio_backup_$BACKUP_DATE.tar.gz -C /data
fi

# Configuration restore
if [ "$BACKUP_TYPE" == "config" ] || [ "$BACKUP_TYPE" == "all" ]; then
    echo "Restoring configuration..."
    tar xzf $BACKUP_DIR/config_backup_$BACKUP_DATE.tar.gz -C /opt/pron-assistant/
fi

echo "Restore completed at $(date)"
echo "Restarting services..."
docker-compose -f docker-compose.prod.yml restart

echo "Restore process completed successfully"
```

### Step 6: Security Hardening

#### 6.1 Security Script

```bash
#!/bin/bash
# scripts/security-hardening.sh

echo "Applying security hardening..."

# Set secure file permissions
chmod 600 .env.prod
chmod 600 nginx/ssl/*
chmod 700 scripts/

# Create non-root user for containers if not exists
# (This is handled in Dockerfiles)

# Configure fail2ban for nginx
apt-get update && apt-get install -y fail2ban
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 5

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
logpath = /var/log/nginx/error.log
maxretry = 10

[nginx-noscript]
enabled = true
filter = nginx-noscript
logpath = /var/log/nginx/access.log
maxretry = 6
EOF

systemctl enable fail2ban
systemctl start fail2ban

# Configure automatic security updates
apt-get install -y unattended-upgrades
echo 'Unattended-Upgrade::Automatic-Reboot "false";' >> /etc/apt/apt.conf.d/50unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

# Set up log rotation
cat > /etc/logrotate.d/pron-assistant << EOF
/opt/pron-assistant/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        docker-compose -f /opt/pron-assistant/docker-compose.prod.yml restart nginx
    endscript
}
EOF

echo "Security hardening completed"
```

## Deployment Instructions

### Initial Setup

```bash
# 1. Clone repository and set up environment
git clone <repository-url>
cd pronunciation-assistant
cp .env.example .env.prod

# 2. Edit environment variables
nano .env.prod

# 3. Generate SSL certificates (Let's Encrypt)
certbot certonly --webroot -w /var/www/html -d pron-assist.yourdomain.com

# 4. Copy certificates to nginx directory
cp /etc/letsencrypt/live/pron-assist.yourdomain.com/fullchain.pem nginx/ssl/
cp /etc/letsencrypt/live/pron-assist.yourdomain.com/privkey.pem nginx/ssl/
cp /etc/letsencrypt/live/pron-assist.yourdomain.com/chain.pem nginx/ssl/

# 5. Create directories
mkdir -p logs/{api,nginx}
mkdir -p backups
chmod 700 backups

# 6. Set up monitoring (optional)
mkdir -p monitoring/{prometheus,grafana,logstash}

# 7. Deploy
docker-compose -f docker-compose.prod.yml up -d

# 8. Run database migrations
docker-compose -f docker-compose.prod.yml exec api bun run db:migrate

# 9. Set up MinIO buckets
docker-compose -f docker-compose.prod.yml --profile setup up minio-setup

# 10. Verify deployment
curl -f https://pron-assist.yourdomain.com/health
```

### Maintenance Tasks

```bash
# Update deployment
docker-compose -f docker-compose.prod.yml pull
docker-compose -f docker-compose.prod.yml up -d

# Backup
./scripts/backup.sh

# Log monitoring
docker-compose -f docker-compose.prod.yml logs -f

# Performance monitoring
# Access Grafana at https://monitoring.pron-assist.yourdomain.com

# Security updates
./scripts/security-hardening.sh
```

## Success Criteria

- [ ] Production Docker images optimized and working
- [ ] SSL/TLS encryption configured and functional
- [ ] Load balancing and reverse proxy operational
- [ ] Database replication and backups working
- [ ] Monitoring and alerting configured
- [ ] Log aggregation and analysis working
- [ ] CI/CD pipeline automated
- [ ] Security hardening applied
- [ ] Backup and recovery procedures tested
- [ ] Performance optimization implemented
- [ ] Health checks and monitoring active
- [ ] Disaster recovery plan in place

This comprehensive production deployment setup provides a secure, scalable, and maintainable foundation for the AI-powered pronunciation assistant with full observability and operational excellence.
