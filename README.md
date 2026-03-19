# 🎬 Ollama Web Project - ASP.NET Core

**Production-Ready AI Video Generation Platform for dicabr.com.br**

A robust, scalable web application for generating videos using AI models through Ollama. Built with ASP.NET Core 8, modern frontend, and optimized for Hostinger KVM VPS deployment.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![.NET](https://img.shields.io/badge/.NET-8.0-purple.svg)
![ASP.NET Core](https://img.shields.io/badge/ASP.NET%20Core-8.0-green.svg)
![Status](https://img.shields.io/badge/status-production--ready-brightgreen.svg)

## ✨ Features

- 🚀 **Production-Ready Architecture** - ASP.NET Core 8 with multi-threading
- 🔐 **Security** - JWT authentication, secure headers, CORS protection
- ⚡ **Real-time Updates** - WebSocket support for live job progress
- 🎨 **Modern UI** - Responsive, dark-themed interface
- 📊 **Job Queue System** - Multi-threaded processing with SQLite persistence
- 🔄 **Auto-recovery** - Automatic reconnection and health monitoring
- 📦 **Easy Deployment** - Optimized for Hostinger KVM VPS
- 💾 **Data Persistence** - SQLite database for production
- 📝 **Comprehensive Logging** - Built-in .NET logging
- 🌐 **Domain Ready** - Configured for dicabr.com.br

## 🏗️ Architecture

```
ollama-web-project/
├── src/
│   ├── backend/          # ASP.NET Core backend
│   │   ├── Program.cs   # Application entry point
│   │   ├── Models.cs    # Data models and DbContext
│   │   ├── Services.cs  # Job queue manager
│   │   ├── Controllers.cs # API controllers
│   │   ├── appsettings.json
│   │   └── OllamaWebApi.csproj
│   └── frontend/         # Vanilla JS frontend
│       └── public/
│           ├── index.html
│           └── src/
│               ├── app.js
│               ├── styles/
│               └── utils/
├── scripts/
│   └── build.sh         # Build and deploy script
├── data/                # Persistent storage
│   ├── videos/
│   ├── images/
│   └── database/
├── logs/                # Application logs
├── web.config          # IIS configuration
├── DEPLOYMENT.md       # Deployment guide
└── README.md
```

## 🚀 Quick Start

### Prerequisites

- .NET 8 SDK
- Node.js (optional, for frontend development)
- Git
- 2GB+ RAM recommended
- 5GB+ free disk space

### Local Development

1. **Clone the repository:**
```bash
git clone <repository-url>
cd ollama-web-project
```

2. **Navigate to backend:**
```bash
cd src/backend
```

3. **Restore dependencies:**
```bash
dotnet restore
```

4. **Run the application:**
```bash
dotnet run
```

5. **Access the application:**
- Frontend: http://localhost:8080
- API Docs: http://localhost:8080/swagger
- Health Check: http://localhost:8080/health

## 🛠️ Management Commands

### Build and Publish
```bash
cd src/backend
dotnet restore
dotnet build -c Release
dotnet publish -c Release -o ./publish
```

### Run in Development
```bash
dotnet watch run
```

### Run Tests (if available)
```bash
dotnet test
```

## ⚙️ Configuration

### Environment Variables

Configure in `web.config` or system environment:

```xml
<environmentVariables>
  <environmentVariable name="DOMAIN" value="dicabr.com.br" />
  <environmentVariable name="ASPNETCORE_HTTP_PORTS" value="8080" />
  <environmentVariable name="DB_PATH" value="data/queue.db" />
  <environmentVariable name="MAX_CONCURRENT_JOBS" value="3" />
  <environmentVariable name="API_KEY" value="your-secret-key" />
  <environmentVariable name="ENABLE_AUTH" value="false" />
</environmentVariables>
```

### appsettings.json

```json
{
  "Domain": "dicabr.com.br",
  "Database": {
    "Provider": "SQLite",
    "ConnectionString": "Data Source=data/queue.db"
  },
  "Security": {
    "ApiKey": "your-secret-key",
    "EnableAuth": false
  },
  "JobQueue": {
    "MaxConcurrentJobs": 3,
    "MaxQueueSize": 100
  }
}
```

## 📡 API Endpoints

### Create Job
```http
POST /api/v1/jobs
Content-Type: application/json

{
  "prompt": "A cinematic sunset over mountains",
  "duration": 5,
  "resolution": "720p",
  "style": "cinematic"
}
```

### List Jobs
```http
GET /api/v1/jobs?status=processing&limit=10&offset=0
```

### Get Job Status
```http
GET /api/v1/jobs/{job_id}
```

### Cancel Job
```http
POST /api/v1/jobs/{job_id}/cancel
```

### Delete Job
```http
DELETE /api/v1/jobs/{job_id}
```

### Health Check
```http
GET /health
```

Response:
```json
{
  "status": "healthy",
  "domain": "dicabr.com.br",
  "timestamp": "2026-03-19T21:05:16.000Z",
  "active_workers": 3
}
```

## 📦 Deployment to Hostinger KVM

See [DEPLOYMENT.md](DEPLOYMENT.md) for complete deployment instructions.

### Quick Deploy

1. **Upload files to VPS:**
```bash
scp -r * user@your-vps-ip:/var/www/dicabr.com.br/
```

2. **Build and deploy:**
```bash
sudo chmod +x scripts/build.sh
sudo ./scripts/build.sh
```

3. **Configure Nginx/Apache as reverse proxy**

4. **Set up systemd service**

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

### Database issues
```bash
# Ensure data directory exists
mkdir -p /var/www/dicabr.com.br/data
sudo chown www-data:www-data /var/www/dicabr.com.br/data
```

### Permission errors
```bash
sudo chown -R www-data:www-data /var/www/dicabr.com.br
sudo chmod -R 755 /var/www/dicabr.com.br
```

### Rebuild from scratch
```bash
cd /var/www/dicabr.com.br/src/backend
dotnet clean
dotnet restore
dotnet publish -c Release -o /var/www/dicabr.com.br/publish
sudo systemctl restart dicabr-web
```

## 📊 Monitoring

### View Real-time Logs
```bash
sudo journalctl -u dicabr-web -f
```

### Resource Usage
```bash
htop
# Filter by: dotnet
```

### Health Check Response
```json
{
  "status": "healthy",
  "domain": "dicabr.com.br",
  "timestamp": "2026-03-19T21:05:16.000Z",
  "active_workers": 3
}
```

## 🔐 Security Best Practices

1. **Always change the default API key**
2. **Enable JWT authentication in production**
3. **Use HTTPS with SSL certificate**
4. **Regular backups of SQLite database**
5. **Monitor logs for suspicious activity**
6. **Keep system and .NET updated**
7. **Use firewall rules to restrict access**
8. **Implement rate limiting for public deployments**

## 🧪 Testing

### Test API Endpoints
```bash
# Health check
curl http://localhost:8080/health

# Create a job
curl -X POST http://localhost:8080/api/v1/jobs \
  -H "Content-Type: application/json" \
  -d '{"prompt":"test video","duration":5}'
```

## 📦 Backup and Recovery

### Manual Backup
```bash
# Create backup directory
mkdir -p ~/ollama-backups/$(date +%Y%m%d)

# Backup database
cp /var/www/dicabr.com.br/data/queue.db ~/ollama-backups/$(date +%Y%m%d)/

# Backup configuration
cp /var/www/dicabr.com.br/src/backend/appsettings.json ~/ollama-backups/
```

### Automated Backups
Add to crontab:
```bash
0 2 * * * cp /var/www/dicabr.com.br/data/queue.db ~/backups/queue-$(date +\%Y\%m\%d).db
```

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open Pull Request

## 📄 License

This project is licensed under the MIT License.

## 🙏 Acknowledgments

- [ASP.NET Core](https://docs.microsoft.com/en-us/aspnet/core/) - Modern web framework
- [Ollama](https://ollama.ai/) - AI model serving
- [.NET 8](https://dotnet.microsoft.com/) - Latest .NET runtime
- [Hostinger](https://www.hostinger.com/) - VPS hosting

## 📞 Support

- Documentation: `/docs` folder
- API Docs: http://localhost:8080/swagger
- Issues: GitHub Issues
- Email: support@dicabr.com.br

---

**Made with ❤️ for dicabr.com.br**

*Last Updated: March 2026*
