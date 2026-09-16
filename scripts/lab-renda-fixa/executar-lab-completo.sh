#!/usr/bin/env bash
# ==============================================================================
# Script: executar-lab-completo.sh
# Descrição: Orquestrador mestre do laboratório Ontos.
#            Executa os 8 passos sequencialmente, com explicações didáticas.
# Uso:
#   ./scripts/lab-renda-fixa/executar-lab-completo.sh
#   ./scripts/lab-renda-fixa/executar-lab-completo.sh --pausar  (pausa após cada etapa)
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

PAUSAR="${1:-}"

echo -e "${BLUE}======================================================================${NC}"
echo -e "${CYAN}${BOLD}       LABORATÓRIO ONTOS - JORNADA COMPLETA DE GOVERNANÇA E DATA MESH ${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo -e "Este exercício demonstra a arquitetura do Ontos partindo do zero,"
echo -e "culminando em um Produto de Dados com duas portas de entrega, linhagem"
echo -e "Medallion completa e publicação ativa no Marketplace:"
echo -e "  1. Domínio & Time (Vinculado ao Core corporativo)"
echo -e "  2. Grafo Semântico (Glossário & Conceitos de Negócio)"
echo -e "  3. Ativos da Esteira Medallion (Bronze ➔ Silver ➔ Gold ➔ MongoDB)"
echo -e "  4. Contrato ODCS Unificado (1 Acordo de Qualidade Governa Múltiplas Saídas)"
echo -e "  5. Produto de Dados ODPS Multi-Portas (Databricks UC & MongoDB)"
echo -e "  6. Construção da Linhagem de Dados (Entity Relationships no Grafo)"
echo -e "  7. Ativação, Certificação Gold e Publicação no Marketplace"
echo -e "  8. Amarração Semântica Final no Grafo RDF"
echo ""

pausar_se_solicitado() {
  if [ "$PAUSAR" = "--pausar" ] || [ "$PAUSAR" = "-p" ]; then
    echo ""
    read -rp "Pressione [ENTER] para prosseguir para a próxima etapa..."
    echo ""
  fi
}

# Etapa 1: Domínio e Time
bash "${SCRIPT_DIR}/01-criar-dominio-e-time.sh"
pausar_se_solicitado

# Etapa 2: Glossário e Conceitos
bash "${SCRIPT_DIR}/02-criar-glossario-e-conceitos.sh"
pausar_se_solicitado

# Etapa 3: Ativos Físicos Medallion
bash "${SCRIPT_DIR}/03-cadastrar-ativos-fisicos.sh"
pausar_se_solicitado

# Etapa 4: Contrato ODCS Unificado
bash "${SCRIPT_DIR}/04-importar-contratos-odcs.sh"
pausar_se_solicitado

# Etapa 5: Produto de Dados Multi-Portas
bash "${SCRIPT_DIR}/05-cadastrar-produto-odps-multi-portas.sh"
pausar_se_solicitado

# Etapa 6: Linhagem de Dados (Bronze -> Silver -> Gold -> Consumo)
bash "${SCRIPT_DIR}/06-construir-linhagem-medallion.sh"
pausar_se_solicitado

# Etapa 7: Ativação e Publicação no Marketplace
bash "${SCRIPT_DIR}/07-ativar-e-publicar-marketplace.sh"
pausar_se_solicitado

# Etapa 8: Vínculos Semânticos e Fechamento
bash "${SCRIPT_DIR}/08-vincular-grafo-semantico.sh"

echo ""
echo -e "${GREEN}${BOLD}🎉 JORNADA COMPLETA DO LABORATÓRIO EXECUTADA COM ÊXITO!${NC}"
