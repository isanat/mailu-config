#!/bin/bash
# ============================================
# INSTALAÇÃO DO MAILU - SERVIDOR DE EMAIL
# ============================================
# Domínio: travelconcierge.site
# IP: 164.68.126.14
# 
# Execute este script como root no servidor
# ============================================

set -e

# ==========================================
# CONFIGURAÇÕES
# ==========================================
MAILU_DIR="/opt/mailu"
DOMAIN="travelconcierge.site"
SERVER_IP="164.68.126.14"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Funções de log
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# ==========================================
# INÍCIO
# ==========================================
clear
echo ""
echo "============================================"
echo "   📧 MAILU - INSTALAÇÃO DO SERVIDOR EMAIL"
echo "============================================"
echo ""
echo "   Domínio: $DOMAIN"
echo "   IP: $SERVER_IP"
echo "   Diretório: $MAILU_DIR"
echo ""
echo "============================================"
echo ""

# Verificar se é root
if [ "$EUID" -ne 0 ]; then 
    log_error "Este script deve ser executado como root!"
    log_info "Use: sudo bash $0"
    exit 1
fi

# ==========================================
# PASSO 1: VERIFICAR PORTAS
# ==========================================
log_step "PASSO 1: Verificando portas necessárias..."

REQUIRED_PORTS="25 80 443 465 587 993 995"
PORTS_IN_USE=""

for PORT in $REQUIRED_PORTS; do
    if ss -tuln | grep -q ":$PORT "; then
        SERVICE=$(ss -tuln | grep ":$PORT " | head -1 | awk '{print $6}')
        PORTS_IN_USE="$PORTS_IN_USE\n  - Porta $PORT: $SERVICE"
    fi
done

if [ ! -z "$PORTS_IN_USE" ]; then
    log_warn "As seguintes portas já estão em uso:"
    echo -e "$PORTS_IN_USE"
    echo ""
    log_warn "Isso pode causar conflitos com o Mailu."
    echo ""
    read -p "Deseja continuar mesmo assim? (s/n): " CONTINUE
    if [ "$CONTINUE" != "s" ]; then
        log_info "Instalação cancelada."
        exit 0
    fi
fi

log_info "Verificação de portas concluída."

# ==========================================
# PASSO 2: INSTALAR DEPENDÊNCIAS
# ==========================================
log_step "PASSO 2: Instalando dependências..."

# Atualizar sistema
log_info "Atualizando sistema..."
apt-get update -qq

# Instalar utilitários necessários
log_info "Instalando utilitários..."
apt-get install -y -qq curl wget git openssl ca-certificates > /dev/null 2>&1

# Instalar Docker se necessário
if ! command -v docker &> /dev/null; then
    log_info "Instalando Docker..."
    curl -fsSL https://get.docker.com | sh > /dev/null 2>&1
    systemctl enable docker > /dev/null 2>&1
    systemctl start docker > /dev/null 2>&1
    log_info "Docker instalado!"
else
    log_info "Docker já está instalado: $(docker --version)"
fi

# Instalar Docker Compose se necessário
if ! command -v docker-compose &> /dev/null; then
    log_info "Instalando Docker Compose..."
    curl -sL "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    log_info "Docker Compose instalado!"
else
    log_info "Docker Compose já está instalado: $(docker-compose --version)"
fi

# ==========================================
# PASSO 3: CONFIGURAR FIREWALL
# ==========================================
log_step "PASSO 3: Configurando firewall..."

if command -v ufw &> /dev/null; then
    log_info "Configurando UFW..."
    
    # Permitir portas necessárias
    ufw allow 22/tcp comment 'SSH' > /dev/null 2>&1
    ufw allow 25/tcp comment 'SMTP' > /dev/null 2>&1
    ufw allow 80/tcp comment 'HTTP' > /dev/null 2>&1
    ufw allow 443/tcp comment 'HTTPS' > /dev/null 2>&1
    ufw allow 465/tcp comment 'SMTPS' > /dev/null 2>&1
    ufw allow 587/tcp comment 'Submission' > /dev/null 2>&1
    ufw allow 993/tcp comment 'IMAPS' > /dev/null 2>&1
    ufw allow 995/tcp comment 'POP3S' > /dev/null 2>&1
    
    # Ativar firewall
    ufw --force enable > /dev/null 2>&1
    
    log_info "Firewall configurado!"
else
    log_warn "UFW não encontrado. Configure o firewall manualmente."
fi

# ==========================================
# PASSO 4: CRIAR ESTRUTURA DE DIRETÓRIOS
# ==========================================
log_step "PASSO 4: Criando estrutura de diretórios..."

mkdir -p $MAILU_DIR
cd $MAILU_DIR

# Criar subdiretórios
mkdir -p certs data dkim filter mail mailqueue \
    overrides/nginx overrides/postfix overrides/dovecot \
    overrides/rspamd overrides/webmail \
    redis webmail clamav

log_info "Diretórios criados em $MAILU_DIR"

# ==========================================
# PASSO 5: GERAR CHAVE SECRETA
# ==========================================
log_step "PASSO 5: Gerando chave secreta..."

SECRET_KEY=$(openssl rand -hex 16)
log_info "Chave secreta gerada!"

# ==========================================
# PASSO 6: CRIAR DOCKER-COMPOSE.YML
# ==========================================
log_step "PASSO 6: Criando docker-compose.yml..."

cat > docker-compose.yml << 'DOCKERCOMPOSE'
version: '3.8'

services:
  front:
    image: ghcr.io/mailu/nginx:2024.06
    restart: always
    env_file: mailu.env
    ports:
      - "80:80"
      - "443:443"
      - "25:25"
      - "465:465"
      - "587:587"
      - "993:993"
      - "995:995"
    volumes:
      - "./certs:/certs"
      - "./overrides/nginx:/overrides:ro"
    networks:
      - mailu
    depends_on:
      - resolver

  resolver:
    image: ghcr.io/mailu/unbound:2024.06
    restart: always
    env_file: mailu.env
    networks:
      mailu:
        ipv4_address: 192.168.203.254

  smtp:
    image: ghcr.io/mailu/postfix:2024.06
    restart: always
    env_file: mailu.env
    volumes:
      - "./mailqueue:/queue"
      - "./overrides/postfix:/overrides:ro"
    networks:
      - mailu
    depends_on:
      - front
      - resolver

  imap:
    image: ghcr.io/mailu/dovecot:2024.06
    restart: always
    env_file: mailu.env
    volumes:
      - "./mail:/mail"
      - "./overrides/dovecot:/overrides:ro"
    networks:
      - mailu
    depends_on:
      - front
      - resolver

  antispam:
    image: ghcr.io/mailu/rspamd:2024.06
    restart: always
    env_file: mailu.env
    volumes:
      - "./filter:/var/lib/rspamd"
      - "./overrides/rspamd:/overrides:ro"
    networks:
      - mailu
    depends_on:
      - front
      - resolver

  antivirus:
    image: ghcr.io/mailu/clamav:2024.06
    restart: always
    env_file: mailu.env
    volumes:
      - "./clamav:/data"
    networks:
      - mailu
    depends_on:
      - resolver

  webmail:
    image: ghcr.io/mailu/webmail:2024.06
    restart: always
    env_file: mailu.env
    volumes:
      - "./webmail:/data"
      - "./overrides/webmail:/overrides:ro"
    networks:
      - mailu
    depends_on:
      - imap
      - resolver

  admin:
    image: ghcr.io/mailu/admin:2024.06
    restart: always
    env_file: mailu.env
    volumes:
      - "./data:/data"
      - "./dkim:/dkim"
    networks:
      - mailu
    depends_on:
      - redis
      - resolver

  redis:
    image: redis:alpine
    restart: always
    volumes:
      - "./redis:/data"
    networks:
      - mailu

networks:
  mailu:
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: 192.168.203.0/24
DOCKERCOMPOSE

log_info "docker-compose.yml criado!"

# ==========================================
# PASSO 7: CRIAR MAILU.ENV
# ==========================================
log_step "PASSO 7: Criando configurações de ambiente..."

cat > mailu.env << EOF
# Mailu Configuration - $DOMAIN
SECRET_KEY=$SECRET_KEY
DOMAIN=$DOMAIN
HOSTNAMES=mail.$DOMAIN,$DOMAIN
POSTMASTER=admin

BIND_ADDRESS4=0.0.0.0
BIND_ADDRESS6=::

RELAYNETS=192.168.203.0/24

MESSAGE_RATELIMIT=200/day
RECIPIENT_RATELIMIT=1000/day

TLS_FLAVOR=letsencrypt

AUTH_RATELIMIT_IP=60/hour
AUTH_RATELIMIT_USER=100/day

MESSAGE_SIZE_LIMIT=52428800

DISABLE_STATISTICS=false
WEBMAIL=snappymail
WEBROOT=/webmail
ADMIN_PATH=/admin

DB_SQLITE_FILE=/data/main.db
REDIS_HOST=redis
FRONT_ADDRESS=front
SMTP_ADDRESS=smtp
SMTP_PORT=25
IMAP_ADDRESS=imap
IMAP_PORT=993
ANTISPAM_ADDRESS=antispam
ANTIVIRUS_ADDRESS=antivirus
WEBMAIL_ADDRESS=webmail
ADMIN_ADDRESS=admin
RESOLVER_ADDRESS=192.168.203.254
LOG_LEVEL=WARNING
DEFAULT_QUOTA=1G

SESSION_COOKIE_SECURE=true
SESSION_COOKIE_HTTPONLY=true
EOF

log_info "mailu.env criado!"

# ==========================================
# PASSO 8: PUXAR IMAGENS
# ==========================================
log_step "PASSO 8: Baixando imagens Docker..."

docker-compose pull

log_info "Imagens baixadas!"

# ==========================================
# PASSO 9: INICIAR CONTAINERS
# ==========================================
log_step "PASSO 9: Iniciando containers Mailu..."

docker-compose up -d

log_info "Containers iniciados!"

# ==========================================
# PASSO 10: AGUARDAR INICIALIZAÇÃO
# ==========================================
log_step "PASSO 10: Aguardando inicialização..."

log_info "Aguardando 30 segundos para inicialização completa..."
sleep 30

# ==========================================
# VERIFICAR STATUS
# ==========================================
log_step "Verificando status dos containers..."

docker-compose ps

# ==========================================
# CONCLUÍDO
# ==========================================
echo ""
echo "============================================"
echo "   ✅ MAILU INSTALADO COM SUCESSO!"
echo "============================================"
echo ""
echo "📋 INFORMAÇÕES DE ACESSO:"
echo ""
echo "   🌐 Painel Admin:  http://$SERVER_IP/admin"
echo "   📧 Webmail:       http://$SERVER_IP/webmail"
echo ""
echo "   📨 Servidor SMTP: mail.$DOMAIN"
echo "   📥 Servidor IMAP: mail.$DOMAIN (porta 993)"
echo ""
echo "============================================"
echo ""
echo "⚠️  PRÓXIMOS PASSOS OBRIGATÓRIOS:"
echo ""
echo "1️⃣  CONFIGURAR DNS:"
echo "   ┌─────────────────────────────────────────┐"
echo "   │ Tipo  │ Nome           │ Valor         │"
echo "   ├─────────────────────────────────────────┤"
echo "   │ A     │ mail           │ $SERVER_IP   │"
echo "   │ MX    │ @              │ mail.$DOMAIN │"
echo "   │ TXT   │ @              │ v=spf1 mx a ~all │"
echo "   │ TXT   │ _dmarc         │ v=DMARC1; p=quarantine │"
echo "   └─────────────────────────────────────────┘"
echo ""
echo "2️⃣  CONFIGURAR REVERSE DNS (PTR):"
echo "   Contate seu provedor VPS para configurar:"
echo "   $SERVER_IP → mail.$DOMAIN"
echo ""
echo "3️⃣  CRIAR CONTA DE EMAIL:"
echo "   Acesse o painel admin e crie o usuário admin@$DOMAIN"
echo ""
echo "4️⃣  CONFIGURAR DKIM:"
echo "   No painel admin, gere as chaves DKIM e"
echo "   adicione o registro TXT ao DNS"
echo ""
echo "============================================"
echo ""
echo "📁 Arquivos em: $MAILU_DIR"
echo ""
echo "Comandos úteis:"
echo "  cd $MAILU_DIR && docker-compose logs -f   # Ver logs"
echo "  cd $MAILU_DIR && docker-compose restart   # Reiniciar"
echo "  cd $MAILU_DIR && docker-compose down      # Parar"
echo "  cd $MAILU_DIR && docker-compose up -d     # Iniciar"
echo ""
echo "============================================"
