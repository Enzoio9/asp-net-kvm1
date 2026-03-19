#!/bin/bash
# Installation Script for dicabr.com.br on Hostinger KVM 1 - Arch Linux
# Complete setup of .NET 8, Ollama, and application

set -e

echo "=========================================="
echo "  Installation Script - dicabr.com.br"
echo "  Hostinger KVM 1 - Arch Linux"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
APP_DIR="/var/www/dicabr.com.br"
SERVICE_NAME="dicabr-web"
DOMAIN="dicabr.com.br"

echo -e "${BLUE}Starting installation on Arch Linux...${NC}"
echo ""

# Step 1: System update
echo -e "${YELLOW}Step 1: Updating system packages...${NC}"
sudo pacman -Syu --noconfirm
echo -e "${GREEN}✓ System updated${NC}"
echo ""

# Step 2: Install .NET 8 SDK
echo -e "${YELLOW}Step 2: Installing .NET 8 SDK...${NC}"
sudo pacman -S --noconfirm dotnet-sdk-8.0 aspnet-runtime aspnet-targeting-pack
echo -e "${GREEN}✓ .NET 8 installed${NC}"
dotnet --version
echo ""

# Step 3: Install Ollama
echo -e "${YELLOW}Step 3: Installing Ollama...${NC}"

# Check if Ollama is already installed
if command -v ollama &> /dev/null; then
    echo -e "${GREEN}✓ Ollama already installed${NC}"
else
    # Install using official install script
    curl -fsSL https://ollama.com/install.sh | sh
    echo -e "${GREEN}✓ Ollama installed${NC}"
fi

# Verify Ollama installation
ollama --version
echo ""

# Step 4: Pull runway/gen2-lite model
echo -e "${YELLOW}Step 4: Pulling runway/gen2-lite model...${NC}"
ollama pull runway/gen2-lite
echo -e "${GREEN}✓ Model pulled successfully${NC}"
echo ""

# Step 5: Create application directory
echo -e "${YELLOW}Step 5: Setting up application directory...${NC}"
sudo mkdir -p $APP_DIR
sudo mkdir -p $APP_DIR/data/videos
sudo mkdir -p $APP_DIR/data/images
sudo mkdir -p $APP_DIR/data/database
sudo mkdir -p $APP_DIR/logs
echo -e "${GREEN}✓ Directories created${NC}"
echo ""

# Step 6: Copy application files
echo -e "${YELLOW}Step 6: Copying application files...${NC}"
echo -e "${YELLOW}Please upload your application files to $APP_DIR${NC}"
echo -e "${YELLOW}Or clone from repository:${NC}"
echo ""
read -p "Do you want to clone from Git? (y/n): " clone_choice
if [[ $clone_choice == [Yy]* ]]; then
    read -p "Enter repository URL: " repo_url
    sudo git clone $repo_url $APP_DIR
    echo -e "${GREEN}✓ Repository cloned${NC}"
fi
echo ""

# Step 7: Build application
echo -e "${YELLOW}Step 7: Building ASP.NET Core application...${NC}"
cd $APP_DIR/src/backend
sudo dotnet restore
sudo dotnet build -c Release
sudo dotnet publish -c Release -o $APP_DIR/publish
echo -e "${GREEN}✓ Application built and published${NC}"
echo ""

# Step 8: Set permissions
echo -e "${YELLOW}Step 8: Setting permissions...${NC}"
sudo chown -R http:http $APP_DIR
sudo chmod -R 755 $APP_DIR
echo -e "${GREEN}✓ Permissions set${NC}"
echo ""

# Step 9: Create systemd service
echo -e "${YELLOW}Step 9: Creating systemd service...${NC}"
sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null <<EOF
[Unit]
Description=Ollama Web API - $DOMAIN
After=network.target ollama.service

[Service]
Type=notify
User=http
Group=http
WorkingDirectory=$APP_DIR/publish
ExecStart=/usr/bin/dotnet $APP_DIR/publish/OllamaWebApi.dll
Restart=on-failure
RestartSec=10
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=DOMAIN=$DOMAIN
Environment=ASPNETCORE_HTTP_PORTS=8080
Environment=DB_PATH=$APP_DIR/data/queue.db
Environment=VIDEO_DIR=$APP_DIR/data/videos
Environment=IMAGE_DIR=$APP_DIR/data/images
Environment=OLLAMA_HOST=http://localhost:11434
Environment=OLLAMA_MODEL=runway/gen2-lite
Environment=MAX_CONCURRENT_JOBS=3
SyslogIdentifier=dotnet-dicabr

[Install]
WantedBy=multi-user.target
EOF
echo -e "${GREEN}✓ Service file created${NC}"
echo ""

# Step 10: Create Ollama service (if not exists)
echo -e "${YELLOW}Step 10: Configuring Ollama service...${NC}"
if [ ! -f /etc/systemd/system/ollama.service ]; then
    sudo tee /etc/systemd/system/ollama.service > /dev/null <<EOF
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
Type=exec
User=http
Group=http
ExecStart=/usr/bin/ollama serve
Restart=always
RestartSec=3
Environment="PATH=/usr/bin"
Environment="OLLAMA_HOST=0.0.0.0:11434"

[Install]
WantedBy=multi-user.target
EOF
    echo -e "${GREEN}✓ Ollama service created${NC}"
else
    echo -e "${GREEN}✓ Ollama service already exists${NC}"
fi
echo ""

# Step 11: Enable and start services
echo -e "${YELLOW}Step 11: Enabling and starting services...${NC}"
sudo systemctl daemon-reload
sudo systemctl enable ollama
sudo systemctl start ollama
sleep 2
sudo systemctl enable $SERVICE_NAME
sudo systemctl start $SERVICE_NAME
sleep 2
echo -e "${GREEN}✓ Services started${NC}"
echo ""

# Step 12: Install and configure Nginx (optional)
echo -e "${YELLOW}Step 12: Web server configuration...${NC}"
read -p "Do you want to install and configure Nginx as reverse proxy? (y/n): " nginx_choice
if [[ $nginx_choice == [Yy]* ]]; then
    sudo pacman -S --noconfirm nginx
    
    # Create Nginx config
    sudo tee /etc/nginx/nginx.conf > /dev/null <<EOF
user http;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/conf.d/*.conf;
    
    server {
        listen 80;
        server_name $DOMAIN www.$DOMAIN;
        
        location / {
            proxy_pass         http://localhost:8080;
            proxy_http_version 1.1;
            proxy_set_header   Upgrade \$http_upgrade;
            proxy_set_header   Connection keep-alive;
            proxy_set_header   Host \$host;
            proxy_cache_bypass \$http_upgrade;
            proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header   X-Forwarded-Proto \$scheme;
        }
        
        location /videos/ {
            proxy_pass         http://localhost:8080;
            proxy_http_version 1.1;
            proxy_set_header   Host \$host;
        }
        
        location /images/ {
            proxy_pass         http://localhost:8080;
            proxy_http_version 1.1;
            proxy_set_header   Host \$host;
        }
        
        location /api/ {
            proxy_pass         http://localhost:8080;
            proxy_http_version 1.1;
            proxy_set_header   Host \$host;
        }
        
        location /health {
            proxy_pass         http://localhost:8080;
            proxy_http_version 1.1;
            proxy_set_header   Host \$host;
        }
    }
}
EOF
    
    sudo systemctl enable nginx
    sudo systemctl start nginx
    echo -e "${GREEN}✓ Nginx installed and configured${NC}"
fi
echo ""

# Step 13: Firewall configuration (optional)
echo -e "${YELLOW}Step 13: Firewall configuration...${NC}"
read -p "Do you want to configure firewall? (y/n): " fw_choice
if [[ $fw_choice == [Yy]* ]]; then
    sudo pacman -S --noconfirm ufw
    sudo ufw allow ssh
    sudo ufw allow http
    sudo ufw allow https
    sudo ufw enable
    echo -e "${GREEN}✓ Firewall configured${NC}"
fi
echo ""

# Step 14: Verification
echo -e "${YELLOW}Step 14: Verifying installation...${NC}"
echo ""
echo "Checking Ollama status..."
sudo systemctl status ollama --no-pager -n 5
echo ""
echo "Checking application status..."
sudo systemctl status $SERVICE_NAME --no-pager -n 5
echo ""
echo "Performing health check..."
if curl -f http://localhost:8080/health &> /dev/null; then
    echo -e "${GREEN}✓ Application is healthy${NC}"
    curl -s http://localhost:8080/health | python -m json.tool 2>/dev/null || curl -s http://localhost:8080/health
else
    echo -e "${RED}✗ Health check failed${NC}"
fi
echo ""

# Summary
echo "=========================================="
echo -e "${GREEN}  Installation Complete!${NC}"
echo "=========================================="
echo ""
echo -e "${BLUE}Services:${NC}"
echo "  - Ollama: $(systemctl is-active ollama)"
echo "  - Application: $(systemctl is-active $SERVICE_NAME)"
if [[ $nginx_choice == [Yy]* ]]; then
    echo "  - Nginx: $(systemctl is-active nginx)"
fi
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  - Domain: $DOMAIN"
echo "  - Port: 8080"
echo "  - Ollama Model: runway/gen2-lite"
echo "  - Max Concurrent Jobs: 3"
echo ""
echo -e "${BLUE}URLs:${NC}"
echo "  - Application: http://$DOMAIN"
echo "  - API Docs: http://$DOMAIN/swagger"
echo "  - Health Check: http://$DOMAIN/health"
echo ""
echo -e "${BLUE}Management Commands:${NC}"
echo "  - Start app: sudo systemctl start $SERVICE_NAME"
echo "  - Stop app: sudo systemctl stop $SERVICE_NAME"
echo "  - Restart app: sudo systemctl restart $SERVICE_NAME"
echo "  - View logs: sudo journalctl -u $SERVICE_NAME -f"
echo "  - Ollama logs: sudo journalctl -u ollama -f"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Configure DNS for $DOMAIN"
echo "  2. Set up SSL certificate with certbot"
echo "  3. Test video generation with Ollama"
echo ""
