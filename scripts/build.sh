#!/bin/bash
# Build and Deploy Script for dicabr.com.br
# ASP.NET Core Application

set -e

echo "=========================================="
echo "  Build Script - dicabr.com.br"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/src/backend" && pwd)"
PUBLISH_DIR="/var/www/dicabr.com.br/publish"
SERVICE_NAME="dicabr-web"

echo -e "${YELLOW}Backend Directory: $BACKEND_DIR${NC}"
echo -e "${YELLOW}Publish Directory: $PUBLISH_DIR${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (sudo ./build.sh)${NC}"
    exit 1
fi

# Step 1: Restore dependencies
echo -e "${YELLOW}Step 1: Restoring dependencies...${NC}"
cd "$BACKEND_DIR"
dotnet restore
echo -e "${GREEN}✓ Dependencies restored${NC}"
echo ""

# Step 2: Build application
echo -e "${YELLOW}Step 2: Building application...${NC}"
dotnet build -c Release --no-restore
echo -e "${GREEN}✓ Build successful${NC}"
echo ""

# Step 3: Publish application
echo -e "${YELLOW}Step 3: Publishing application...${NC}"
dotnet publish -c Release -o "$PUBLISH_DIR" --no-build
echo -e "${GREEN}✓ Published to $PUBLISH_DIR${NC}"
echo ""

# Step 4: Set permissions
echo -e "${YELLOW}Step 4: Setting permissions...${NC}"
chown -R www-data:www-data "$PUBLISH_DIR"
chmod -R 755 "$PUBLISH_DIR"
mkdir -p /var/www/dicabr.com.br/data
chown www-data:www-data /var/www/dicabr.com.br/data
echo -e "${GREEN}✓ Permissions set${NC}"
echo ""

# Step 5: Restart service
echo -e "${YELLOW}Step 5: Restarting service...${NC}"
systemctl daemon-reload
systemctl restart $SERVICE_NAME
sleep 2
echo -e "${GREEN}✓ Service restarted${NC}"
echo ""

# Step 6: Check status
echo -e "${YELLOW}Checking service status...${NC}"
systemctl status $SERVICE_NAME --no-pager -n 10
echo ""

# Step 7: Health check
echo -e "${YELLOW}Performing health check...${NC}"
if curl -f http://localhost:8080/health &> /dev/null; then
    echo -e "${GREEN}✓ Application is healthy${NC}"
    curl -s http://localhost:8080/health | python3 -m json.tool 2>/dev/null || curl -s http://localhost:8080/health
else
    echo -e "${RED}✗ Health check failed${NC}"
    exit 1
fi
echo ""

echo "=========================================="
echo -e "${GREEN}  Deployment Complete!${NC}"
echo "=========================================="
echo ""
echo "Application URL: http://dicabr.com.br"
echo "API Docs: http://dicabr.com.br/swagger"
echo "Health Check: http://dicabr.com.br/health"
echo ""
