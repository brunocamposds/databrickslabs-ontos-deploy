#!/usr/bin/env bash
# ==============================================================================
# Script 02: 02-criar-glossario-e-conceitos.sh
# Conceito Ontos: GRAFO DE CONHECIMENTO & CAMADA SEMÂNTICA RDF/OWL
#                (Glossários de Negócio e Conceitos Semânticos)
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
[ -f "${SCRIPT_DIR}/.state/env.sh" ] && source "${SCRIPT_DIR}/.state/env.sh"

check_health

echo -e "${BLUE}======================================================================${NC}"
echo -e "${CYAN}${BOLD}  ETAPA 2: CAMADA SEMÂNTICA & GRAFO DE CONHECIMENTO (GLOSSÁRIO)      ${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo -e "📖 ${BOLD}Conceito no Ontos:${NC}"
echo -e "   Antes de modelar tabelas físicas, o Ontos permite formalizar o"
echo -e "   ${CYAN}Significado de Negócio${NC} em um Grafo Semântico RDF/OWL. Isso cria uma"
echo -e "   linguagem comum para toda a organização, independente da tecnologia"
echo -e "   (se o dado está no Databricks, PostgreSQL ou MongoDB)."
echo ""

COLLECTION_LABEL="Glossário de Mercado de Capitais e Investimentos"
COLLECTION_DESC="Vocabulário institucional controlado contendo os conceitos canônicos de custódia, transações e posições de renda fixa."

echo -e "${YELLOW}2.1 Criando Coleção / Glossário de Negócio:${NC}"
echo -e "    Endpoint: POST ${BASE_URL}/api/knowledge/collections"

COLLECTION_RESP=$(curl -s -X POST "${BASE_URL}/api/knowledge/collections" \
  -H "Content-Type: application/json" \
  -d "{
    \"label\": \"${COLLECTION_LABEL}\",
    \"collection_type\": \"glossary\",
    \"scope_level\": \"domain\",
    \"description\": \"${COLLECTION_DESC}\",
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
  COLLECTION_IRI="urn:glossary:glossario-de-mercado-de-capitais-e-investimentos"
fi

echo -e "    ${GREEN}✓ Coleção Semântica pronta:${NC} IRI: ${CYAN}${COLLECTION_IRI}${NC}"
echo ""

criar_conceito() {
  local label="$1"
  local definition="$2"
  local synonyms="$3"
  local examples="$4"

  echo -e "    • Cadastrando Conceito: ${CYAN}${label}${NC}" >&2
  local resp=$(curl -s -X POST "${BASE_URL}/api/knowledge/concepts" \
    -H "Content-Type: application/json" \
    -d "{
      \"collection_iri\": \"${COLLECTION_IRI}\",
      \"label\": \"${label}\",
      \"definition\": \"${definition}\",
      \"concept_type\": \"concept\",
      \"synonyms\": ${synonyms},
      \"examples\": ${examples}
    }" || true)

  local iri=$(echo "$resp" | parse_json "iri")
  if [ -z "$iri" ]; then
    iri=$(echo "$resp" | parse_json "concept_iri")
  fi
  echo "$iri"
}

echo -e "${YELLOW}2.2 Cadastrando Conceitos Semânticos no Grafo:${NC}"

# Conceito 1: Posição em Renda Fixa
IRI_POSICAO=$(criar_conceito \
  "Posição em Renda Fixa" \
  "Foto diária do saldo e custódia de títulos de dívida (públicos ou privados) mantidos por um investidor, valorizados na curva e a mercado." \
  '["Saldo de Renda Fixa", "Custódia de Títulos", "Fixed Income Holding"]' \
  '["Posição em NTN-B", "CDB em Carteira"]')

# Conceito 2: Movimentação em Renda Fixa
IRI_MOVIMENTACAO=$(criar_conceito \
  "Movimentação em Renda Fixa" \
  "Registro cronológico de operações de compra, venda, amortização, resgate ou recebimento de cupons de juros associados a títulos de dívida." \
  '["Transação de Renda Fixa", "Ordem de Compra e Venda", "Trade de Renda Fixa"]' \
  '["Compra de Debênture", "Amortização de CRI", "Resgate de CDB"]')

# Conceito 3: Posição Consolidada do Cliente
IRI_CONSOLIDADA=$(criar_conceito \
  "Posição Consolidada do Cliente em Renda Fixa" \
  "Visão agregada e unificada de todo o patrimônio alocado em renda fixa por CPF ou CNPJ, formatada para consulta ágil nos canais digitais." \
  '["Patrimônio Consolidado RF", "Extrato Unificado de Investimentos", "Saldo Agregado Mobile"]' \
  '["Extrato do App Mobile", "Visão de Carteira Internet Banking"]')

echo -e "    ${GREEN}✓ Conceitos Semânticos registrados no Grafo!${NC}"
echo ""

# Persiste estado
echo "export COLLECTION_LABEL=\"${COLLECTION_LABEL}\"" >> "${SCRIPT_DIR}/.state/env.sh"
echo "export COLLECTION_IRI=\"${COLLECTION_IRI}\"" >> "${SCRIPT_DIR}/.state/env.sh"
echo "export IRI_POSICAO=\"${IRI_POSICAO:-urn:concept:posicao_em_renda_fixa}\"" >> "${SCRIPT_DIR}/.state/env.sh"
echo "export IRI_MOVIMENTACAO=\"${IRI_MOVIMENTACAO:-urn:concept:movimentacao_em_renda_fixa}\"" >> "${SCRIPT_DIR}/.state/env.sh"
echo "export IRI_CONSOLIDADA=\"${IRI_CONSOLIDADA:-urn:concept:posicao_consolidada_do_cliente_em_renda_fixa}\"" >> "${SCRIPT_DIR}/.state/env.sh"

echo -e "${GREEN}======================================================================${NC}"
echo -e "✅ ${BOLD}Etapa 2 Concluída com Sucesso!${NC}"
echo -e "   • Visualizar Coleção: ${BLUE}${BASE_URL}/knowledge/collections${NC}"
echo -e "   • Próximo Script:     ${CYAN}./scripts/lab-renda-fixa/03-cadastrar-ativos-fisicos.sh${NC}"
echo -e "${GREEN}======================================================================${NC}"
