# Fix 500 Internal Server Error - nginx/1.28.2

## Problema
Ao iniciar o site com nginx/1.28.2, ocorre o erro "500 Internal Server Error".

## Soluções

### 1. Verificar se o Backend está Rodando

O nginx atua como proxy reverso para a aplicação ASP.NET Core na porta 8080.

```bash
# Verificar se a aplicação está rodando
sudo systemctl status ollama-web-api

# Ou verificar a porta 8080
sudo netstat -tlnp | grep 8080

# Iniciar manualmente se necessário
cd /path/to/ollama-web-project
./start.sh
```

### 2. Configurar Diretórios de Dados

A aplicação precisa de diretórios para vídeos e imagens:

```bash
# Criar diretórios necessários
sudo mkdir -p /var/www/dicabr.com.br/data/videos
sudo mkdir -p /var/www/dicabr.com.br/data/images
sudo mkdir -p /var/www/dicabr.com.br/data/database

# Definir permissões corretas
sudo chown -R $USER:$USER /var/www/dicabr.com.br/data
sudo chmod -R 755 /var/www/dicabr.com.br/data
```

### 3. Configurar Nginx Corretamente

Use o arquivo `nginx.conf` fornecido neste repositório:

```bash
# Copiar configuração do nginx
sudo cp nginx.conf /etc/nginx/sites-available/dicabr.com.br

# Habilitar o site
sudo ln -sf /etc/nginx/sites-available/dicabr.com.br \
            /etc/nginx/sites-enabled/dicabr.com.br

# Testar configuração
sudo nginx -t

# Recarregar nginx
sudo systemctl reload nginx
```

### 4. Verificar Logs de Erro

Os logs do nginx mostram o erro específico:

```bash
# Ver logs de erro do nginx
sudo tail -f /var/log/nginx/dicabr_error.log

# Ver logs da aplicação (se usando systemd)
sudo journalctl -u ollama-web-api -f

# Ver logs do nginx em tempo real
sudo tail -f /var/log/nginx/access.log
```

### 5. Causas Comuns do Erro 500

#### A. Backend não está rodando
**Sintoma**: nginx não consegue conectar na porta 8080

**Solução**:
```bash
# Iniciar aplicação
cd /path/to/ollama-web-project/src/backend
dotnet run
```

#### B. Permissão de diretório
**Sintoma**: Erro ao criar arquivos ou banco de dados

**Solução**:
```bash
sudo chown -R www-data:www-data /var/www/dicabr.com.br/data
sudo chmod -R 755 /var/www/dicabr.com.br/data
```

#### C. Banco de dados SQLite
**Sintoma**: Erro ao inicializar o Entity Framework

**Solução**:
```bash
# Verificar se o diretório do banco existe
ls -la /var/www/dicabr.com.br/data/database/

# Criar se não existir
mkdir -p /var/www/dicabr.com.br/data/database
```

#### D. Ollama não disponível
**Sintoma**: Aplicação inicia mas falha ao processar jobs

**Solução**:
```bash
# Verificar se Ollama está rodando
ollama list

# Iniciar Ollama se necessário
ollama serve &

# Ou configurar OLLAMA_HOST para apontar para instância remota
export OLLAMA_HOST=http://seu-servidor-ollama:11434
```

### 6. Script de Diagnóstico

Execute o script de diagnóstico fornecido:

```bash
chmod +x start.sh
sudo ./start.sh
```

### 7. Configurar Serviço Systemd (Produção)

Crie um serviço para gerenciar a aplicação:

```bash
sudo nano /etc/systemd/system/ollama-web-api.service
```

Conteúdo do serviço:
```ini
[Unit]
Description=Ollama Web API - dicabr.com.br
After=network.target ollama.service

[Service]
Type=exec
WorkingDirectory=/path/to/ollama-web-project/src/backend
Environment="ASPNETCORE_URLS=http://*:8080"
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

Habilitar e iniciar:
```bash
sudo systemctl daemon-reload
sudo systemctl enable ollama-web-api
sudo systemctl start ollama-web-api
sudo systemctl status ollama-web-api
```

### 8. Testar Aplicação Diretamente

Teste a aplicação sem nginx para isolar o problema:

```bash
# Acessar diretamente (sem nginx)
curl http://localhost:8080/health
curl http://localhost:8080/api/jobs

# Se funcionar, o problema está no nginx
# Se falhar, o problema está na aplicação
```

### 9. Aumentar Limites do Nginx

Para uploads grandes de vídeo:

```nginx
# Em /etc/nginx/nginx.conf
http {
    client_max_body_size 500M;
    proxy_request_buffering off;
    proxy_buffering off;
}
```

### 10. Checklist Rápido

- [ ] Backend ASP.NET Core está rodando na porta 8080
- [ ] Diretórios `/var/www/dicabr.com.br/data/{videos,images,database}` existem
- [ ] Permissões dos diretórios estão corretas (755)
- [ ] Nginx configurado com proxy_pass para localhost:8080
- [ ] Configuração do nginx testada (`nginx -t`)
- [ ] Nginx recarregado (`systemctl reload nginx`)
- [ ] Ollama está acessível (local ou remoto)
- [ ] Logs verificados em busca de erros específicos

## Exemplo de Configuração Funcional

Veja o arquivo `nginx.conf` neste repositório para uma configuração completa e testada.

## Suporte

Se nenhum desses passos resolver, colete as seguintes informações:

1. Logs de erro do nginx: `/var/log/nginx/dicabr_error.log`
2. Logs da aplicação (output do dotnet run)
3. Versão do nginx: `nginx -v`
4. Versão do .NET: `dotnet --version`
5. Sistema operacional: `cat /etc/os-release`

Com essas informações, será mais fácil diagnosticar o problema específico.
