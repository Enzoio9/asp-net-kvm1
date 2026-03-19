#!/bin/bash
# ============================================================
# Ollama Web Project - Management Script
# Start, Stop, Restart, Monitor, and Maintenance Operations
# ============================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$SCRIPT_DIR/docker"
PROJECT_NAME="${PROJECT_NAME:-ollama-web}"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[⚠]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

# Check if running from correct directory
check_context() {
    if [ ! -f "$DOCKER_DIR/docker-compose.yml" ]; then
        log_error "docker-compose.yml not found in $DOCKER_DIR"
        exit 1
    fi
}

# Docker compose command (compatible with v1 and v2)
docker_compose() {
    cd "$DOCKER_DIR"
    if command -v docker-compose &>/dev/null; then
        docker-compose "$@"
    else
        docker compose "$@"
    fi
}

# Start services
start_services() {
    log_info "Starting Ollama Web services..."
    docker_compose up -d
    log_success "Services started successfully!"
    
    log_info "Waiting for services to be ready..."
    sleep 10
    
    if curl -sf http://localhost:${HOST_PORT:-8080}/health &>/dev/null; then
        log_success "Backend is healthy and running!"
    else
        log_warning "Backend may still be starting. Check logs with: $0 logs"
    fi
}

# Stop services
stop_services() {
    log_info "Stopping Ollama Web services..."
    docker_compose down
    log_success "Services stopped successfully!"
}

# Restart services
restart_services() {
    log_info "Restarting Ollama Web services..."
    stop_services
    sleep 2
    start_services
}

# Rebuild services
rebuild_services() {
    log_info "Rebuilding and restarting services..."
    docker_compose build --no-cache
    docker_compose up -d --force-recreate
    log_success "Services rebuilt and restarted!"
}

# View logs
view_logs() {
    local service="${1:-}"
    
    if [ -n "$service" ]; then
        log_info "Viewing logs for $service..."
        docker_compose logs -f "$service"
    else
        log_info "Viewing all logs..."
        docker_compose logs -f
    fi
}

# Show status
show_status() {
    log_info "Service Status:"
    echo ""
    docker_compose ps
    echo ""
    
    log_info "Resource Usage:"
    docker stats --no-stream $(docker_compose ps -q) 2>/dev/null || log_warning "Unable to get stats"
}

# Backup data
backup_data() {
    local backup_dir="$SCRIPT_DIR/backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    log_info "Creating backup in $backup_dir..."
    
    # Backup database
    if [ -f "$SCRIPT_DIR/data/database/queue.db" ]; then
        cp "$SCRIPT_DIR/data/database/queue.db" "$backup_dir/"
        log_success "✓ Database backed up"
    fi
    
    # Backup configuration
    cp "$SCRIPT_DIR/.env" "$backup_dir/" 2>/dev/null || true
    log_success "✓ Configuration backed up"
    
    # Backup videos metadata (not the actual videos to save space)
    log_info "Generating video inventory..."
    find "$SCRIPT_DIR/data/videos" -type f -name "*.mp4" -exec ls -lh {} \; > "$backup_dir/videos_inventory.txt" 2>/dev/null || true
    
    log_success "Backup completed: $backup_dir"
}

# Clean up
cleanup() {
    log_warning "This will remove all containers, networks, and volumes!"
    read -p "Are you sure? (y/N): " confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        log_info "Cleaning up..."
        docker_compose down -v --remove-orphans
        log_success "Cleanup completed!"
    else
        log_info "Cleanup cancelled"
    fi
}

# Health check
health_check() {
    log_info "Running health checks..."
    
    local backend_health=$(curl -sf http://localhost:${HOST_PORT:-8080}/health 2>/dev/null)
    
    if [ -n "$backend_health" ]; then
        log_success "✓ Backend is healthy"
        echo "$backend_health" | python3 -m json.tool 2>/dev/null || echo "$backend_health"
    else
        log_error "✗ Backend is not responding"
    fi
    
    echo ""
    
    # Check container health
    log_info "Container Status:"
    docker_compose ps
}

# Execute command inside container
exec_in_container() {
    local service="${1:-ollama-web}"
    shift
    local cmd="$*"
    
    if [ -z "$cmd" ]; then
        log_error "Please provide a command to execute"
        exit 1
    fi
    
    log_info "Executing in $service: $cmd"
    docker_compose exec "$service" bash -c "$cmd"
}

# Database operations
database_ops() {
    local action="${1:-status}"
    local db_file="$SCRIPT_DIR/data/database/queue.db"
    
    case "$action" in
        status)
            if [ -f "$db_file" ]; then
                local size=$(du -h "$db_file" | cut -f1)
                log_success "Database exists (Size: $size)"
                
                local count=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM jobs;" 2>/dev/null || echo "N/A")
                log_info "Total jobs in database: $count"
            else
                log_warning "Database not found"
            fi
            ;;
        export)
            if [ -f "$db_file" ]; then
                local export_file="$SCRIPT_DIR/backups/db_export_$(date +%Y%m%d_%H%M%S).sql"
                mkdir -p "$(dirname "$export_file")"
                sqlite3 "$db_file" ".dump" > "$export_file"
                log_success "Database exported to: $export_file"
            else
                log_error "Database not found"
            fi
            ;;
        vacuum)
            if [ -f "$db_file" ]; then
                sqlite3 "$db_file" "VACUUM;"
                log_success "Database vacuumed successfully"
            else
                log_error "Database not found"
            fi
            ;;
        *)
            log_error "Unknown action: $action. Use: status, export, vacuum"
            exit 1
            ;;
    esac
}

# Show help
show_help() {
    cat << EOF
${GREEN}Ollama Web Project - Management Script${NC}

${BLUE}Usage:${NC} $0 <command> [options]

${BLUE}Commands:${NC}
  ${GREEN}start${NC}              Start all services
  ${GREEN}stop${NC}               Stop all services
  ${GREEN}restart${NC}            Restart all services
  ${GREEN}rebuild${NC}            Rebuild and restart services
  ${GREEN}logs [service]${NC}     View logs (optionally filter by service)
  ${GREEN}status${NC}             Show service status
  ${GREEN}health${NC}             Run health checks
  ${GREEN}backup${NC}             Create backup of data and config
  ${GREEN}cleanup${NC}            Remove all containers and volumes
  ${GREEN}exec <service> <cmd>${NC} Execute command in container
  ${GREEN}db <action>${NC}        Database operations (status, export, vacuum)
  ${GREEN}help${NC}               Show this help message

${BLUE}Examples:${NC}
  $0 start                  # Start all services
  $0 logs ollama-web        # View backend logs
  $0 exec ollama-web "ls"   # Execute 'ls' in backend container
  $0 db export              # Export database

EOF
}

# Main
main() {
    check_context
    
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        start)
            start_services
            ;;
        stop)
            stop_services
            ;;
        restart)
            restart_services
            ;;
        rebuild)
            rebuild_services
            ;;
        logs)
            view_logs "$@"
            ;;
        status)
            show_status
            ;;
        health)
            health_check
            ;;
        backup)
            backup_data
            ;;
        cleanup)
            cleanup
            ;;
        exec)
            exec_in_container "$@"
            ;;
        db)
            database_ops "$@"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
