# ============================================
# CONFIGURAÇÃO DNS - travelconcierge.site
# Servidor: 164.68.126.14
# ============================================

## Registros DNS Obrigatórios

### 1. Registro A (Apontamento)
| Tipo | Nome | Valor | TTL |
|------|------|-------|-----|
| A | mail | 164.68.126.14 | 3600 |

### 2. Registro MX (Mail Exchange)
| Tipo | Nome | Valor | Prioridade | TTL |
|------|------|-------|------------|-----|
| MX | @ | mail.travelconcierge.site | 10 | 3600 |

### 3. Registro SPF (Sender Policy Framework)
| Tipo | Nome | Valor | TTL |
|------|------|-------|-----|
| TXT | @ | v=spf1 mx a ip4:164.68.126.14 ~all | 3600 |

### 4. Registro DKIM (DomainKeys Identified Mail)
| Tipo | Nome | Valor | TTL |
|------|------|-------|-----|
| TXT | dkim._domainkey | [Gerado pelo Mailu - veja no admin] | 3600 |

### 5. Registro DMARC (Domain-based Message Authentication)
| Tipo | Nome | Valor | TTL |
|------|------|-------|-----|
| TXT | _dmarc | v=DMARC1; p=quarantine; rua=mailto:admin@travelconcierge.site; pct=100; adkim=s; aspf=s | 3600 |

### 6. Registro PTR (Reverse DNS) - IMPORTANTE!
| Tipo | IP | Valor |
|------|-----|-------|
| PTR | 164.68.126.14 | mail.travelconcierge.site |

⚠️ **Nota sobre PTR**: Este registro deve ser configurado pelo seu provedor de VPS. 
Contate o suporte do seu datacenter para configurar o reverse DNS.

## Registros Adicionais (Opcionais)

### Auto-discover (Configuração automática de email)
| Tipo | Nome | Valor | TTL |
|------|------|-------|-----|
| CNAME | autodiscover | mail.travelconcierge.site | 3600 |
| CNAME | autoconfig | mail.travelconcierge.site | 3600 |

### SRV Records para Autodiscover
| Tipo | Nome | Valor | TTL |
|------|------|-------|-----|
| SRV | _autodiscover._tcp | 0 1 443 mail.travelconcierge.site | 3600 |
| SRV | _imaps._tcp | 0 1 993 mail.travelconcierge.site | 3600 |
| SRV | _submission._tcp | 0 1 587 mail.travelconcierge.site | 3600 |

## Verificação de DNS

Após configurar, verifique com:

```bash
# Verificar MX
dig MX travelconcierge.site +short

# Verificar SPF
dig TXT travelconcierge.site +short

# Verificar DKIM
dig TXT dkim._domainkey.travelconcierge.site +short

# Verificar DMARC
dig TXT _dmarc.travelconcierge.site +short

# Verificar Reverse DNS
dig -x 164.68.126.14 +short
```

## Testes de Email

### 1. Testar SPF
https://www.kitterman.com/spf/validate.html

### 2. Testar DKIM
https://dmarcian.com/dkim-inspector/

### 3. Testar entrega
Enviar email para: mail-tester.com
(Verificar score de entregabilidade)

### 4. Verificar IP em blacklists
https://mxtoolbox.com/blacklists.aspx
