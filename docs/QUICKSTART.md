# Quick Start Guide

## 5-Minute Setup

### Step 1: Clone and Install
```bash
cd ollama-web-project
chmod +x scripts/install.sh
./scripts/install.sh
```

### Step 2: Access Application
- **Frontend**: http://localhost
- **API Docs**: http://localhost:8080/docs

### Step 3: Create Your First Video

1. Go to the "Create" section
2. Enter a prompt: "A serene mountain landscape at sunset"
3. Choose duration and resolution
4. Click "Generate Video"
5. Watch the progress in real-time!

## Common Commands

```bash
# Start/Stop/Restart
./scripts/manage.sh start
./scripts/manage.sh stop
./scripts/manage.sh restart

# View Logs
./scripts/manage.sh logs

# Check Status
./scripts/manage.sh status

# Backup Data
./scripts/manage.sh backup
```

## Troubleshooting

**Port already in use?**
```bash
# Change port in .env file
HOST_PORT=8081
```

**Services not starting?**
```bash
# Check Docker is running
docker ps

# View detailed logs
./scripts/manage.sh logs ollama-web
```

**Need to reset everything?**
```bash
./scripts/manage.sh cleanup
./scripts/install.sh
```

## Next Steps

1. **Customize Configuration** - Edit `.env` file
2. **Enable Security** - Set `ENABLE_AUTH=true` and change `API_KEY`
3. **Set Custom Domain** - Update `DOMAIN` in `.env`
4. **Deploy to Production** - Follow production deployment guide

For full documentation, see [README.md](README.md)
