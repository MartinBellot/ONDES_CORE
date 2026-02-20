#!/bin/bash
# sync_local_db_to_vps.sh
# Synchronise la DB SQLite locale + les médias vers la production PostgreSQL sur le VPS.
#
# Usage:
#   ./sync_local_db_to_vps.sh            # DB + médias
#   ./sync_local_db_to_vps.sh --db-only  # DB uniquement
#   ./sync_local_db_to_vps.sh --media-only # Médias uniquement

set -e

# ──────────────────────────────────────────────────────────────────────────────
# Config
# ──────────────────────────────────────────────────────────────────────────────
VPS="root@72.62.28.63"
REMOTE_APP_DIR="/opt/ondes_api"
REMOTE_VOLUME="/var/lib/docker/volumes/ondes_api_media_files/_data"
CONTAINER="ondes_api"

LOCAL_API_DIR="$(cd "$(dirname "$0")/api" && pwd)"
LOCAL_MEDIA_DIR="$LOCAL_API_DIR/media"
LOCAL_VENV="$(cd "$(dirname "$0")" && pwd)/venv/bin/python"
DUMP_FILE="/tmp/ondes_dump_$(date +%Y%m%d_%H%M%S).json"

DB_ONLY=false
MEDIA_ONLY=false

# ──────────────────────────────────────────────────────────────────────────────
# Parse args
# ──────────────────────────────────────────────────────────────────────────────
for arg in "$@"; do
  case $arg in
    --db-only)    DB_ONLY=true ;;
    --media-only) MEDIA_ONLY=true ;;
    *) echo "Option inconnue: $arg" && exit 1 ;;
  esac
done

# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────
log()  { echo -e "\033[1;34m[$(date +%H:%M:%S)]\033[0m $*"; }
ok()   { echo -e "\033[1;32m  ✓ $*\033[0m"; }
warn() { echo -e "\033[1;33m  ⚠ $*\033[0m"; }
fail() { echo -e "\033[1;31m  ✗ $*\033[0m" && exit 1; }

confirm() {
  echo -e "\033[1;33m⚠️  ATTENTION : Cette opération va écraser les données de PRODUCTION !\033[0m"
  read -rp "  Continuer ? (oui/non) : " answer
  [[ "$answer" == "oui" ]] || { warn "Annulé."; exit 0; }
}

# ──────────────────────────────────────────────────────────────────────────────
# Checks
# ──────────────────────────────────────────────────────────────────────────────
log "Vérifications préalables..."
[[ -f "$LOCAL_VENV" ]]      || fail "virtualenv non trouvé: $LOCAL_VENV"
[[ -d "$LOCAL_API_DIR" ]]   || fail "Dossier api non trouvé: $LOCAL_API_DIR"
[[ -d "$LOCAL_MEDIA_DIR" ]] || fail "Dossier media non trouvé: $LOCAL_MEDIA_DIR"
command -v rsync &>/dev/null || fail "rsync non installé"
ssh -o BatchMode=yes -o ConnectTimeout=5 "$VPS" exit 2>/dev/null || \
  fail "Impossible de se connecter au VPS $VPS (clé SSH ?)"
ok "Connexion VPS OK"

# ──────────────────────────────────────────────────────────────────────────────
# DB migration
# ──────────────────────────────────────────────────────────────────────────────
sync_db() {
  log "Étape 1/4 — Export SQLite local → $DUMP_FILE"
  cd "$LOCAL_API_DIR"
  "$LOCAL_VENV" manage.py dumpdata \
    --exclude auth.permission \
    --exclude contenttypes \
    --natural-foreign \
    --natural-primary \
    --indent 2 \
    -o "$DUMP_FILE"
  local size
  size=$(du -sh "$DUMP_FILE" | cut -f1)
  ok "Dump créé : $DUMP_FILE ($size)"

  log "Étape 2/4 — Transfert vers le VPS..."
  scp "$DUMP_FILE" "$VPS:/tmp/ondes_dump.json"
  ok "Transfert OK"

  log "Étape 3/4 — Copie dans le container + flush + loaddata..."
  ssh "$VPS" "
    docker cp /tmp/ondes_dump.json $CONTAINER:/app/ondes_dump.json
    docker exec $CONTAINER python manage.py flush --no-input
    docker exec $CONTAINER python manage.py loaddata /app/ondes_dump.json
    docker exec $CONTAINER rm /app/ondes_dump.json
    rm /tmp/ondes_dump.json
  "
  ok "Base de données importée dans PostgreSQL"

  log "Étape 4/4 — Nettoyage local..."
  rm -f "$DUMP_FILE"
  ok "Nettoyage OK"
}

# ──────────────────────────────────────────────────────────────────────────────
# Media sync
# ──────────────────────────────────────────────────────────────────────────────
sync_media() {
  log "Sync médias → $VPS:$REMOTE_VOLUME"
  local count
  count=$(find "$LOCAL_MEDIA_DIR" -type f | wc -l | tr -d ' ')
  log "  $count fichiers à synchroniser..."

  rsync -avz --progress \
    "$LOCAL_MEDIA_DIR/" \
    "$VPS:$REMOTE_VOLUME/" \
    2>&1 | grep -E "^(sent|total|[^ ].*(jpg|png|mp4|gif|webp|json))" || true

  ok "Médias synchronisés"
}

# ──────────────────────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "╔════════════════════════════════════════╗"
echo "║     SYNC LOCAL → PRODUCTION (VPS)      ║"
echo "╚════════════════════════════════════════╝"
echo ""

if $MEDIA_ONLY; then
  confirm
  sync_media
elif $DB_ONLY; then
  confirm
  sync_db
else
  confirm
  sync_db
  sync_media
fi

echo ""
echo -e "\033[1;32m✅ Synchronisation terminée avec succès !\033[0m"
echo "   API : https://api.ondes.pro"
echo ""
