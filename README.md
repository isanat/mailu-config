# ============================================
# GUIA COMPLETO DE INSTALAÇÃO - MAILU
# Servidor de Email para travelconcierge.site
# IP: 164.68.126.14
# ============================================

## 📋 SUMÁRIO

1. [Pré-requisitos](#pré-requisitos)
2. [Instalação Rápida](#instalação-rápida)
3. [Configuração DNS](#configuração-dns)
4. [Configuração SSL](#configuração-ssl)
5. [Criação de Contas](#criação-de-contas)
6. [Testes](#testes)
7. [Manutenção](#manutenção)

---

## 🔧 PRÉ-REQUISITOS

### Requisitos do Servidor
- **Sistema Operacional**: Ubuntu 20.04+ ou Debian 11+
- **RAM**: Mínimo 2GB (recomendado 4GB)
- **Disco**: Mínimo 20GB
- **Acesso**: Root ou sudo

### Portas Necessárias
| Porta | Protocolo | Uso |
|-------|-----------|-----|
| 25 | TCP | SMTP (recebimento) |
| 80 | TCP | HTTP (Let's Encrypt) |
| 443 | TCP | HTTPS |
| 465 | TCP | SMTPS |
| 587 | TCP | Submission |
| 993 | TCP | IMAPS |
| 995 | TCP | POP3S |

### ⚠️ IMPORTANTE: Conflito com Coolify/Traefik

O Mailu precisa das portas 80 e 443. Se você já tem o Coolify/Traefik rodando, há duas opções:

**Opção A: Servidor Dedicado (Recomendado)**
- Use um IP dedicado ou servidor separado para email

**Opção B: Modificar Coolify**
- Pare o Traefik do Coolify temporariamente
- Ou configure o Mailu em portas diferentes e use proxy reverso

---

## 🚀 INSTALAÇÃO RÁPIDA

### Método 1: Script Automático

```bash
# Baixar e executar o script
curl -fsSL https://raw.githubusercontent.com/isanat/mailu-config/main/install-mailu.sh | bash
```

### Método 2: Manual

```bash
# 1. Acessar servidor via SSH
ssh root@164.68.126.14

# 2. Criar diretório
mkdir -p /opt/mailu && cd /opt/mailu

# 3. Baixar arquivos
git clone https://github.com/isanat/mailu-config.git .

# 4. Gerar chave secreta
SECRET_KEY=$(openssl rand -hex 16)
sed -i "s/SECRET_KEY=.*/SECRET_KEY=$SECRET_KEY/" mailu.env

# 5. Iniciar containers
docker-compose pull
docker-compose up -d

# 6. Verificar status
docker-compose ps
```

---

## 🌐 CONFIGURAÇÃO DNS

### Registros Obrigatórios

Faça login no seu provedor de DNS e adicione os seguintes registros:

#### 1. Registro A (Apontamento)
```
Tipo: A
Nome: mail
Valor: 164.68.126.14
TTL: 3600
```

#### 2. Registro MX (Mail Exchange)
```
Tipo: MX
Nome: @
Valor: mail.travelconcierge.site
Prioridade: 10
TTL: 3600
```

#### 3. Registro SPF
```
Tipo: TXT
Nome: @
Valor: v=spf1 mx a ip4:164.68.126.14 ~all
TTL: 3600
```

#### 4. Registro DMARC
```
Tipo: TXT
Nome: _dmarc
Valor: v=DMARC1; p=quarantine; rua=mailto:admin@travelconcierge.site; pct=100; adkim=s; aspf=s
TTL: 3600
```

#### 5. Registro DKIM (Após instalação)

O DKIM é gerado automaticamente pelo Mailu. Para obter:

1. Acesse o painel admin: http://164.68.126.14/admin
2. Vá em "Mail domains" → "travelconcierge.site"
3. Clique em "Generate keys"
4. Adicione o registro TXT mostrado:

```
Tipo: TXT
Nome: dkim._domainkey
Valor: [Gerado pelo Mailu - string longa]
TTL: 3600
```

### Registros Opcionais (Auto-discover)

```
Tipo: CNAME
Nome: autodiscover
Valor: mail.travelconcierge.site

Tipo: CNAME
Nome: autoconfig
Valor: mail.travelconcierge.site

Tipo: SRV
Nome: _autodiscover._tcp
Valor: 0 1 443 mail.travelconcierge.site

Tipo: SRV
Nome: _imaps._tcp
Valor: 0 1 993 mail.travelconcierge.site

Tipo: SRV
Nome: _submission._tcp
Valor: 0 1 587 mail.travelconcierge.site
```

---

## 🔒 REVERSE DNS (PTR) - CRÍTICO!

**O registro PTR é essencial para entrega de emails!**

Sem PTR, seus emails provavelmente serão marcados como spam.

### Como Configurar

Contate o suporte do seu provedor VPS e solicite:

```
IP: 164.68.126.14
PTR: mail.travelconcierge.site
```

**Provedores comuns:**

| Provedor | Como Configurar |
|----------|-----------------|
| Hetzner | Console → Networking → Reverse DNS |
| DigitalOcean | Settings → Networking → Reverse DNS |
| Vultr | Settings → Reverse DNS |
| OVH | IP → Reverse DNS |

---

## 🔐 CONFIGURAÇÃO SSL

O Mailu usa Let's Encrypt automaticamente. Para funcionar:

1. Certifique-se que o DNS está propagado:
```bash
dig mail.travelconcierge.site +short
# Deve retornar: 164.68.126.14
```

2. O SSL será gerado automaticamente na primeira execução

3. Verifique os certificados:
```bash
ls -la /opt/mailu/certs/
```

---

## 👤 CRIAÇÃO DE CONTAS

### Acessar Painel Admin

1. URL: `http://164.68.126.14/admin`
2. Login: `admin@travelconcierge.site` (primeiro acesso)
3. Defina uma senha forte

### Criar Novo Usuário

1. No painel, vá em "Mail users"
2. Clique em "Add user"
3. Preencha:
   - Email: `usuario@travelconcierge.site`
   - Senha: [senha forte]
   - Quota: 1G (padrão)
4. Clique em "Save"

---

## ✅ TESTES

### 1. Verificar DNS

```bash
# MX
dig MX travelconcierge.site +short

# SPF
dig TXT travelconcierge.site +short

# DKIM
dig TXT dkim._domainkey.travelconcierge.site +short

# DMARC
dig TXT _dmarc.travelconcierge.site +short

# Reverse DNS
dig -x 164.68.126.14 +short
```

### 2. Testar Conectividade

```bash
# Testar SMTP
telnet mail.travelconcierge.site 25

# Testar IMAP
openssl s_client -connect mail.travelconcierge.site:993
```

### 3. Testar Entregabilidade

Envie um email para: `mail-tester.com`

Você receberá um score de 0-10. Meta: >8/10

### 4. Verificar Blacklists

Acesse: https://mxtoolbox.com/blacklists.aspx

Digite seu IP: `164.68.126.14`

---

## 🛠️ MANUTENÇÃO

### Comandos Úteis

```bash
cd /opt/mailu

# Ver status
docker-compose ps

# Ver logs
docker-compose logs -f

# Ver logs de um serviço específico
docker-compose logs -f smtp
docker-compose logs -f imap

# Reiniciar serviços
docker-compose restart

# Parar serviços
docker-compose down

# Iniciar serviços
docker-compose up -d

# Atualizar imagens
docker-compose pull
docker-compose up -d
```

### Backup

```bash
# Criar backup
cd /opt
tar -czvf mailu-backup-$(date +%Y%m%d).tar.gz mailu/

# Transferir para outro servidor
scp mailu-backup-*.tar.gz user@backup-server:/backups/
```

### Monitoramento

```bash
# Verificar espaço em disco
df -h /opt/mailu

# Verificar uso de memória
docker stats
```

---

## 📧 CONFIGURAÇÃO DE CLIENTES EMAIL

### Outlook / Thunderbird / Mail.app

| Configuração | Valor |
|--------------|-------|
| Servidor Entrante (IMAP) | mail.travelconcierge.site |
| Porta IMAP | 993 |
| Segurança IMAP | SSL/TLS |
| Servidor Saída (SMTP) | mail.travelconcierge.site |
| Porta SMTP | 587 |
| Segurança SMTP | STARTTLS |
| Usuário | email@travelconcierge.site |
| Senha | [sua senha] |

---

## 🚨 TROUBLESHOOTING

### Emails vão para SPAM

1. Verifique SPF, DKIM, DMARC
2. Configure Reverse DNS (PTR)
3. Verifique se IP não está em blacklist
4. Aqueça o IP enviando poucos emails inicialmente

### Não recebe emails

1. Verifique se porta 25 está aberta
2. Verifique logs: `docker-compose logs -f smtp`
3. Teste conectividade: `telnet mail.travelconcierge.site 25`

### Não envia emails

1. Verifique logs: `docker-compose logs -f smtp`
2. Verifique autenticação SMTP
3. Verifique se porta 587 está acessível

### SSL não funciona

1. Verifique se DNS está propagado
2. Verifique se porta 80 está acessível
3. Verifique logs: `docker-compose logs -f front`

---

## 📞 SUPORTE

- Documentação Mailu: https://mailu.io/
- GitHub Mailu: https://github.com/Mailu/Mailu
- Comunidade: https://discussion.mailu.io/

---

**Instalado com sucesso!** 🎉

Seu servidor de email está pronto em `travelconcierge.site`
