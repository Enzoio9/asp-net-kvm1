#!/bin/bash
# ============================================================
# Ollama Web Project - Main Installation and Deployment Script
# Production-Ready Setup with Docker Compose
# ============================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="${PROJECT_NAME:-ollama-web}"
CONTAINER_NAME="${CONTAINER_NAME:-ollama-web-backend}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$SCRIPT_DIR/docker"
DATA_DIR="$SCRIPT_DIR/data"
LOGS_DIR="$SCRIPT_DIR/logs"

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

log_step() { echo -e "\n${GREEN}==== $1 ====${NC}\n"; }

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites"
    
    local missing=()
    
    # Check Docker
    if ! command -v docker &>/dev/null; then
        missing+=("Docker")
    else
        log_info "✓ Docker found: $(docker --version)"
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &>/dev/null && ! docker compose version &>/dev/null; then
        missing+=("Docker Compose")
    else
        if command -v docker-compose &>/dev/null; then
            log_info "✓ Docker Compose found: $(docker-compose --version)"
        else
            log_info "✓ Docker Compose found: $(docker compose version)"
        fi
    fi
    
    # Check Git
    if ! command -v git &>/dev/null; then
        missing+=("Git")
    else
        log_info "✓ Git found: $(git --version | head -n1)"
    fi
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing prerequisites: ${missing[*]}"
        log_error "Please install the missing tools and run again."
        exit 1
    fi
    
    log_success "All prerequisites met!"
}

# Create directory structure
create_directories() {
    log_step "Creating directory structure"
    
    mkdir -p "$DATA_DIR"/{videos,images,database,backups}
    mkdir -p "$LOGS_DIR"
    mkdir -p "$DOCKER_DIR"
    
    # Set permissions
    chmod -R 755 "$DATA_DIR" "$LOGS_DIR"
    
    log_success "Directories created successfully"
}

# Setup environment file
setup_environment() {
    log_step "Setting up environment"
    
    if [ ! -f "$SCRIPT_DIR/.env" ]; then
        log_info "Creating .env file from template..."
        cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
        
        # Generate secure API key
        if command -v openssl &>/dev/null; then
            SECURE_KEY=$(openssl rand -hex 32)
            sed -i.bak "s/API_KEY=.*/API_KEY=$SECURE_KEY/" "$SCRIPT_DIR/.env" 2>/dev/null || \
            sed -i '' "s/API_KEY=.*/API_KEY=$SECURE_KEY/" "$SCRIPT_DIR/.env" || true
            rm -f "$SCRIPT_DIR/.env.bak"
            log_info "✓ Generated secure API key"
        fi
        
        log_info "Environment file created at: $SCRIPT_DIR/.env"
        log_warning "Please review and customize the .env file before deployment!"
    else
        log_info "✓ Environment file already exists"
    fi
}

# Setup Caddy configuration
setup_caddy() {
    log_step "Setting up Caddy reverse proxy"
    
    local DOMAIN="${DOMAIN:-localhost}"
    
    cat > "$DOCKER_DIR/Caddyfile" <<EOF
$DOMAIN {
    reverse_proxy ollama-web:8080
    encode gzip
    log {
        output stdout
        format json
    }
    
    # Security headers
    header {
        # Prevent clickjacking
        X-Frame-Options "SAMEORIGIN"
        # XSS protection
        X-XSS-Protection "1; mode=block"
        # Prevent MIME type sniffing
        X-Content-Type-Options "nosniff"
        # Referrer policy
        Referrer-Policy "strict-origin-when-cross-origin"
    }
    
    # Rate limiting (optional, requires Caddy Enterprise)
    # rate_limit {
    #     zone static_key {
    #         match {
    #             method GET
    #         }
    #         rate 100r/s
    #         burst 50
    #     }
    # }
}
EOF
    
    log_success "Caddy configuration created"
}

# Install Docker and dependencies (for fresh systems)
install_docker_if_needed() {
    log_step "Checking Docker installation"
    
    if ! command -v docker &>/dev/null; then
        log_warning "Docker not found. Installing Docker..."
        
        # Detect OS
        if [ -f /etc/debian_version ]; then
            log_info "Detected Debian/Ubuntu system"
            
            # Update package list
            apt-get update
            
            # Install prerequisites
            apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release
            
            # Add Docker's official GPG key
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            
            # Set up stable repository
            echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Install Docker
            apt-get update
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            
            # Start and enable Docker
            systemctl start docker
            systemctl enable docker
            
            log_success "Docker installed successfully!"
            
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            log_info "Detected macOS"
            log_info "Please install Docker Desktop from: https://www.docker.com/products/docker-desktop"
            exit 1
        else
            log_error "Unsupported operating system. Please install Docker manually."
            log_info "Visit: https://docs.docker.com/get-docker/"
            exit 1
        fi
    else
        log_success "✓ Docker is already installed"
    fi
}

# Build and start services
deploy_services() {
    log_step "Building and deploying services"
    
    cd "$DOCKER_DIR"
    
    # Pull or build images
    log_info "Building Docker images (this may take a few minutes)..."
    if command -v docker-compose &>/dev/null; then
        docker-compose build --no-cache
    else
        docker compose build --no-cache
    fi
    
    log_info "Starting services..."
    if command -v docker-compose &>/dev/null; then
        docker-compose up -d
    else
        docker compose up -d
    fi
    
    log_success "Services deployed successfully!"
}

# Wait for services to be healthy
wait_for_services() {
    log_step "Waiting for services to be healthy"
    
    local max_wait=120
    local elapsed=0
    
    log_info "Waiting for backend service..."
    while [ $elapsed -lt $max_wait ]; do
        if curl -sf http://localhost:${HOST_PORT:-8080}/health &>/dev/null; then
            log_success "✓ Backend is healthy!"
            break
        fi
        echo -n "."
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    if [ $elapsed -ge $max_wait ]; then
        log_warning "Backend took longer than expected to start"
    fi
    
    echo ""
}

# Show status
show_status() {
    log_step "Service Status"
    
    cd "$DOCKER_DIR"
    
    if command -v docker-compose &>/dev/null; then
        docker-compose ps
    else
        docker compose ps
    fi
    
    echo ""
    log_info "Logs:"
    log_info "  View all logs: docker-compose logs -f"
    log_info "  Backend logs: docker-compose logs -f ollama-web"
    log_info "  Caddy logs: docker-compose logs -f caddy"
    
    echo ""
    log_success "🎉 Deployment Complete!"
    echo ""
    log_info "Access the application:"
    log_info "  📱 Frontend: http://${DOMAIN:-localhost}"
    log_info "  🔧 API Docs: http://${DOMAIN:-localhost}:${HOST_PORT:-8080}/docs"
    log_info "  💚 Health: http://${DOMAIN:-localhost}:${HOST_PORT:-8080}/health"
    echo ""
}

# Main execution
main() {
    log_info "🚀 Starting Ollama Web Project Installation"
    log_info "Project directory: $SCRIPT_DIR"
    
    check_prerequisites
    create_directories
    setup_environment
    setup_caddy
    deploy_services
    wait_for_services
    show_status
    
    log_success "✅ Installation completed successfully!"
    log_warning "Remember to change the API_KEY in .env for production use!"
}

# Run main function
main "$@"
