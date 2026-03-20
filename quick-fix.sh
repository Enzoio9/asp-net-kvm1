#!/bin/bash
# Quick Fix Script - Run this to fix the 500 error immediately
# Usage: sudo bash quick-fix.sh

set -e

echo "=========================================="
echo "🔧 Quick Fix for Nginx 500 Error"
echo "=========================================="
echo ""

# Check if running on Windows (WSL) or Linux
if [[ "$(uname -r)" == *"microsoft"* ]]; then
    echo "⚠️  Running on WSL/Windows"
    echo "Note: This script is designed for Linux production servers."
    echo "For development on Windows, run:"
    echo ""
    echo "  cd src/backend"
    echo "  dotnet run"
    echo ""
    exit 1
fi

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_ok() { echo -e "${GREEN}✅${NC} $1"; }
print_warn() { echo -e "${YELLOW}⚠️${NC} $1"; }
print_err() { echo -e "${RED}❌${NC} $1"; }

# Step 1: Stop services
print_warn "Stopping services..."
systemctl stop ollama-web-api 2>/dev/null || true
systemctl stop nginx 2>/dev/null || true
print_ok "Services stopped"

# Step 2: Create directories
print_ok "Creating directories..."
mkdir -p /var/www/dicabr.com.br/data/videos
mkdir -p /var/www/dicabr.com.br/data/images
mkdir -p /var/www/dicabr.com.br/data/database
chmod -R 755 /var/www/dicabr.com.br/data
print_ok "Directories created"

# Step 3: Set permissions
print_ok "Setting permissions..."
chown -R www-data:www-data /var/www/dicabr.com.br/data 2>/dev/null || \
chown -R $USER:$USER /var/www/dicabr.com.br/data || \
print_warn "Could not set ownership, continuing..."

# Step 4: Configure nginx
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/nginx.conf" ]; then
    print_ok "Configuring nginx..."
    cp "$SCRIPT_DIR/nginx.conf" /etc/nginx/sites-available/dicabr.com.br
    ln -sf /etc/nginx/sites-available/dicabr.com.br \
            /etc/nginx/sites-enabled/dicabr.com.br
    
    if nginx -t; then
        print_ok "Nginx configuration valid"
    else
        print_err "Nginx configuration has errors!"
        exit 1
    fi
else
    print_warn "nginx.conf not found in current directory"
    print_warn "Skipping nginx configuration"
fi

# Step 5: Start nginx
print_ok "Starting nginx..."
systemctl start nginx
sleep 2
if systemctl is-active nginx > /dev/null 2>&1; then
    print_ok "Nginx started successfully"
else
    print_warn "Nginx failed to start. Check logs with: journalctl -u nginx"
fi

# Step 6: Build and start application
print_ok "Building application..."
cd "$SCRIPT_DIR/src/backend"

export ASPNETCORE_HTTP_PORTS=8080
export ASPNETCORE_URLS="http://*:8080"
export VIDEO_DIR=/var/www/dicabr.com.br/data/videos
export IMAGE_DIR=/var/www/dicabr.com.br/data/images
export DB_PATH=/var/www/dicabr.com.br/data/database/queue.db
export DOMAIN=dicabr.com.br
export OLLAMA_HOST=http://localhost:11434
export OLLAMA_MODEL=runway/gen2-lite

if dotnet build --configuration Release > /dev/null 2>&1; then
    print_ok "Build successful"
else
    print_err "Build failed!"
    dotnet build --configuration Release
    exit 1
fi

# Step 7: Start application
print_ok "Starting application on port 8080..."
nohup dotnet run --configuration Release > /var/log/ollama-web.log 2>&1 &
APP_PID=$!
echo $APP_PID > /var/run/ollama-web.pid
print_ok "Application started (PID: $APP_PID)"

# Wait for application to start
sleep 5

# Step 8: Test health endpoint
print_ok "Testing application..."
if curl -s http://localhost:8080/health > /dev/null; then
    print_ok "Application is healthy!"
    echo ""
    echo "=========================================="
    echo "✅ FIX COMPLETE!"
    echo "=========================================="
    echo ""
    echo "Your application is now running:"
    echo "  🌐 Direct: http://localhost:8080"
    echo "  📝 API Docs: http://localhost:8080/docs"
    echo "  💚 Health: http://localhost:8080/health"
    echo "  🔄 Via Nginx: http://dicabr.com.br"
    echo ""
    echo "Logs:"
    echo "  App: tail -f /var/log/ollama-web.log"
    echo "  Nginx: tail -f /var/log/nginx/error.log"
    echo ""
    echo "To stop: kill $APP_PID"
    echo ""
else
    print_warn "Application may still be starting..."
    echo ""
    echo "Check logs:"
    echo "  tail -f /var/log/ollama-web.log"
    echo ""
fi
