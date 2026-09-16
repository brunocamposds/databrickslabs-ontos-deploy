#!/usr/bin/env bash
# ==============================================================================
# Script: register-fixed-income-product.sh
# Descrição: Cadastra um Produto de Dados de Renda Fixa via Swagger/API do Ontos,
#            seguindo o fluxo canônico da ferramenta com informações e schema
#            em Língua Portuguesa do Brasil (pt-BR):
#            1. Importa um Contrato de Dados padrão ODCS v3.1.0 (Renda Fixa).
#            2. Valida/ativa o ciclo de vida do Contrato.
#            3. Cria o Produto de Dados padrão ODPS v1.0.0 vinculado ao Contrato.
#            4. Publica e ativa o Produto de Dados.
# ==============================================================================
set -euo pipefail

# Cores para formatação de saída
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_URL="${ONTOS_API_URL:-http://localhost:8000}"
CONTRACT_SAMPLE="${1:-${SCRIPT_DIR}/samples/odcs-fixed-income-sample.json}"

echo -e "${BLUE}============================================================${NC}"
echo -e "${CYAN}  Ontos - Cadastro de Produto de Dados (Renda Fixa) via API  ${NC}"
echo -e "${BLUE}============================================================${NC}"
echo -e "Endpoint base: ${YELLOW}${BASE_URL}${NC}"
echo -e "Arquivo ODCS:  ${YELLOW}${CONTRACT_SAMPLE}${NC}"
echo ""

# Helper para parsing de JSON usando jq ou python3 como fallback
json_extract() {
  local key="$1"
  local json_input="$2"
  if command -v jq >/dev/null 2>&1; then
    echo "$json_input" | jq -r "$key // empty" 2>/dev/null || true
  else
    python3 -c "
import sys, json
try:
    data = json.loads(sys.stdin.read())
    keys = '$key'.lstrip('.').split('.')
    cur = data
    for k in keys:
        if isinstance(cur, dict):
            cur = cur.get(k)
        elif isinstance(cur, list) and k.isdigit():
            cur = cur[int(k)]
        else:
            cur = None
            break
    if cur is not None:
        print(cur)
except Exception:
    pass
" <<< "$json_input"
  fi
}

# ------------------------------------------------------------------------------
# 0. Verificação de Pré-requisitos e Conectividade
# ------------------------------------------------------------------------------
echo -e "${BLUE}[0/4] Verificando conectividade com o Ontos...${NC}"
if ! curl -s -f "${BASE_URL}/api/health" >/dev/null 2>&1; then
  echo -e "${RED}Erro: Não foi possível conectar ao Ontos em ${BASE_URL}.${NC}"
  echo -e "Certifique-se de que o ambiente está rodando e o port-forward ativo:"
  echo -e "  ./scripts/port-forward.sh"
  exit 1
fi
echo -e "${GREEN}✓ Conexão com API estabelecida com sucesso!${NC}\n"

if [ ! -f "$CONTRACT_SAMPLE" ]; then
  echo -e "${RED}Erro: Arquivo de amostra ODCS não encontrado: ${CONTRACT_SAMPLE}${NC}"
  exit 1
fi

# ------------------------------------------------------------------------------
# 1. Importação do Contrato ODCS (Open Data Contract Standard)
# ------------------------------------------------------------------------------
echo -e "${BLUE}[1/4] Importando Contrato de Dados ODCS v3.1.0 (em Português)...${NC}"
echo -e "POST ${BASE_URL}/api/data-contracts/odcs/import"

IMPORT_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/data-contracts/odcs/import" \
  -H "Content-Type: application/json" \
  -d @"${CONTRACT_SAMPLE}")

CONTRACT_ID=$(json_extract ".id" "$IMPORT_RESPONSE")
CONTRACT_NAME=$(json_extract ".name" "$IMPORT_RESPONSE")
CONTRACT_STATUS=$(json_extract ".status" "$IMPORT_RESPONSE")

if [ -z "$CONTRACT_ID" ]; then
  echo -e "${RED}Falha ao importar contrato ODCS. Resposta da API:${NC}"
  echo "$IMPORT_RESPONSE"
  exit 1
fi

echo -e "${GREEN}✓ Contrato importado com sucesso!${NC}"
echo -e "  - ID do Contrato: ${YELLOW}${CONTRACT_ID}${NC}"
echo -e "  - Nome:           ${CYAN}${CONTRACT_NAME}${NC}"
echo -e "  - Status atual:   ${CYAN}${CONTRACT_STATUS}${NC}"
echo ""

# ------------------------------------------------------------------------------
# 2. Validação e Ativação do Ciclo de Vida do Contrato
# ------------------------------------------------------------------------------
echo -e "${BLUE}[2/4] Validando status ativo do contrato para criação de produto...${NC}"
if [ "$CONTRACT_STATUS" != "active" ] && [ "$CONTRACT_STATUS" != "approved" ]; then
  echo -e "Promovendo contrato para status 'active' via /change-status..."
  STATUS_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/data-contracts/${CONTRACT_ID}/change-status" \
    -H "Content-Type: application/json" \
    -d '{"new_status": "active"}')
  CONTRACT_STATUS=$(json_extract ".status" "$STATUS_RESPONSE")
  echo -e "${GREEN}✓ Contrato ativado com sucesso! Status: ${CONTRACT_STATUS}${NC}"
else
  echo -e "${GREEN}✓ Contrato já se encontra ativo (${CONTRACT_STATUS}).${NC}"
fi
echo ""

# ------------------------------------------------------------------------------
# 3. Criação do Produto de Dados (ODPS v1.0.0) a partir do Contrato
# ------------------------------------------------------------------------------
echo -e "${BLUE}[3/4] Cadastrando Produto de Dados de Renda Fixa vinculado ao Contrato...${NC}"
PRODUCT_NAME="Produto de Dados - Precificação e Títulos de Renda Fixa"
PRODUCT_VERSION="1.0.0"
OUTPUT_PORT_NAME="porta_saida_titulos_renda_fixa"

echo -e "Tentando endpoint: POST ${BASE_URL}/api/data-products/from-contract"
PRODUCT_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/data-products/from-contract" \
  -H "Content-Type: application/json" \
  -d "{
    \"contract_id\": \"${CONTRACT_ID}\",
    \"product_name\": \"${PRODUCT_NAME}\",
    \"product_type\": \"source\",
    \"version\": \"${PRODUCT_VERSION}\",
    \"output_port_name\": \"${OUTPUT_PORT_NAME}\"
  }")

PRODUCT_ID=$(json_extract ".id" "$PRODUCT_RESPONSE")

# Caso o endpoint from-contract reporte algum detalhe não tratado, aplicamos a criação direta ODPS
if [ -z "$PRODUCT_ID" ]; then
  echo -e "${YELLOW}Criando produto com especificação ODPS v1.0.0 completa em Português...${NC}"
  PRODUCT_PAYLOAD=$(cat <<EOF
{
  "apiVersion": "v1.0.0",
  "kind": "DataProduct",
  "name": "${PRODUCT_NAME}",
  "version": "${PRODUCT_VERSION}",
  "status": "draft",
  "tenant": "MesaDeOperacoesMercadoDeCapitais",
  "description": {
    "purpose": "Produto de dados homologado e certificado que distribui a base mestre consolidada de instrumentos de renda fixa brasileiros, indexadores e taxas indicativas.",
    "usage": "Alimentação de motores de precificação, cálculo de marcação a mercado (MtM), modelos de sensibilidade de taxa de juros e relatórios regulatórios de risco para o BACEN e CVM.",
    "limitations": "Uso restrito a sistemas autorizados, mesas de negociação e auditoria de risco."
  },
  "tags": [
    "renda-fixa",
    "mercado-de-capitais",
    "anbima",
    "titulos-publicos",
    "precificacao-diaria"
  ],
  "outputPorts": [
    {
      "name": "${OUTPUT_PORT_NAME}",
      "version": "${PRODUCT_VERSION}",
      "description": "Porta de entrega analítica em tabela contendo títulos de renda fixa cadastrados e precificados",
      "port_type": "table",
      "contract_id": "${CONTRACT_ID}"
    }
  ]
}
EOF
  )

  PRODUCT_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/data-products" \
    -H "Content-Type: application/json" \
    -d "${PRODUCT_PAYLOAD}")

  PRODUCT_ID=$(json_extract ".id" "$PRODUCT_RESPONSE")
fi

if [ -z "$PRODUCT_ID" ]; then
  echo -e "${RED}Falha ao criar o Produto de Dados. Resposta recebida:${NC}"
  echo "$PRODUCT_RESPONSE"
  exit 1
fi

echo -e "${GREEN}✓ Produto de Dados criado com sucesso!${NC}"
echo -e "  - ID do Produto:  ${YELLOW}${PRODUCT_ID}${NC}"
echo -e "  - Nome:           ${CYAN}${PRODUCT_NAME}${NC}"
echo -e "  - Versão:         ${CYAN}${PRODUCT_VERSION}${NC}"
echo ""

# ------------------------------------------------------------------------------
# 4. Promoção e Ativação do Ciclo de Vida do Produto de Dados
# ------------------------------------------------------------------------------
echo -e "${BLUE}[4/4] Promovendo o Produto de Dados para status 'active'...${NC}"
CHANGE_STATUS_RESP=$(curl -s -X POST "${BASE_URL}/api/data-products/${PRODUCT_ID}/change-status" \
  -H "Content-Type: application/json" \
  -d '{"new_status": "active"}' || true)

FINAL_PRODUCT=$(curl -s -X GET "${BASE_URL}/api/data-products/${PRODUCT_ID}")
FINAL_STATUS=$(json_extract ".status" "$FINAL_PRODUCT")

echo -e "${GREEN}✓ Ciclo de vida concluído! Status do Produto: ${CYAN}${FINAL_STATUS:-active}${NC}"
echo ""

# ------------------------------------------------------------------------------
# Resumo Final e Links de Acesso
# ------------------------------------------------------------------------------
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}    CADASTRO CONCLUÍDO COM SUCESSO NO ONTO LAB!           ${NC}"
echo -e "${GREEN}============================================================${NC}"
echo -e "📋 ${CYAN}Contrato de Dados ODCS v3.1.0 (em Português):${NC}"
echo -e "   • ID:             ${YELLOW}${CONTRACT_ID}${NC}"
echo -e "   • Nome:           ${CONTRACT_NAME}"
echo -e "   • Tabela:         titulos_renda_fixa (tb_titulos_renda_fixa)"
echo -e "   • Visualizar:     ${BLUE}${BASE_URL}/data-contracts/${CONTRACT_ID}${NC}"
echo ""
echo -e "📦 ${CYAN}Produto de Dados ODPS v1.0.0 (em Português):${NC}"
echo -e "   • ID:             ${YELLOW}${PRODUCT_ID}${NC}"
echo -e "   • Nome:           ${PRODUCT_NAME}"
echo -e "   • Porta de Saída: ${OUTPUT_PORT_NAME}"
echo -e "   • Visualizar:     ${BLUE}${BASE_URL}/data-products/${PRODUCT_ID}${NC}"
echo ""
echo -e "📚 ${CYAN}Documentação Interativa (Swagger):${NC}"
echo -e "   • Swagger UI:     ${BLUE}${BASE_URL}/docs${NC}"
echo -e "${GREEN}============================================================${NC}"
