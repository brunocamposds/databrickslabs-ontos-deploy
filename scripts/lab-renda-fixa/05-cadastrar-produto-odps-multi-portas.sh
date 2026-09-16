#!/usr/bin/env bash
# ==============================================================================
# Script 05: 05-cadastrar-produto-odps-multi-portas.sh
# Conceito Ontos: PRODUTO DE DADOS MULTI-PORTAS (OPEN DATA PRODUCT STANDARD - ODPS v1.0.0)
#                (1 Contrato Unificado -> 2 Output Ports: Databricks UC & MongoDB)
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
[ -f "${SCRIPT_DIR}/.state/env.sh" ] && source "${SCRIPT_DIR}/.state/env.sh"

check_health

echo -e "${BLUE}======================================================================${NC}"
echo -e "${CYAN}${BOLD}  ETAPA 5: PRODUTO DE DADOS COM DUAS PORTAS DE SAÍDA (ODPS v1.0.0)    ${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo -e "📖 ${BOLD}Conceito no Ontos:${NC}"
echo -e "   Um ${CYAN}Data Product (ODPS v1.0.0)${NC} é um componente de arquitetura autônomo."
echo -e "   Ele encapsula dados, contratos e metadados, expondo ${CYAN}Múltiplas Portas de Saída${NC}"
echo -e "   regidas pelo ${BOLD}mesmo Contrato de Dados unificado:${NC}"
echo -e "     • Porta 1: Analítica (Databricks UC - Posição & Transações)"
echo -e "     • Porta 2: Operacional (MongoDB - Consolidado de Cliente para App/IB)"
echo ""

PRODUCT_NAME="Produto de Dados - Renda Fixa 360 (Analítico & Operacional)"
PRODUCT_DESC="Produto de dados unificado de renda fixa que oferece tanto a camada analítica/lakehouse no Databricks Unity Catalog para relatórios e riscos, quanto a camada operacional no MongoDB para consulta em tempo real no Internet Banking e Mobile App."

echo -e "${YELLOW}5.1 Montando payload ODPS v1.0.0 com duas portas de saída...${NC}"

PRODUCT_PAYLOAD=$(cat <<EOF
{
  "apiVersion": "v1.0.0",
  "kind": "DataProduct",
  "name": "${PRODUCT_NAME}",
  "version": "1.0.0",
  "status": "draft",
  "domain_ids": ["${DOMAIN_ID}"],
  "primary_domain_id": "${DOMAIN_ID}",
  "owner_team_id": "${TEAM_ID}",
  "tenant": "MesaDeOperacoesMercadoDeCapitais",
  "description": {
    "purpose": "${PRODUCT_DESC}",
    "usage": "Alimentação de dashboards analíticos no Databricks, modelos de precificação e backends de alta performance dos canais digitais (App Mobile e Internet Banking).",
    "limitations": "Porta Databricks atualizada em D+1; Porta MongoDB sincronizada intradiária para consultas de clientes."
  },
  "tags": [
    "renda-fixa",
    "mercado-de-capitais",
    "databricks-uc",
    "mongodb",
    "internet-banking",
    "mobile-app",
    "multi-portas"
  ],
  "outputPorts": [
    {
      "name": "porta_analitica_databricks_uc",
      "version": "1.0.0",
      "description": "Porta de entrega analítica no Databricks Unity Catalog contendo tabelas Delta de posição diária e movimentações.",
      "port_type": "table",
      "contract_id": "${CONTRACT_ID}",
      "asset_type": "table",
      "asset_identifier": "posicao_titulos_renda_fixa"
    },
    {
      "name": "porta_operacional_mongodb_canais",
      "version": "1.0.0",
      "description": "Porta de entrega operacional NoSQL no MongoDB otimizada para respostas rápidas de extrato no Mobile App e Internet Banking.",
      "port_type": "collection",
      "contract_id": "${CONTRACT_ID}",
      "asset_type": "collection",
      "asset_identifier": "posicao_consolidada_cliente_rf"
    }
  ]
}
EOF
)

echo -e "${YELLOW}5.2 Enviando criação para o Ontos:${NC}"
echo -e "    Endpoint: POST ${BASE_URL}/api/data-products"

PRODUCT_RESP=$(curl -s -X POST "${BASE_URL}/api/data-products" \
  -H "Content-Type: application/json" \
  -d "${PRODUCT_PAYLOAD}")

PRODUCT_ID=$(echo "$PRODUCT_RESP" | parse_json "id")

if [ -z "$PRODUCT_ID" ]; then
  # Se já existir, busca pelo nome
  PRODUCT_ID=$(curl -s "${BASE_URL}/api/data-products" | python3 -c "
import json, sys
data = json.load(sys.stdin)
items = data.get('items', data) if isinstance(data, dict) else data
match = next((p['id'] for p in items if isinstance(p, dict) and p.get('name') == '${PRODUCT_NAME}'), '')
print(match)
")
fi

if [ -z "$PRODUCT_ID" ]; then
  echo -e "    ${RED}Falha ao obter ID do produto de dados:${NC} ${PRODUCT_RESP}"
  exit 1
fi

echo -e "    ${GREEN}✓ Produto de Dados cadastrado:${NC} ID: ${CYAN}${PRODUCT_ID}${NC}"
echo ""

# Persiste estado
echo "export PRODUCT_ID=\"${PRODUCT_ID}\"" >> "${SCRIPT_DIR}/.state/env.sh"
echo "export PRODUCT_NAME=\"${PRODUCT_NAME}\"" >> "${SCRIPT_DIR}/.state/env.sh"

echo -e "${GREEN}======================================================================${NC}"
echo -e "✅ ${BOLD}Etapa 5 Concluída com Sucesso!${NC}"
echo -e "   • Visualizar Produto: ${BLUE}${BASE_URL}/data-products/${PRODUCT_ID}${NC}"
echo -e "   • Próximo Script:     ${CYAN}./scripts/lab-renda-fixa/06-construir-linhagem-medallion.sh${NC}"
echo -e "${GREEN}======================================================================${NC}"
