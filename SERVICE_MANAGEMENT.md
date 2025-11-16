# Service Management Script Documentation

## Overview

The `manage.sh` script provides unified control over all services in the Pronunciation Assistant project. It handles both Docker infrastructure services and local development servers with comprehensive port cleanup.

## Quick Start

```bash
# Make executable (first time only)
chmod +x manage.sh

# Start all services
./manage.sh start

# Check what's running
./manage.sh status

# Stop everything and clean up ports
./manage.sh stop
```

## Services Managed

### Docker Infrastructure Services

- **PostgreSQL** (Port 5432) - Primary database
- **Redis** (Port 6379) - Cache and session storage
- **MinIO** (Ports 9000/9001) - S3-compatible object storage

### Development Services

- **Astro Web** (Port 4321) - Static site and documentation
- **Vite App** (Port 5174) - Main React frontend application
- **tRPC API** (Port 4000) - Backend API service

### AI Services

- **AI Gateway** (Port 8001) - FastAPI service for AI operations
- **Docling** (Port 5001) - Document processing service (external)
- **Qwen3 Inference** (Port 8000) - AI model inference (external)

## Commands

### Main Commands

```bash
./manage.sh start         # Start all services in dependency order
./manage.sh stop          # Stop all services AND kill all processes on managed ports
./manage.sh status        # Show current status of all services
./manage.sh restart       # Restart all services
./manage.sh logs          # Show logs from all services
./manage.sh kill          # Force kill everything on all managed ports
./manage.sh help          # Show help message
```

### Service-Specific Commands

```bash
./manage.sh docker start  # Start only Docker services
./manage.sh docker stop   # Stop only Docker services
./manage.sh docker status # Show Docker service status

./manage.sh dev start     # Start only development servers
./manage.sh dev stop      # Stop only development servers
./manage.sh dev status    # Show development server status
```

## Port Management

### Managed Ports

The script monitors and manages these ports: `3000 4000 4321 5001 5174 8000 8001 9000 9001 5050 5432 6379`

### Aggressive Cleanup

The `stop` command performs **comprehensive port cleanup**:

1. **Graceful Shutdown**: Attempts SIGTERM first
2. **Force Kill**: Uses SIGKILL if processes don't stop
3. **Port Hunting**: Finds and kills any remaining processes on managed ports
4. **Process Pattern Matching**: Kills processes by name patterns
5. **Cleanup Verification**: Ensures all ports are actually free

### Port Conflict Resolution

- Automatically detects port conflicts before starting services
- Kills conflicting processes before attempting to start
- Provides clear feedback about what's using each port

## Usage Examples

### Development Workflow

```bash
# Start everything for development
./manage.sh start

# Check if everything is running
./manage.sh status

# View logs if something's wrong
./manage.sh logs

# Stop everything when done
./manage.sh stop
```

### Troubleshooting

```bash
# Check what's running
./manage.sh status

# Force kill everything if things get stuck
./manage.sh kill

# Restart specific service groups
./manage.sh docker restart
./manage.sh dev restart
```

### Individual Service Management

```bash
# Start only infrastructure (for backend work)
./manage.sh docker start

# Start only frontend (for UI work)
./manage.sh dev start

# Stop just the dev servers
./manage.sh dev stop
```

## Service URLs

After starting services, you can access them at:

- **Main App**: http://localhost:5174/ (React application)
- **Web Site**: http://localhost:4321/ (Astro site)
- **API Docs**: http://localhost:4000/ (tRPC API)
- **AI API Docs**: http://localhost:8001/docs (FastAPI Swagger)
- **MinIO Console**: http://localhost:9001 (Storage admin)
- **MinIO API**: http://localhost:9000 (Storage API)

## File Structure

```
project-root/
├── manage.sh              # Main management script
├── .pids/                 # Process ID files (auto-created)
├── .logs/                 # Service logs (auto-created)
├── docker-compose.dev.yml # Docker services configuration
└── apps/                  # Application code
```

## Environment Setup

The script expects these environment variables to be set in `.env`:

```bash
# Database
DATABASE_URL=postgresql://postgres:password@localhost:5432/pronunciation_assistant

# Cache
REDIS_URL=redis://localhost:6379

# Storage
MINIO_URL=http://localhost:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin

# AI Services
AI_GATEWAY_URL=http://localhost:8001
OPENAI_API_KEY=your-key-here
GOOGLE_API_KEY=your-key-here

# Authentication
BETTER_AUTH_SECRET=your-secret-key
BETTER_AUTH_URL=http://localhost:4000
```

## Troubleshooting

### Common Issues

**"Port already in use" errors:**

```bash
# Force cleanup
./manage.sh kill
# Or manually check what's using the port
lsof -i :4321
```

**Services not starting:**

```bash
# Check logs
./manage.sh logs
# Or check individual service logs
tail -f .logs/dev-servers.log
```

**Docker services not starting:**

```bash
# Check Docker is running
docker ps
# Restart Docker daemon if needed
sudo systemctl restart docker
```

### Getting Help

```bash
# Show all available commands
./manage.sh help

# Check current status
./manage.sh status

# View recent logs
./manage.sh logs
```

## Script Features

### Smart Service Detection

- Automatically detects which services are already running
- Avoids conflicts between local and Docker services
- Health checks for critical dependencies

### Process Management

- Backgrounds all services with proper PID tracking
- Graceful shutdown handling
- Multiple termination methods (SIGTERM → SIGKILL)
- Comprehensive cleanup of orphaned processes

### Logging

- Centralized log storage in `.logs/` directory
- Real-time log access with `./manage.sh logs`
- Separate logs for different service types

### Color-Coded Output

- Green: Success/Running services
- Red: Errors/Stopped services
- Yellow: Warnings
- Blue: Information
- Purple: Headers

## Best Practices

1. **Always use `./manage.sh stop`** before closing your terminal to ensure proper cleanup
2. **Check status first** with `./manage.sh status` before starting services
3. **Use `./manage.sh kill`** only when normal shutdown doesn't work
4. **Monitor logs** when troubleshooting issues with `./manage.sh logs`
5. **Keep script updated** when adding new services or changing ports

## Integration with Development Workflow

### IDE Integration

You can integrate the script into your IDE for easy service management:

**VS Code Tasks** (add to `.vscode/tasks.json`):

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Start All Services",
      "type": "shell",
      "command": "./manage.sh",
      "args": ["start"],
      "group": "build"
    },
    {
      "label": "Stop All Services",
      "type": "shell",
      "command": "./manage.sh",
      "args": ["stop"],
      "group": "build"
    }
  ]
}
```

### Git Hooks

Consider adding a pre-push hook to ensure services are stopped:

```bash
#!/bin/sh
# .git/hooks/pre-push
./manage.sh status > /dev/null 2>&1 && ./manage.sh stop
```

This ensures clean state when switching between branches or development sessions.
