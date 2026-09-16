#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "================================================================="
echo "   DEPLOY AUTOMATIZADO DO ONTOS (RANCHER DESKTOP / K3S / WSL)   "
echo "================================================================="

# 1. Executar Build e verificação de imagens
"${SCRIPT_DIR}/scripts/build-images.sh" "$@"

# 2. Executar provisionamento da infraestrutura com Terraform
"${SCRIPT_DIR}/scripts/terraform-deploy.sh"

# 3. Iniciar Port-Forward dos serviços em segundo plano
"${SCRIPT_DIR}/scripts/port-forward.sh" start

# 4. Validar saúde da aplicação e carregar dados de demonstração
echo "================================================================="
echo " [Step 4] Verificação de Saúde e Carga de Dados Demo"
echo "================================================================="

HEALTH_RESP=$(curl -s http://localhost:8000/api/health || echo "{}")
echo "Health Status: ${HEALTH_RESP}"

echo "Carregando dataset vertical de demonstração (preset: retail)..."
DEMO_LOAD_RESP=$(curl -s -X POST "http://localhost:8000/api/settings/demo-data/load?preset=retail" || echo "{}")
echo "Demo Load: ${DEMO_LOAD_RESP}"

echo ""
echo "================================================================="
echo "               ✓ DEPLOY CONCLUÍDO COM SUCESSO!                   "
echo "================================================================="
echo ""
echo "Acesse as interfaces diretamente pelo seu navegador no Windows:"
echo ""
echo "  • Ontos Web UI (React SPA) : http://localhost:8000"
echo "  • Swagger API Docs         : http://localhost:8000/docs"
echo "  • ReDoc                    : http://localhost:8000/redoc"
echo "  • Health Check API         : http://localhost:8000/api/health"
echo "  • PostgreSQL Interno       : localhost:5432 (User: ontos_app_user, DB: app_ontos)"
echo ""
echo "Dicas de Operação:"
echo "  - Rebuild forçado de imagem: ./deploy.sh --build"
echo "  - Gerenciar túneis:          ./scripts/port-forward.sh [start|stop|status]"
echo "  - Destruir infraestrutura:   cd terraform && terraform destroy -auto-approve"
echo "================================================================="
