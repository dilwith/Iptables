# Guia de Execução — N2 Atividade 01
## Disciplina: CIC7019 - Segurança de Sistemas

---

## PRÉ-REQUISITOS

1. **Docker Desktop aberto e rodando** (ícone na bandeja do sistema = baleia azul)
2. **Git Bash ou PowerShell** como terminal no host (Windows)
3. Todos os scripts `.sh` na pasta desta atividade

---

## PASSO A PASSO COMPLETO

### PARTE 1 — Montar o Ambiente

**No terminal do HOST (Git Bash / PowerShell):**

```bash
bash parte1_setup.sh
```

**Prints que você precisa tirar (Parte 1):**

```bash
# Print 1 — Contêineres em execução
docker ps

# Print 2 — Inspecionar rede interna
docker network inspect net_interna

# Print 3 — Inspecionar rede DMZ
docker network inspect net_dmz
```

---

### PARTE 2 — Tabela Filter

```bash
docker cp parte2_filter.sh gateway:/parte2_filter.sh
docker exec gateway sh /parte2_filter.sh
```

**Prints que você precisa tirar (Parte 2):**

```bash
# Print 1 — Listar regras filter com contadores
docker exec gateway iptables -L -v -n --line-numbers

# Print 2 — Teste de acesso HTTP (deve mostrar HTML do nginx)
docker exec cliente wget -qO- http://172.21.0.10/

# Print 3 — Teste de bloqueio: DMZ tentando acessar rede interna (deve falhar/timeout)
docker exec webserver wget -T 5 -qO- http://172.20.0.10/ || echo "BLOQUEADO — timeout esperado"
```

---

### PARTE 3 — Tabela NAT

```bash
docker cp parte3_nat.sh gateway:/parte3_nat.sh
docker exec gateway sh /parte3_nat.sh
```

**Prints que você precisa tirar (Parte 3):**

```bash
# Print 1 — Listar tabela NAT com contadores
docker exec gateway iptables -t nat -L -v -n

# Print 2 — Teste DNAT: acessar port 8080 no gateway, deve entregar página do nginx
docker exec cliente wget -qO- http://172.20.0.1:8080/
```

---

### PARTE 4 — Tabela Mangle

```bash
docker cp parte4_mangle.sh gateway:/parte4_mangle.sh
docker exec gateway sh /parte4_mangle.sh
```

**Prints que você precisa tirar (Parte 4):**

```bash
# Gerar tráfego HTTP para ver contadores incrementando
docker exec cliente wget -qO- http://172.21.0.10/

# Print 1 — Listar tabela mangle com contadores (após gerar tráfego)
docker exec gateway iptables -t mangle -L -v -n
```

---

### LIMPEZA (incluir no relatório)

```bash
bash cleanup.sh
```

---

## DICAS PARA O RELATÓRIO

### Ordem das seções no PDF

```
Capa (nome, RA, turma)
├── Parte 1 — Ambiente Docker
│   ├── Comandos utilizados
│   ├── Print: docker ps
│   ├── Print: docker network inspect net_interna
│   └── Print: docker network inspect net_dmz
│
├── Parte 2 — Tabela Filter
│   ├── Comandos iptables (cada requisito 2.1 a 2.6)
│   ├── Print: iptables -L -v -n --line-numbers
│   ├── Print: teste wget http://172.21.0.10/ (sucesso)
│   ├── Print: teste DMZ -> interna (bloqueio)
│   └── Questão Conceitual 1 (resposta em texto)
│
├── Parte 3 — Tabela NAT
│   ├── Comandos iptables (requisitos 3.1 a 3.3)
│   ├── Print: iptables -t nat -L -v -n
│   ├── Print: teste DNAT wget http://172.20.0.1:8080/ (sucesso)
│   └── Questão Conceitual 2 (resposta em texto)
│
├── Parte 4 — Tabela Mangle
│   ├── Comandos iptables (requisitos 4.1 a 4.3)
│   ├── Print: iptables -t mangle -L -v -n (com contadores)
│   └── Questão Conceitual 3 (resposta em texto)
│
└── Limpeza — Comandos de remoção de contêineres e redes
```

---

## RESOLUÇÃO DE PROBLEMAS COMUNS

### "docker: command not found" ou daemon não conectado
- Abrir Docker Desktop e aguardar o ícone ficar estável

### wget não encontrado no cliente
```bash
docker exec cliente apk add --no-cache wget
```

### Interface da DMZ no gateway não é eth1
```bash
docker exec gateway ip addr show
```
