#!/bin/bash
# Ollama Web API - Startup and Troubleshooting Script
# This script helps start the application and diagnose issues

set -e

echo "🚀 Ollama Web API - Startup Script"
echo "=================================="
echo ""

# Configuration
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$APP_DIR/src/backend"
DATA_DIR="/var/www/dicabr.com.br/data"
VIDEO_DIR="$DATA_DIR/videos"
IMAGE_DIR="$DATA_DIR/images"
DATABASE_DIR="$DATA_DIR/database"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✅${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_warning "This script should be run with sudo for full functionality"
fi

echo "📁 Application Directory: $APP_DIR"
echo "📁 Backend Directory: $BACKEND_DIR"
echo ""

# Step 1: Create necessary directories
print_status "Creating data directories..."
mkdir -p "$VIDEO_DIR"
mkdir -p "$IMAGE_DIR"
mkdir -p "$DATABASE_DIR"
chmod -R 755 "$DATA_DIR"
print_status "Directories created successfully"

# Step 2: Set environment variables
export ASPNETCORE_HTTP_PORTS=8080
export ASPNETCORE_URLS="http://*:8080"
export DOMAIN="${DOMAIN:-dicabr.com.br}"
export API_KEY="${API_KEY:-ollama-web-secret-key-change-in-production}"
export ENABLE_AUTH="${ENABLE_AUTH:-false}"
export MAX_CONCURRENT_JOBS="${MAX_CONCURRENT_JOBS:-3}"
export MAX_QUEUE_SIZE="${MAX_QUEUE_SIZE:-100}"
export OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
export OLLAMA_MODEL="${OLLAMA_MODEL:-runway/gen2-lite}"
export VIDEO_DIR="$VIDEO_DIR"
export IMAGE_DIR="$IMAGE_DIR"
export DB_PATH="$DATABASE_DIR/queue.db"

print_status "Environment variables configured"
echo "   Domain: $DOMAIN"
echo "   Port: $ASPNETCORE_HTTP_PORTS"
echo "   Ollama Host: $OLLAMA_HOST"
echo "   Ollama Model: $OLLAMA_MODEL"
echo ""

# Step 3: Check if Ollama is running
print_status "Checking Ollama service..."
if command -v ollama &> /dev/null; then
    if ! pgrep -x "ollama" > /dev/null; then
        print_warning "Ollama is not running. Starting Ollama..."
        ollama serve &
        sleep 3
    fi
    print_status "Ollama is running"
else
    print_warning "Ollama not installed. The app will use remote Ollama at $OLLAMA_HOST"
fi

# Step 4: Build the application
print_status "Building the application..."
cd "$BACKEND_DIR"
dotnet restore
dotnet build --configuration Release
print_status "Build successful"

# Step 5: Test database connection
print_status "Testing database connection..."
if [ ! -f "$DB_PATH" ]; then
    print_warning "Database doesn't exist. It will be created on first run."
fi

# Step 6: Start the application
print_status "Starting ASP.NET Core application..."
echo ""
echo "📊 Application starting on port 8080..."
echo "🌐 Domain: $DOMAIN"
echo "📝 API Docs: http://localhost:8080/docs"
echo "💚 Health Check: http://localhost:8080/health"
echo ""
echo "Press Ctrl+C to stop the application"
echo ""

# Start the application
dotnet run --configuration Release --project "$BACKEND_DIR/OllamaWebApi.csproj"
