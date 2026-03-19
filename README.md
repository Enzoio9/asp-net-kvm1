# 🎬 Ollama Web Project

**Production-Ready AI Video Generation Platform**

A robust, scalable web application for generating videos using AI models through Ollama. Built with FastAPI backend, modern frontend, and Docker-based deployment.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Python](https://img.shields.io/badge/python-3.11-blue.svg)
![FastAPI](https://img.shields.io/badge/FastAPI-0.109-green.svg)
![Docker](https://img.shields.io/badge/docker-ready-blue.svg)

## ✨ Features

- 🚀 **Production-Ready Architecture** - Microservices with Docker Compose
- 🔐 **Security** - API key authentication, secure headers, CORS protection
- ⚡ **Real-time Updates** - WebSocket support for live job progress
- 🎨 **Modern UI** - Responsive, dark-themed interface
- 📊 **Job Queue System** - Multi-threaded processing with SQLite persistence
- 🔄 **Auto-recovery** - Automatic reconnection and health monitoring
- 📦 **Easy Deployment** - One-command installation
- 🌐 **HTTPS Ready** - Caddy reverse proxy with automatic SSL
- 💾 **Data Persistence** - Volume-mounted storage for videos and database
- 📝 **Comprehensive Logging** - JSON-formatted logs for production monitoring

## 🏗️ Architecture

```
ollama-web-project/
├── src/
│   ├── backend/          # FastAPI Python backend
│   │   ├── app/
│   │   │   └── main.py  # Main application
│   │   └── requirements.txt
│   └── frontend/         # Vanilla JS frontend
│       └── public/
│           ├── index.html
│           └── src/
│               ├── app.js
│               ├── styles/
│               └── utils/
├── docker/
│   ├── Dockerfile.backend
│   ├── docker-compose.yml
│   └── Caddyfile
├── scripts/
│   ├── install.sh       # Installation script
│   └── manage.sh        # Management utilities
├── data/                # Persistent storage
│   ├── videos/
│   ├── images/
│   └── database/
├── logs/                # Application logs
├── .env.example         # Environment template
└── README.md
```

## 🚀 Quick Start

### Prerequisites

- Docker (version 20.10+)
- Docker Compose (version 2.0+)
- Git
- 4GB+ RAM recommended
- 10GB+ free disk space

### Installation

1. **Clone the repository:**
```bash
git clone <repository-url>
cd ollama-web-project
```

2. **Run the installation script:**
```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

This will:
- Check prerequisites
- Create directory structure
- Generate secure API keys
- Build Docker images
- Start all services
- Configure Caddy reverse proxy

3. **Access the application:**
- Frontend: http://localhost
- API Docs: http://localhost:8080/docs
- Health Check: http://localhost:8080/health

## 🛠️ Management Commands

The `manage.sh` script provides essential operations:

```bash
# Start services
./scripts/manage.sh start

# Stop services
./scripts/manage.sh stop

# Restart services
./scripts/manage.sh restart

# View logs
./scripts/manage.sh logs              # All services
./scripts/manage.sh logs ollama-web   # Backend only

# Check status
./scripts/manage.sh status

# Health check
./scripts/manage.sh health

# Backup data
./scripts/manage.sh backup

# Database operations
./scripts/manage.sh db status
./scripts/manage.sh db export
./scripts/manage.sh db vacuum

# Execute commands in container
./scripts/manage.sh exec ollama-web "ls -la /app"

# Cleanup (removes all containers and volumes)
./scripts/manage.sh cleanup
```

## ⚙️ Configuration

### Environment Variables (.env file)

```bash
# Server Configuration
HOST_PORT=8080
DOMAIN=localhost

# Security (CHANGE IN PRODUCTION!)
API_KEY=your-secure-key-here
ENABLE_AUTH=false

# Performance
MAX_CONCURRENT_JOBS=3
MAX_QUEUE_SIZE=100

# Ollama Configuration
OLLAMA_HOST=http://localhost:11434
OLLAMA_MODEL=runway/gen2-lite

# Storage Paths
VIDEO_DIR=./data/videos
IMAGE_DIR=./data/images
DATABASE_DIR=./data/database
```

### Production Deployment

1. **Update .env file:**
```bash
cp .env.example .env
nano .env  # Edit values
```

2. **Set your domain:**
```bash
DOMAIN=yourdomain.com
```

3. **Enable authentication:**
```bash
ENABLE_AUTH=true
API_KEY=$(openssl rand -hex 32)
```

4. **Deploy:**
```bash
./scripts/install.sh
```

## 📡 API Endpoints

### Create Job
```http
POST /api/v1/jobs
Content-Type: application/json
Authorization: Bearer YOUR_API_KEY

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

### WebSocket Real-time Updates
```javascript
const ws = new WebSocket('ws://localhost/ws/jobs');
ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log('Job update:', data);
};
```

## 🔧 Troubleshooting

### Services won't start
```bash
# Check logs
./scripts/manage.sh logs

# Verify Docker is running
docker ps

# Check port conflicts
netstat -tulpn | grep :8080
```

### Database issues
```bash
# Check database status
./scripts/manage.sh db status

# Export database (backup)
./scripts/manage.sh db export

# Vacuum database
./scripts/manage.sh db vacuum
```

### Permission errors
```bash
# Fix permissions
sudo chown -R $USER:$USER data/ logs/
chmod -R 755 data/ logs/
```

### Rebuild from scratch
```bash
# Complete cleanup
./scripts/manage.sh cleanup

# Reinstall
./scripts/install.sh
```

## 📊 Monitoring

### View Real-time Logs
```bash
docker-compose -f docker/docker-compose.yml logs -f
```

### Resource Usage
```bash
docker stats ollama-web-backend ollama-web-caddy
```

### Health Check Response
```json
{
  "status": "healthy",
  "timestamp": "2026-03-19T21:05:16.000Z",
  "queue_size": 2,
  "active_workers": 3
}
```

## 🔐 Security Best Practices

1. **Always change the default API key**
2. **Enable authentication in production**
3. **Use HTTPS (Caddy auto-configures SSL)**
4. **Regular backups of database**
5. **Monitor logs for suspicious activity**
6. **Keep Docker and system updated**
7. **Use firewall rules to restrict access**
8. **Implement rate limiting for public deployments**

## 🧪 Testing

### Test API Endpoints
```bash
# Health check
curl http://localhost:8080/health

# Create a job (if auth disabled)
curl -X POST http://localhost:8080/api/v1/jobs \
  -H "Content-Type: application/json" \
  -d '{"prompt":"test video","duration":5}'
```

### Load Testing
```bash
# Install Apache Bench
apt-get install apache2-utils

# Run load test (100 requests, 10 concurrent)
ab -n 100 -c 10 http://localhost:8080/health
```

## 📦 Backup and Recovery

### Manual Backup
```bash
# Create backup directory
mkdir -p ~/ollama-backups/$(date +%Y%m%d)

# Backup database
cp data/database/queue.db ~/ollama-backups/$(date +%Y%m%d)/

# Backup configuration
cp .env ~/ollama-backups/$(date +%Y%m%d)/
```

### Automated Backups
Add to crontab:
```bash
0 2 * * * /path/to/ollama-web-project/scripts/manage.sh backup
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

- [FastAPI](https://fastapi.tiangolo.com/) - Modern Python web framework
- [Ollama](https://ollama.ai/) - AI model serving
- [Caddy](https://caddyserver.com/) - Secure reverse proxy
- [Docker](https://docker.com/) - Container platform

## 📞 Support

- Documentation: `/docs` folder
- API Docs: http://localhost:8080/docs
- Issues: GitHub Issues
- Email: support@example.com

---

**Made with ❤️ by the Ollama Web Team**

*Last Updated: March 2026*
