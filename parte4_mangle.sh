#!/bin/bash
# =============================================================================
# PARTE 4 — Tabela Mangle
# Disciplina: CIC7019 - Segurança de Sistemas
# Atividade N2 - iptables: Filter, NAT e Mangle
# =============================================================================
# Execute DENTRO do contêiner gateway:
#   docker exec -it gateway sh
#   sh /parte4_mangle.sh
# =============================================================================

echo "=============================================="
echo " PARTE 4 — Tabela Mangle"
echo "=============================================="

# ------------------------------------------------------------------------------
# 4.1 — Marcar pacotes HTTP (porta 80) com MARK 1
#        e pacotes HTTPS (porta 443) com MARK 2 na chain FORWARD
# ------------------------------------------------------------------------------
echo ""
echo "[4.1] Marcando pacotes HTTP e HTTPS na chain FORWARD..."

# MARK 1 para HTTP (porta 80)
iptables -t mangle -A FORWARD \
  -p tcp \
  --dport 80 \
  -j MARK --set-mark 1

echo "  FORWARD tcp dport 80  -> MARK 1"

# MARK 2 para HTTPS (porta 443)
iptables -t mangle -A FORWARD \
  -p tcp \
  --dport 443 \
  -j MARK --set-mark 2

echo "  FORWARD tcp dport 443 -> MARK 2"

# ------------------------------------------------------------------------------
# 4.2 — Definir DSCP classe EF (Expedited Forwarding = 0x2E = 46) para
#        pacotes marcados com MARK 2 na chain POSTROUTING
#        EF garante baixa latência e alta prioridade (voz/vídeo em VoIP)
# ------------------------------------------------------------------------------
echo ""
echo "[4.2] Definindo DSCP EF para pacotes com MARK 2 (POSTROUTING)..."

iptables -t mangle -A POSTROUTING \
  -m mark --mark 2 \
  -j DSCP --set-dscp-class EF

echo "  POSTROUTING MARK==2 -> DSCP EF (Expedited Forwarding)"

# ------------------------------------------------------------------------------
# 4.3 — Correção automática de MSS (clamp-mss-to-pmtu) para TCP SYN
#        Evita problemas de fragmentação em túneis (VPN, PPPoE, etc.)
#        Ajusta o MSS ao PMTU do caminho para evitar pacotes oversized
# ------------------------------------------------------------------------------
echo ""
echo "[4.3] Aplicando clamp-mss-to-pmtu para TCP SYN na chain FORWARD..."

iptables -t mangle -A FORWARD \
  -p tcp \
  --tcp-flags SYN,RST SYN \
  -j TCPMSS --clamp-mss-to-pmtu

echo "  FORWARD tcp SYN -> TCPMSS clamp-mss-to-pmtu"

# ------------------------------------------------------------------------------
# Verificação das regras Mangle aplicadas
# ------------------------------------------------------------------------------
echo ""
echo "=============================================="
echo " Verificação: iptables -t mangle -L -v -n"
echo "=============================================="
iptables -t mangle -L -v -n

echo ""
echo "=============================================="
echo " PARTE 4 concluída."
echo " Gere tráfego HTTP/HTTPS e reexecute a"
echo " verificação para ver os contadores incrementarem."
echo "=============================================="
echo ""
echo "Exemplo para gerar tráfego e ver contadores:"
echo "  docker exec cliente wget -qO- http://172.21.0.10/   # HTTP (marca 1)"
echo "  iptables -t mangle -L -v -n                         # ver contadores"
