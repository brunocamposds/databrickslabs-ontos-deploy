# Roteiro de Apresentação de Laboratório: Ontos & Data Mesh na Prática
## Caso de Uso: Produto de Dados Renda Fixa 360 (Databricks Unity Catalog + MongoDB)

Este documento foi elaborado para guiar a condução e apresentação de um laboratório prático (*hands-on*) demonstrando o **Ontos** como **Portal de Produtos de Dados, Marketplace Corporativo e Home de Governança Semântica**.

---

## 💡 Resposta Conceitual: É mesmo necessário dois contratos ODCS para duas portas de saída?

> **Resposta direta: NÃO! Pelo contrário, o padrão ODCS v3.1.0 e ODPS v1.0.0 preconizam UM ÚNICO contrato de dados corporativo.**

### Por que um único contrato é a melhor prática?
1. **O dado de negócio e as regras de qualidade são os mesmos:**
   Seja consumindo a posição de renda fixa em uma tabela Delta no Databricks ou em um documento JSON no MongoDB, a regra de que o código ISIN deve ser válido (`^[A-Z]{2}[A-Z0-9]{9}[0-9]$`), que a quantidade não pode ser negativa e que o saldo deve ser consistente é **uma regra de negócio corporativa**.
2. **A seção `servers` do ODCS foi feita exatamente para entregas multi-plataforma:**
   No ODCS, o bloco `servers` lista os destinos onde o dado governado é servido:
   ```json
   "servers": [
     { "server": "databricks-unity-catalog-prod", "type": "databricks", "description": "Porta Analítica Delta" },
     { "server": "mongodb-cluster-investimentos", "type": "mongodb", "description": "Porta Operacional NoSQL" }
   ]
   ```
3. **No Produto de Dados (ODPS):**
   O produto declara duas portas de saída (`porta_analitica_databricks_uc` e `porta_operacional_mongodb_canais`), e ambas apontam para o **mesmo contrato** (`contract_id`).
   Isso prova para a organização que a tecnologia é apenas o meio de transporte; **o contrato garante a verdade única do dado**.

---

## 📌 Links de Acesso ao Ambiente Local

- **Marketplace / Home de Dados**: [http://localhost:8000](http://localhost:8000)
- **Catálogo de Produtos de Dados**: [http://localhost:8000/data-products](http://localhost:8000/data-products)
- **Catálogo de Ativos Técnicos (Lineage)**: [http://localhost:8000/assets](http://localhost:8000/assets)
- **Contratos de Dados (ODCS)**: [http://localhost:8000/data-contracts](http://localhost:8000/data-contracts)
- **Domínios de Dados (Hierarquia)**: [http://localhost:8000/data-domains](http://localhost:8000/data-domains)
- **Grafo de Conhecimento (Glossário)**: [http://localhost:8000/knowledge/collections](http://localhost:8000/knowledge/collections)
- **Documentação Interativa Swagger UI**: [http://localhost:8000/docs](http://localhost:8000/docs)

---

## 🗺️ Mapa Visual da Arquitetura Medallion & Linhagem

```
[FONTES BRUTAS]                 [CAMADA BRONZE]                  [CAMADA SILVER]                   [CAMADA GOLD / CONSUMO]
                                 (Raw Ingestion)                  (Conformed Data)                  (Sumarizada & Entrega)

API BACEN / SELIC  ─────────►  bronze_operacoes_selic_bacen  ─►  silver_titulos_renda_fixa  ──┐
                                (Tabela Delta)                   (Tabela Delta)               │
                                                                                              ├──►  gold_posicao_titulos_renda_fixa
                                                                                              │      (Databricks UC - Delta Lake)
MAINFRAME LEGADO   ─────────►  bronze_boletas_legado        ─►  silver_movimentacao_rf     ──┘               │
                                (Tabela Delta)                   (Tabela Delta)                               │ (Sync Contínuo)
                                                                                                              ▼
                                                                                                    gold_posicao_consolidada_cliente_rf
                                                                                                     (NoSQL MongoDB - App & IB)
                                                                                                              ▲
                                                                                                              │
                                                   ┌──────────────────────────────────────────────────────────┴───────────────┐
                                                   │             PRODUTO DE DADOS: RENDA FIXA 360 (ODPS)                      │
                                                   │  • Status: ACTIVE | Escopo: ORGANIZATION | Selo: GOLD CERTIFIED          │
                                                   │  • Contrato Unificado: ODCS v3.1.0 (Databricks UC + MongoDB)             │
                                                   │  • Porta 1: Analítica (posicao + movimentacao)                           │
                                                   │  • Porta 2: Operacional (posicao_consolidada)                            │
                                                   └──────────────────────────────────────────────────────────────────────────┘
```

---

## 🎬 Roteiro de Apresentação Passo a Passo (8 Etapas Modulares)

Execute a partir da raiz do repositório no terminal WSL2 / Linux.
Você pode rodar script a script para narrar a jornada, ou utilizar o orquestrador com pausas:
```bash
./scripts/lab-renda-fixa/executar-lab-completo.sh --pausar
```

---

### ETAPA 1: Domínio Federado e Time de Negócio (Vinculação ao Core)

#### Comando:
```bash
./scripts/lab-renda-fixa/01-criar-dominio-e-time.sh
```
- **Onde clicar**: [http://localhost:8000/data-domains](http://localhost:8000/data-domains) e clique em **Core**.
- **O que falar/mostrar**:
  - Destaque que o domínio **Mercado de Capitais** é um subdomínio subordinado ao **Core**, aparecendo lado a lado com *Customer*, *Finance*, *Supply Chain* e *Retail*.
  - Mostre o time proprietário **Mesa de Operações e Dados de Renda Fixa** com canal de comunicação e contato funcional.

---

### ETAPA 2: Camada Semântica no Grafo RDF (Conceitos de Negócio)

#### Comando:
```bash
./scripts/lab-renda-fixa/02-criar-glossario-e-conceitos.sh
```
- **Onde clicar**: [http://localhost:8000/knowledge/collections](http://localhost:8000/knowledge/collections)
- **O que falar/mostrar**:
  - A semântica vem antes da engenharia: definimos no Grafo RDF/OWL o significado corporativo de *Posição em Renda Fixa*, *Movimentação em Renda Fixa* e *Posição Consolidada*.
  - Mostre sinônimos e exemplos práticos que habilitam busca vetorial e IA conversacional (Genie).

---

### ETAPA 3: Registro dos Ativos na Arquitetura Medallion

#### Comando:
```bash
./scripts/lab-renda-fixa/03-cadastrar-ativos-fisicos.sh
```
- **Onde clicar**: [http://localhost:8000/assets](http://localhost:8000/assets)
- **O que falar/mostrar**:
  - O catálogo unifica todas as camadas:
    - **Bronze**: `bronze_operacoes_selic_bacen` e `bronze_boletas_transacoes_legado`
    - **Silver**: `silver_titulos_renda_fixa` e `silver_movimentacao_renda_fixa`
    - **Gold**: `gold_posicao_titulos_renda_fixa` (Databricks UC) e `gold_posicao_consolidada_cliente_rf` (MongoDB).

---

### ETAPA 4: Contrato de Dados ODCS v3.1.0 Unificado

#### Comando:
```bash
./scripts/lab-renda-fixa/04-importar-contratos-odcs.sh
```
- **Onde clicar**: [http://localhost:8000/data-contracts](http://localhost:8000/data-contracts)
- **O que falar/mostrar**:
  - Abra o **Contrato Unificado de Renda Fixa**.
  - Mostre a seção `servers` com os dois destinos (Databricks UC e MongoDB).
  - Mostre as regras executáveis de qualidade (ISIN via Regex, valores `>= 0`, não-nulos) e SLAs distintos por canal (D+1 analítico vs latência < 50ms operacional).

---

### ETAPA 5: Produto de Dados ODPS v1.0.0 Multi-Portas

#### Comando:
```bash
./scripts/lab-renda-fixa/05-cadastrar-produto-odps-multi-portas.sh
```
- **Onde clicar**: [http://localhost:8000/data-products](http://localhost:8000/data-products)
- **O que falar/mostrar**:
  - Abra o produto **Produto de Dados - Renda Fixa 360**.
  - Mostre as duas **Output Ports** autônomas (`porta_analitica_databricks_uc` e `porta_operacional_mongodb_canais`), ambas amparadas pelo mesmo contrato ODCS.

---

### ETAPA 6: Grafo de Linhagem de Dados (Bronze ➔ Silver ➔ Gold ➔ Canais)

#### Comando:
```bash
./scripts/lab-renda-fixa/06-construir-linhagem-medallion.sh
```
- **Onde clicar**: [http://localhost:8000/assets](http://localhost:8000/assets), clique no ativo `gold_posicao_titulos_renda_fixa` e abra a aba **Lineage (Linhagem)**.
- **O que falar/mostrar**:
  - Mostre na tela o grafo interativo completo gerado pelo Ontos:
    - *Bronze Selic* e *Bronze Boletas* alimentando a camada *Silver*.
    - *Silver Títulos* e *Silver Movimentação* alimentando a tabela *Gold Posição no Databricks UC*.
    - *Gold Posição* alimentando a coleção *Gold Consolidada no MongoDB*.
  - Explique que isso permite **Análise de Impacto (Downstream)** caso uma fonte sofra alteração e **Auditoria de Proveniência (Upstream)** regulatória.

---

### ETAPA 7: Governança de Ciclo de Vida, Publicação e Marketplace

#### Comando:
```bash
./scripts/lab-renda-fixa/07-ativar-e-publicar-marketplace.sh
```
- **Onde clicar**: Acesse a Home / Marketplace em [http://localhost:8000/](http://localhost:8000/) e o Catálogo em [http://localhost:8000/data-products](http://localhost:8000/data-products).
- **O que falar/mostrar**:
  - O produto não fica preso em `draft`: ele passou pelo ciclo de vida formal (`draft` ➔ `proposed` ➔ `under_review` ➔ `approved` ➔ `active`).
  - Seu escopo de publicação foi configurado como **Organization**.
  - O produto recebeu o selo **Gold Certified**, aparecendo com destaque no Marketplace para consumo imediato de qualquer área de negócio.

---

### ETAPA 8: Conexão no Grafo Semântico Final (Semantic Links)

#### Comando:
```bash
./scripts/lab-renda-fixa/08-vincular-grafo-semantico.sh
```
- **Onde clicar**: [http://localhost:8000/knowledge/concepts](http://localhost:8000/knowledge/concepts)
- **O que falar/mostrar**:
  - Mostre que o ciclo se completa no Grafo RDF: ao consultar o conceito de negócio *Posição em Renda Fixa*, o sistema rastreia os vínculos semânticos até o contrato ODCS unificado, as portas analítica e operacional, e as tabelas físicas.
