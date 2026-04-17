#!/bin/bash
# =============================================================================
# PARTE 2 — Tabela Filter
# Disciplina: CIC7019 - Segurança de Sistemas
# Atividade N2 - iptables: Filter, NAT e Mangle
# =============================================================================
# Execute este script DENTRO do contêiner gateway:
#   docker exec -it gateway sh
#   sh /parte2_filter.sh
# OU diretamente:
#   docker exec gateway sh -c "$(cat parte2_filter.sh)"
# =============================================================================

echo "=============================================="
echo " PARTE 2 — Tabela Filter"
echo "=============================================="

# ------------------------------------------------------------------------------
# 2.1 — Política padrão DROP para INPUT e FORWARD; OUTPUT fica ACCEPT
# ------------------------------------------------------------------------------
echo ""
echo "[2.1] Definindo políticas padrão..."

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

echo "  INPUT  -> DROP"
echo "  FORWARD -> DROP"
echo "  OUTPUT  -> ACCEPT"

# ------------------------------------------------------------------------------
# 2.2 — Permitir todo tráfego na interface loopback
# ------------------------------------------------------------------------------
echo ""
echo "[2.2] Permitindo tráfego loopback..."

iptables -A INPUT -i lo -j ACCEPT

echo "  INPUT -i lo -> ACCEPT"

# ------------------------------------------------------------------------------
# 2.3 — Permitir conexões ESTABLISHED e RELATED (stateful) em INPUT e FORWARD
# ------------------------------------------------------------------------------
echo ""
echo "[2.3] Permitindo conexões estabelecidas e relacionadas..."

iptables -A INPUT  -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

echo "  INPUT  ESTABLISHED,RELATED -> ACCEPT"
echo "  FORWARD ESTABLISHED,RELATED -> ACCEPT"

# ------------------------------------------------------------------------------
# 2.4 — Permitir cliente (172.20.0.10) acessar HTTP/HTTPS no webserver
# ------------------------------------------------------------------------------
echo ""
echo "[2.4] Permitindo cliente -> webserver HTTP(80) e HTTPS(443)..."

iptables -A FORWARD \
  -s 172.20.0.10 \
  -d 172.21.0.10 \
  -p tcp \
  --dport 80 \
  -m conntrack --ctstate NEW,ESTABLISHED \
  -j ACCEPT

iptables -A FORWARD \
  -s 172.20.0.10 \
  -d 172.21.0.10 \
  -p tcp \
  --dport 443 \
  -m conntrack --ctstate NEW,ESTABLISHED \
  -j ACCEPT

echo "  FORWARD 172.20.0.10 -> 172.21.0.10:80  -> ACCEPT"
echo "  FORWARD 172.20.0.10 -> 172.21.0.10:443 -> ACCEPT"

# ------------------------------------------------------------------------------
# 2.5 — Bloquear qualquer acesso da DMZ (172.21.0.0/24) à rede interna (172.20.0.0/24)
# ------------------------------------------------------------------------------
echo ""
echo "[2.5] Bloqueando DMZ -> rede interna..."

iptables -A FORWARD \
  -s 172.21.0.0/24 \
  -d 172.20.0.0/24 \
  -j DROP

echo "  FORWARD 172.21.0.0/24 -> 172.20.0.0/24 -> DROP"

# ------------------------------------------------------------------------------
# 2.6 — Chain customizada LOG_DROP + bloquear Telnet (porta 23) no INPUT
# ------------------------------------------------------------------------------
echo ""
echo "[2.6] Criando chain customizada LOG_DROP e bloqueando Telnet (porta 23)..."

# Criar a chain customizada
iptables -N LOG_DROP

# Regra de LOG dentro da chain (prefixo para facilitar filtrar nos logs)
iptables -A LOG_DROP \
  -j LOG \
  --log-prefix "[IPTABLES DROP] " \
  --log-level 4

# Regra de DROP após o log
iptables -A LOG_DROP -j DROP

# Usar LOG_DROP como target para Telnet na chain INPUT
iptables -A INPUT \
  -p tcp \
  --dport 23 \
  -j LOG_DROP

echo "  Chain LOG_DROP criada (LOG + DROP)"
echo "  INPUT tcp dport 23 -> LOG_DROP"

# ------------------------------------------------------------------------------
# Verificação das regras aplicadas
# ------------------------------------------------------------------------------
echo ""
echo "=============================================="
echo " Verificação: iptables -L -v -n --line-numbers"
echo "=============================================="
iptables -L -v -n --line-numbers

echo ""
echo "=============================================="
echo " Teste 1: cliente acessando webserver via HTTP"
echo "=============================================="
echo "Execute no HOST (fora do gateway):"
echo "  docker exec cliente wget -qO- http://172.21.0.10/"
echo ""
echo "Resultado esperado: página HTML do nginx"

echo ""
echo "=============================================="
echo " Teste 2: DMZ tentando acessar rede interna"
echo "=============================================="
echo "Execute no HOST:"
echo "  docker exec webserver wget -qO- http://172.20.0.10/ --timeout=5"
echo ""
echo "Resultado esperado: timeout (bloqueado pelo DROP)"
