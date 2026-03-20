#!/bin/bash
# KVM1 Ollama Web API - Deploy e Startup Script
# Arch Linux / Hostinger KVM
set -euo pipefail

# -------------------------------
# CONFIGURAÇÃO
# -------------------------------
APP_DIR="/var/www/KVM1"
GIT_REPO="https://github.com/Enzoio9/asp-net-kvm1.git"
USER_NAME="$(whoami)"
DOMAIN="dicabr.com.br"
EMAIL="admin@$DOMAIN"
IPV6="2a02:4780:66:2c1f::1"
BACKEND_DIR="$APP_DIR/src/backend"
FRONTEND_DIR="$APP_DIR/src/frontend"
PUBLISH_DIR="$APP_DIR/publish"
DATA_DIR="$APP_DIR/data"
VIDEO_DIR="$DATA_DIR/videos"
IMAGE_DIR="$DATA_DIR/images"
DATABASE_DIR="$DATA_DIR/database"
DB_PATH="$DATABASE_DIR/queue.db"
PORT=8080

# Cores para log
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}✅${NC} $1"; }
log_warn()  { echo -e "${YELLOW}⚠️${NC} $1"; }
log_error() { echo -e "${RED}❌${NC} $1"; exit 1; }

# -------------------------------
# 1️⃣ Atualizar sistema e instalar dependências
# -------------------------------
log_info "Atualizando sistema e instalando dependências..."
sudo pacman -Syu --noconfirm
sudo pacman -S --noconfirm git dotnet-sdk dotnet-runtime aspnet-runtime nginx certbot certbot-nginx bind-tools lsof

# Checar .NET 8
if ! dotnet --list-runtimes | grep -q "8.0"; then
    log_error ".NET 8 não foi instalado corretamente!"
fi
log_info ".NET 8 instalado com sucesso"

# -------------------------------
# 2️⃣ Clonar repositório
# -------------------------------
if [ ! -d "$APP_DIR" ]; then
    log_info "Clonando repositório..."
    sudo git clone "$GIT_REPO" "$APP_DIR"
else
    log_warn "$APP_DIR já existe. Pulando clone."
fi

# Ajustar permissões
sudo chown -R $USER_NAME:$USER_NAME "$APP_DIR"

# -------------------------------
# 3️⃣ Corrigir arquivos C# para .NET 8
# -------------------------------
log_info "Ajustando código C# para .NET 8..."
[ -f "$BACKEND_DIR/Services.cs" ] && grep -q "using System.Text;" "$BACKEND_DIR/Services.cs" || sed -i '1i using System.Text;' "$BACKEND_DIR/Services.cs"
sed -i 's|, "application/json"|, Encoding.UTF8, "application/json"|' "$BACKEND_DIR/Services.cs"
[ -f "$BACKEND_DIR/Controllers.cs" ] && grep -q "using Microsoft.EntityFrameworkCore;" "$BACKEND_DIR/Controllers.cs" || sed -i '1i using Microsoft.EntityFrameworkCore;' "$BACKEND_DIR/Controllers.cs"

# -------------------------------
# 4️⃣ Publicar backend
# -------------------------------
log_info "Publicando backend..."
dotnet publish "$BACKEND_DIR/OllamaWebApi.csproj" -c Release -o "$PUBLISH_DIR"

# -------------------------------
# 5️⃣ Criar diretórios de dados
# -------------------------------
log_info "Criando diretórios de dados..."
mkdir -p "$VIDEO_DIR" "$IMAGE_DIR" "$DATABASE_DIR"
chmod -R 755 "$DATA_DIR"
sudo chown -R $USER_NAME:$USER_NAME "$DATA_DIR"

# -------------------------------
# 6️⃣ Parar serviço existente (se houver)
# -------------------------------
log_info "Parando serviço existente..."
sudo systemctl stop kvm1.service 2>/dev/null || true
sleep 2

# Verificar se há processos usando a porta
if lsof -iTCP:"$PORT" -sTCP:LISTEN &>/dev/null; then
    log_warn "Porta $PORT ainda está em uso. Matando processo..."
    sudo fuser -k ${PORT}/tcp 2>/dev/null || true
    sleep 2
fi

# -------------------------------
# 7️⃣ Criar serviço systemd
# -------------------------------
SERVICE_FILE="/etc/systemd/system/kvm1.service"
log_info "Criando/atualizando serviço systemd..."
sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=ASP.NET KVM1 Backend
After=network.target

[Service]
WorkingDirectory=$PUBLISH_DIR
ExecStart=/usr/bin/dotnet $PUBLISH_DIR/OllamaWebApi.dll
Restart=always
RestartSec=10
User=$USER_NAME
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=ASPNETCORE_HTTP_PORTS=$PORT
Environment=VIDEO_DIR=$VIDEO_DIR
Environment=IMAGE_DIR=$IMAGE_DIR
Environment=DB_PATH=$DB_PATH
Environment=DOTNET_ROOT=/usr/share/dotnet

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl daemon-reload
sudo systemctl enable kvm1.service

# -------------------------------
# 8️⃣ Iniciar serviço
# -------------------------------
log_info "Iniciando serviço systemd..."
sudo systemctl start kvm1.service
sleep 5

# -------------------------------
# 9️⃣ Verificar status
# -------------------------------
log_info "Verificando status do serviço..."
sudo systemctl status kvm1.service --no-pager

# Aguardar aplicação iniciar
log_info "Aguardando aplicação iniciar..."
sleep 5

# Testar health check
if curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT/health | grep -q "200"; then
    log_info "✅ Aplicação está rodando com sucesso!"
else
    log_warn "⚠️ Aplicação pode não estar responding. Verifique os logs."
fi

# -------------------------------
# 🔟 Mostrar informações
# -------------------------------
echo ""
log_info "🎉 Deploy concluído!"
echo ""
echo "🌐 URL: http://localhost:$PORT"
echo "📝 API Docs: http://localhost:$PORT/docs"
echo "💚 Health Check: http://localhost:$PORT/health"
echo "📁 Video Directory: $VIDEO_DIR"
echo "📁 Image Directory: $IMAGE_DIR"
echo "📁 Database Path: $DB_PATH"
echo ""
echo "📊 Comandos úteis:"
echo "  - Ver logs: sudo journalctl -u kvm1 -f"
echo "  - Reiniciar: sudo systemctl restart kvm1"
echo "  - Parar: sudo systemctl stop kvm1"
echo "  - Status: sudo systemctl status kvm1"
echo ""
