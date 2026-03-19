# 🏗️ Architecture - dicabr.com.br

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    USER BROWSER                             │
│                  http://dicabr.com.br                       │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ HTTP/HTTPS (80/443)
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      NGINX REVERSE PROXY                    │
│              /etc/nginx/nginx.conf                          │
│                                                             │
│  Routes:                                                    │
│    - /        → Forward to localhost:8080                   │
│    - /api/*   → Forward to localhost:8080                   │
│    - /health  → Forward to localhost:8080                   │
│    - /videos/* → Forward to localhost:8080                  │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ localhost:8080
                            ▼
┌─────────────────────────────────────────────────────────────┐
│               ASP.NET CORE 8 APPLICATION                    │
│            /var/www/dicabr.com.br/publish                   │
│                                                             │
│  Components:                                                │
│    ┌──────────────────────────────────────────────┐        │
│    │  Controllers.cs                               │        │
│    │  - JobsController (API endpoints)             │        │
│    │  - RootController (Health, Root)              │        │
│    └──────────────────────────────────────────────┘        │
│                            │                                │
│    ┌──────────────────────────────────────────────┐        │
│    │  Services.cs                                 │        │
│    │  - JobQueueManager                          │        │
│    │  - IJobQueueManager                         │        │
│    │  - 3 Worker Threads                         │        │
│    └──────────────────────────────────────────────┘        │
│                            │                                │
│    ┌──────────────────────────────────────────────┐        │
│    │  Models.cs                                   │        │
│    │  - VideoJob (Entity)                        │        │
│    │  - AppDbContext (EF Core)                   │        │
│    └──────────────────────────────────────────────┘        │
│                                                             │
│  Environment Variables:                                     │
│    - DOMAIN=dicabr.com.br                                  │
│    - OLLAMA_HOST=http://localhost:11434                    │
│    - OLLAMA_MODEL=runway/gen2-lite                         │
│    - MAX_CONCURRENT_JOBS=3                                 │
└─────────────────────────────────────────────────────────────┘
                │                           │
                │ SQLite                    │ HTTP POST
                │                           │ :11434
                ▼                           ▼
    ┌──────────────────────┐    ┌──────────────────────────┐
    │   SQLITE DATABASE    │    │      OLLAMA SERVICE      │
    │                      │    │  /usr/bin/ollama serve   │
    │  /var/www/dicabr...  │    │                          │
    │  data/queue.db       │    │  Model: runway/gen2-lite │
    │                      │    │                          │
    │  Tables:             │    │  Endpoint:               │
    │  - Jobs              │    │  /api/generate           │
    │  - Metrics           │    │                          │
    └──────────────────────┘    └──────────────────────────┘
                                            │
                                            │ Generate Video
                                            ▼
                                  ┌──────────────────────────┐
                                  │   runway/gen2-lite       │
                                  │     AI MODEL             │
                                  │                          │
                                  │  Input: Text Prompt      │
                                  │  Output: Video Data      │
                                  └──────────────────────────┘
                                            │
                                            │ Save Video
                                            ▼
                                  ┌──────────────────────────┐
                                  │   VIDEO STORAGE          │
                                  │                          │
                                  │  /var/www/dicabr...      │
                                  │  data/videos/{id}.mp4    │
                                  └──────────────────────────┘
```

---

## Data Flow Sequence

### 1. User Creates Video Job

```
┌──────┐  POST /api/v1/jobs  ┌─────────┐  Add to Queue  ┌────────┐
│User  │ ───────────────────►│ASP.NET  │───────────────►│SQLite  │
│      │  {prompt, duration} │Controller│                │  DB    │
└──────┘                     └─────────┘                └────────┘
                                                            │
                                                      Status: pending
                                                      Progress: 0
```

### 2. Worker Picks Up Job

```
┌──────────┐  Get Job  ┌──────────┐  Update Status  ┌────────┐
│Worker #1 │◄──────────┤Job Queue │────────────────►│SQLite  │
│Thread    │           │Manager   │                 │  DB    │
└──────────┘           └──────────┘                 └────────┘
                                                  Status: processing
                                                  Progress: 10
```

### 3. REAL Ollama Integration (No Simulation!)

```
┌──────────┐  HTTP POST    ┌─────────┐  Generate  ┌────────┐
│Worker #1 │──────────────►│ Ollama  │───────────►│runway/ │
│          │ /api/generate │Service  │            │gen2-   │
│          │{model,prompt} │(11434)  │            │lite    │
└──────────┘               └─────────┘            └────────┘
                                                        │
                                                   Process with AI
                                                        │
                                                        ▼
                                                  Video Binary Data
```

### 4. Save Generated Video

```
┌──────────┐  Write File   ┌─────────┐  Update  ┌────────┐
│Worker #1 │──────────────►│File     │─────────►│SQLite  │
│          │               │System   │          │  DB    │
└──────────┘               └─────────┘          └────────┘
                                              Status: completed
                                              Progress: 100
                                              VideoPath: /videos/{id}.mp4
```

### 5. User Gets Result

```
┌──────┐  GET /api/v1/jobs/{id}  ┌─────────┐  Query  ┌────────┐
│User  │◄────────────────────────│ASP.NET  │◄────────│SQLite  │
│      │  {status, videoUrl}     │Controller│         │  DB    │
└──────┘                         └─────────┘         └────────┘
```

---

## Technology Stack

### Backend
```
┌─────────────────────────────────────┐
│  ASP.NET Core 8                     │
│  - .NET 8 SDK                       │
│  - Entity Framework Core 8          │
│  - Kestrel Web Server               │
│  - JWT Authentication (optional)    │
│  - WebSocket Support                │
└─────────────────────────────────────┘
```

### Database
```
┌─────────────────────────────────────┐
│  SQLite 3.x                         │
│  - Single file database             │
│  - No server required               │
│  - ACID compliant                   │
│  - Location: data/queue.db          │
└─────────────────────────────────────┘
```

### AI/ML
```
┌─────────────────────────────────────┐
│  Ollama                             │
│  - Local AI model serving           │
│  - Model: runway/gen2-lite          │
│  - Port: 11434                      │
│  - REST API                         │
└─────────────────────────────────────┘
```

### Web Server
```
┌─────────────────────────────────────┐
│  Nginx                              │
│  - Reverse proxy                    │
│  - Load balancing                   │
│  - SSL termination                  │
│  - Static file serving              │
└─────────────────────────────────────┘
```

### Operating System
```
┌─────────────────────────────────────┐
│  Arch Linux                         │
│  - Rolling release                  │
│  - Latest packages                  │
│  - pacman package manager           │
│  - systemd init system              │
└─────────────────────────────────────┘
```

---

## File Structure

```
/var/www/dicabr.com.br/
│
├── src/
│   ├── backend/
│   │   ├── Program.cs              ← Application entry point
│   │   ├── Models.cs               ← Data models & EF Core
│   │   ├── Services.cs             ← Business logic & Ollama client
│   │   ├── Controllers.cs          ← API endpoints
│   │   ├── appsettings.json        ← Configuration
│   │   ├── appsettings.Development.json
│   │   ├── OllamaWebApi.csproj     ← Project file
│   │   └── Properties/
│   │       └── launchSettings.json
│   │
│   └── frontend/public/
│       ├── index.html              ← Main HTML
│       └── src/
│           ├── app.js              ← Frontend logic
│           ├── styles/main.css     ← Styles
│           └── utils/api.js        ← API client
│
├── scripts/
│   ├── install-archlinux.sh        ← Auto installer
│   └── build.sh                    ← Build script
│
├── data/
│   ├── queue.db                    ← SQLite database
│   ├── videos/                     ← Generated videos
│   ├── images/                     ← Uploaded images
│   └── database/                   ← Additional data
│
├── logs/
│   └── stdout.log                  ← Application logs
│
├── publish/                        ← Compiled application
│   ├── OllamaWebApi.dll
│   ├── OllamaWebApi.pdb
│   └── [dependencies...]
│
├── web.config                      ← IIS configuration
├── DEPLOYMENT.md                   ← Deployment guide
├── QUICKSTART-ARCHLINUX.md         ← Quick start guide
├── README-REAL-OLLAMA.md           ← Main documentation
└── CONVERSAO-RESUMO.md             ← Conversion summary
```

---

## Network Ports

| Service | Port | Protocol | Purpose |
|---------|------|----------|---------|
| Nginx   | 80   | HTTP     | Web traffic (unencrypted) |
| Nginx   | 443  | HTTPS    | Web traffic (encrypted) |
| ASP.NET | 8080 | HTTP     | Application server |
| Ollama  | 11434| HTTP     | AI model API |

---

## Systemd Services

### dicabr-web.service
```ini
[Unit]
Description=Ollama Web API - dicabr.com.br
After=network.target ollama.service

[Service]
Type=notify
User=http
WorkingDirectory=/var/www/dicabr.com.br/publish
ExecStart=/usr/bin/dotnet OllamaWebApi.dll
Restart=on-failure
Environment=DOMAIN=dicabr.com.br
Environment=OLLAMA_MODEL=runway/gen2-lite

[Install]
WantedBy=multi-user.target
```

### ollama.service
```ini
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
Type=exec
User=http
ExecStart=/usr/bin/ollama serve
Restart=always

[Install]
WantedBy=multi-user.target
```

---

## Security Layers

```
┌─────────────────────────────────────┐
│  Firewall (UFW)                     │
│  - Allow SSH (22)                   │
│  - Allow HTTP (80)                  │
│  - Allow HTTPS (443)                │
└─────────────────────────────────────┘
              ▼
┌─────────────────────────────────────┐
│  Nginx                              │
│  - Rate limiting                    │
│  - Request filtering                │
│  - SSL/TLS termination              │
└─────────────────────────────────────┘
              ▼
┌─────────────────────────────────────┐
│  ASP.NET Core                       │
│  - JWT Authentication               │
│  - CORS policies                    │
│  - Input validation                 │
│  - API key protection               │
└─────────────────────────────────────┘
              ▼
┌─────────────────────────────────────┐
│  Application Layer                  │
│  - Parameter sanitization           │
│  - SQL injection prevention (EF)    │
│  - Error handling                   │
└─────────────────────────────────────┘
```

---

## Performance Characteristics

### Resource Allocation (KVM 1 - 2GB RAM)

```
┌─────────────────────────────────────┐
│  Total RAM: 2048 MB                 │
│                                     │
│  ┌───────────────────────────────┐ │
│  │ Ollama + Model: ~800 MB      │ │
│  ├───────────────────────────────┤ │
│  │ ASP.NET Core: ~200 MB        │ │
│  ├───────────────────────────────┤ │
│  │ Nginx: ~10 MB                │ │
│  ├───────────────────────────────┤ │
│  │ System: ~500 MB              │ │
│  ├───────────────────────────────┤ │
│  │ Free/Cache: ~538 MB          │ │
│  └───────────────────────────────┘ │
└─────────────────────────────────────┘
```

### Concurrent Processing

```
MAX_CONCURRENT_JOBS = 3

Worker #1 ──► Processing Job A
Worker #2 ──► Processing Job B
Worker #3 ──► Processing Job C

Queue: [Job D, Job E, Job F...]
```

---

## Monitoring Points

### Health Checks
```
GET /health
↓
Returns: {
  "status": "healthy",
  "domain": "dicabr.com.br",
  "timestamp": "...",
  "active_workers": 3
}
```

### Logs
```
Application Logs: /var/www/dicabr.com.br/logs/stdout.log
System Logs: journalctl -u dicabr-web
Ollama Logs: journalctl -u ollama
Nginx Logs: /var/log/nginx/access.log, error.log
```

### Metrics
```
Database Size: du -h data/queue.db
Video Storage: du -sh data/videos/*
Memory Usage: free -h
CPU Usage: htop
Disk Space: df -h
```

---

This architecture is optimized for:
- ✅ Hostinger KVM 1 specifications
- ✅ Arch Linux rolling release
- ✅ Real Ollama integration (no simulation)
- ✅ Production deployment
- ✅ Scalability and reliability
