#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
IMAGE_TAG="ontos:lab"
FORCE_BUILD=false

for arg in "$@"; do
  if [[ "$arg" == "--build" ]]; then
    FORCE_BUILD=true
    break
  fi
done

echo "================================================================="
echo " [Step 1] Build & Verificação de Imagens Docker no WSL"
echo "================================================================="

# Verificar se o daemon do Docker está acessível
if ! docker info >/dev/null 2>&1; then
  echo "Erro: Não foi possível conectar ao daemon do Docker no WSL."
  echo "Certifique-se de que o Rancher Desktop está em execução."
  exit 1
fi

# Verificar existência da imagem no daemon local
IMAGE_EXISTS=false
if docker image inspect "${IMAGE_TAG}" >/dev/null 2>&1; then
  IMAGE_EXISTS=true
fi

if [[ "${FORCE_BUILD}" == true ]]; then
  echo "Flag '--build' fornecida. Reconstruindo a imagem '${IMAGE_TAG}'..."
elif [[ "${IMAGE_EXISTS}" == false ]]; then
  echo "Imagem '${IMAGE_TAG}' não encontrada no daemon do Docker. Realizando build inicial..."
else
  echo "✓ Imagem '${IMAGE_TAG}' já presente no daemon do Docker local."
  echo "  Reaproveitando imagem do cache (use '--build' para forçar reconstrução)."
  exit 0
fi

cd "${ROOT_DIR}"
echo "Construindo imagem '${IMAGE_TAG}' a partir do Dockerfile..."
docker build -t "${IMAGE_TAG}" -f Dockerfile .

echo "✓ Imagem '${IMAGE_TAG}' compilada e importada no daemon do Docker com sucesso!"
docker images "${IMAGE_TAG}" --format "table {{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}\t{{.CreatedAt}}"
