#!/usr/bin/env bash
# ==============================================================================
# Script 04: 04-importar-contratos-odcs.sh
# Conceito Ontos: CONTRATO DE DADOS UNIFICADO (OPEN DATA CONTRACT STANDARD - ODCS v3.1.0)
#                (1 Contrato de Negócio Governa Múltiplas Entregas/Servers)
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
[ -f "${SCRIPT_DIR}/.state/env.sh" ] && source "${SCRIPT_DIR}/.state/env.sh"

check_health

echo -e "${BLUE}======================================================================${NC}"
echo -e "${CYAN}${BOLD}  ETAPA 4: IMPORTAÇÃO DO CONTRATO DE DADOS UNIFICADO (ODCS v3.1.0)   ${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo -e "📖 ${BOLD}Conceito no Ontos:${NC}"
echo -e "   O ${CYAN}Data Contract (ODCS v3.1.0)${NC} é o acordo formal de negócio e qualidade."
echo -e "   ${BOLD}Não é necessário um contrato por banco físico:${NC} um único contrato corporativo"
echo -e "   define os schemas e regras de qualidade para o domínio, mapeando na seção"
echo -e "   'servers' tanto a porta analítica (Databricks UC) quanto a operacional (MongoDB)."
echo ""

ARQ_CONTRATO_UNIFICADO="${SCRIPT_DIR}/contratos/contrato-odcs-renda-fixa-unificado.json"

importar_e_ativar_contrato() {
  local arquivo="$1"
  local rotulo="$2"

  echo -e "${YELLOW}Importando ${rotulo}...${NC}" >&2
  echo -e "    Arquivo:  ${arquivo}" >&2
  echo -e "    Endpoint: POST ${BASE_URL}/api/data-contracts/odcs/import" >&2

  local resp=$(curl -s -X POST "${BASE_URL}/api/data-contracts/odcs/import" \
    -H "Content-Type: application/json" \
    -d @"${arquivo}")

  local cid=$(echo "$resp" | parse_json "id")
  local cname=$(echo "$resp" | parse_json "name")

  if [ -z "$cid" ]; then
    echo -e "    ${RED}Erro ao importar contrato:${NC} ${resp}" >&2
    exit 1
  fi

  echo -e "    ${GREEN}✓ Contrato importado:${NC} ID: ${CYAN}${cid}${NC} (${cname})" >&2
  echo -e "    Garantindo ativação do ciclo de vida (/change-status)..." >&2

  curl -s -X POST "${BASE_URL}/api/data-contracts/${cid}/change-status" \
    -H "Content-Type: application/json" \
    -d '{"new_status": "active"}' >/dev/null 2>&1 || true

  echo "$cid"
}

# Importa o Contrato Unificado
echo -e "${YELLOW}4.1 Contrato Unificado de Renda Fixa (Databricks UC & MongoDB):${NC}"
CONTRACT_ID=$(importar_e_ativar_contrato "$ARQ_CONTRATO_UNIFICADO" "Contrato ODCS Unificado de Renda Fixa")
echo ""

# Persiste estado
echo "export CONTRACT_ID=\"${CONTRACT_ID}\"" >> "${SCRIPT_DIR}/.state/env.sh"
echo "export CONTRACT_ID_DATABRICKS=\"${CONTRACT_ID}\"" >> "${SCRIPT_DIR}/.state/env.sh"
echo "export CONTRACT_ID_MONGODB=\"${CONTRACT_ID}\"" >> "${SCRIPT_DIR}/.state/env.sh"

echo -e "${GREEN}======================================================================${NC}"
echo -e "✅ ${BOLD}Etapa 4 Concluída com Sucesso!${NC}"
echo -e "   • Contrato Unificado: ${BLUE}${BASE_URL}/data-contracts/${CONTRACT_ID}${NC}"
echo -e "   • Próximo Script:     ${CYAN}./scripts/lab-renda-fixa/05-cadastrar-produto-odps-multi-portas.sh${NC}"
echo -e "${GREEN}======================================================================${NC}"
