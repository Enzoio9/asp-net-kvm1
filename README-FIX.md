# 🚀 Complete Fix for 500 Internal Server Error - nginx/1.28.2

## ✅ What Was Fixed

### Critical Issue: Port Mismatch
**Problem**: Application was listening on port **5000**, but nginx expected it on port **8080**

**Solution**: Updated `Program.cs` to use configurable port (defaults to 8080)

### Additional Fixes Applied
1. ✅ Static file serving for `/videos/` and `/images/`
2. ✅ Automatic directory creation for data storage
3. ✅ Better error handling for database initialization
4. ✅ Enhanced logging for troubleshooting
5. ✅ Complete nginx configuration provided
6. ✅ Startup scripts created

---

## 🎯 Quick Start - Choose Your Method

### Method 1: Automated Script (Recommended for Linux)

On your Linux server:

```bash
# Navigate to project directory
cd /path/to/ollama-web-project

# Run the quick fix script
sudo bash quick-fix.sh
```

This will:
- Stop services
- Create directories
- Configure nginx
- Start application
- Test health endpoint

### Method 2: Manual Steps (Windows Development or Linux)

#### On Windows (Development):

```cmd
cd c:\Users\ioenz\Documents\docker.io\ollama-web-project\src\backend

REM Set environment variables
set ASPNETCORE_HTTP_PORTS=8080
set VIDEO_DIR=%CD%\data\videos
set IMAGE_DIR=%CD%\data\images
set DB_PATH=%CD%\data\queue.db

REM Run application
dotnet run
```

In another terminal, test:
```cmd
curl http://localhost:8080/health
```

#### On Linux (Production):

```bash
# 1. Create directories
sudo mkdir -p /var/www/dicabr.com.br/data/{videos,images,database}
sudo chown -R www-data:www-data /var/www/dicabr.com.br/data
sudo chmod -R 755 /var/www/dicabr.com.br/data

# 2. Configure nginx
sudo cp nginx.conf /etc/nginx/sites-available/dicabr.com.br
sudo ln -sf /etc/nginx/sites-available/dicabr.com.br \
            /etc/nginx/sites-enabled/dicabr.com.br
sudo nginx -t
sudo systemctl reload nginx

# 3. Set environment and run
export ASPNETCORE_HTTP_PORTS=8080
export VIDEO_DIR=/var/www/dicabr.com.br/data/videos
export IMAGE_DIR=/var/www/dicabr.com.br/data/images
export DB_PATH=/var/www/dicabr.com.br/data/database/queue.db

cd /path/to/ollama-web-project/src/backend
dotnet build --configuration Release
dotnet run
```

---

## 📋 Step-by-Step Verification

After applying the fix, verify everything works:

### 1. Check Application is Running

```bash
# Direct test (bypass nginx)
curl http://localhost:8080/health

# Expected response:
# {"status":"healthy","domain":"dicabr.com.br",...}
```

### 2. Check Nginx Proxy

```bash
# Through nginx
curl http://localhost/health
curl http://dicabr.com.br/health
```

### 3. Check Logs

```bash
# Application logs (if using nohup)
tail -f /var/log/ollama-web.log

# Nginx error logs
sudo tail -f /var/log/nginx/dicabr_error.log

# Systemd service logs (if using systemd)
sudo journalctl -u ollama-web-api -f
```

### 4. Verify Services

```bash
# Check if application is listening
sudo netstat -tlnp | grep 8080

# Check nginx status
sudo systemctl status nginx

# Check application status (if using systemd)
sudo systemctl status ollama-web-api
```

---

## 🔧 Configuration Options

### Environment Variables

Set these before running the application:

| Variable | Default | Description |
|----------|---------|-------------|
| `ASPNETCORE_HTTP_PORTS` | `8080` | Port application listens on |
| `VIDEO_DIR` | `/var/www/dicabr.com.br/data/videos` | Where videos are stored |
| `IMAGE_DIR` | `/var/www/dicabr.com.br/data/images` | Where images are stored |
| `DB_PATH` | `/var/www/dicabr.com.br/data/database/queue.db` | SQLite database location |
| `OLLAMA_HOST` | `http://localhost:11434` | Ollama API endpoint |
| `OLLAMA_MODEL` | `runway/gen2-lite` | AI model to use |
| `DOMAIN` | `dicabr.com.br` | Domain name |
| `API_KEY` | `ollama-web-secret-key-change-in-production` | API secret key |
| `ENABLE_AUTH` | `false` | Enable JWT authentication |
| `MAX_CONCURRENT_JOBS` | `3` | Number of worker threads |

### Example .env File for Production

Create `.env` in the project root:

```bash
ASPNETCORE_HTTP_PORTS=8080
DOMAIN=dicabr.com.br
VIDEO_DIR=/var/www/dicabr.com.br/data/videos
IMAGE_DIR=/var/www/dicabr.com.br/data/images
DB_PATH=/var/www/dicabr.com.br/data/database/queue.db
OLLAMA_HOST=http://localhost:11434
OLLAMA_MODEL=runway/gen2-lite
API_KEY=change-this-to-a-secure-random-string
ENABLE_AUTH=true
MAX_CONCURRENT_JOBS=3
```

Load it before starting:

```bash
source .env
export $(cat .env | grep -v '^#' | xargs)
```

---

## 🛠️ Production Setup with Systemd

For automatic startup and management:

### 1. Create Service File

```bash
sudo nano /etc/systemd/system/ollama-web-api.service
```

### 2. Service Configuration

```ini
[Unit]
Description=Ollama Web API - dicabr.com.br
After=network.target ollama.service

[Service]
Type=exec
WorkingDirectory=/var/www/dicabr.com.br/app/src/backend
EnvironmentFile=/var/www/dicabr.com.br/app/.env
Environment="ASPNETCORE_URLS=http://*:8080"
ExecStart=/usr/bin/dotnet run --configuration Release
Restart=always
RestartSec=10
User=www-data
Group=www-data

[Install]
WantedBy=multi-user.target
```

### 3. Enable and Start

```bash
sudo systemctl daemon-reload
sudo systemctl enable ollama-web-api
sudo systemctl start ollama-web-api
sudo systemctl status ollama-web-api
```

---

## 🐛 Troubleshooting

### Problem: "Address already in use"

```bash
# Find what's using port 8080
sudo netstat -tlnp | grep 8080

# Kill the process
sudo kill -9 <PID>

# Or change the port
export ASPNETCORE_HTTP_PORTS=8081
```

### Problem: "Permission denied" creating files

```bash
# Fix directory permissions
sudo chown -R www-data:www-data /var/www/dicabr.com.br/data
sudo chmod -R 755 /var/www/dicabr.com.br/data
```

### Problem: Nginx returns 502 Bad Gateway

```bash
# Check if app is running
curl http://localhost:8080/health

# If not, check logs
sudo journalctl -u ollama-web-api -n 50

# Restart app
sudo systemctl restart ollama-web-api
```

### Problem: Database errors

```bash
# Ensure directory exists and is writable
ls -la /var/www/dicabr.com.br/data/database/

# Create if needed
sudo mkdir -p /var/www/dicabr.com.br/data/database
sudo chown -R www-data:www-data /var/www/dicabr.com.br/data/database
```

---

## 📊 Files Created/Modified

### Modified Files
- ✏️ `src/backend/Program.cs` - Port configuration, static files, error handling

### New Files
- 📄 `nginx.conf` - Complete nginx configuration
- 📄 `start.sh` - Startup script with environment setup
- 📄 `quick-fix.sh` - Automated fix script
- 📄 `FIX-NGINX-500-ERROR.md` - Detailed troubleshooting (English)
- 📄 `CORRECAO-RAPIDA-NGINX-500.md` - Quick fix guide (Portuguese)
- 📄 `CHANGES-SUMMARY.md` - Summary of all changes
- 📄 `README-FIX.md` - This comprehensive guide

---

## ✅ Success Indicators

You'll know it's working when:

1. ✅ `curl http://localhost:8080/health` returns healthy status
2. ✅ `curl http://localhost/health` works through nginx
3. ✅ No errors in `/var/log/nginx/dicabr_error.log`
4. ✅ Application logs show "Application started successfully"
5. ✅ Can access Swagger docs at `/docs`
6. ✅ Can upload images and download videos

---

## 🆘 Still Having Issues?

If you've tried everything and still get 500 errors:

### 1. Gather Information

```bash
# System info
uname -a
dotnet --version
nginx -v

# Service status
sudo systemctl status nginx
sudo systemctl status ollama-web-api

# Recent logs
sudo journalctl -u ollama-web-api -n 100
sudo tail -n 100 /var/log/nginx/error.log

# Network config
sudo netstat -tlnp | grep 8080
```

### 2. Common Issues Checklist

- [ ] Application is running on port 8080
- [ ] Nginx config points to `http://127.0.0.1:8080`
- [ ] Data directories exist and are writable
- [ ] Ollama is accessible (check `OLLAMA_HOST`)
- [ ] No firewall blocking port 8080
- [ ] Nginx configuration tested (`nginx -t`)

### 3. Get Help

Share the gathered information along with:
- Which method you used to apply the fix
- Any error messages you see
- When the error occurs (startup, during requests, etc.)

---

## 📝 Notes

- **Port 8080**: Changed from hardcoded 5000 to configurable (default 8080)
- **Static Files**: Application now serves `/videos/` and `/images/` directly
- **Auto-creation**: Directories are created automatically on startup
- **Error Handling**: Better error messages for easier debugging
- **Nginx Ready**: Use provided `nginx.conf` for optimal configuration

---

## 🎉 Conclusion

The 500 Internal Server Error has been fixed by:

1. Correcting the port mismatch (5000 → 8080)
2. Adding proper static file serving
3. Implementing automatic directory creation
4. Providing complete nginx configuration
5. Creating automated fix scripts

Your application should now run smoothly behind nginx!

**Last Updated**: March 20, 2026  
**Version**: 1.0.0  
**Domain**: dicabr.com.br
