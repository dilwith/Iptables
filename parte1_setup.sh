#!/bin/bash
# =============================================================================
# PARTE 1 — Montagem do Ambiente Docker
# Disciplina: CIC7019 - Segurança de Sistemas
# Atividade N2 - iptables: Filter, NAT e Mangle
# =============================================================================
# NOTA: As redes usam .254 como gateway da bridge Docker para que o
# contêiner gateway possa ocupar o IP .1 (conforme a topologia da atividade).

echo "=============================================="
echo " PARTE 1 — Limpeza prévia (se existir)"
echo "=============================================="

docker stop gateway cliente webserver 2>/dev/null || true
docker rm   gateway cliente webserver 2>/dev/null || true
docker network rm net_interna net_dmz   2>/dev/null || true
echo "[OK] Ambiente anterior removido (ou já estava limpo)"

echo ""
echo "=============================================="
echo " PARTE 1 — Criando redes Docker"
echo "=============================================="

# Rede interna — gateway da bridge em .254 para liberar .1 ao contêiner
docker network create \
  --driver bridge \
  --subnet 172.20.0.0/24 \
  --gateway 172.20.0.254 \
  net_interna

echo "[OK] Rede net_interna criada (172.20.0.0/24, bridge em .254)"

# Rede DMZ — mesmo esquema
docker network create \
  --driver bridge \
  --subnet 172.21.0.0/24 \
  --gateway 172.21.0.254 \
  net_dmz

echo "[OK] Rede net_dmz criada (172.21.0.0/24, bridge em .254)"

echo ""
echo "=============================================="
echo " PARTE 1 — Criando contêineres"
echo "=============================================="

# Contêiner GATEWAY — conectado às duas redes, com capacidades de firewall
docker run -d \
  --name gateway \
  --cap-add NET_ADMIN \
  --cap-add NET_RAW \
  --sysctl net.ipv4.ip_forward=1 \
  --network net_interna \
  --ip 172.20.0.1 \
  alpine:latest \
  sh -c "apk add --no-cache iptables conntrack-tools && sleep infinity"

echo "[OK] Contêiner gateway iniciado (172.20.0.1 em net_interna)"

# Conectar gateway também à rede DMZ
docker network connect --ip 172.21.0.1 net_dmz gateway

echo "[OK] Gateway conectado à net_dmz (172.21.0.1)"

# Contêiner CLIENTE — somente na rede interna
docker run -d \
  --name cliente \
  --network net_interna \
  --ip 172.20.0.10 \
  alpine:latest \
  sh -c "apk add --no-cache wget && sleep infinity"

echo "[OK] Contêiner cliente criado (172.20.0.10)"

# Contêiner WEBSERVER — nginx na DMZ
docker run -d \
  --name webserver \
  --network net_dmz \
  --ip 172.21.0.10 \
  nginx:alpine

echo "[OK] Contêiner webserver (nginx) criado (172.21.0.10)"

echo ""
echo "=============================================="
echo " PARTE 1 — Aguardando gateway instalar iptables..."
echo "=============================================="

# Esperar o apk add terminar dentro do gateway
until docker exec gateway which iptables > /dev/null 2>&1; do
  echo "  aguardando..."
  sleep 3
done
echo "[OK] iptables disponível no gateway"

echo ""
echo "=============================================="
echo " PARTE 1 — Configurando rotas"
echo "=============================================="

# Rota no cliente: pacotes para DMZ passam pelo gateway
docker exec cliente ip route add 172.21.0.0/24 via 172.20.0.1
echo "[OK] Rota no cliente: 172.21.0.0/24 via 172.20.0.1"

# Rota no webserver: pacotes para rede interna passam pelo gateway
docker exec webserver ip route add 172.20.0.0/24 via 172.21.0.1
echo "[OK] Rota no webserver: 172.20.0.0/24 via 172.21.0.1"

echo ""
echo "=============================================="
echo " PARTE 1 — Verificação do ambiente"
echo "=============================================="

echo ""
echo "--- docker ps ---"
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "--- docker network inspect net_interna ---"
docker network inspect net_interna

echo ""
echo "--- docker network inspect net_dmz ---"
docker network inspect net_dmz

echo ""
echo "=============================================="
echo " Ambiente pronto! Execute os próximos scripts."
echo "=============================================="
