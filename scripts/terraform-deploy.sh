#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TERRAFORM_DIR="${ROOT_DIR}/terraform"

echo "================================================================="
echo " [Step 2] Provisionamento da Infraestrutura com Terraform"
echo "================================================================="

# Verificar se o Terraform está instalado
if ! command -v terraform >/dev/null 2>&1; then
  echo "Erro: O comando 'terraform' não foi encontrado no PATH do WSL."
  exit 1
fi

# Verificar se o kubectl está funcional
if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "Erro: O cluster Kubernetes (k3s) do Rancher Desktop não está acessível via kubectl."
  exit 1
fi

cd "${TERRAFORM_DIR}"

echo "Inicializando Terraform..."
terraform init -input=false

echo "Aplicando configuração da infraestrutura no Kubernetes..."
terraform apply -auto-approve -input=false

echo "Reiniciando ontos-app para garantir que a imagem mais recente seja carregada..."
kubectl rollout restart deployment/ontos-app -n ontos

echo "Aguardando prontidão dos serviços no cluster..."
echo "-> Aguardando pod do PostgreSQL..."
kubectl rollout status deployment/postgres -n ontos --timeout=120s

echo "-> Aguardando pod do Ontos Application..."
kubectl rollout status deployment/ontos-app -n ontos --timeout=300s

echo "✓ Infraestrutura provisionada e validada pelo Terraform com sucesso!"
terraform output
