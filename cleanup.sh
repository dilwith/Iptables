#!/bin/bash
# =============================================================================
# LIMPEZA — Remoção de contêineres e redes Docker
# Disciplina: CIC7019 - Segurança de Sistemas
# Atividade N2 - iptables: Filter, NAT e Mangle
# =============================================================================
# Execute no HOST (fora dos contêineres), no terminal do Windows/Git Bash

echo "=============================================="
echo " Limpeza do ambiente Docker"
echo "=============================================="

echo ""
echo "Parando e removendo contêineres..."
docker stop gateway cliente webserver 2>/dev/null && echo "  [OK] Contêineres parados"
docker rm   gateway cliente webserver 2>/dev/null && echo "  [OK] Contêineres removidos"

echo ""
echo "Removendo redes Docker..."
docker network rm net_interna net_dmz 2>/dev/null && echo "  [OK] Redes removidas"

echo ""
echo "Verificação final:"
docker ps -a --filter "name=gateway" --filter "name=cliente" --filter "name=webserver"
docker network ls | grep -E "net_interna|net_dmz" || echo "  Redes removidas com sucesso."

echo ""
echo "=============================================="
echo " Limpeza concluída."
echo "=============================================="
