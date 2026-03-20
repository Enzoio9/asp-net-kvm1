# Correção Rápida - Erro 500 Internal Server Error nginx/1.28.2

## ⚠️ Problema Principal Corrigido

O código foi atualizado para corrigir o problema principal:
- **Porta do Kestrel**: Alterada de 5000 para 8080 (configurável via variável de ambiente)
- **Servir arquivos estáticos**: Adicionado suporte para `/videos/` e `/images/`
- **Criação automática de diretórios**: Diretórios necessários são criados automaticamente

## 🚀 Passos para Corrigir

### 1. No Servidor Linux (Produção)

```bash
# 1. Parar serviços
sudo systemctl stop ollama-web-api
sudo systemctl stop nginx

# 2. Criar diretórios necessários
sudo mkdir -p /var/www/dicabr.com.br/data/videos
sudo mkdir -p /var/www/dicabr.com.br/data/images
sudo mkdir -p /var/www/dicabr.com.br/data/database

# 3. Definir permissões
sudo chown -R www-data:www-data /var/www/dicabr.com.br/data
sudo chmod -R 755 /var/www/dicabr.com.br/data

# 4. Copiar configuração do nginx
sudo cp /caminho/para/ollama-web-project/nginx.conf \
        /etc/nginx/sites-available/dicabr.com.br

# 5. Habilitar site
sudo ln -sf /etc/nginx/sites-available/dicabr.com.br \
            /etc/nginx/sites-enabled/dicabr.com.br

# 6. Testar configuração nginx
sudo nginx -t

# 7. Iniciar aplicação .NET
cd /caminho/para/ollama-web-project/src/backend
export ASPNETCORE_HTTP_PORTS=8080
export VIDEO_DIR=/var/www/dicabr.com.br/data/videos
export IMAGE_DIR=/var/www/dicabr.com.br/data/images
export DB_PATH=/var/www/dicabr.com.br/data/database/queue.db
dotnet build --configuration Release

# 8. Iniciar aplicação em segundo plano (ou usar systemd)
nohup dotnet run --configuration Release > /var/log/ollama-web.log 2>&1 &

# 9. Verificar se está rodando
sleep 3
curl http://localhost:8080/health

# 10. Iniciar nginx
sudo systemctl start nginx
sudo systemctl status nginx
```

### 2. Testar Aplicação

```bash
# Testar endpoint de saúde
curl http://localhost:8080/health

# Testar API
curl http://localhost:8080/api/jobs

# Testar através do nginx
curl http://localhost/health
curl http://dicabr.com.br/health
```

### 3. Verificar Logs

```bash
# Logs da aplicação
tail -f /var/log/ollama-web.log

# Logs do nginx
sudo tail -f /var/log/nginx/dicabr_error.log
sudo tail -f /var/log/nginx/access.log

# Status dos serviços
sudo systemctl status ollama-web-api
sudo systemctl status nginx
```

## 🔧 Configurar como Serviço Systemd (Recomendado)

Crie o arquivo de serviço:

```bash
sudo nano /etc/systemd/system/ollama-web-api.service
```

Conteúdo:

```ini
[Unit]
Description=Ollama Web API - dicabr.com.br
After=network.target ollama.service

[Service]
Type=exec
WorkingDirectory=/var/www/dicabr.com.br/app/src/backend
Environment="ASPNETCORE_URLS=http://*:8080"
Environment="ASPNETCORE_HTTP_PORTS=8080"
Environment="DOMAIN=dicabr.com.br"
Environment="VIDEO_DIR=/var/www/dicabr.com.br/data/videos"
Environment="IMAGE_DIR=/var/www/dicabr.com.br/data/images"
Environment="DB_PATH=/var/www/dicabr.com.br/data/database/queue.db"
Environment="OLLAMA_HOST=http://localhost:11434"
Environment="OLLAMA_MODEL=runway/gen2-lite"
ExecStart=/usr/bin/dotnet run --configuration Release
Restart=always
RestartSec=10
User=www-data
Group=www-data

[Install]
WantedBy=multi-user.target
```

Ativar e iniciar:

```bash
sudo systemctl daemon-reload
sudo systemctl enable ollama-web-api
sudo systemctl start ollama-web-api
sudo systemctl status ollama-web-api
```

## ✅ Checklist de Verificação

- [ ] Diretórios `/var/www/dicabr.com.br/data/{videos,images,database}` existem
- [ ] Permissões estão corretas (755, proprietário www-data)
- [ ] Aplicação .NET está rodando na porta 8080
- [ ] Comando `curl http://localhost:8080/health` retorna sucesso
- [ ] Configuração do nginx copiada e habilitada
- [ ] Comando `nginx -t` não mostra erros
- [ ] Nginx está ativo (`systemctl status nginx`)
- [ ] Ollama está acessível em `http://localhost:11434`

## 🐛 Diagnóstico de Problemas Comuns

### Erro: "Address already in use"

```bash
# Verificar o que está usando a porta 8080
sudo netstat -tlnp | grep 8080

# Matar processo se necessário
sudo kill -9 <PID>
```

### Erro: "Permission denied" ao criar arquivos

```bash
# Corrigir permissões
sudo chown -R www-data:www-data /var/www/dicabr.com.br/data
sudo chmod -R 755 /var/www/dicabr.com.br/data
```

### Nginx retorna 502 Bad Gateway

```bash
# Verificar se aplicação está rodando
curl http://localhost:8080/health

# Se falhar, verificar logs
journalctl -u ollama-web-api -n 50
```

### Erro de banco de dados SQLite

```bash
# Verificar diretório do banco
ls -la /var/www/dicabr.com.br/data/database/

# Criar se não existir
sudo mkdir -p /var/www/dicabr.com.br/data/database
sudo chown -R www-data:www-data /var/www/dicabr.com.br/data/database
```

## 📝 Notas Importantes

1. **Porta 8080**: A aplicação agora usa a porta 8080 por padrão (configurável via `ASPNETCORE_HTTP_PORTS`)
2. **Diretórios**: Os diretórios de vídeos e imagens são criados automaticamente
3. **Banco de Dados**: SQLite é criado automaticamente no primeiro acesso
4. **Nginx**: Atua como proxy reverso e serve arquivos estáticos diretamente

## 🆘 Suporte

Se ainda tiver problemas, colete:

```bash
# Informações do sistema
uname -a
dotnet --version
nginx -v

# Logs
sudo journalctl -u ollama-web-api -n 100
sudo tail -n 100 /var/log/nginx/error.log

# Configurações
cat /etc/nginx/sites-enabled/dicabr.com.br
```

Com essas informações, será mais fácil diagnosticar o problema específico.
