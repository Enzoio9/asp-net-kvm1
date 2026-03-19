#!/bin/bash
# COMANDOS EXATOS para instalar dicabr.com.br no Hostinger KVM 1 - Arch Linux
# Copie e cole estes comandos no seu terminal SSH

echo "=========================================="
echo "  COMANDOS EXATOS - dicabr.com.br"
echo "  Hostinger KVM 1 - Arch Linux"
echo "=========================================="
echo ""

# Passo 1: Conectar ao VPS via SSH (faça isso manualmente)
echo "PASSO 1: Conecte-se ao seu VPS:"
echo "ssh root@SEU-IP-VPS"
echo ""
read -p "Pressione Enter após conectar..."

# Passo 2: Atualizar sistema
echo ""
echo "PASSO 2: Atualizando sistema..."
sudo pacman -Syu --noconfirm
echo ""

# Passo 3: Instalar .NET 8
echo "PASSO 3: Instalando .NET 8 SDK..."
sudo pacman -S --noconfirm dotnet-sdk-8.0 aspnet-runtime aspnet-targeting-pack
dotnet --version
echo ""

# Passo 4: Instalar Ollama
echo "PASSO 4: Instalando Ollama..."
curl -fsSL https://ollama.com/install.sh | sh
ollama --version
echo ""

# Passo 5: Baixar modelo runway/gen2-lite
echo "PASSO 5: Baixando modelo runway/gen2-lite..."
ollama pull runway/gen2-lite
ollama list
echo ""

# Passo 6: Criar diretório da aplicação
echo "PASSO 6: Criando diretórios..."
sudo mkdir -p /var/www/dicabr.com.br
cd /var/www/dicabr.com.br
echo ""

# Passo 7: Clonar repositório (substitua pela URL real)
echo "PASSO 7: Clone o repositório ou faça upload dos arquivos"
echo "Opção A - Git:"
echo "  git clone SUA-URL-DO-REPOSITORIO ."
echo ""
echo "Opção B - Upload manual:"
echo "  Use FTP/SFTP para enviar arquivos para /var/www/dicabr.com.br"
echo ""
read -p "Pressione Enter quando os arquivos estiverem no lugar..."

# Passo 8: Build da aplicação
echo ""
echo "PASSO 8: Build da aplicação ASP.NET..."
cd /var/www/dicabr.com.br/src/backend
sudo dotnet restore
sudo dotnet build -c Release
sudo dotnet publish -c Release -o /var/www/dicabr.com.br/publish
echo ""

# Passo 9: Configurar permissões
echo "PASSO 9: Configurando permissões..."
sudo chown -R http:http /var/www/dicabr.com.br
sudo chmod -R 755 /var/www/dicabr.com.br
sudo mkdir -p /var/www/dicabr.com.br/data/videos
sudo mkdir -p /var/www/dicabr.com.br/data/images
sudo mkdir -p /var/www/dicabr.com.br/data/database
sudo chown http:http /var/www/dicabr.com.br/data/*
echo ""

# Passo 10: Criar serviço systemd
echo "PASSO 10: Criando serviço systemd..."
sudo tee /etc/systemd/system/dicabr-web.service > /dev/null <<'EOF'
[Unit]
Description=Ollama Web API - dicabr.com.br
After=network.target ollama.service

[Service]
Type=notify
User=http
Group=http
WorkingDirectory=/var/www/dicabr.com.br/publish
ExecStart=/usr/bin/dotnet /var/www/dicabr.com.br/publish/OllamaWebApi.dll
Restart=on-failure
RestartSec=10
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=DOMAIN=dicabr.com.br
Environment=ASPNETCORE_HTTP_PORTS=8080
Environment=DB_PATH=/var/www/dicabr.com.br/data/queue.db
Environment=VIDEO_DIR=/var/www/dicabr.com.br/data/videos
Environment=IMAGE_DIR=/var/www/dicabr.com.br/data/images
Environment=OLLAMA_HOST=http://localhost:11434
Environment=OLLAMA_MODEL=runway/gen2-lite
Environment=MAX_CONCURRENT_JOBS=3
SyslogIdentifier=dotnet-dicabr

[Install]
WantedBy=multi-user.target
EOF
echo ""

# Passo 11: Criar serviço do Ollama (se não existir)
echo "PASSO 11: Configurando serviço do Ollama..."
if [ ! -f /etc/systemd/system/ollama.service ]; then
    sudo tee /etc/systemd/system/ollama.service > /dev/null <<'EOF'
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
    echo "Serviço do Ollama criado."
else
    echo "Serviço do Ollama já existe."
fi
echo ""

# Passo 12: Recarregar systemd
echo "PASSO 12: Recarregando systemd..."
sudo systemctl daemon-reload
echo ""

# Passo 13: Habilitar e iniciar serviços
echo "PASSO 13: Iniciando serviços..."
sudo systemctl enable ollama
sudo systemctl start ollama
sleep 2
echo "✓ Ollama iniciado"

sudo systemctl enable dicabr-web
sudo systemctl start dicabr-web
sleep 2
echo "✓ Aplicação iniciada"
echo ""

# Passo 14: Verificar status
echo "PASSO 14: Verificando status..."
echo ""
echo "Status do Ollama:"
sudo systemctl status ollama --no-pager -n 3
echo ""
echo "Status da Aplicação:"
sudo systemctl status dicabr-web --no-pager -n 3
echo ""

# Passo 15: Teste de saúde (health check)
echo "PASSO 15: Health check..."
if curl -f http://localhost:8080/health &> /dev/null; then
    echo "✅ Aplicação está saudável!"
    curl -s http://localhost:8080/health | python -m json.tool 2>/dev/null || curl -s http://localhost:8080/health
else
    echo "❌ Health check falhou!"
fi
echo ""

# Passo 16: Instalar Nginx (opcional mas recomendado)
echo "PASSO 16: Instalar Nginx como reverse proxy?"
read -p "Instalar Nginx? (y/n): " install_nginx
if [[ $install_nginx == [Yy]* ]]; then
    sudo pacman -S --noconfirm nginx
    
    sudo tee /etc/nginx/nginx.conf > /dev/null <<'EOF'
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
        }
        
        location /images/ {
            proxy_pass         http://localhost:8080;
        }
        
        location /api/ {
            proxy_pass         http://localhost:8080;
        }
        
        location /health {
            proxy_pass         http://localhost:8080;
        }
    }
}
EOF
    
    sudo systemctl enable nginx
    sudo systemctl start nginx
    echo "✅ Nginx instalado e configurado!"
fi
echo ""

# Passo 17: Configurar firewall (opcional)
echo "PASSO 17: Configurar firewall UFW?"
read -p "Configurar firewall? (y/n): " config_firewall
if [[ $config_firewall == [Yy]* ]]; then
    sudo pacman -S --noconfirm ufw
    sudo ufw allow ssh
    sudo ufw allow http
    sudo ufw allow https
    sudo ufw enable
    echo "✅ Firewall configurado!"
fi
echo ""

# RESUMO FINAL
echo "=========================================="
echo "  ✅ INSTALAÇÃO CONCLUÍDA!"
echo "=========================================="
echo ""
echo "📊 Status dos Serviços:"
echo "  - Ollama: $(systemctl is-active ollama)"
echo "  - Aplicação: $(systemctl is-active dicabr-web)"
if [[ $install_nginx == [Yy]* ]]; then
    echo "  - Nginx: $(systemctl is-active nginx)"
fi
echo ""
echo "🌐 URLs de Acesso:"
echo "  - Frontend: http://dicabr.com.br"
echo "  - API Docs: http://dicabr.com.br/swagger"
echo "  - Health: http://dicabr.com.br/health"
echo ""
echo "🔧 Comandos Úteis:"
echo "  - Iniciar app: sudo systemctl start dicabr-web"
echo "  - Parar app: sudo systemctl stop dicabr-web"
echo "  - Reiniciar app: sudo systemctl restart dicabr-web"
echo "  - Logs app: sudo journalctl -u dicabr-web -f"
echo "  - Logs Ollama: sudo journalctl -u ollama -f"
echo ""
echo "🎯 Testar API:"
echo "  curl http://localhost:8080/health"
echo "  curl http://localhost:8080/api/v1/jobs"
echo ""
echo "📁 Diretórios Importantes:"
echo "  - App: /var/www/dicabr.com.br"
echo "  - Banco: /var/www/dicabr.com.br/data/queue.db"
echo "  - Vídeos: /var/www/dicabr.com.br/data/videos"
echo "  - Logs: /var/www/dicabr.com.br/logs"
echo ""
echo "🚀 TUDO PRONTO PARA USO!"
echo ""
