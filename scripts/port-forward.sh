#!/usr/bin/env bash
set -euo pipefail

PID_FILE="/tmp/ontos-port-forward.pid"
LOG_APP="/tmp/ontos-pf-app.log"
LOG_PG="/tmp/ontos-pf-postgres.log"

ACTION="${1:-start}"

stop_port_forward() {
  if [[ -f "${PID_FILE}" ]]; then
    echo "Encerrando instâncias anteriores de port-forward..."
    while IFS= read -r pid; do
      if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
        kill "${pid}" 2>/dev/null || true
      fi
    done < "${PID_FILE}"
    rm -f "${PID_FILE}"
  fi
  # Limpar quaisquer processos órfãos residuais
  pkill -f "port-forward -n ontos" 2>/dev/null || true
}

status_port_forward() {
  echo "Verificando status dos port-forwards..."
  if [[ -f "${PID_FILE}" ]]; then
    echo "PIDs registrados em ${PID_FILE}:"
    cat "${PID_FILE}"
    echo ""
  fi
  ps aux | grep "[p]ort-forward -n ontos" || echo "Nenhum port-forward ativo."
}

start_port_forward() {
  stop_port_forward

  echo "================================================================="
  echo " [Step 3] Iniciando Port-Forward em Segundo Plano"
  echo "================================================================="

  # Iniciar port-forward do Ontos App (8000:8000)
  echo "Iniciando túnel para o Ontos App (localhost:8000)..."
  nohup kubectl port-forward -n ontos svc/ontos-app 8000:8000 --address 0.0.0.0 > "${LOG_APP}" 2>&1 &
  PID_APP=$!

  # Iniciar port-forward do PostgreSQL (5432:5432)
  echo "Iniciando túnel para o PostgreSQL (localhost:5432)..."
  nohup kubectl port-forward -n ontos svc/postgres 5432:5432 --address 0.0.0.0 > "${LOG_PG}" 2>&1 &
  PID_PG=$!

  # Salvar PIDs
  echo "${PID_APP}" > "${PID_FILE}"
  echo "${PID_PG}" >> "${PID_FILE}"

  # Aguardar ativação das portas (até 15 segundos)
  echo "Aguardando portas ficarem ativas..."
  for i in {1..15}; do
    if curl -s http://localhost:8000/api/health >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done

  echo "✓ Port-forward ativo em segundo plano!"
  echo "  - Ontos Web UI & API : http://localhost:8000 (PID: ${PID_APP}, Log: ${LOG_APP})"
  echo "  - PostgreSQL         : localhost:5432 (PID: ${PID_PG}, Log: ${LOG_PG})"
  echo ""
  echo "Para parar os túneis a qualquer momento, execute:"
  echo "  ./scripts/port-forward.sh stop"
}

case "${ACTION}" in
  start)
    start_port_forward
    ;;
  stop)
    stop_port_forward
    echo "✓ Port-forwards encerrados."
    ;;
  status)
    status_port_forward
    ;;
  *)
    echo "Uso: $0 [start|stop|status]"
    exit 1
    ;;
esac
