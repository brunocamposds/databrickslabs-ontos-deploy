#!/usr/bin/env bash
# ==============================================================================
# Script 01: 01-criar-dominio-e-time.sh
# Conceito Ontos: ESTRUTURA ORGANIZACIONAL & DATA MESH
#                (Domínios de Dados e Equipes Proprietárias)
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

check_health

echo -e "${BLUE}======================================================================${NC}"
echo -e "${CYAN}${BOLD}  ETAPA 1: CRIAÇÃO DE DOMÍNIO DE DADOS E TIME RESPONSÁVEL (DATA MESH) ${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo -e "📖 ${BOLD}Conceito no Ontos:${NC}"
echo -e "   No Data Mesh, a governança deixa de ser monolítica e passa a ser"
echo -e "   descentralizada por ${CYAN}Domínios de Negócio${NC}. Cada domínio agrupa produtos"
echo -e "   e ativos afins, sob a custódia e responsabilidade de um ${CYAN}Time Multidisciplinar${NC}."
echo ""

DOMAIN_NAME="Mercado de Capitais"
DOMAIN_DESC="Domínio responsável por títulos, operações, custódia, marcação a mercado e precificação no mercado financeiro e de capitais brasileiro."

# Busca o domínio raiz 'Core' existente na demo
CORE_DOMAIN_ID=$(curl -s "${BASE_URL}/api/data-domains" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    items = data.get('items', data) if isinstance(data, dict) else data
    core = next((d['id'] for d in items if isinstance(d, dict) and d.get('name', '').lower() == 'core'), '')
    print(core or '00000001-0000-4000-8000-000000000001')
except:
    print('00000001-0000-4000-8000-000000000001')
")

echo -e "    Domínio Pai (Hierarquia): ${CYAN}Core${NC} (${CORE_DOMAIN_ID})"
echo -e "${YELLOW}1.1 Criando Domínio de Dados:${NC} '${DOMAIN_NAME}' vinculado a 'Core'"
echo -e "    Endpoint: POST ${BASE_URL}/api/data-domains"

DOMAIN_RESP=$(curl -s -X POST "${BASE_URL}/api/data-domains" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"${DOMAIN_NAME}\",
    \"description\": \"${DOMAIN_DESC}\",
    \"parent_id\": \"${CORE_DOMAIN_ID}\"
  }" || true)

DOMAIN_ID=$(echo "$DOMAIN_RESP" | parse_json "id")

if [ -z "$DOMAIN_ID" ]; then
  echo -e "    ${YELLOW}Domínio já existente, recuperando ID e vinculando ao Core...${NC}"
  DOMAIN_ID=$(curl -s "${BASE_URL}/api/data-domains" | python3 -c "
import json, sys
data = json.load(sys.stdin)
items = data.get('items', data) if isinstance(data, dict) else data
match = next((d['id'] for d in items if isinstance(d, dict) and d.get('name') == '${DOMAIN_NAME}'), '')
print(match)
")
  # Garante vinculação ao Core via PUT
  python3 -c "
import urllib.request, json
try:
    url = '${BASE_URL}/api/data-domains/${DOMAIN_ID}'
    data = json.dumps({'parent_id': '${CORE_DOMAIN_ID}'}).encode()
    req = urllib.request.Request(url, data=data, headers={'Content-Type': 'application/json'}, method='PUT')
    urllib.request.urlopen(req)
except Exception as e:
    pass
"
fi

echo -e "    ${GREEN}✓ Domínio pronto e vinculado ao CORE:${NC} ID: ${CYAN}${DOMAIN_ID}${NC} (Pai: Core)"
echo ""

TEAM_NAME="mesa-renda-fixa"
TEAM_TITLE="Mesa de Operações e Dados de Renda Fixa"
TEAM_DESC="Equipe responsável pela engenharia de dados, precificação e distribuição de produtos de renda fixa analíticos e operacionais."

echo -e "${YELLOW}1.2 Criando Time Proprietário:${NC} '${TEAM_TITLE}'"
echo -e "    Endpoint: POST ${BASE_URL}/api/teams"

TEAM_RESP=$(curl -s -X POST "${BASE_URL}/api/teams" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"${TEAM_NAME}\",
    \"title\": \"${TEAM_TITLE}\",
    \"description\": \"${TEAM_DESC}\",
    \"domain_ids\": [\"${DOMAIN_ID}\"],
    \"primary_domain_id\": \"${DOMAIN_ID}\"
  }" || true)

TEAM_ID=$(echo "$TEAM_RESP" | parse_json "id")

if [ -z "$TEAM_ID" ]; then
  echo -e "    ${YELLOW}Time já existente, recuperando ID...${NC}"
  TEAM_ID=$(curl -s "${BASE_URL}/api/teams" | python3 -c "
import json, sys
teams = json.load(sys.stdin)
match = next((t['id'] for t in teams if isinstance(t, dict) and t.get('name') == '${TEAM_NAME}'), '')
print(match)
")
fi

echo -e "    ${GREEN}✓ Time pronto:${NC} ID: ${CYAN}${TEAM_ID}${NC}"
echo ""

# Salva variáveis de estado para os próximos scripts
mkdir -p "${SCRIPT_DIR}/.state"
echo "export DOMAIN_ID=\"${DOMAIN_ID}\"" > "${SCRIPT_DIR}/.state/env.sh"
echo "export DOMAIN_NAME=\"${DOMAIN_NAME}\"" >> "${SCRIPT_DIR}/.state/env.sh"
echo "export TEAM_ID=\"${TEAM_ID}\"" >> "${SCRIPT_DIR}/.state/env.sh"
echo "export TEAM_TITLE=\"${TEAM_TITLE}\"" >> "${SCRIPT_DIR}/.state/env.sh"

echo -e "${GREEN}======================================================================${NC}"
echo -e "✅ ${BOLD}Etapa 1 Concluída com Sucesso!${NC}"
echo -e "   • Visualizar Domínio: ${BLUE}${BASE_URL}/data-domains${NC}"
echo -e "   • Visualizar Time:    ${BLUE}${BASE_URL}/teams/${TEAM_ID}${NC}"
echo -e "   • Próximo Script:     ${CYAN}./scripts/lab-renda-fixa/02-criar-glossario-e-conceitos.sh${NC}"
echo -e "${GREEN}======================================================================${NC}"
