# Databricks Ontos — Laboratório de Data Mesh & Governança de Produtos de Dados

> **Nota:** A documentação técnica original do projeto upstream Databricks Labs Ontos foi preservada e renomeada para [**`README_ONTOS.md`**](README_ONTOS.md).

---

## 🎯 Sobre o Laboratório

Este repositório contém uma distribuição do **Databricks Ontos** preparada para execução local e demonstração prática de **Governança Semântica e Data Mesh**.

O ambiente foi customizado para simular um cenário corporativo do setor financeiro: o **Produto de Dados Renda Fixa 360**, integrando a camada analítica (**Databricks Unity Catalog — Delta Lake**) e a camada operacional (**MongoDB — Document Store**) sob o mesmo contrato de dados padronizado.

### 🌟 Principais Conceitos Demonstrados

1. **Contratos de Dados Unificados ([ODCS v3.1.0](https://github.com/bitol-io/open-data-contract-standard))**:
   - Um único contrato formal define schema, regras de negócio corporativas (ex.: validação de ISIN, saldos não negativos) e SLOs de qualidade.
   - O contrato atende simultaneamente múltiplas plataformas através da seção `servers`.
2. **Produtos de Dados Multi-Porta ([ODPS v1.0.0](https://github.com/bitol-io/open-data-product-standard))**:
   - Entrega por porta analítica (Delta Lake para cientistas e analistas) e porta operacional (MongoDB para canais digitais e internet banking).
3. **Semântica e Ontologias (RDF / OWL)**:
   - Termos de negócio e grafos semânticos conectando o catálogo técnico a conceitos corporativos.
4. **Linhagem Medallion Ponta a Ponta**:
   - Rastreabilidade visual desde as fontes brutas (BACEN/Mainframe) $\rightarrow$ Bronze $\rightarrow$ Silver $\rightarrow$ Gold.
5. **Marketplace Corporativo e Self-Service**:
   - Descoberta de produtos com selos de certificação (*Gold Certified*), termos de uso e subscrição.

---

## 🗺️ Arquitetura do Caso de Uso (Renda Fixa 360)

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

## 💻 Pré-requisitos para Reprodução

Para executar o ambiente e rodar os cenários de teste, certifique-se de possuir:

* **Sistema Operacional:** Windows 10/11 com **WSL2** (distribuição recomendada: Ubuntu).
* **Motor de Contêineres:** [Rancher Desktop](https://rancherdesktop.io/) (com motor Moby/Docker e Kubernetes k3s habilitados) OU Docker Desktop.
* **Ferramentas de Linha de Comando (no WSL):**
  * `bash`, `curl`, `jq`
  * `kubectl` (conectado ao cluster k3s do Rancher Desktop)
  * `docker` ou `docker compose`
  * *(Opcional)* `terraform` (caso utilize a esteira automatizada)

---

## 🚀 Como Subir o Ambiente

Você pode inicializar a plataforma de duas formas:

### Opção 1: Deploy Automatizado no Kubernetes (Recomendado)

O script unificado provisiona a infraestrutura, compila a imagem Docker multi-stage local, aplica os manifestos Kubernetes e inicia os túneis de acesso:

```bash
# Na raiz do repositório clonado (no terminal WSL2 / Linux):
chmod +x deploy.sh scripts/*.sh scripts/lab-renda-fixa/*.sh

./deploy.sh
```

### Opção 2: Execução Direta via Docker Compose

Caso prefira executar sem o Kubernetes:

```bash
docker compose -f docker-compose.lab.yml up -d
```

---

## 🌐 Endereços de Acesso

Após a inicialização dos serviços, acesse pelo navegador no Windows:

| Serviço / Interface | URL Local | Descrição |
| :--- | :--- | :--- |
| **Marketplace & UI do Ontos** | [http://localhost:8000](http://localhost:8000) (ou `:30080` via NodePort) | Portal completo de Produtos de Dados e Governança |
| **Catálogo de Produtos** | [http://localhost:8000/data-products](http://localhost:8000/data-products) | Gestão e catálogo de produtos ODPS |
| **Contratos de Dados** | [http://localhost:8000/data-contracts](http://localhost:8000/data-contracts) | Especificações e schemas ODCS v3.1.0 |
| **Linhagem e Ativos Técnicos** | [http://localhost:8000/assets](http://localhost:8000/assets) | Grafo de ativos e rastreabilidade técnica |
| **Domínios de Dados** | [http://localhost:8000/data-domains](http://localhost:8000/data-domains) | Estrutura organizacional e times federados |
| **Grafo Semântico / Glossário** | [http://localhost:8000/knowledge/collections](http://localhost:8000/knowledge/collections) | Conceitos de negócio no grafo RDF/OWL |
| **Documentação da API (Swagger)** | [http://localhost:8000/docs](http://localhost:8000/docs) | Endpoints REST OpenAPI interativos |
| **Health Check** | [http://localhost:8000/api/health](http://localhost:8000/api/health) | Diagnóstico de integridade do backend e banco |

---

## 🎬 Execução do Laboratório Prático (Renda Fixa 360)

O laboratório é composto por 8 etapas guiadas e automatizadas via scripts Shell.

### Execução Completa com Pausas Interativas

Execute o orquestrador no terminal para narrar e demonstrar cada etapa:

```bash
./scripts/lab-renda-fixa/executar-lab-completo.sh --pausar
```

### Etapas do Roteiro

| # | Etapa | Script | O que é demonstrado |
| :-: | :--- | :--- | :--- |
| **1** | **Domínio e Time** | `01-criar-dominio-e-time.sh` | Criação do subdomínio *Mercado de Capitais* subordinado ao *Core*, e do time *Mesa de Operações de Renda Fixa*. |
| **2** | **Camada Semântica** | `02-criar-glossario-e-conceitos.sh` | Modelagem dos conceitos no Grafo RDF/OWL (*Posição*, *Movimentação* e *Posição Consolidada*). |
| **3** | **Ativos Físicos** | `03-cadastrar-ativos-fisicos.sh` | Registro das tabelas Medallion (Bronze, Silver, Gold Delta e NoSQL MongoDB). |
| **4** | **Contrato ODCS** | `04-importar-contratos-odcs.sh` | Registro do contrato de dados unificado v3.1.0 contemplando múltiplos servidores. |
| **5** | **Produto ODPS** | `05-cadastrar-produto-odps-multi-portas.sh` | Publicação do Produto de Dados com porta analítica e operacional apontando para o mesmo contrato. |
| **6** | **Linhagem Medallion** | `06-construir-linhagem-medallion.sh` | Conexão dos nós de linhagem desde a ingestão até as saídas de consumo. |
| **7** | **Marketplace de Dados** | `07-ativar-e-publicar-marketplace.sh` | Transição para status `ACTIVE`, atribuição de selo *Gold Certified* e publicação no catálogo de consumo. |
| **8** | **Grafo Semântico** | `08-vincular-grafo-semantico.sh` | Conexão entre colunas técnicas físicas e os conceitos semânticos de negócio. |

Consulte o documento completo em [**`docs/ROTEIRO_APRESENTACAO_LAB_RENDA_FIXA.md`**](docs/ROTEIRO_APRESENTACAO_LAB_RENDA_FIXA.md) para os pontos de fala, telas a serem exibidas e perguntas frequentes de arquitetura.

---

## 🛠️ Comandos Úteis do Ambiente

* **Status dos Pods do Kubernetes:**
  ```bash
  kubectl get pods -n ontos
  ```
* **Logs da Aplicação:**
  ```bash
  kubectl logs -n ontos -l app=ontos-app -f
  ```
* **Gerenciamento de Túneis (Port-Forward):**
  ```bash
  ./scripts/port-forward.sh [start|stop|status]
  ```
* **Reset / Destruição do Ambiente:**
  ```bash
  kubectl delete -f k8s/
  # ou via terraform:
  cd terraform && terraform destroy -auto-approve
  ```

---

## 📚 Documentação Complementar

* [**`README_ONTOS.md`**](README_ONTOS.md): Documentação oficial do Databricks Labs Ontos (arquitetura interna, desenvolvimento local com Hatch, testes unitários e CI/CD).
* [**`docs/LAB_GUIDE.md`**](docs/LAB_GUIDE.md): Guia detalhado de infraestrutura no Rancher Desktop / k3s / WSL2.
* [**`docs/ROTEIRO_APRESENTACAO_LAB_RENDA_FIXA.md`**](docs/ROTEIRO_APRESENTACAO_LAB_RENDA_FIXA.md): Roteiro completo de apresentação para executivos e times técnicos.
