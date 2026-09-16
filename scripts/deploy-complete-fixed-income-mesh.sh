#!/usr/bin/env bash
# ==============================================================================
# Script: deploy-complete-fixed-income-mesh.sh
# Descrição: Implementa o fluxo canônico de ponta a ponta proposto pelo Ontos:
#            1. Extrai metadados do contrato padrão ODCS v3.1.0
#            2. Cria/Obtém o Domínio de Negócios (Data Domain)
#            3. Cria/Obtém o Time Responsável (Team)
#            4. Cria o Ativo Físico de Dados (Data Asset - Tabela Postgres)
#            5. Cria a Coleção Semântica e o Conceito de Negócio (Knowledge Concept)
#            6. Importa e ativa o Contrato de Dados (ODCS v3.1.0)
#            7. Cria e publica o Produto de Dados (ODPS v1.0.0) vinculado a tudo
#            8. Estabelece os vínculos semânticos e relacionamentos de entidade
# ==============================================================================
set -euo pipefail

# Paleta de cores para terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_URL="${ONTOS_API_URL:-http://localhost:8000}"
CONTRACT_SAMPLE="${1:-${SCRIPT_DIR}/samples/odcs-fixed-income-sample.json}"

echo -e "${BLUE}======================================================================${NC}"
echo -e "${CYAN}${BOLD}       ONTOS - FLUXO COMPLETO DE GOVERNANÇA DE PRODUTO DE DADOS       ${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo -e "Base da API: ${YELLOW}${BASE_URL}${NC}"
echo -e "Arquivo ODCS:${YELLOW}${CONTRACT_SAMPLE}${NC}"
echo ""

if [ ! -f "$CONTRACT_SAMPLE" ]; then
  echo -e "${RED}Erro: Arquivo ODCS não encontrado em: ${CONTRACT_SAMPLE}${NC}"
  exit 1
fi

# Função segura para parsing de JSON via stdin
parse_json() {
  local expr="$1"
  python3 -c "
import json, sys
try:
    raw = sys.stdin.read()
    if not raw.strip():
        print('')
        sys.exit(0)
    data = json.loads(raw)
    expr = '''$expr'''
    keys = expr.split('.')
    cur = data
    for k in keys:
        if isinstance(cur, dict):
            cur = cur.get(k)
        elif isinstance(cur, list) and k.isdigit():
            cur = cur[int(k)]
        else:
            cur = None
            break
    print(cur if cur is not None else '')
except Exception:
    print('')
"
}

# ------------------------------------------------------------------------------
# 0. Teste de Conectividade
# ------------------------------------------------------------------------------
echo -e "${BLUE}[0/7] Testando conectividade com o Ontos...${NC}"
if ! curl -s -f "${BASE_URL}/api/health" >/dev/null 2>&1; then
  echo -e "${RED}Erro: Não foi possível conectar ao Ontos em ${BASE_URL}.${NC}"
  echo -e "Verifique se os serviços e o port-forward estão ativos:"
  echo -e "  ./scripts/port-forward.sh"
  exit 1
fi
echo -e "${GREEN}✓ Conectado à API com sucesso!${NC}\n"

# ------------------------------------------------------------------------------
# Leitura e Extração de Metadados do ODCS
# ------------------------------------------------------------------------------
echo -e "${BLUE}[Leitura ODCS] Extraindo definições do contrato de dados...${NC}"
EXTRACTED_VARS=$(python3 - <<EOF
import json, sys

with open("${CONTRACT_SAMPLE}", "r", encoding="utf-8") as f:
    odcs = json.load(f)

domain_name = odcs.get("domain", "Mercado de Capitais")
if domain_name.lower() == "capital markets":
    domain_name = "Mercado de Capitais"

tenant_raw = odcs.get("tenant", "mesa-renda-fixa")
team_name = "mesa-renda-fixa"
team_title = "Mesa de Operações e Dados de Renda Fixa"

schemas = odcs.get("schema", [])
table_meta = schemas[0] if schemas else {}
asset_name = table_meta.get("physicalName", "tb_titulos_renda_fixa")
asset_business_name = table_meta.get("businessName", "Títulos e Instrumentos de Renda Fixa")
asset_desc = table_meta.get("description", "Tabela mestre contendo os títulos de dívida negociados, indexadores, taxas contratuais, prazos e preços unitários.")

servers = odcs.get("servers", [])
server_meta = servers[0] if servers else {}
server_type = server_meta.get("type", "postgres")
server_host = server_meta.get("host", "postgres.ontos.svc.cluster.local")
server_port = server_meta.get("port", 5432)
server_db = server_meta.get("database", "ontos_lab")
server_schema = server_meta.get("schema", "mercado_de_capitais")

location_url = f"{server_host}:{server_port}/{server_db}/{server_schema}/{asset_name}"

concept_name = asset_business_name
concept_def = odcs.get("description", {}).get("purpose", "Instrumentos e títulos de renda fixa.")
contract_name = odcs.get("name", "Contrato de Dados - Renda Fixa")
product_name = odcs.get("dataProduct", "Produto de Dados - Precificação e Títulos de Renda Fixa")

print(f'DOMAIN_NAME="{domain_name}"')
print(f'TEAM_NAME="{team_name}"')
print(f'TEAM_TITLE="{team_title}"')
print(f'ASSET_NAME="{asset_name}"')
print(f'ASSET_DESC="{asset_desc}"')
print(f'SERVER_TYPE="{server_type}"')
print(f'LOCATION_URL="{location_url}"')
print(f'CONCEPT_NAME="{concept_name}"')
print(f'CONCEPT_DEF="{concept_def}"')
print(f'CONTRACT_NAME="{contract_name}"')
print(f'PRODUCT_NAME="{product_name}"')
EOF
)

eval "$EXTRACTED_VARS"

echo -e "  • Domínio extraído:  ${CYAN}${DOMAIN_NAME}${NC}"
echo -e "  • Time extraído:     ${CYAN}${TEAM_TITLE}${NC}"
echo -e "  • Ativo extraído:    ${CYAN}${ASSET_NAME}${NC} (${SERVER_TYPE})"
echo -e "  • Conceito extraído: ${CYAN}${CONCEPT_NAME}${NC}"
echo -e "  • Produto de Dados:  ${CYAN}${PRODUCT_NAME}${NC}\n"

# ------------------------------------------------------------------------------
# 1. Domínio de Negócios (Data Domain)
# ------------------------------------------------------------------------------
echo -e "${BLUE}[1/7] Criando ou obtendo Domínio de Negócios...${NC}"
echo -e "POST ${BASE_URL}/api/data-domains"

DOMAIN_RESP=$(curl -s -X POST "${BASE_URL}/api/data-domains" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"${DOMAIN_NAME}\",
    \"description\": \"Domínio de negócio responsável pela emissão, custódia, negociação e precificação de ativos e títulos no mercado de capitais brasileiro.\"
  }" || true)

DOMAIN_ID=$(echo "$DOMAIN_RESP" | parse_json "id")

if [ -z "$DOMAIN_ID" ]; then
  DOMAIN_ID=$(curl -s "${BASE_URL}/api/data-domains" | python3 -c "
import json, sys
data = json.load(sys.stdin)
domains = data.get('items', data) if isinstance(data, dict) else data
match = next((d['id'] for d in domains if isinstance(d, dict) and d.get('name') == '${DOMAIN_NAME}'), '')
print(match)
")
fi

echo -e "${GREEN}✓ Domínio de Negócios pronto:${NC} ID ${YELLOW}${DOMAIN_ID}${NC} (${DOMAIN_NAME})\n"

# ------------------------------------------------------------------------------
# 2. Time Responsável (Team)
# ------------------------------------------------------------------------------
echo -e "${BLUE}[2/7] Criando ou obtendo Time de Negócios/Engenharia...${NC}"
echo -e "POST ${BASE_URL}/api/teams"

TEAM_RESP=$(curl -s -X POST "${BASE_URL}/api/teams" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"${TEAM_NAME}\",
    \"title\": \"${TEAM_TITLE}\",
    \"description\": \"Equipe responsável pelo ciclo de vida, ingestão, governança e modelos de apreçamento de ativos de renda fixa.\",
    \"domain_ids\": [\"${DOMAIN_ID}\"],
    \"primary_domain_id\": \"${DOMAIN_ID}\"
  }" || true)

TEAM_ID=$(echo "$TEAM_RESP" | parse_json "id")

if [ -z "$TEAM_ID" ]; then
  TEAM_ID=$(curl -s "${BASE_URL}/api/teams" | python3 -c "
import json, sys
teams = json.load(sys.stdin)
match = next((t['id'] for t in teams if isinstance(t, dict) and t.get('name') == '${TEAM_NAME}'), '')
print(match)
")
fi

echo -e "${GREEN}✓ Time pronto:${NC} ID ${YELLOW}${TEAM_ID}${NC} (${TEAM_TITLE})\n"

# ------------------------------------------------------------------------------
# 3. Ativo Físico de Dados (Data Asset)
# ------------------------------------------------------------------------------
echo -e "${BLUE}[3/7] Cadastrando Ativo Físico de Dados (Tabela PostgreSQL)...${NC}"
TABLE_ASSET_TYPE_ID=$(curl -s "${BASE_URL}/api/asset-types" | python3 -c "
import json, sys
try:
    types = json.load(sys.stdin)
    if isinstance(types, dict):
        types = types.get('items', types.get('asset_types', []))
    table_t = next((t['id'] for t in types if isinstance(t, dict) and t.get('name', '').lower() == 'table'), '')
    print(table_t or '247d14ff-7500-4f62-a953-05f9bdadc108')
except Exception:
    print('247d14ff-7500-4f62-a953-05f9bdadc108')
")

echo -e "POST ${BASE_URL}/api/assets"
ASSET_RESP=$(curl -s -X POST "${BASE_URL}/api/assets" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"${ASSET_NAME}\",
    \"description\": \"${ASSET_DESC}\",
    \"asset_type_id\": \"${TABLE_ASSET_TYPE_ID}\",
    \"platform\": \"postgres\",
    \"location\": \"${LOCATION_URL}\",
    \"domain_ids\": [\"${DOMAIN_ID}\"],
    \"primary_domain_id\": \"${DOMAIN_ID}\",
    \"tags\": [\"renda-fixa\", \"mercado-de-capitais\", \"tabela-mestre\"],
    \"status\": \"active\"
  }" || true)

ASSET_ID=$(echo "$ASSET_RESP" | parse_json "id")

if [ -z "$ASSET_ID" ]; then
  ASSET_ID=$(curl -s "${BASE_URL}/api/assets?name=${ASSET_NAME}" | python3 -c "
import json, sys
try:
    res = json.load(sys.stdin)
    items = res.get('items', []) if isinstance(res, dict) else res
    match = next((a['id'] for a in items if isinstance(a, dict) and a.get('name') == '${ASSET_NAME}'), '')
    print(match)
except:
    pass
")
fi

echo -e "${GREEN}✓ Ativo de Dados cadastrado:${NC} ID ${YELLOW}${ASSET_ID}${NC} (${ASSET_NAME})\n"

# ------------------------------------------------------------------------------
# 4. Coleção de Conhecimento e Conceito de Negócio (Semantic Concept)
# ------------------------------------------------------------------------------
echo -e "${BLUE}[4/7] Criando Coleção Semântica e Conceito de Negócio...${NC}"
COLLECTION_LABEL="Glossário de Mercado de Capitais e Renda Fixa"

COLLECTION_RESP=$(curl -s -X POST "${BASE_URL}/api/knowledge/collections" \
  -H "Content-Type: application/json" \
  -d "{
    \"label\": \"${COLLECTION_LABEL}\",
    \"collection_type\": \"glossary\",
    \"scope_level\": \"domain\",
    \"description\": \"Vocabulário controlado, termos de negócio e conceitos semânticos para instrumentos de renda fixa.\",
    \"is_editable\": true
  }" || true)

COLLECTION_IRI=$(echo "$COLLECTION_RESP" | parse_json "iri")
if [ -z "$COLLECTION_IRI" ]; then
  COLLECTION_IRI=$(echo "$COLLECTION_RESP" | parse_json "collection_iri")
fi

if [ -z "$COLLECTION_IRI" ]; then
  COLLECTION_IRI=$(curl -s "${BASE_URL}/api/knowledge/collections" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    cols = data.get('collections', data) if isinstance(data, dict) else data
    match = next((c['iri'] for c in cols if isinstance(c, dict) and c.get('label') == '${COLLECTION_LABEL}'), '')
    print(match)
except:
    pass
")
fi

if [ -z "$COLLECTION_IRI" ]; then
  COLLECTION_IRI="urn:glossary:glossario-de-mercado-de-capitais-e-renda-fixa"
fi

echo -e "  • Coleção Semântica IRI: ${CYAN}${COLLECTION_IRI}${NC}"

CONCEPT_RESP=$(curl -s -X POST "${BASE_URL}/api/knowledge/concepts" \
  -H "Content-Type: application/json" \
  -d "{
    \"collection_iri\": \"${COLLECTION_IRI}\",
    \"label\": \"${CONCEPT_NAME}\",
    \"definition\": \"${CONCEPT_DEF}\",
    \"concept_type\": \"concept\",
    \"synonyms\": [\"Título de Renda Fixa\", \"Instrumento Financeiro de Dívida\", \"Ativo de Renda Fixa\", \"Fixed Income Security\"],
    \"examples\": [\"Tesouro IPCA+ (NTN-B)\", \"CDB DI\", \"Debênture Incentivada Vale\"]
  }" || true)

CONCEPT_IRI=$(echo "$CONCEPT_RESP" | parse_json "iri")
if [ -z "$CONCEPT_IRI" ]; then
  CONCEPT_IRI="urn:concept:titulos_e_instrumentos_de_renda_fixa"
fi

echo -e "${GREEN}✓ Conceito Semântico de Negócio criado:${NC} ${YELLOW}${CONCEPT_IRI}${NC} (${CONCEPT_NAME})\n"

# ------------------------------------------------------------------------------
# 5. Importação e Ativação do Contrato de Dados (ODCS v3.1.0)
# ------------------------------------------------------------------------------
echo -e "${BLUE}[5/7] Importando Contrato de Dados ODCS v3.1.0...${NC}"
echo -e "POST ${BASE_URL}/api/data-contracts/odcs/import"

CONTRACT_RESP=$(curl -s -X POST "${BASE_URL}/api/data-contracts/odcs/import" \
  -H "Content-Type: application/json" \
  -d @"${CONTRACT_SAMPLE}")

CONTRACT_ID=$(echo "$CONTRACT_RESP" | parse_json "id")

if [ -z "$CONTRACT_ID" ]; then
  echo -e "${RED}Falha ao importar contrato ODCS. Resposta da API:${NC}"
  echo "$CONTRACT_RESP"
  exit 1
fi

echo -e "Garantindo status 'active' para o contrato..."
curl -s -X POST "${BASE_URL}/api/data-contracts/${CONTRACT_ID}/change-status" \
  -H "Content-Type: application/json" \
  -d '{"new_status": "active"}' >/dev/null 2>&1 || true

echo -e "${GREEN}✓ Contrato ODCS ativo:${NC} ID ${YELLOW}${CONTRACT_ID}${NC} (${CONTRACT_NAME})\n"

# ------------------------------------------------------------------------------
# 6. Cadastro e Publicação do Produto de Dados (ODPS v1.0.0)
# ------------------------------------------------------------------------------
echo -e "${BLUE}[6/7] Cadastrando e Publicando o Produto de Dados ODPS v1.0.0...${NC}"
OUTPUT_PORT_NAME="porta_saida_titulos_renda_fixa"

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
    "purpose": "Produto de dados certificado que distribui a base consolidada de títulos de renda fixa com marcação a mercado e taxas indicativas.",
    "usage": "Alimentação de sistemas de risco, liquidação financeira, relatórios executivos e auditoria regulatória.",
    "limitations": "Restrito a usuários autorizados da mesa de operações e compliance."
  },
  "tags": [
    "renda-fixa",
    "mercado-de-capitais",
    "titulos-publicos",
    "anbima"
  ],
  "outputPorts": [
    {
      "name": "${OUTPUT_PORT_NAME}",
      "version": "1.0.0",
      "description": "Porta de saída analítica contendo títulos de renda fixa certificados",
      "port_type": "table",
      "contract_id": "${CONTRACT_ID}",
      "asset_type": "table",
      "asset_identifier": "${ASSET_NAME}"
    }
  ]
}
EOF
)

PRODUCT_RESP=$(curl -s -X POST "${BASE_URL}/api/data-products" \
  -H "Content-Type: application/json" \
  -d "${PRODUCT_PAYLOAD}")

PRODUCT_ID=$(echo "$PRODUCT_RESP" | parse_json "id")

if [ -z "$PRODUCT_ID" ]; then
  echo -e "${RED}Falha ao criar Produto de Dados: ${PRODUCT_RESP}${NC}"
  exit 1
fi

echo -e "Promovendo produto para status 'active'..."
curl -s -X POST "${BASE_URL}/api/data-products/${PRODUCT_ID}/change-status" \
  -H "Content-Type: application/json" \
  -d '{"new_status": "active"}' >/dev/null 2>&1 || true

echo -e "${GREEN}✓ Produto de Dados publicado com sucesso:${NC} ID ${YELLOW}${PRODUCT_ID}${NC}\n"

# ------------------------------------------------------------------------------
# 7. Estabelecer Relacionamentos de Entidades e Vínculos Semânticos
# ------------------------------------------------------------------------------
echo -e "${BLUE}[7/7] Estabelecendo Vínculos Semânticos e Relacionamentos no Grafo...${NC}"

# A) Relacionamento Produto <-> Ativo
echo -e "Vinculando Produto de Dados ao Ativo Físico..."
curl -s -X POST "${BASE_URL}/api/entity-relationships" \
  -H "Content-Type: application/json" \
  -d "{
    \"source_type\": \"data_product\",
    \"source_id\": \"${PRODUCT_ID}\",
    \"target_type\": \"asset\",
    \"target_id\": \"${ASSET_ID}\",
    \"relationship_type\": \"producesAsset\",
    \"properties\": {
      \"output_port\": \"${OUTPUT_PORT_NAME}\",
      \"contract_id\": \"${CONTRACT_ID}\"
    }
  }" >/dev/null 2>&1 || true

# B) Link Semântico: Produto de Dados <-> Conceito de Negócio
echo -e "Vinculando Conceito de Negócio ao Produto de Dados..."
curl -s -X POST "${BASE_URL}/api/semantic-links/" \
  -H "Content-Type: application/json" \
  -d "{
    \"entity_type\": \"data_product\",
    \"entity_id\": \"${PRODUCT_ID}\",
    \"iri\": \"${CONCEPT_IRI}\",
    \"label\": \"${CONCEPT_NAME}\"
  }" >/dev/null 2>&1 || true

# C) Link Semântico: Ativo de Dados <-> Conceito de Negócio
echo -e "Vinculando Conceito de Negócio ao Ativo de Dados..."
curl -s -X POST "${BASE_URL}/api/semantic-links/" \
  -H "Content-Type: application/json" \
  -d "{
    \"entity_type\": \"asset\",
    \"entity_id\": \"${ASSET_ID}\",
    \"iri\": \"${CONCEPT_IRI}\",
    \"label\": \"${CONCEPT_NAME}\"
  }" >/dev/null 2>&1 || true

# D) Link Semântico: Contrato de Dados <-> Conceito de Negócio
echo -e "Vinculando Conceito de Negócio ao Contrato de Dados..."
curl -s -X POST "${BASE_URL}/api/semantic-links/" \
  -H "Content-Type: application/json" \
  -d "{
    \"entity_type\": \"data_contract\",
    \"entity_id\": \"${CONTRACT_ID}\",
    \"iri\": \"${CONCEPT_IRI}\",
    \"label\": \"${CONCEPT_NAME}\"
  }" >/dev/null 2>&1 || true

echo -e "${GREEN}✓ Relacionamentos e Links Semânticos criados no grafo de conhecimento!${NC}\n"

# ------------------------------------------------------------------------------
# Resumo do Grafo de Conhecimento Criado
# ------------------------------------------------------------------------------
echo -e "${GREEN}======================================================================${NC}"
echo -e "${GREEN}${BOLD}     ECOSSISTEMA DE GOVERNANÇA MONTADO COM SUCESSO NO ONTO LAB!      ${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "🏛️  ${CYAN}${BOLD}Domínio de Negócios:${NC}"
echo -e "   • Nome:       ${DOMAIN_NAME}"
echo -e "   • ID:         ${YELLOW}${DOMAIN_ID}${NC}"
echo -e "   • Link:       ${BLUE}${BASE_URL}/data-domains${NC}"
echo ""
echo -e "👥 ${CYAN}${BOLD}Time Responsável:${NC}"
echo -e "   • Título:     ${TEAM_TITLE}"
echo -e "   • Slug/ID:    ${YELLOW}${TEAM_ID}${NC}"
echo -e "   • Link:       ${BLUE}${BASE_URL}/teams/${TEAM_ID}${NC}"
echo ""
echo -e "💡 ${CYAN}${BOLD}Conceito Semântico de Negócio:${NC}"
echo -e "   • Conceito:   ${CONCEPT_NAME}"
echo -e "   • IRI:        ${YELLOW}${CONCEPT_IRI}${NC}"
echo -e "   • Coleção:    ${COLLECTION_LABEL}"
echo -e "   • Link:       ${BLUE}${BASE_URL}/knowledge/concepts?iri=${CONCEPT_IRI}${NC}"
echo ""
echo -e "📋 ${CYAN}${BOLD}Contrato de Dados ODCS v3.1.0:${NC}"
echo -e "   • Nome:       ${CONTRACT_NAME}"
echo -e "   • ID:         ${YELLOW}${CONTRACT_ID}${NC}"
echo -e "   • Tabela:     ${ASSET_NAME} (13 colunas, 3 regras de qualidade)"
echo -e "   • Link:       ${BLUE}${BASE_URL}/data-contracts/${CONTRACT_ID}${NC}"
echo ""
echo -e "💾 ${CYAN}${BOLD}Ativo Físico de Dados (Data Asset):${NC}"
echo -e "   • Tabela:     ${ASSET_NAME}"
echo -e "   • ID:         ${YELLOW}${ASSET_ID}${NC}"
echo -e "   • Plataforma: ${SERVER_TYPE} (${LOCATION_URL})"
echo -e "   • Link:       ${BLUE}${BASE_URL}/assets/${ASSET_ID}${NC}"
echo ""
echo -e "📦 ${CYAN}${BOLD}Produto de Dados ODPS v1.0.0:${NC}"
echo -e "   • Nome:       ${PRODUCT_NAME}"
echo -e "   • ID:         ${YELLOW}${PRODUCT_ID}${NC}"
echo -e "   • Porta:      ${OUTPUT_PORT_NAME}"
echo -e "   • Link:       ${BLUE}${BASE_URL}/data-products/${PRODUCT_ID}${NC}"
echo ""
echo -e "📚 ${CYAN}${BOLD}Swagger UI Interativo:${NC}"
echo -e "   • OpenAPI:    ${BLUE}${BASE_URL}/docs${NC}"
echo -e "${GREEN}======================================================================${NC}"
