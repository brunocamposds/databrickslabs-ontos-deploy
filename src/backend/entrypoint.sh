#!/usr/bin/env bash
set -e

echo "=== Ontos Container Entrypoint ==="
echo "Initializing database schema and migrations..."

python -c "
import sys
from src.common.database import init_db
try:
    init_db()
    print('✓ Database initialization successful.')
except Exception as e:
    print(f'Warning: init_db encountered: {e}', file=sys.stderr)
"

echo "=== Starting Ontos Application (Uvicorn) ==="
exec uvicorn src.app:app --host 0.0.0.0 --port 8000
