# Firewall com iptables — Filter, NAT e Mangle

Atividade prática da disciplina **CIC7019 - Segurança de Sistemas**.  
Configuração de um ambiente de rede virtualizado com Docker, aplicando regras de firewall nas tabelas `filter`, `nat` e `mangle` do iptables.

---

## Topologia

```
[cliente]                [gateway]               [webserver]
172.20.0.10/24  ──────  172.20.0.1               172.21.0.10/24
                net_interna    172.21.0.1  net_dmz
                         (firewall/roteador)
```

| Rede | Subnet | Função |
|---|---|---|
| `net_interna` | 172.20.0.0/24 | Rede dos clientes internos |
| `net_dmz` | 172.21.0.0/24 | Zona desmilitarizada (servidores) |

---

## Pré-requisitos

- Docker Desktop instalado e em execução
- Git Bash ou terminal compatível com bash (no Windows)

---

## Estrutura dos scripts

```
.
├── parte1_setup.sh          # Cria redes, contêineres e rotas
├── parte2_filter.sh         # Regras da tabela filter
├── parte3_nat.sh            # Regras da tabela NAT (MASQUERADE e DNAT)
├── parte4_mangle.sh         # Regras da tabela mangle (MARK, DSCP, TCPMSS)
├── cleanup.sh               # Remove contêineres e redes
└── respostas_conceituais.md # Respostas às questões teóricas
```

---

## Como executar

### 1. Montar o ambiente

```bash
bash parte1_setup.sh
```

Cria as duas redes Docker, sobe os três contêineres e configura as rotas entre eles. O contêiner `gateway` recebe automaticamente o pacote `iptables` via `apk`.

### 2. Aplicar as regras de firewall

Cada parte é executada dentro do contêiner `gateway` via `docker exec`:

```bash
# Parte 2 — Filter
docker cp parte2_filter.sh gateway:/parte2_filter.sh
docker exec gateway sh /parte2_filter.sh

# Parte 3 — NAT
docker cp parte3_nat.sh gateway:/parte3_nat.sh
docker exec gateway sh /parte3_nat.sh

# Parte 4 — Mangle
docker cp parte4_mangle.sh gateway:/parte4_mangle.sh
docker exec gateway sh /parte4_mangle.sh
```

### 3. Limpar o ambiente

```bash
bash cleanup.sh
```

---

## Parte 2 — Tabela Filter

Regras de controle de acesso aplicadas no contêiner `gateway`.

| # | Requisito | Chain |
|---|---|---|
| 2.1 | Política padrão DROP para INPUT e FORWARD | INPUT / FORWARD |
| 2.2 | Permitir tráfego na interface loopback | INPUT |
| 2.3 | Permitir conexões ESTABLISHED e RELATED (stateful) | INPUT / FORWARD |
| 2.4 | Cliente (172.20.0.10) acessa HTTP/HTTPS no webserver | FORWARD |
| 2.5 | Bloquear qualquer acesso da DMZ à rede interna | FORWARD |
| 2.6 | Chain customizada `LOG_DROP` para bloquear Telnet (porta 23) | INPUT |

**Verificar regras aplicadas:**
```bash
docker exec gateway iptables -L -v -n --line-numbers
```

**Testes:**
```bash
# Deve retornar o HTML do nginx
docker exec cliente wget -qO- http://172.21.0.10/

# Deve dar timeout (bloqueado)
docker exec webserver wget -T 5 -qO- http://172.20.0.10/ || echo "BLOQUEADO"
```

---

## Parte 3 — Tabela NAT

Regras de tradução de endereços aplicadas no `gateway`.

| # | Requisito | Tipo |
|---|---|---|
| 3.1 | Rede interna acessa DMZ com IP do gateway | MASQUERADE / POSTROUTING |
| 3.2 | Porta 8080 do gateway redireciona para webserver:80 | DNAT / PREROUTING |
| 3.3 | Regra FORWARD correspondente ao DNAT | filter FORWARD |

**Verificar regras NAT:**
```bash
docker exec gateway iptables -t nat -L -v -n
```

**Teste do DNAT:**
```bash
# Acessa porta 8080 no gateway, deve retornar página do nginx
docker exec cliente wget -qO- http://172.20.0.1:8080/
```

---

## Parte 4 — Tabela Mangle

Regras de marcação e modificação de pacotes.

| # | Requisito | Operação |
|---|---|---|
| 4.1 | HTTP → MARK 1, HTTPS → MARK 2 na chain FORWARD | MARK |
| 4.2 | MARK 2 recebe DSCP classe EF (Expedited Forwarding) | DSCP / POSTROUTING |
| 4.3 | Correção de MSS para TCP SYN (clamp-mss-to-pmtu) | TCPMSS / FORWARD |

**Verificar regras mangle (com contadores):**
```bash
docker exec gateway iptables -t mangle -L -v -n
```

---

## Conceitos aplicados

**Netfilter / iptables**  
O Netfilter é o framework do kernel Linux que processa pacotes via hooks. O iptables é a interface de usuário para programar as regras. O fluxo de processamento segue: *Tabela → Chain → Regra → Target*.

**Stateful Firewall (conntrack)**  
O módulo `conntrack` rastreia o estado das conexões (`NEW`, `ESTABLISHED`, `RELATED`, `INVALID`), permitindo que respostas de conexões legítimas passem sem regras individuais de retorno.

**NAT**  
- **MASQUERADE**: traduz o IP de origem dinamicamente com base na interface de saída. Ideal para IPs dinâmicos (como contêineres Docker).  
- **DNAT**: redireciona tráfego de uma porta do gateway para um servidor interno (port forwarding).

**Mangle / QoS**  
A marcação `MARK` é interna ao kernel (não viaja no pacote). Outros subsistemas como o `tc` (Traffic Control) podem usar essas marcas para enfileirar pacotes em prioridades distintas. O DSCP modifica bits no cabeçalho IP para sinalizar prioridade na rede.
