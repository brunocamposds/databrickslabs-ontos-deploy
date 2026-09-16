#!/usr/bin/env bash
# ==============================================================================
# config.sh - Configurações comuns e helpers para o Laboratório Ontos
# ==============================================================================
export BASE_URL="${ONTOS_API_URL:-http://localhost:8000}"

# Cores para formatação de console
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export BLUE='\033[0;34m'
export YELLOW='\033[1;33m'
export CYAN='\033[0;36m'
export MAGENTA='\033[0;35m'
export BOLD='\033[1m'
export NC='\033[0m'

# Helper de parsing JSON via stdin (seguro para qualquer tamanho e caracteres)
parse_json() {
  local expr="$1"
  python3 -c "
import json, sys
try:
    raw = sys.stdin.read()
    if not raw.strip():
        print('')
        sys.exit(0)
    data = json.loads(raw)
    keys = '''$expr'''.split('.')
    cur = data
    for k in keys:
        if isinstance(cur, dict):
            cur = cur.get(k)
        elif isinstance(cur, list) and k.isdigit():
            cur = cur[int(k)]
        else:
            cur = None
            break
    print(cur if cur is not None else '')
except Exception:
    print('')
"
}

# Verificador de saúde da API
check_health() {
  if ! curl -s -f "${BASE_URL}/api/health" >/dev/null 2>&1; then
    echo -e "${RED}Erro: Não foi possível conectar ao Ontos em ${BASE_URL}.${NC}"
    echo -e "Certifique-se de que o port-forward está ativo:"
    echo -e "  ./scripts/port-forward.sh"
    exit 1
  fi
}
