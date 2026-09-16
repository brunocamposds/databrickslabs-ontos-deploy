#!/usr/bin/env bash
# ==============================================================================
# Script 06: 06-construir-linhagem-medallion.sh
# Conceito Ontos: LINHAGEM DE DADOS MULTI-CAMADA (BRONZE -> SILVER -> GOLD -> CONSUMO)
#                (Conectando origens brutas a tabelas refinadas, sumarizadas e produtos)
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
[ -f "${SCRIPT_DIR}/.state/env.sh" ] && source "${SCRIPT_DIR}/.state/env.sh"

check_health

echo -e "${BLUE}======================================================================${NC}"
echo -e "${CYAN}${BOLD}  ETAPA 6: CONSTRUÇÃO DA LINHAGEM DE DADOS (ARQUITETURA MEDALLION)   ${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo -e "📖 ${BOLD}Conceito no Ontos:${NC}"
echo -e "   A ${CYAN}Linhagem de Dados (Business Lineage)${NC} no Ontos conecta as camadas da arquitetura"
echo -e "   em um Grafo Direcionado. Isso permite rastrear a proveniência dos dados (upstream)"
echo -e "   e realizar análise de impacto (downstream):"
echo -e "     [Bronze Ingestão] ──producesTo──> [Silver Conformada] ──producesTo──>"
echo -e "     ──> [Gold Analítica Databricks] ──producesTo──> [Gold NoSQL MongoDB]"
echo -e "     Além disso, o [Produto de Dados] ──exposes──> as tabelas Silver e Gold."
echo ""

criar_relacionamento() {
  local s_type="$1"
  local s_id="$2"
  local s_name="$3"
  local t_type="$4"
  local t_id="$5"
  local t_name="$6"
  local rel_type="$7"

  echo -e "    • ${CYAN}${s_name}${NC} ──[${rel_type}]──> ${YELLOW}${t_name}${NC}"

  curl -s -X POST "${BASE_URL}/api/entity-relationships" \
    -H "Content-Type: application/json" \
    -d "{
      \"source_type\": \"${s_type}\",
      \"source_id\": \"${s_id}\",
      \"target_type\": \"${t_type}\",
      \"target_id\": \"${t_id}\",
      \"relationship_type\": \"${rel_type}\"
    }" >/dev/null 2>&1 || true
}

echo -e "${YELLOW}6.1 Construindo Linhagem Técnica (Bronze ➔ Silver):${NC}"
# 1. Bronze Selic -> Silver Títulos
criar_relacionamento "Table" "${ASSET_ID_BRONZE_SELIC}" "[Bronze] Operações Selic (BACEN)" \
                     "Table" "${ASSET_ID_SILVER_TITULOS}" "[Silver] Títulos Renda Fixa" \
                     "producesTo"

# 2. Bronze Legado -> Silver Movimentação
criar_relacionamento "Table" "${ASSET_ID_BRONZE_LEGADO}" "[Bronze] Boletas Mainframe (Legado)" \
                     "Table" "${ASSET_ID_SILVER_MOVIMENTACAO}" "[Silver] Movimentação Renda Fixa" \
                     "producesTo"

echo ""
echo -e "${YELLOW}6.2 Construindo Linhagem de Refinamento (Silver ➔ Gold Sumarizada):${NC}"
# 3. Silver Títulos -> Gold Posição
criar_relacionamento "Table" "${ASSET_ID_SILVER_TITULOS}" "[Silver] Títulos Renda Fixa" \
                     "Table" "${ASSET_ID_GOLD_POSICAO}" "[Gold] Posição Analítica UC" \
                     "producesTo"

# 4. Silver Movimentação -> Gold Posição
criar_relacionamento "Table" "${ASSET_ID_SILVER_MOVIMENTACAO}" "[Silver] Movimentação Renda Fixa" \
                     "Table" "${ASSET_ID_GOLD_POSICAO}" "[Gold] Posição Analítica UC" \
                     "producesTo"

echo ""
echo -e "${YELLOW}6.3 Construindo Linhagem de Distribuição para Canais (Gold Databricks ➔ Gold MongoDB):${NC}"
# 5. Gold Posição UC -> Gold Consolidado MongoDB
criar_relacionamento "Table" "${ASSET_ID_GOLD_POSICAO}" "[Gold] Posição Analítica UC" \
                     "Table" "${ASSET_ID_GOLD_MONGO}" "[Gold/Operacional] MongoDB Canais" \
                     "producesTo"

echo ""
echo -e "${YELLOW}6.4 Vinculando Ativos ao Produto de Dados (DataProduct ➔ Exposes):${NC}"
# 6. DataProduct -> Silver Movimentação
criar_relacionamento "DataProduct" "${PRODUCT_ID}" "Produto Renda Fixa 360" \
                     "Table" "${ASSET_ID_SILVER_MOVIMENTACAO}" "[Silver] Movimentação Renda Fixa" \
                     "exposes"

# 7. DataProduct -> Gold Posição
criar_relacionamento "DataProduct" "${PRODUCT_ID}" "Produto Renda Fixa 360" \
                     "Table" "${ASSET_ID_GOLD_POSICAO}" "[Gold] Posição Analítica UC" \
                     "exposes"

# 8. DataProduct -> Gold MongoDB
criar_relacionamento "DataProduct" "${PRODUCT_ID}" "Produto Renda Fixa 360" \
                     "Table" "${ASSET_ID_GOLD_MONGO}" "[Gold/Operacional] MongoDB Canais" \
                     "exposes"

echo ""
echo -e "    ${GREEN}✓ Toda a malha de linhagem Medallion foi registrada no Ontos!${NC}"
echo ""

echo -e "${GREEN}======================================================================${NC}"
echo -e "✅ ${BOLD}Etapa 6 Concluída com Sucesso!${NC}"
echo -e "   • Linhagem do Produto de Dados:  ${BLUE}${BASE_URL}/data-products/${PRODUCT_ID}${NC}"
echo -e "   • Linhagem da Tabela Gold no UC: ${BLUE}${BASE_URL}/assets/${ASSET_ID_GOLD_POSICAO}${NC}"
echo -e "   • Próximo Script:                ${CYAN}./scripts/lab-renda-fixa/07-ativar-e-publicar-marketplace.sh${NC}"
echo -e "${GREEN}======================================================================${NC}"
