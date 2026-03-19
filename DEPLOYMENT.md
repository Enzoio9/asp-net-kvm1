# 🚀 Deployment Guide - dicabr.com.br on Hostinger KVM

## ASP.NET Core Application Deployment Instructions

This guide covers deploying the Ollama Web API to Hostinger's KVM VPS hosting.

---

## 📋 Prerequisites

- Hostinger KVM VPS (KVM 1 or higher)
- Domain: `dicabr.com.br` pointed to your VPS
- SSH access to your server
- Root or sudo privileges

---

## 🔧 Step 1: Server Setup

### 1.1 Connect to your VPS via SSH
```bash
ssh user@your-vps-ip
```

### 1.2 Update system packages
```bash
sudo apt update && sudo apt upgrade -y
```

---

## 📦 Step 2: Install .NET 8 SDK

### 2.1 Download and install .NET 8
```bash
# Download Microsoft package signing key
wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb

# Install .NET SDK
sudo apt update
sudo apt install -y dotnet-sdk-8.0
```

### 2.2 Verify installation
```bash
dotnet --version
# Should show: 8.0.x
```

---

## 🌐 Step 3: Install Web Server (Nginx or Apache)

### Option A: Nginx (Recommended)
```bash
sudo apt install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx
```

### Option B: Apache with mod_proxy
```bash
sudo apt install -y apache2 libapache2-mod-proxy-html
sudo a2enmod proxy
sudo a2enmod proxy_http
sudo systemctl start apache2
sudo systemctl enable apache2
```

---

## 📁 Step 4: Deploy the Application

### 4.1 Create application directory
```bash
sudo mkdir -p /var/www/dicabr.com.br
cd /var/www/dicabr.com.br
```

### 4.2 Copy application files
Upload your application files using FTP/SFTP or git:
```bash
# If using Git
git clone <your-repository-url> .
```

Or copy files manually to `/var/www/dicabr.com.br`

### 4.3 Set permissions
```bash
sudo chown -R www-data:www-data /var/www/dicabr.com.br
sudo chmod -R 755 /var/www/dicabr.com.br
```

---

## 🔨 Step 5: Build and Publish

### 5.1 Navigate to backend directory
```bash
cd /var/www/dicabr.com.br/src/backend
```

### 5.2 Restore dependencies
```bash
dotnet restore
```

### 5.3 Publish the application
```bash
dotnet publish -c Release -o /var/www/dicabr.com.br/publish
```

---

## ⚙️ Step 6: Configure Web Server

### For Nginx:

Create site configuration:
```bash
sudo nano /etc/nginx/sites-available/dicabr.com.br
```

Add this configuration:
```nginx
server {
    listen 80;
    server_name dicabr.com.br www.dicabr.com.br;

    location / {
        proxy_pass         http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade $http_upgrade;
        proxy_set_header   Connection keep-alive;
        proxy_set_header   Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }

    location /videos/ {
        proxy_pass         http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header   Host $host;
    }

    location /images/ {
        proxy_pass         http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header   Host $host;
    }

    location /api/ {
        proxy_pass         http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header   Host $host;
    }

    location /health {
        proxy_pass         http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header   Host $host;
    }
}
```

Enable the site:
```bash
sudo ln -s /etc/nginx/sites-available/dicabr.com.br /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### For Apache:

Create virtual host:
```bash
sudo nano /etc/apache2/sites-available/dicabr.com.br.conf
```

Add this configuration:
```apache
<VirtualHost *:80>
    ServerName dicabr.com.br
    ServerAlias www.dicabr.com.br
    
    ProxyPreserveHost On
    ProxyPass / http://localhost:8080/
    ProxyPassReverse / http://localhost:8080/
    
    # WebSocket support
    RewriteEngine On
    RewriteCond %{HTTP:Upgrade} websocket [NC]
    RewriteCond %{HTTP:Connection} upgrade [NC]
    RewriteRule ^/(.*) "ws://localhost:8080/$1" [P,L]
</VirtualHost>
```

Enable the site:
```bash
sudo a2ensite dicabr.com.br.conf
sudo systemctl restart apache2
```

---

## 🔄 Step 7: Create Systemd Service

Create service file:
```bash
sudo nano /etc/systemd/system/dicabr-web.service
```

Add the following:
```ini
[Unit]
Description=Ollama Web API - dicabr.com.br
After=network.target

[Service]
Type=notify
User=www-data
Group=www-data
WorkingDirectory=/var/www/dicabr.com.br/publish
ExecStart=/usr/bin/dotnet /var/www/dicabr.com.br/publish/OllamaWebApi.dll
Restart=on-failure
RestartSec=10
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=DOMAIN=dicabr.com.br
Environment=ASPNETCORE_HTTP_PORTS=8080
Environment=DB_PATH=/var/www/dicabr.com.br/data/queue.db
Environment=MAX_CONCURRENT_JOBS=3
SyslogIdentifier=dotnet-dicabr

[Install]
WantedBy=multi-user.target
```

Enable and start the service:
```bash
sudo systemctl daemon-reload
sudo systemctl enable dicabr-web
sudo systemctl start dicabr-web
sudo systemctl status dicabr-web
```

---

## 🔒 Step 8: SSL Certificate (Optional but Recommended)

Install Certbot:
```bash
sudo apt install -y certbot python3-certbot-nginx  # For Nginx
# OR
sudo apt install -y certbot python3-certbot-apache  # For Apache
```

Obtain SSL certificate:
```bash
sudo certbot --nginx -d dicabr.com.br -d www.dicabr.com.br
# OR
sudo certbot --apache -d dicabr.com.br -d www.dicabr.com.br
```

Auto-renewal is configured automatically. Test it:
```bash
sudo certbot renew --dry-run
```

---

## ✅ Step 9: Verify Deployment

### 9.1 Check service status
```bash
sudo systemctl status dicabr-web
```

### 9.2 View logs
```bash
sudo journalctl -u dicabr-web -f
```

### 9.3 Test health endpoint
```bash
curl http://localhost:8080/health
```

### 9.4 Test from browser
Visit: `http://dicabr.com.br`

Expected response:
```json
{
  "status": "healthy",
  "domain": "dicabr.com.br",
  "timestamp": "2026-03-19T...",
  "active_workers": 3
}
```

---

## 🛠️ Management Commands

### Start/Stop/Restart Application
```bash
sudo systemctl start dicabr-web
sudo systemctl stop dicabr-web
sudo systemctl restart dicabr-web
```

### View Real-time Logs
```bash
sudo journalctl -u dicabr-web -f
```

### Check Application Logs
```bash
tail -f /var/www/dicabr.com.br/logs/stdout.log
```

### Rebuild Application
```bash
cd /var/www/dicabr.com.br/src/backend
dotnet restore
dotnet publish -c Release -o /var/www/dicabr.com.br/publish
sudo systemctl restart dicabr-web
```

---

## 🗄️ Database Location

The SQLite database will be created at:
```
/var/www/dicabr.com.br/data/queue.db
```

Backup command:
```bash
cp /var/www/dicabr.com.br/data/queue.db ~/queue-backup-$(date +%Y%m%d).db
```

---

## 📊 Monitoring

### Check if application is running
```bash
curl http://localhost:8080/health
```

### Check resource usage
```bash
htop
# Filter by: dotnet
```

### Check disk usage
```bash
df -h
du -sh /var/www/dicabr.com.br/*
```

---

## 🔧 Troubleshooting

### Application won't start
```bash
# Check logs
sudo journalctl -u dicabr-web --no-pager -n 50

# Verify .NET installation
dotnet --version

# Check if port is in use
sudo netstat -tulpn | grep :8080
```

### Permission issues
```bash
sudo chown -R www-data:www-data /var/www/dicabr.com.br
sudo chmod -R 755 /var/www/dicabr.com.br
```

### Database errors
```bash
# Ensure data directory exists
mkdir -p /var/www/dicabr.com.br/data
sudo chown www-data:www-data /var/www/dicabr.com.br/data
```

### 502 Bad Gateway
```bash
# Check if backend is running
sudo systemctl status dicabr-web

# Restart if needed
sudo systemctl restart dicabr-web
```

---

## 📝 Environment Variables

Configure these in `/etc/systemd/system/dicabr-web.service`:

- `DOMAIN=dicabr.com.br` - Your domain
- `ASPNETCORE_HTTP_PORTS=8080` - Application port
- `DB_PATH=/var/www/dicabr.com.br/data/queue.db` - Database path
- `MAX_CONCURRENT_JOBS=3` - Number of worker threads
- `API_KEY=your-secret-key` - Change in production!
- `ENABLE_AUTH=false` - Enable/disable authentication

After changing environment variables:
```bash
sudo systemctl daemon-reload
sudo systemctl restart dicabr-web
```

---

## 🎯 Next Steps

1. **Configure Firewall**: Allow only necessary ports (80, 443, 22)
2. **Set up monitoring**: Consider adding Application Insights or similar
3. **Regular backups**: Automate database backups
4. **Update strategy**: Plan for zero-downtime deployments
5. **Security hardening**: Regular security updates

---

## 📞 Support

For issues specific to Hostinger:
- Hostinger Support: https://www.hostinger.com/contact
- Documentation: https://www.hostinger.com/tutorials

For ASP.NET Core issues:
- Official Docs: https://docs.microsoft.com/en-us/aspnet/core/
- GitHub Issues: https://github.com/dotnet/aspnetcore/issues

---

**Deployment completed! Your application is now running at:**
- 🌐 http://dicabr.com.br
- 🔗 API: http://dicabr.com.br/api/v1/jobs
- 📖 Swagger: http://dicabr.com.br/swagger
