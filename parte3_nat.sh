#!/bin/bash
# =============================================================================
# PARTE 3 — Tabela NAT
# Disciplina: CIC7019 - Segurança de Sistemas
# Atividade N2 - iptables: Filter, NAT e Mangle
# =============================================================================
# Execute DENTRO do contêiner gateway:
#   docker exec -it gateway sh
#   sh /parte3_nat.sh
# =============================================================================

echo "=============================================="
echo " PARTE 3 — Tabela NAT"
echo "=============================================="

# ------------------------------------------------------------------------------
# 3.1 — MASQUERADE: rede interna acessa internet pela interface da DMZ
#        Pacotes originados em 172.20.0.0/24 saem com o IP do gateway (172.21.0.1)
# ------------------------------------------------------------------------------
echo ""
echo "[3.1] Configurando MASQUERADE (POSTROUTING)..."

# eth1 é a interface da DMZ dentro do gateway (segunda interface conectada)
# Para verificar o nome real: ip addr show
IFACE_DMZ=$(ip route | grep 172.21.0.0 | awk '{print $3}')
echo "  Interface DMZ detectada: $IFACE_DMZ"

iptables -t nat -A POSTROUTING \
  -s 172.20.0.0/24 \
  -o "$IFACE_DMZ" \
  -j MASQUERADE

echo "  NAT POSTROUTING: 172.20.0.0/24 -> MASQUERADE via $IFACE_DMZ"

# ------------------------------------------------------------------------------
# 3.2 — DNAT: redirecionar porta 8080 do gateway para webserver:80
#        Conexões chegando na rede interna (172.20.0.1:8080) -> 172.21.0.10:80
# ------------------------------------------------------------------------------
echo ""
echo "[3.2] Configurando DNAT (PREROUTING)..."

# Interface da rede interna
IFACE_INTERNA=$(ip route | grep 172.20.0.0 | awk '{print $3}')
echo "  Interface interna detectada: $IFACE_INTERNA"

iptables -t nat -A PREROUTING \
  -i "$IFACE_INTERNA" \
  -p tcp \
  --dport 8080 \
  -j DNAT \
  --to-destination 172.21.0.10:80

echo "  NAT PREROUTING: *:8080 (via $IFACE_INTERNA) -> DNAT 172.21.0.10:80"

# ------------------------------------------------------------------------------
# 3.3 — Regra FORWARD correspondente ao DNAT
#        Sem esta regra, o pacote redirecionado pelo DNAT seria descartado
#        pela política DROP da chain FORWARD
# ------------------------------------------------------------------------------
echo ""
echo "[3.3] Adicionando regra FORWARD para o tráfego DNAT..."

iptables -A FORWARD \
  -p tcp \
  -d 172.21.0.10 \
  --dport 80 \
  -m conntrack --ctstate NEW,ESTABLISHED \
  -j ACCEPT

echo "  FORWARD -> 172.21.0.10:80 (DNAT) -> ACCEPT"

# ------------------------------------------------------------------------------
# Verificação das regras NAT aplicadas
# ------------------------------------------------------------------------------
echo ""
echo "=============================================="
echo " Verificação: iptables -t nat -L -v -n"
echo "=============================================="
iptables -t nat -L -v -n

echo ""
echo "=============================================="
echo " Teste DNAT: cliente acessando gateway:8080"
echo "=============================================="
echo "Execute no HOST:"
echo "  docker exec cliente wget -qO- http://172.20.0.1:8080/"
echo ""
echo "Resultado esperado: página HTML do nginx (redirecionado para 172.21.0.10:80)"
