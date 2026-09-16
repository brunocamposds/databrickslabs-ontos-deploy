# Guia Prático de Laboratório: Databricks Ontos no Rancher Desktop

Este guia orienta a execução do **Ontos** no ambiente local do **Rancher Desktop** (Kubernetes k3s / WSL2) operando em **Modo Demo Isolado**.

---

## 1. Visão Geral da Arquitetura do Laboratório

```
                           Navegador / Usuário
                                    │
           ┌────────────────────────┴────────────────────────┐
           ▼                                                 ▼
http://localhost:30080                            http://localhost (Ingress)
(Service NodePort)                                (Traefik Ingress)
           │                                                 │
           └────────────────────────┬────────────────────────┘
                                    ▼
                         Service: ontos-app (Port 8000)
                                    │
                                    ▼
                          Pod: ontos-app (FastAPI + React SPA)
                                    │
                                    ▼
                         Service: postgres (Port 5432)
                                    │
                                    ▼
                          Pod: postgres:16-alpine
                                    │
                                    ▼
                          PVC: postgres-pvc (local-path)
```

---

## 2. Pré-requisitos Verificados

- **Rancher Desktop** ativo com o motor Moby (Docker) e Kubernetes k3s.
- **WSL2 (Ubuntu)** integrado.
- Todos os comandos são executados a partir do WSL (no diretório do repositório):
  ```bash
  wsl -d Ubuntu
  cd /caminho/para/ontos
  ```

---

## 3. Passo a Passo do Deploy

### Passo 1: Construir a imagem Docker do Ontos
No terminal WSL, execute o build da imagem multi-stage (que compila o frontend React e empacota o backend FastAPI):

```bash
docker build -t ontos:lab -f Dockerfile .
```

*Como o Rancher Desktop compartilha o daemon de contêineres com o k3s, a imagem `ontos:lab` fica imediatamente disponível para os pods do Kubernetes com `imagePullPolicy: IfNotPresent`.*

### Passo 2: Aplicar os manifestos no Kubernetes

```bash
kubectl apply -f k8s/
```

### Passo 3: Acompanhar a inicialização

```bash
kubectl get pods -n ontos -w
```

Você verá:
1. O pod `postgres` atingindo status `Running` e `1/1 Ready`.
2. O pod `ontos-app` iniciando, conectando ao PostgreSQL, aplicando as migrações do Alembic, populando os esquemas e atingindo status `Running` e `1/1 Ready`.

Para visualizar os logs detalhados de inicialização do Ontos:
```bash
kubectl logs -n ontos -l app=ontos-app -f
```

---

## 4. Acesso à Aplicação e Validações

### 4.1 Acesso via Navegador
Abra o navegador no Windows e acerte qualquer um dos seguintes endereços:
- **Via NodePort (Recomendado)**: [http://localhost:30080](http://localhost:30080)
- **Via Ingress Traefik**: [http://localhost](http://localhost) (ou configure `127.0.0.1 ontos.local` no seu arquivo `hosts` e acesse [http://ontos.local](http://ontos.local))

### 4.2 Verificação de Saúde (Health Check)
Acesse no navegador ou via curl no WSL:
```bash
curl -s http://localhost:30080/api/health | jq .
```
Resposta esperada:
```json
{
  "db_ok": true,
  "ws_ok": true,
  "seed_ok": true,
  "warnings": [],
  "db_error": null,
  "seed_error": null
}
```

### 4.3 Documentação Interativa da API (Swagger / OpenAPI)
- **Swagger UI**: [http://localhost:30080/docs](http://localhost:30080/docs)
- **ReDoc**: [http://localhost:30080/redoc](http://localhost:30080/redoc)

---

## 5. Roteiro Prático de Exploração do Laboratório

### Cenário A: Carregar Presets de Dados de Demonstração
O Ontos vem com dados verticais completos para testar casos de uso reais da indústria. No terminal WSL, você pode carregar ou trocar o preset:

1. **Carregar o preset de Varejo (Retail - Padrão)**:
   ```bash
   curl -X POST "http://localhost:30080/api/settings/demo-data/load?preset=retail"
   ```
2. **Outros presets disponíveis**:
   - `hls` (Healthcare & Life Sciences)
   - `fsi` (Financial Services Industry)
   - `mfg` (Manufacturing)
   - `auto` (Automotive)

### Cenário B: Explorar o Catálogo de Contratos de Dados (ODCS)
1. Navegue até a seção **Data Contracts**.
2. Veja as especificações de schema, regras de qualidade, SLAs/SLOs e versões de contratos.
3. Teste a exportação em formato padronizado BITOL ODCS v3.1.0 YAML/JSON.

### Cenário C: Explorar Produtos de Dados (ODPS)
1. Navegue até **Data Products**.
2. Examine as portas de entrada e saída (input/output ports), classificação de domínios e times responsáveis.

### Cenário D: Explorar o Grafo de Conhecimento e Ontologias
1. Acesse o **Concept Browser / Ontologies**.
2. Veja as entidades semânticas, relacionamentos e modelos conceituais mapeados visualmente pelo motor de grafos.

---

## 6. Comandos Úteis para Administração do Laboratório

- **Reiniciar o pod do Ontos**:
  ```bash
  kubectl rollout restart deployment ontos-app -n ontos
  ```
- **Verificar eventos do namespace**:
  ```bash
  kubectl get events -n ontos --sort-by='.metadata.creationTimestamp'
  ```
- **Limpar / Resetar o laboratório**:
  ```bash
  kubectl delete -f k8s/
  ```

---

## 7. Alternativa Direta via Docker Compose
Se preferir executar fora do Kubernetes, use o Docker Compose nativo no WSL:
```bash
docker compose -f docker-compose.lab.yml up -d
docker compose -f docker-compose.lab.yml logs -f
```
Acesse em: [http://localhost:8000](http://localhost:8000).
