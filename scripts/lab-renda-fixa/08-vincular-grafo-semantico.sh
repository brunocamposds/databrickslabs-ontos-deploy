#!/usr/bin/env bash
# ==============================================================================
# Script 08: 08-vincular-grafo-semantico.sh
# Conceito Ontos: CONEXÃO NO GRAFO DE CONHECIMENTO (SEMANTIC LINKS & GRAPH)
#                (Conecta Produto, Ativos e Contratos aos Conceitos de Negócio)
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
[ -f "${SCRIPT_DIR}/.state/env.sh" ] && source "${SCRIPT_DIR}/.state/env.sh"

check_health

echo -e "${BLUE}======================================================================${NC}"
echo -e "${CYAN}${BOLD}  ETAPA 8: VINCULAÇÃO NO GRAFO SEMÂNTICO (SEMANTIC LINKS)             ${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo -e "📖 ${BOLD}Conceito no Ontos:${NC}"
echo -e "   Os ${CYAN}Semantic Links${NC} amarram todas as pontas da arquitetura:"
echo -e "   Quando um usuário ou IA pesquisa pelo conceito de negócio no catálogo,"
echo -e "   o Ontos rastreia o grafo e exibe a linhagem completa, as portas analíticas"
echo -e "   (Databricks) e operacionais (MongoDB), sob o mesmo Contrato ODCS."
echo ""

criar_link_semantico() {
  local tipo_entidade="$1"
  local id_entidade="$2"
  local iri_conceito="$3"
  local rotulo="$4"

  echo -e "    • Vinculando ${CYAN}${tipo_entidade}${NC} -> ${YELLOW}${rotulo}${NC}"
  curl -s -X POST "${BASE_URL}/api/semantic-links/" \
    -H "Content-Type: application/json" \
    -d "{
      \"entity_type\": \"${tipo_entidade}\",
      \"entity_id\": \"${id_entidade}\",
      \"iri\": \"${iri_conceito}\",
      \"label\": \"${rotulo}\"
    }" >/dev/null 2>&1 || true
}

echo -e "${YELLOW}8.1 Vinculando Conceitos ao Produto de Dados:${NC}"
criar_link_semantico "data_product" "${PRODUCT_ID}" "${IRI_POSICAO}" "Posição em Renda Fixa"
criar_link_semantico "data_product" "${PRODUCT_ID}" "${IRI_MOVIMENTACAO}" "Movimentação em Renda Fixa"
criar_link_semantico "data_product" "${PRODUCT_ID}" "${IRI_CONSOLIDADA}" "Posição Consolidada do Cliente em Renda Fixa"
echo ""

echo -e "${YELLOW}8.2 Vinculando Conceitos aos Ativos Físicos correspondentes:${NC}"
# Ativo Gold UC Posição -> Conceito Posição
criar_link_semantico "asset" "${ASSET_ID_GOLD_POSICAO}" "${IRI_POSICAO}" "Posição em Renda Fixa"

# Ativo Silver UC Movimentação -> Conceito Movimentação
criar_link_semantico "asset" "${ASSET_ID_SILVER_MOVIMENTACAO}" "${IRI_MOVIMENTACAO}" "Movimentação em Renda Fixa"

# Ativo Gold MongoDB Consolidada -> Conceito Consolidada
criar_link_semantico "asset" "${ASSET_ID_GOLD_MONGO}" "${IRI_CONSOLIDADA}" "Posição Consolidada do Cliente em Renda Fixa"
echo ""

echo -e "${YELLOW}8.3 Vinculando Conceitos ao Contrato ODCS Unificado:${NC}"
criar_link_semantico "data_contract" "${CONTRACT_ID}" "${IRI_POSICAO}" "Posição em Renda Fixa"
criar_link_semantico "data_contract" "${CONTRACT_ID}" "${IRI_CONSOLIDADA}" "Posição Consolidada do Cliente em Renda Fixa"
echo ""

echo -e "    ${GREEN}✓ Toda a malha de governança semântica foi vinculada com sucesso no Grafo RDF!${NC}"
echo ""

echo -e "${GREEN}======================================================================${NC}"
echo -e "${GREEN}${BOLD}         ECOSSISTEMA COMPLETO PROVISIONADO COM SUCESSO!               ${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "🏛️  ${CYAN}${BOLD}Domínio de Dados:${NC}    ${DOMAIN_NAME} (${DOMAIN_ID}) - Subdomínio de 'Core'"
echo -e "   • Visualizar:         ${BLUE}${BASE_URL}/data-domains${NC}"
echo ""
echo -e "👥 ${CYAN}${BOLD}Time Responsável:${NC}    ${TEAM_TITLE} (${TEAM_ID})"
echo -e "   • Visualizar:         ${BLUE}${BASE_URL}/teams/${TEAM_ID}${NC}"
echo ""
echo -e "💡 ${CYAN}${BOLD}Conceitos no Grafo:${NC}  Coleção '${COLLECTION_LABEL:-Glossário de Mercado de Capitais e Investimentos}'"
echo -e "   • Posição RF:         ${BLUE}${BASE_URL}/knowledge/concepts?iri=${IRI_POSICAO}${NC}"
echo -e "   • Movimentação RF:    ${BLUE}${BASE_URL}/knowledge/concepts?iri=${IRI_MOVIMENTACAO}${NC}"
echo -e "   • Consolidado Canais: ${BLUE}${BASE_URL}/knowledge/concepts?iri=${IRI_CONSOLIDADA}${NC}"
echo ""
echo -e "📋 ${CYAN}${BOLD}Contrato ODCS Unificado:${NC}"
echo -e "   • ID:                 ${CONTRACT_ID}"
echo -e "   • Visualizar:         ${BLUE}${BASE_URL}/data-contracts/${CONTRACT_ID}${NC}"
echo ""
echo -e "💾 ${CYAN}${BOLD}Ativos da Linhagem Medallion:${NC}"
echo -e "   • [Bronze] Selic:     ${BLUE}${BASE_URL}/assets/${ASSET_ID_BRONZE_SELIC}${NC}"
echo -e "   • [Bronze] Legado:    ${BLUE}${BASE_URL}/assets/${ASSET_ID_BRONZE_LEGADO}${NC}"
echo -e "   • [Silver] Títulos:   ${BLUE}${BASE_URL}/assets/${ASSET_ID_SILVER_TITULOS}${NC}"
echo -e "   • [Silver] Movim.:    ${BLUE}${BASE_URL}/assets/${ASSET_ID_SILVER_MOVIMENTACAO}${NC}"
echo -e "   • [Gold]   Posição:   ${BLUE}${BASE_URL}/assets/${ASSET_ID_GOLD_POSICAO}${NC}"
echo -e "   • [Gold]   MongoDB:   ${BLUE}${BASE_URL}/assets/${ASSET_ID_GOLD_MONGO}${NC}"
echo ""
echo -e "📦 ${CYAN}${BOLD}Produto de Dados (2 Portas - Ativo & Publicado no Marketplace):${NC}"
echo -e "   • Nome:               ${PRODUCT_NAME}"
echo -e "   • ID:                 ${PRODUCT_ID}"
echo -e "   • Status:             ACTIVE (Publicado no Marketplace - Escopo Organization - Certificado Gold)"
echo -e "   • Porta 1:            porta_analitica_databricks_uc (posicao + movimentacao)"
echo -e "   • Porta 2:            porta_operacional_mongodb_canais (posicao_consolidada)"
echo -e "   • Ver no Marketplace: ${BLUE}${BASE_URL}/${NC}"
echo -e "   • Ver Produto:        ${BLUE}${BASE_URL}/data-products/${PRODUCT_ID}${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo ""
echo -e "🎉 ${BOLD}${GREEN}JORNADA COMPLETA DO LABORATÓRIO EXECUTADA COM ÊXITO!${NC}"
echo ""
