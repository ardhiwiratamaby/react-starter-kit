#!/bin/bash

# Pronunciation Assistant Service Management Script
# Provides unified control over all project services

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_DIR="$PROJECT_ROOT/.pids"
LOG_DIR="$PROJECT_ROOT/.logs"

# Create necessary directories
mkdir -p "$PID_DIR" "$LOG_DIR"

# Managed ports
MANAGED_PORTS=(3000 4000 4321 5001 5173 5174 8000 8001 9000 9001 5050 5432 6379)

# Service configurations
declare -A SERVICES
SERVICES[postgres]="5432 PostgreSQL"
SERVICES[redis]="6379 Redis"
SERVICES[minio]="9000,9001 MinIO"
SERVICES[web]="4321 Astro Web"
SERVICES[app]="5173 Vite App"
SERVICES[api]="4000 tRPC API"
SERVICES[ai-gateway]="8001 AI Gateway"
SERVICES[docling]="5001 Docling"
SERVICES[qwen3]="8000 Qwen3 Inference"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "${PURPLE}=== $1 ===${NC}"
}

# Port management functions
is_port_in_use() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

get_process_on_port() {
    local port=$1
    lsof -ti:$port 2>/dev/null || echo ""
}

kill_process_on_port() {
    local port=$1
    local pids=$(get_process_on_port $port)

    if [[ -n "$pids" ]]; then
        log_info "Killing processes on port $port (PIDs: $pids)"
        echo "$pids" | xargs kill -TERM 2>/dev/null || true
        sleep 2

        # Force kill if still running
        pids=$(get_process_on_port $port)
        if [[ -n "$pids" ]]; then
            log_warning "Force killing processes on port $port"
            echo "$pids" | xargs kill -9 2>/dev/null || true
        fi

        # Final check
        if is_port_in_use $port; then
            log_error "Failed to kill processes on port $port"
            return 1
        else
            log_success "Port $port is now free"
            return 0
        fi
    else
        log_info "Port $port is already free"
        return 0
    fi
}

kill_all_processes_on_ports() {
    log_header "Killing All Processes on Managed Ports"

    local killed_any=false
    for port in "${MANAGED_PORTS[@]}"; do
        if is_port_in_use $port; then
            killed_any=true
            local process_info=$(lsof -i:$port -n -P 2>/dev/null | tail -n +2)
            log_warning "Port $port is in use:"
            echo "$process_info"

            if kill_process_on_port $port; then
                log_success "Successfully killed processes on port $port"
            else
                log_error "Failed to kill processes on port $port"
            fi
        fi
    done

    if ! $killed_any; then
        log_info "No managed ports are currently in use"
    fi

    # Additional cleanup for common processes
    log_info "Performing additional process cleanup..."

    # Kill Node.js processes that might be related
    pkill -f "node.*vite" 2>/dev/null || true
    pkill -f "node.*astro" 2>/dev/null || true
    pkill -f "bun.*dev" 2>/dev/null || true

    # Kill Python processes for AI services
    pkill -f "uvicorn.*main:app" 2>/dev/null || true
    pkill -f "python.*ai-gateway" 2>/dev/null || true

    # Clean up PID files
    rm -f "$PID_DIR"/*.pid 2>/dev/null || true

    log_success "Process cleanup completed"
}

# Docker service management
is_docker_running() {
    local service_name=$1
    if docker ps --format "table {{.Names}}" | grep -q "^pronounciation-assistant-claudecode_${service_name}_1$"; then
        return 0
    else
        return 1
    fi
}

start_docker_services() {
    log_header "Starting Docker Services"

    cd "$PROJECT_ROOT"

    # Check if docker-compose.dev.yml exists
    if [[ ! -f "docker-compose.dev.yml" ]]; then
        log_error "docker-compose.dev.yml not found"
        return 1
    fi

    # Start only infrastructure services
    log_info "Starting Docker infrastructure services..."
    docker-compose -f docker-compose.dev.yml up -d postgres redis minio 2>&1 | tee "$LOG_DIR/docker-start.log"

    # Wait for services to be ready
    log_info "Waiting for Docker services to be ready..."
    sleep 5

    # Check if services are running
    local all_running=true
    for service in postgres redis minio; do
        if is_docker_running $service; then
            # Handle services with multiple ports (like MinIO)
            local port_info="${SERVICES[$service]}"
            log_success "Docker $service is running on ports $port_info"
        else
            log_error "Docker $service failed to start"
            all_running=false
        fi
    done

    if $all_running; then
        log_success "All Docker services started successfully"
        echo
        show_docker_service_urls
    else
        log_error "Some Docker services failed to start"
        return 1
    fi
}

stop_docker_services() {
    log_header "Stopping Docker Services"

    cd "$PROJECT_ROOT"

    if [[ -f "docker-compose.dev.yml" ]]; then
        log_info "Stopping Docker services..."
        docker-compose -f docker-compose.dev.yml down 2>&1 | tee "$LOG_DIR/docker-stop.log"
        log_success "Docker services stopped"
    else
        log_info "No docker-compose.dev.yml found, skipping Docker stop"
    fi
}

# Local development server management
start_dev_servers() {
    log_header "Starting Local Development Servers"

    cd "$PROJECT_ROOT"

    # Ensure Bun is available
    if ! command -v bun &> /dev/null; then
        export PATH="$HOME/.bun/bin:$PATH"
        if ! command -v bun &> /dev/null; then
            log_error "Bun is not installed or not in PATH"
            return 1
        fi
    fi

    # Check if ports are available
    for service in "web:4321" "app:5173" "app:5174" "api:4000"; do
        local service_name=${service%:*}
        local port=${service#*:}
        if is_port_in_use $port; then
            log_warning "Port $port is already in use, will attempt to kill processes"
            kill_process_on_port $port
        fi
    done

    # Start development servers in background
    log_info "Starting development servers..."

    # Kill any existing dev processes
    pkill -f "bun.*dev" 2>/dev/null || true
    sleep 2

    # Start new dev processes
    export PATH="$HOME/.bun/bin:$PATH"
    nohup bun run dev > "$LOG_DIR/dev-servers.log" 2>&1 &
    local dev_pid=$!
    echo $dev_pid > "$PID_DIR/dev-servers.pid"

    log_info "Development servers starting with PID: $dev_pid"
    log_info "Waiting for servers to initialize..."

    # Wait and check if servers started successfully
    sleep 10

    local started_count=0
    # Check web service
    if is_port_in_use 4321; then
        log_success "web started on port 4321"
        ((started_count++))
    else
        log_warning "web may not have started properly"
    fi

    # Check app service on both possible ports
    local app_started=false
    for port in 5173 5174; do
        if is_port_in_use $port; then
            log_success "app started on port $port"
            ((started_count++))
            app_started=true
            break
        fi
    done
    if ! $app_started; then
        log_warning "app may not have started properly"
    fi

    if [[ $started_count -gt 0 ]]; then
        log_success "$started_count development services started"
        log_info "Logs available at: $LOG_DIR/dev-servers.log"
    else
        log_error "No development services started successfully"
        return 1
    fi
}

stop_dev_servers() {
    log_header "Stopping Local Development Servers"

    # Stop using PID file if available
    if [[ -f "$PID_DIR/dev-servers.pid" ]]; then
        local dev_pid=$(cat "$PID_DIR/dev-servers.pid")
        if kill -0 $dev_pid 2>/dev/null; then
            log_info "Stopping development servers (PID: $dev_pid)"
            kill -TERM $dev_pid 2>/dev/null || true
            sleep 3
            kill -9 $dev_pid 2>/dev/null || true
        fi
        rm -f "$PID_DIR/dev-servers.pid"
    fi

    # Kill any remaining dev processes
    log_info "Killing any remaining development processes..."
    pkill -f "bun.*dev" 2>/dev/null || true
    pkill -f "node.*vite" 2>/dev/null || true
    pkill -f "node.*astro" 2>/dev/null || true

    log_success "Development servers stopped"
}

# External AI services (already running Docker containers)
start_external_services() {
    log_header "Starting External Services"

    # Check if external services are already running
    local docling_running=false
    local qwen3_running=false

    if docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -q "docling-serve"; then
        log_success "Docling service is already running"
        docling_running=true
    fi

    if docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -q "qwen3-4b-inference"; then
        log_success "Qwen3 inference service is already running"
        qwen3_running=true
    fi

    if ! $docling_running; then
        log_warning "Docling service is not running - please start it manually if needed"
    fi

    if ! $qwen3_running; then
        log_warning "Qwen3 inference service is not running - please start it manually if needed"
    fi
}

# Display Docker service URLs
show_docker_service_urls() {
    log_header "Docker Service URLs"

    echo -e "\n${CYAN}Infrastructure Services:${NC}"

    # PostgreSQL
    if is_docker_running postgres; then
        echo -e "  ${GREEN}●${NC} PostgreSQL - Port: 5432"
        echo -e "     Connection: postgresql://localhost:5432/pronunciation_assistant"
        echo -e "     Management: Use DBeaver or psql to connect"
    fi

    # Redis
    if is_docker_running redis; then
        echo -e "  ${GREEN}●${NC} Redis - Port: 6379"
        echo -e "     Connection: redis://localhost:6379"
        echo -e "     Management: Use Redis CLI or GUI tools"
    fi

    # MinIO
    if is_docker_running minio; then
        echo -e "  ${GREEN}●${NC} MinIO - Ports: 9000 (API), 9001 (Console)"
        echo -e "     API: http://localhost:9000"
        echo -e "     Console: http://localhost:9001"
        echo -e "     Default credentials: minioadmin/minioadmin (check docker-compose.dev.yml)"
    fi

    echo -e "\n${CYAN}Quick Access:${NC}"
    echo -e "  🗄️  ${BLUE}MinIO Console:${NC} http://localhost:9001"
    echo -e "  🔴 ${BLUE}Redis:${NC} redis-cli -h localhost -p 6379"
    echo -e "  🐘 ${BLUE}PostgreSQL:${NC} psql -h localhost -p 5432 -U postgres -d pronunciation_assistant"
    echo

    # Show Docker container status (simplified format)
    echo -e "${CYAN}Docker Container Status:${NC}"
    if command -v docker &> /dev/null; then
        cd "$PROJECT_ROOT"
        if [[ -f "docker-compose.dev.yml" ]]; then
            echo
            docker-compose -f docker-compose.dev.yml ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
        fi
    fi
}

# Status checking
show_status() {
    log_header "Service Status"

    echo -e "\n${CYAN}Docker Infrastructure Services:${NC}"
    for service in postgres redis minio; do
        local port=${SERVICES[$service]%% *}
        if is_docker_running $service; then
            echo -e "  ${GREEN}●${NC} $service (port $port) - Running"
        else
            echo -e "  ${RED}●${NC} $service (port $port) - Stopped"
        fi
    done

    echo -e "\n${CYAN}Development Services:${NC}"
    # Check web and API services
    for service_pair in "web:4321" "api:4000"; do
        local service_name=${service_pair%:*}
        local port=${service_pair#*:}
        if is_port_in_use $port; then
            local process_info=$(lsof -i:$port -n -P 2>/dev/null | tail -n +2 | head -n1)
            echo -e "  ${GREEN}●${NC} $service_name (port $port) - Running ($process_info)"
        else
            echo -e "  ${RED}●${NC} $service_name (port $port) - Stopped"
        fi
    done

    # Check app service on both possible ports
    local app_running=false
    local app_port=""
    for port in 5173 5174; do
        if is_port_in_use $port; then
            app_running=true
            app_port=$port
            local process_info=$(lsof -i:$port -n -P 2>/dev/null | tail -n +2 | head -n1)
            echo -e "  ${GREEN}●${NC} app (port $port) - Running ($process_info)"
            break
        fi
    done
    if ! $app_running; then
        echo -e "  ${RED}●${NC} app (port 5173/5174) - Stopped"
    fi

    echo -e "\n${CYAN}External AI Services:${NC}"
    if docker ps --format "table {{.Names}}" | grep -q "docling-serve"; then
        echo -e "  ${GREEN}●${NC} Docling (port 5001) - Running"
    else
        echo -e "  ${RED}●${NC} Docling (port 5001) - Stopped"
    fi

    if docker ps --format "table {{.Names}}" | grep -q "qwen3-4b-inference"; then
        echo -e "  ${GREEN}●${NC} Qwen3 Inference (port 8000) - Running"
    else
        echo -e "  ${RED}●${NC} Qwen3 Inference (port 8000) - Stopped"
    fi

    echo -e "\n${CYAN}AI Gateway:${NC}"
    if is_port_in_use 8001; then
        echo -e "  ${GREEN}●${NC} AI Gateway (port 8001) - Running"
    else
        echo -e "  ${RED}●${NC} AI Gateway (port 8001) - Stopped"
    fi

    echo -e "\n${CYAN}Port Summary:${NC}"
    echo "Managed ports: ${MANAGED_PORTS[*]}"
    local used_ports=()
    for port in "${MANAGED_PORTS[@]}"; do
        if is_port_in_use $port; then
            used_ports+=($port)
        fi
    done

    if [[ ${#used_ports[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Ports in use: ${used_ports[*]}${NC}"
    else
        echo -e "${GREEN}All managed ports are free${NC}"
    fi
}

# Show logs
show_logs() {
    log_header "Service Logs"

    echo -e "\n${CYAN}Development Servers:${NC}"
    if [[ -f "$LOG_DIR/dev-servers.log" ]]; then
        tail -n 50 "$LOG_DIR/dev-servers.log"
    else
        echo "No development server logs found"
    fi

    echo -e "\n${CYAN}Docker Services:${NC}"
    if command -v docker-compose &> /dev/null && [[ -f "$PROJECT_ROOT/docker-compose.dev.yml" ]]; then
        cd "$PROJECT_ROOT"
        docker-compose -f docker-compose.dev.yml logs --tail=20 2>/dev/null || echo "No Docker logs available"
    fi
}

# Main command functions
start_services() {
    log_header "Starting All Services"

    # Kill any existing processes first
    kill_all_processes_on_ports

    echo
    start_docker_services
    echo
    start_external_services
    echo
    start_dev_servers
    echo

    log_success "Service startup completed"
    show_status
}

stop_services() {
    log_header "Stopping All Services"

    stop_dev_servers
    echo
    stop_docker_services
    echo
    kill_all_processes_on_ports
    echo

    log_success "All services stopped and ports cleaned up"
}

restart_services() {
    log_info "Restarting all services..."
    stop_services
    sleep 3
    start_services
}

force_kill_all() {
    log_header "Force Killing Everything"
    kill_all_processes_on_ports

    # Additional forceful cleanup
    log_info "Performing force cleanup of all related processes..."

    # Kill any remaining processes
    pkill -f "pronunciation-assistant" 2>/dev/null || true
    pkill -f "vite" 2>/dev/null || true
    pkill -f "astro" 2>/dev/null || true
    pkill -f "trpc" 2>/dev/null || true
    pkill -f "next" 2>/dev/null || true
    pkill -f "uvicorn" 2>/dev/null || true
    pkill -f "fastapi" 2>/dev/null || true

    # Clean up all temp files
    rm -rf "$PID_DIR" 2>/dev/null || true

    log_success "Force kill completed"
    show_status
}

# Help function
show_help() {
    cat << EOF
Pronunciation Assistant Service Management Script

USAGE:
    $0 [COMMAND]

COMMANDS:
    start       Start all services in dependency order
    stop        Stop all services AND kill all processes on managed ports
    status      Show current status of all services
    restart     Restart all services
    logs        Show logs from all services
    docker      Manage Docker services only
    dev         Manage development servers only
    kill        Force kill everything on all managed ports
    help        Show this help message

MANAGED PORTS:
    ${MANAGED_PORTS[*]}

SERVICES:
    - Docker Infrastructure: PostgreSQL (5432), Redis (6379), MinIO (9000, 9001)
    - Development: Astro Web (4321), Vite App (5174), tRPC API (4000)
    - AI Services: AI Gateway (8001), Docling (5001), Qwen3 Inference (8000)

EXAMPLES:
    $0 start          # Start all services
    $0 stop           # Stop all services completely
    $0 status         # Check what's running
    $0 kill           # Force kill everything

EOF
}

# Main script logic
case "${1:-help}" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    status)
        show_status
        ;;
    restart)
        restart_services
        ;;
    logs)
        show_logs
        ;;
    docker)
        case "${2:-status}" in
            start)
                start_docker_services
                ;;
            stop)
                stop_docker_services
                ;;
            status)
                show_status
                ;;
            *)
                echo "Usage: $0 docker {start|stop|status}"
                exit 1
                ;;
        esac
        ;;
    dev)
        case "${2:-status}" in
            start)
                start_dev_servers
                ;;
            stop)
                stop_dev_servers
                ;;
            status)
                show_status
                ;;
            *)
                echo "Usage: $0 dev {start|stop|status}"
                exit 1
                ;;
        esac
        ;;
    kill)
        force_kill_all
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac