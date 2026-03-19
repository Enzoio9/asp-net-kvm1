# 🚀 Quick Start Guide - dicabr.com.br on Hostinger KVM 1 (Arch Linux)

## Complete Installation in 5 Minutes

### 1️⃣ Connect to your VPS
```bash
ssh root@your-vps-ip
```

### 2️⃣ Clone the repository
```bash
cd /var/www
git clone <your-repository-url> dicabr.com.br
cd dicabr.com.br
```

### 3️⃣ Make installer executable
```bash
chmod +x scripts/install-archlinux.sh
```

### 4️⃣ Run the installer
```bash
sudo ./scripts/install-archlinux.sh
```

The script will automatically:
- ✅ Update Arch Linux system
- ✅ Install .NET 8 SDK
- ✅ Install Ollama
- ✅ Pull runway/gen2-lite model
- ✅ Build and configure ASP.NET application
- ✅ Create systemd services
- ✅ Configure Nginx (optional)
- ✅ Set up firewall (optional)

---

## 🔧 Manual Installation Steps

If you prefer manual installation:

### Install .NET 8
```bash
sudo pacman -S --noconfirm dotnet-sdk-8.0 aspnet-runtime aspnet-targeting-pack
```

### Install Ollama
```bash
curl -fsSL https://ollama.com/install.sh | sh
```

### Pull the model
```bash
ollama pull runway/gen2-lite
```

### Build the application
```bash
cd /var/www/dicabr.com.br/src/backend
dotnet restore
dotnet publish -c Release -o /var/www/dicabr.com.br/publish
```

### Start services
```bash
sudo systemctl start ollama
sudo systemctl enable ollama
sudo systemctl start dicabr-web
sudo systemctl enable dicabr-web
```

---

## ✅ Verify Installation

### Check Ollama
```bash
ollama list
# Should show: runway/gen2-lite
```

### Check Application
```bash
curl http://localhost:8080/health
```

Expected response:
```json
{
  "status": "healthy",
  "domain": "dicabr.com.br",
  "timestamp": "2026-03-19T...",
  "active_workers": 3
}
```

### Test Video Generation
```bash
curl -X POST http://localhost:8080/api/v1/jobs \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "A cinematic sunset over mountains",
    "duration": 5,
    "resolution": "720p",
    "style": "cinematic"
  }'
```

---

## 🔍 Troubleshooting

### Ollama not running
```bash
sudo systemctl status ollama
sudo journalctl -u ollama -f
```

### Application not starting
```bash
sudo systemctl status dicabr-web
sudo journalctl -u dicabr-web -f
```

### Model not found error
```bash
# Re-pull the model
ollama pull runway/gen2-lite
```

### Port already in use
```bash
sudo netstat -tulpn | grep :8080
sudo netstat -tulpn | grep :11434
```

### Permission issues
```bash
sudo chown -R http:http /var/www/dicabr.com.br
sudo chmod -R 755 /var/www/dicabr.com.br
```

---

## 📊 Monitoring

### Real-time logs
```bash
# Application logs
sudo journalctl -u dicabr-web -f

# Ollama logs
sudo journalctl -u ollama -f

# Both together
sudo journalctl -f | grep -E "(dicabr|ollama)"
```

### Resource usage
```bash
htop
# Press F4 and type "dotnet" or "ollama"
```

### Check disk space
```bash
df -h
du -sh /var/www/dicabr.com.br/*
```

---

## 🔄 Update Application

```bash
cd /var/www/dicabr.com.br
git pull
cd src/backend
dotnet restore
dotnet publish -c Release -o /var/www/dicabr.com.br/publish
sudo systemctl restart dicabr-web
```

---

## 🗄️ Backup Database

```bash
# Create backup
cp /var/www/dicabr.com.br/data/queue.db ~/backup-$(date +%Y%m%d).db

# Restore from backup
cp ~/backup-20260319.db /var/www/dicabr.com.br/data/queue.db
sudo systemctl restart dicabr-web
```

---

## 🔐 SSL Certificate (HTTPS)

Install Certbot:
```bash
sudo pacman -S --noconfirm certbot python-certbot
```

Get certificate:
```bash
sudo certbot --nginx -d dicabr.com.br -d www.dicabr.com.br
```

Auto-renewal:
```bash
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer
```

---

## 📝 Important Files

- **Application Directory**: `/var/www/dicabr.com.br`
- **Database**: `/var/www/dicabr.com.br/data/queue.db`
- **Videos**: `/var/www/dicabr.com.br/data/videos`
- **Images**: `/var/www/dicabr.com.br/data/images`
- **Logs**: `/var/www/dicabr.com.br/logs`
- **Service File**: `/etc/systemd/system/dicabr-web.service`
- **Nginx Config**: `/etc/nginx/nginx.conf`

---

## 🎯 Test with Actual Ollama

### 1. Check Ollama is responding
```bash
curl http://localhost:11434/api/tags
```

### 2. Test model directly
```bash
ollama run runway/gen2-lite "Test prompt"
```

### 3. Generate video via API
```bash
curl -X POST http://localhost:8080/api/v1/jobs \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "A beautiful sunset over the ocean, cinematic style",
    "duration": 5,
    "resolution": "720p"
  }'
```

### 4. Check job status
```bash
curl http://localhost:8080/api/v1/jobs/{JOB_ID}
```

---

## 💡 Tips for Hostinger KVM 1

- **RAM**: 2GB is sufficient for basic usage
- **Storage**: Monitor disk space, videos can grow large
- **CPU**: Single core is fine for light usage
- **Swap**: Consider adding 2GB swap if running low on RAM
  ```bash
  sudo fallocate -l 2G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
  ```

---

## 🆘 Getting Help

### System logs
```bash
dmesg | tail -50
```

### Service status
```bash
systemctl --failed
```

### Network connectivity
```bash
ping -c 4 dicabr.com.br
curl -I http://localhost:8080
```

---

**Your application is now running with:**
- ✅ ASP.NET Core 8 backend
- ✅ Real Ollama integration (runway/gen2-lite model)
- ✅ SQLite database
- ✅ Multi-threaded job processing
- ✅ Production-ready configuration

**Access your application at:** http://dicabr.com.br
