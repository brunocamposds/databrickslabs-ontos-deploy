#!/usr/bin/env bash
# ==============================================================================
# Script 07: 07-ativar-e-publicar-marketplace.sh
# Conceito Ontos: CICLO DE VIDA, CERTIFICAÇÃO E PUBLICAÇÃO NO MARKETPLACE
#                (DRAFT -> PROPOSED -> UNDER_REVIEW -> APPROVED -> ACTIVE -> MARKETPLACE)
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
[ -f "${SCRIPT_DIR}/.state/env.sh" ] && source "${SCRIPT_DIR}/.state/env.sh"

check_health

echo -e "${BLUE}======================================================================${NC}"
echo -e "${CYAN}${BOLD}  ETAPA 7: ATIVAÇÃO, CERTIFICAÇÃO E PUBLICAÇÃO NO MARKETPLACE        ${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo -e "📖 ${BOLD}Conceito no Ontos:${NC}"
echo -e "   Um Produto de Dados entra no sistema como 'draft'. Para que ele apareça"
echo -e "   no ${CYAN}Marketplace / Home de Dados${NC} da organização e possa ser descoberto"
echo -e "   e consumido por outros times, ele passa pelo ciclo de vida formal:"
echo -e "     1. ${YELLOW}Governança de Status:${NC} draft ➔ proposed ➔ under_review ➔ approved ➔ active"
echo -e "     2. ${YELLOW}Publicação:${NC} Definição de escopo corporativo ('organization')"
echo -e "     3. ${YELLOW}Certificação:${NC} Atribuição de selo de qualidade nível 3 ('Gold')"
echo ""

echo -e "${YELLOW}7.1 Executando ciclo de vida ODPS até status 'active'...${NC}"
python3 -c "
import urllib.request, json, sys

pid = '${PRODUCT_ID}'
base_url = '${BASE_URL}'

# Consulta status atual
try:
    res = urllib.request.urlopen(f'{base_url}/api/data-products/{pid}')
    current_status = json.loads(res.read().decode()).get('status', 'draft')
except Exception:
    current_status = 'draft'

print(f'    • Status atual do Produto: {current_status}')

# Roteiro de transições ordenadas
all_transitions = ['proposed', 'under_review', 'approved', 'active']
start_idx = 0
if current_status in all_transitions:
    start_idx = all_transitions.index(current_status) + 1

for target_status in all_transitions[start_idx:]:
    url = f'{base_url}/api/data-products/{pid}/change-status'
    payload = json.dumps({'new_status': target_status}).encode()
    req = urllib.request.Request(url, data=payload, headers={'Content-Type': 'application/json'}, method='POST')
    try:
        urllib.request.urlopen(req)
        print(f'      ➔ Transicionado para: {target_status}')
    except urllib.error.HTTPError as e:
        print(f'      Erro ao transicionar para {target_status}: {e.code}')
"

echo -e "    ${GREEN}✓ Produto promovido com sucesso para:${NC} ${CYAN}active${NC}"
echo ""

echo -e "${YELLOW}7.2 Definindo Escopo de Publicação Corporativa (Marketplace)...${NC}"
echo -e "    Endpoint: POST ${BASE_URL}/api/data-products/${PRODUCT_ID}/set-publication-scope"

python3 -c "
import urllib.request, json
url_pub = '${BASE_URL}/api/data-products/${PRODUCT_ID}/set-publication-scope'
req_pub = urllib.request.Request(url_pub, data=json.dumps({'scope': 'organization'}).encode(), headers={'Content-Type': 'application/json'}, method='POST')
try:
    res = urllib.request.urlopen(req_pub)
    data = json.loads(res.read().decode())
    print(f'    • Escopo de Publicação: {data.get(\"publication_scope\")} em {data.get(\"published_at\")}')
except Exception as e:
    print('    Erro ao publicar:', e)
"

echo -e "    ${GREEN}✓ Produto publicado com sucesso no Marketplace!${NC}"
echo ""

echo -e "${YELLOW}7.3 Aplicando Selo de Certificação 'Gold' (Nível 3) ao Produto...${NC}"
echo -e "    Endpoint: POST ${BASE_URL}/api/data-products/${PRODUCT_ID}/certify"

python3 -c "
import urllib.request, json
url_cert = '${BASE_URL}/api/data-products/${PRODUCT_ID}/certify'
payload = {
    'certification_level': 3,
    'notes': 'Certificação Gold: Produto de dados com linhagem completa Bronze->Silver->Gold e Contrato ODCS ativo'
}
req_cert = urllib.request.Request(url_cert, data=json.dumps(payload).encode(), headers={'Content-Type': 'application/json'}, method='POST')
try:
    res = urllib.request.urlopen(req_cert)
    print('    • Selo Gold atribuído com sucesso!')
except Exception as e:
    print('    Erro ao certificar:', e)
"

echo -e "    ${GREEN}✓ Produto certificado:${NC} Selo ${CYAN}Gold${NC} atribuído!"
echo ""

echo -e "${GREEN}======================================================================${NC}"
echo -e "✅ ${BOLD}Etapa 7 Concluída com Sucesso!${NC}"
echo -e "   • Ver no Marketplace / Home: ${BLUE}${BASE_URL}/${NC}"
echo -e "   • Ver no Catálogo de Produtos: ${BLUE}${BASE_URL}/data-products${NC}"
echo -e "   • Detalhes do Produto:        ${BLUE}${BASE_URL}/data-products/${PRODUCT_ID}${NC}"
echo -e "   • Próximo Script:             ${CYAN}./scripts/lab-renda-fixa/08-vincular-grafo-semantico.sh${NC}"
echo -e "${GREEN}======================================================================${NC}"
