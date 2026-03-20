# Summary of Changes - Fix 500 Internal Server Error

## 🎯 Problem Fixed

**Error**: `500 Internal Server Error nginx/1.28.2` when starting the website

## ✅ Changes Made

### 1. Program.cs - Critical Fixes

#### A. Port Configuration (CRITICAL)
**Before:**
```csharp
options.ListenAnyIP(5000); // Wrong port - nginx expects 8080
```

**After:**
```csharp
var ports = Environment.GetEnvironmentVariable("ASPNETCORE_HTTP_PORTS") ?? "8080";
int port = int.Parse(ports);
options.ListenAnyIP(port); // Configurable port, defaults to 8080
```

**Why**: Nginx configuration proxies requests to `http://localhost:8080`, but the application was listening on port 5000.

#### B. Static File Serving
**Added:**
```csharp
// Serve static files for /videos and /images paths
var videoDir = Environment.GetEnvironmentVariable("VIDEO_DIR") ?? 
              Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "data", "videos");
var imageDir = Environment.GetEnvironmentVariable("IMAGE_DIR") ?? 
              Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "data", "images");

// Ensure directories exist
Directory.CreateDirectory(videoDir);
Directory.CreateDirectory(imageDir);

// Map static file locations
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new Microsoft.Extensions.FileProviders.PhysicalFileProvider(imageDir),
    RequestPath = "/images"
});

app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new Microsoft.Extensions.FileProviders.PhysicalFileProvider(videoDir),
    RequestPath = "/videos"
});
```

**Why**: Application needs to serve uploaded images and generated videos directly.

#### C. Database Initialization Error Handling
**Before:**
```csharp
dbContext.Database.EnsureCreated();
```

**After:**
```csharp
try
{
    var dbContext = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    dbContext.Database.EnsureCreated();
    Console.WriteLine("✅ Database initialized successfully");
}
catch (Exception ex)
{
    Console.WriteLine($"❌ Database initialization error: {ex.Message}");
    throw;
}
```

**Why**: Better error reporting when database initialization fails.

#### D. Additional Logging
**Added:**
- Video/image directory paths logged on startup
- Kestrel port configuration logged
- Database initialization status logged

### 2. New Files Created

#### A. nginx.conf
Complete nginx configuration with:
- Proper proxy settings for port 8080
- Static file serving for `/videos/` and `/images/`
- Large file upload support (500MB limit)
- Extended timeouts for long-running operations
- Security headers
- HTTPS ready (just add SSL certificates)

#### B. start.sh
Startup script that:
- Creates necessary directories
- Sets environment variables
- Checks if Ollama is running
- Builds and starts the application
- Provides colored output for better readability

#### C. FIX-NGINX-500-ERROR.md (English)
Comprehensive troubleshooting guide covering:
- Common causes of 500 errors
- Step-by-step solutions
- Diagnostic procedures
- Systemd service configuration
- Quick checklist

#### D. CORRECAO-RAPIDA-NGINX-500.md (Portuguese)
Guia completo em português com:
- Solução do problema principal
- Passos detalhados para correção
- Configuração systemd
- Diagnóstico de problemas comuns
- Checklist de verificação

## 🔧 How to Apply the Fix

### On Linux Server (Production):

```bash
# 1. Update application files
cd /path/to/ollama-web-project

# 2. Create required directories
sudo mkdir -p /var/www/dicabr.com.br/data/{videos,images,database}
sudo chown -R www-data:www-data /var/www/dicabr.com.br/data
sudo chmod -R 755 /var/www/dicabr.com.br/data

# 3. Configure nginx
sudo cp nginx.conf /etc/nginx/sites-available/dicabr.com.br
sudo ln -sf /etc/nginx/sites-available/dicabr.com.br \
            /etc/nginx/sites-enabled/dicabr.com.br
sudo nginx -t
sudo systemctl reload nginx

# 4. Start application
export ASPNETCORE_HTTP_PORTS=8080
export VIDEO_DIR=/var/www/dicabr.com.br/data/videos
export IMAGE_DIR=/var/www/dicabr.com.br/data/images
export DB_PATH=/var/www/dicabr.com.br/data/database/queue.db
cd src/backend
dotnet build --configuration Release
dotnet run --configuration Release
```

### Or use the startup script:

```bash
chmod +x start.sh
sudo ./start.sh
```

## 📋 Testing

After applying fixes:

```bash
# Test application directly
curl http://localhost:8080/health

# Test through nginx
curl http://localhost/health
curl http://dicabr.com.br/health

# Check logs
tail -f /var/log/nginx/error.log
journalctl -u ollama-web-api -f
```

## 🎯 Expected Results

✅ Application listens on port 8080  
✅ Nginx successfully proxies to application  
✅ Static files (/videos/, /images/) are served  
✅ Database is created automatically  
✅ No more 500 errors  

## ⚠️ Important Notes

1. **Port Change**: Application now uses port 8080 (configurable via `ASPNETCORE_HTTP_PORTS`)
2. **Directory Structure**: Requires `/var/www/dicabr.com.br/data/` for production
3. **Permissions**: Directories must be writable by the application user
4. **Nginx Config**: Use the provided `nginx.conf` or ensure your config proxies to port 8080

## 📝 Related Memory

This fix addresses the issue documented in memory:
- **Memory**: "ASP.NET Core Kestrel ListenAnyIP Fix for NGINX Compatibility"
- **Issue**: Kestrel configured on port 5000, but nginx expects port 8080
- **Solution**: Made port configurable via environment variable, defaulting to 8080

## 🔗 Files Modified/Created

**Modified:**
- `src/backend/Program.cs` - Port configuration, static files, error handling

**Created:**
- `nginx.conf` - Complete nginx configuration
- `start.sh` - Startup script
- `FIX-NGINX-500-ERROR.md` - Troubleshooting guide (English)
- `CORRECAO-RAPIDA-NGINX-500.md` - Quick fix guide (Portuguese)

## 🆘 Next Steps

If you still encounter issues after applying these fixes:

1. Check application logs: `journalctl -u ollama-web-api -f`
2. Check nginx logs: `tail -f /var/log/nginx/error.log`
3. Verify application is running: `curl http://localhost:8080/health`
4. Review the troubleshooting guides created

The fixes address the most common causes of 500 errors with this nginx/ASP.NET Core setup.
