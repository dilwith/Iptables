# Respostas Conceituais — N2 Atividade 01
## Disciplina: CIC7019 - Segurança de Sistemas

---

## Questão Conceitual 1 (Parte 2 — Tabela Filter)

**Por que é obrigatório incluir a regra de conexões ESTABLISHED,RELATED quando a política padrão é DROP? O que aconteceria com o tráfego legítimo sem essa regra?**

Quando a política padrão de uma chain é DROP, o firewall descarta silenciosamente todo pacote que não corresponder a nenhuma regra explícita de ACCEPT. O protocolo TCP, por sua natureza, é bidirecional: para cada pacote enviado (SYN), o destino responde (SYN-ACK), e o remetente confirma (ACK). Sem a regra de ESTABLISHED,RELATED, apenas o primeiro pacote (NEW) encontraria correspondência na regra de permissão, mas os pacotes de resposta — que chegam na direção oposta — não se encaixariam em nenhuma regra e seriam descartados pela política DROP.

Na prática, o resultado seria que nenhuma conexão TCP conseguiria se completar: o cliente enviaria o SYN, o servidor responderia com SYN-ACK, porém essa resposta seria bloqueada pelo gateway antes de chegar ao cliente, tornando impossível a conclusão do handshake de três vias. Da mesma forma, dados HTTP de retorno (respostas do servidor) e pacotes ICMP de erro associados a conexões ativas também seriam bloqueados. O módulo `conntrack` do Netfilter rastreia o estado de cada fluxo, identificando pacotes como ESTABLISHED (pertencentes a uma conexão já iniciada) ou RELATED (como uma conexão FTP de dados relacionada à sessão de controle). A regra `-m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT` é, portanto, o mecanismo que torna o firewall stateful, garantindo que respostas legítimas sempre possam retornar, sem precisar abrir buracos permanentes nas regras de filtragem.

---

## Questão Conceitual 2 (Parte 3 — Tabela NAT)

**Qual a diferença entre SNAT e MASQUERADE? Em que situação prática cada um é mais adequado? Por que no cenário Docker utilizamos MASQUERADE e não SNAT?**

Tanto SNAT (Source NAT) quanto MASQUERADE realizam a tradução do endereço IP de origem dos pacotes que saem por uma interface, permitindo que hosts de redes privadas se comuniquem com redes externas usando o IP do gateway. A diferença fundamental está em como o endereço IP de saída é determinado.

Com **SNAT**, o administrador especifica explicitamente o endereço IP público de destino na regra, por exemplo: `--to-source 203.0.113.5`. O Netfilter armazena esse valor em cache para todas as conexões que atravessam aquela regra. Isso é mais eficiente em termos de desempenho porque o kernel não precisa consultar dinamicamente o IP da interface a cada novo pacote. É adequado em servidores com IP fixo e estável, como em datacenters com links dedicados, onde o IP da interface externa nunca muda.

Já o **MASQUERADE** determina automaticamente o IP de saída consultando a tabela de roteamento no momento em que cada pacote é processado. Ele sempre usa o IP atual da interface de saída, o que o torna ideal para situações onde o IP pode mudar: conexões PPPoE (banda larga com IP dinâmico), interfaces de tunelamento VPN ou, como no nosso cenário, **contêineres Docker**. As interfaces de rede dos contêineres são virtuais e atribuídas dinamicamente pelo Docker; seus endereços podem variar entre reinicializações ou recriações de contêineres. Utilizar SNAT com um IP fixo codificado na regra quebraria o NAT sempre que o IP da interface mudasse. O MASQUERADE resolve isso de forma transparente, adaptando-se automaticamente ao endereço corrente da interface, ao custo de uma pequena sobrecarga de consulta por pacote.

---

## Questão Conceitual 3 (Parte 4 — Tabela Mangle)

**A marcação MARK é visível no pacote que trafega na rede (on the wire)? Explique para que ela serve e dê um exemplo de como outro subsistema do kernel Linux pode utilizá-la.**

Não, a marcação MARK **não é visível no pacote que trafega na rede**. Ela existe exclusivamente na memória do kernel como metadado associado ao `sk_buff` (socket buffer), que é a estrutura interna que o kernel Linux usa para representar um pacote enquanto ele está sendo processado. Quando o pacote sai pela interface de rede e é colocado no cabo (ou no meio sem fio), a marca é descartada — ela nunca aparece em nenhum campo do cabeçalho IP, TCP ou em qualquer camada do modelo OSI.

A utilidade da marcação MARK está em servir como um canal de comunicação entre diferentes subsistemas do kernel. Ela permite que o iptables classifique pacotes com base em critérios complexos (porta, protocolo, endereço IP, estado de conexão) e depois delegue ações específicas a outros módulos do kernel com base nessa classificação.

Um exemplo clássico é a integração com o **subsistema de QoS (Traffic Control — `tc`)**: após o iptables marcar pacotes HTTP com MARK 1 e pacotes HTTPS com MARK 2, o `tc` pode usar o filtro `fw` para ler essas marcas e enfileirar os pacotes em filas de prioridade distintas — por exemplo, colocando pacotes com MARK 2 (HTTPS/voz sobre IP) em uma fila de alta prioridade que garante menor latência, enquanto pacotes com MARK 1 (HTTP comum) vão para uma fila de melhor esforço. Outro exemplo é o **policy routing (roteamento baseado em política)**: o comando `ip rule add fwmark 2 table 100` faz com que pacotes marcados com MARK 2 sejam roteados pela tabela de roteamento 100, podendo sair por um link diferente (útil em cenários de balanceamento de carga ou failover com múltiplos provedores de internet).
