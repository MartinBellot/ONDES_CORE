#!/bin/sh
# ============================================================
#  Ondes Backend — Docker Entrypoint
#  Waits for PostgreSQL, then migrates, collectstatic, starts Daphne
# ============================================================
set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Ondes Backend — Starting production server"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Créer les répertoires nécessaires
mkdir -p /app/logs /app/staticfiles /app/media

# ----------------------------------------------------------
# 1. Wait for PostgreSQL to be ready
# ----------------------------------------------------------
echo "[1/4] Waiting for PostgreSQL..."
until python -c "
import sys, os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ondes_backend.settings')
import django; django.setup()
from django.db import connection
connection.ensure_connection()
print('PostgreSQL is ready.')
" 2>/dev/null; do
  echo "  → PostgreSQL not ready yet, retrying in 2s..."
  sleep 2
done

# ----------------------------------------------------------
# 2. Apply migrations
# ----------------------------------------------------------
echo "[2/4] Applying database migrations..."
python manage.py migrate --no-input

# ----------------------------------------------------------
# 3. Collect static files
# ----------------------------------------------------------
echo "[3/4] Collecting static files..."
python manage.py collectstatic --no-input --clear

# ----------------------------------------------------------
# 4. Start Daphne (ASGI — handles HTTP + WebSockets)
# ----------------------------------------------------------
echo "[4/4] Starting Daphne on 0.0.0.0:8000..."
exec daphne \
  -b 0.0.0.0 \
  -p 8000 \
  --proxy-headers \
  ondes_backend.asgi:application
