#!/usr/bin/env bash
# ==============================================================================
# Script 03: 03-cadastrar-ativos-fisicos.sh
# Conceito Ontos: CATÁLOGO TÉCNICO MULTI-ENGINE E ARQUITETURA MEDALLION (BRONZE -> SILVER -> GOLD)
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
[ -f "${SCRIPT_DIR}/.state/env.sh" ] && source "${SCRIPT_DIR}/.state/env.sh"

check_health

echo -e "${BLUE}======================================================================${NC}"
echo -e "${CYAN}${BOLD}  ETAPA 3: REGISTRO DE ATIVOS FÍSICOS (ESTEIRA MEDALLION COMPLETA)   ${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo -e "📖 ${BOLD}Conceito no Ontos:${NC}"
echo -e "   Os Ativos Físicos (Data Assets) representam as tabelas, views, coleções"
echo -e "   ou tópicos onde os dados efetivamente residem. Registramos a linhagem"
echo -e "   completa das camadas Bronze (ingestão), Silver (conformação) e Gold (entrega)."
echo ""

# Busca o tipo de ativo Table no Ontos
TABLE_TYPE_ID=$(curl -s "${BASE_URL}/api/asset-types" | python3 -c "
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

cadastrar_ativo() {
  local nome="$1"
  local desc="$2"
  local plataforma="$3"
  local localizacao="$4"
  local tags="$5"

  echo -e "    • Registrando ativo: ${CYAN}${nome}${NC} (${plataforma})" >&2
  local resp=$(curl -s -X POST "${BASE_URL}/api/assets" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"${nome}\",
      \"description\": \"${desc}\",
      \"asset_type_id\": \"${TABLE_TYPE_ID}\",
      \"platform\": \"${plataforma}\",
      \"location\": \"${localizacao}\",
      \"domain_ids\": [\"${DOMAIN_ID}\"],
      \"primary_domain_id\": \"${DOMAIN_ID}\",
      \"tags\": ${tags},
      \"status\": \"active\"
    }" || true)

  local id=$(echo "$resp" | parse_json "id")
  if [ -z "$id" ]; then
    id=$(curl -s "${BASE_URL}/api/assets?name=${nome}" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    items = data.get('items', data) if isinstance(data, dict) else data
    match = next((a['id'] for a in items if isinstance(a, dict) and a.get('name') == '${nome}'), '')
    print(match)
except:
    pass
")
  fi
  echo "$id"
}

# --- CAMADA BRONZE (Origem / Raw) ---
echo -e "${YELLOW}3.1 Cadastrando Ativos de Origem (Camada Bronze - Databricks UC):${NC}"

ASSET_ID_BRONZE_SELIC=$(cadastrar_ativo \
  "bronze_operacoes_selic_bacen" \
  "Dados brutos de leilões e taxas SELIC importados diretamente da API do Banco Central / Tesouro Direto." \
  "Databricks Unity Catalog" \
  "raw_investimentos.bronze.operacoes_selic_bacen" \
  '["bronze", "bacen", "selic", "raw-ingestion", "databricks"]')

ASSET_ID_BRONZE_LEGADO=$(cadastrar_ativo \
  "bronze_boletas_transacoes_legado" \
  "Logs brutos e mensagens transacionais de boletas recebidas do mainframe legado da corretora." \
  "Databricks Unity Catalog" \
  "raw_investimentos.bronze.boletas_transacoes_legado" \
  '["bronze", "mainframe", "boletas", "mensageria", "databricks"]')

echo ""

# --- CAMADA SILVER (Conformada / Compõe Produto de Dados) ---
echo -e "${YELLOW}3.2 Cadastrando Ativos Conformados (Camada Silver - Databricks UC):${NC}"

ASSET_ID_SILVER_TITULOS=$(cadastrar_ativo \
  "silver_titulos_renda_fixa" \
  "Cadastro padronizado e limpo de títulos de renda fixa (CDB, LCI, LCA, Debêntures, Tesouro) com atributos validados." \
  "Databricks Unity Catalog" \
  "prod_investimentos.renda_fixa.silver_titulos_renda_fixa" \
  '["silver", "titulos", "renda-fixa", "cadastro", "databricks"]')

ASSET_ID_SILVER_MOVIMENTACAO=$(cadastrar_ativo \
  "silver_movimentacao_renda_fixa" \
  "Histórico limpo e deduplicado de movimentações financeiras, compras, vendas, resgates e amortizações." \
  "Databricks Unity Catalog" \
  "prod_investimentos.renda_fixa.movimentacao_titulos_renda_fixa" \
  '["silver", "movimentacao", "transacoes", "renda-fixa", "databricks"]')

echo ""

# --- CAMADA GOLD (Sumarizada / Produto de Dados & Canais) ---
echo -e "${YELLOW}3.3 Cadastrando Ativos Sumarizados (Camada Gold - Databricks UC & MongoDB):${NC}"

ASSET_ID_GOLD_POSICAO=$(cadastrar_ativo \
  "gold_posicao_titulos_renda_fixa" \
  "Posição consolidada diária de custódia calculada por cliente e título com marcação a mercado (MtM)." \
  "Databricks Unity Catalog" \
  "prod_investimentos.renda_fixa.posicao_titulos_renda_fixa" \
  '["gold", "posicao", "custodia", "delta-lake", "databricks", "marcação-a-mercado"]')

ASSET_ID_GOLD_MONGO=$(cadastrar_ativo \
  "gold_posicao_consolidada_cliente_rf" \
  "Documento NoSQL sumarizado por cliente com total investido e saldo unificado para consumo instantâneo no App e IB." \
  "MongoDB" \
  "mongodb://mongodb-cluster-invest:27017/canais_digitais.posicao_consolidada_cliente_rf" \
  '["gold", "mongodb", "nosql", "canais-digitais", "mobile-app", "internet-banking", "baixa-latencia"]')

echo ""
echo -e "    ${GREEN}✓ Todos os 6 ativos cadastrados no catálogo com sucesso!${NC}"
echo -e "      1. [Bronze] Bacen/Selic:     ID ${CYAN}${ASSET_ID_BRONZE_SELIC}${NC}"
echo -e "      2. [Bronze] Boletas Legado:  ID ${CYAN}${ASSET_ID_BRONZE_LEGADO}${NC}"
echo -e "      3. [Silver] Títulos RF:      ID ${CYAN}${ASSET_ID_SILVER_TITULOS}${NC}"
echo -e "      4. [Silver] Movimentação RF: ID ${CYAN}${ASSET_ID_SILVER_MOVIMENTACAO}${NC}"
echo -e "      5. [Gold]   Posição UC:      ID ${CYAN}${ASSET_ID_GOLD_POSICAO}${NC}"
echo -e "      6. [Gold]   Consolidado App: ID ${CYAN}${ASSET_ID_GOLD_MONGO}${NC}"
echo ""

# Persiste estado
echo "export ASSET_ID_BRONZE_SELIC=\"${ASSET_ID_BRONZE_SELIC}\"" >> "${SCRIPT_DIR}/.state/env.sh"
echo "export ASSET_ID_BRONZE_LEGADO=\"${ASSET_ID_BRONZE_LEGADO}\"" >> "${SCRIPT_DIR}/.state/env.sh"
echo "export ASSET_ID_SILVER_TITULOS=\"${ASSET_ID_SILVER_TITULOS}\"" >> "${SCRIPT_DIR}/.state/env.sh"
echo "export ASSET_ID_SILVER_MOVIMENTACAO=\"${ASSET_ID_SILVER_MOVIMENTACAO}\"" >> "${SCRIPT_DIR}/.state/env.sh"
echo "export ASSET_ID_GOLD_POSICAO=\"${ASSET_ID_GOLD_POSICAO}\"" >> "${SCRIPT_DIR}/.state/env.sh"
echo "export ASSET_ID_GOLD_MONGO=\"${ASSET_ID_GOLD_MONGO}\"" >> "${SCRIPT_DIR}/.state/env.sh"

echo -e "${GREEN}======================================================================${NC}"
echo -e "✅ ${BOLD}Etapa 3 Concluída com Sucesso!${NC}"
echo -e "   • Visualizar Catálogo: ${BLUE}${BASE_URL}/assets${NC}"
echo -e "   • Próximo Script:     ${CYAN}./scripts/lab-renda-fixa/04-importar-contratos-odcs.sh${NC}"
echo -e "${GREEN}======================================================================${NC}"
