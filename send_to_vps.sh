#!/usr/bin/env bash
# ============================================================
#  send_to_vps.sh — Déploiement de l'API Ondes sur le VPS
#
#  Utilisation :
#    ./send_to_vps.sh           → déploiement standard (mise à jour)
#    ./send_to_vps.sh --init    → premier déploiement (SSL Let's Encrypt)
#    ./send_to_vps.sh --logs    → afficher les logs en direct
#    ./send_to_vps.sh --status  → état des containers
#    ./send_to_vps.sh --help    → aide
#
#  Prérequis :
#    - Clé SSH configurée pour root@72.62.28.63
#    - Docker + Docker Compose installés sur le VPS
#    - .env.prod présent dans api/ (copier .env.prod.example)
#    - Enregistrement DNS : api.ondes.pro → 72.62.28.63
# ============================================================
set -euo pipefail

# ── Configuration ────────────────────────────────────────
VPS_HOST="root@72.62.28.63"
VPS_APP_DIR="/opt/ondes_api"
LOCAL_API_DIR="$(cd "$(dirname "$0")/api" && pwd)"
DOMAIN="api.ondes.pro"
CERTBOT_EMAIL="martin.bellot.off@gmail.com"   # ← adapte si besoin

# ── Couleurs ─────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Helpers ───────────────────────────────────────────────
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
step()    { echo -e "\n${BOLD}${CYAN}━━━  $*  ━━━${NC}"; }

banner() {
  echo -e "${BOLD}${CYAN}"
  echo "  ╔═══════════════════════════════════════════╗"
  echo "  ║     Ondes API — Déploiement VPS           ║"
  echo "  ║     ${DOMAIN}                  ║"
  echo "  ╚═══════════════════════════════════════════╝"
  echo -e "${NC}"
}

usage() {
  echo "Usage: $(basename "$0") [--init|--logs|--status|--help]"
  echo ""
  echo "  (aucun arg)   Mise à jour du code + restart des containers"
  echo "  --init        Premier déploiement (setup SSL Let's Encrypt)"
  echo "  --logs        Afficher les logs en temps réel"
  echo "  --status      État des containers"
  echo "  --help        Afficher cette aide"
}

# ── Parsing des arguments ─────────────────────────────────
MODE="deploy"
case "${1:-}" in
  --init)   MODE="init"   ;;
  --logs)   MODE="logs"   ;;
  --status) MODE="status" ;;
  --help|-h) usage; exit 0 ;;
  "")       MODE="deploy" ;;
  *) error "Argument inconnu: $1. Utilise --help." ;;
esac

# ── Vérifications pré-déploiement ─────────────────────────
preflight_checks() {
  step "Vérifications pré-déploiement"

  # .env.prod présent ?
  if [[ ! -f "$LOCAL_API_DIR/.env.prod" ]]; then
    error ".env.prod introuvable dans api/\n  → Copie api/.env.prod.example en api/.env.prod et remplis les valeurs."
  fi
  success ".env.prod trouvé"

  # SSH accessible ?
  if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$VPS_HOST" "echo ok" &>/dev/null; then
    error "Impossible de se connecter à $VPS_HOST via SSH.\n  → Vérifie que ta clé SSH est configurée pour ce serveur."
  fi
  success "Connexion SSH OK → $VPS_HOST"

  # rsync disponible ?
  command -v rsync &>/dev/null || error "rsync n'est pas installé sur cette machine."
  success "rsync disponible"
}

# ── Synchronisation du code ─────────────────────────────
sync_code() {
  step "Synchronisation du code → $VPS_HOST:$VPS_APP_DIR"

  ssh "$VPS_HOST" "mkdir -p $VPS_APP_DIR"

  rsync -avz --progress \
    --delete \
    --exclude='.env' \
    --exclude='.env.prod' \
    --exclude='__pycache__/' \
    --exclude='*.pyc' \
    --exclude='*.pyo' \
    --exclude='.git/' \
    --exclude='db.sqlite3' \
    --exclude='media/' \
    --exclude='staticfiles/' \
    --exclude='ondes.log' \
    "$LOCAL_API_DIR/" "$VPS_HOST:$VPS_APP_DIR/"

  # Copier .env.prod séparément (pas inclus dans le rsync global)
  info "Envoi de .env.prod..."
  scp "$LOCAL_API_DIR/.env.prod" "$VPS_HOST:$VPS_APP_DIR/.env.prod"
  # Sécuriser les permissions du fichier .env.prod
  ssh "$VPS_HOST" "chmod 600 $VPS_APP_DIR/.env.prod"

  success "Code synchronisé"
}

# ── Vérification Docker sur VPS ───────────────────────────
ensure_docker() {
  info "Vérification de Docker sur le VPS..."
  if ! ssh "$VPS_HOST" "command -v docker &>/dev/null && docker compose version &>/dev/null"; then
    warn "Docker ou Docker Compose absent. Installation en cours..."
    ssh "$VPS_HOST" "bash -s" << 'REMOTE_EOF'
      apt-get update -qq
      apt-get install -y -qq ca-certificates curl gnupg lsb-release
      install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      chmod a+r /etc/apt/keyrings/docker.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
        > /etc/apt/sources.list.d/docker.list
      apt-get update -qq
      apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      systemctl enable docker && systemctl start docker
REMOTE_EOF
    success "Docker installé sur le VPS"
  else
    success "Docker disponible sur le VPS"
  fi
}

# ── Premier déploiement (SSL) ─────────────────────────────
init_ssl() {
  step "Initialisation SSL Let's Encrypt pour $DOMAIN"

  # Vérifier que le DNS est bien configuré avant de tenter certbot
  info "Vérification DNS : $DOMAIN → 72.62.28.63 ?"
  local dns_ip
  dns_ip=$(dig +short "$DOMAIN" @8.8.8.8 2>/dev/null | tail -1)
  if [[ "$dns_ip" != "72.62.28.63" ]]; then
    echo ""
    error "Le DNS de $DOMAIN ne pointe pas encore vers le VPS.\n\
  → Résolu : $dns_ip (attendu : 72.62.28.63)\n\
  → Crée l'enregistrement A sur Hostinger : $DOMAIN → 72.62.28.63\n\
  → Attends 5‑15 min la propagation DNS puis relance : ./send_to_vps.sh --init"
  fi
  success "DNS OK : $DOMAIN → $dns_ip"

  info "Nettoyage des containers existants éventuels..."
  ssh "$VPS_HOST" "
    cd $VPS_APP_DIR
    docker compose --env-file .env.prod -f docker-compose.prod.yml down --remove-orphans 2>/dev/null || true
    for name in ondes_api ondes_db ondes_redis ondes_nginx ondes_certbot; do
      docker rm -f \$name 2>/dev/null || true
    done
  "

  local DC="docker compose --env-file .env.prod -f docker-compose.prod.yml"

  info "Vérification du certificat SSL..."
  if ssh "$VPS_HOST" "certbot certificates 2>/dev/null | grep -q 'api.ondes.pro\|ondes.pro'" 2>/dev/null; then
    success "Certificat Let's Encrypt déjà valide sur le VPS — étape certbot ignorée."
  else
    info "Démarrage de nginx avec config HTTP-only (pour ACME challenge)..."
    ssh "$VPS_HOST" "
      cd $VPS_APP_DIR
      cp nginx/ondes.conf nginx/ondes.conf.ssl
      cp nginx/ondes-init.conf nginx/ondes.conf
      docker compose --env-file .env.prod -f docker-compose.prod.yml up -d --no-deps nginx certbot
      echo 'Attente démarrage nginx (5s)...'
      sleep 5
    "

    info "Obtention du certificat SSL pour $DOMAIN..."
    ssh "$VPS_HOST" "
      cd $VPS_APP_DIR
      docker compose --env-file .env.prod -f docker-compose.prod.yml run --rm \\
        certbot \\
        certonly \\
        --webroot \\
        --webroot-path=/var/www/certbot \\
        --email $CERTBOT_EMAIL \\
        --agree-tos \\
        --no-eff-email \\
        -d $DOMAIN
    "
    success "Certificat SSL obtenu !"

    info "Restauration de la configuration HTTPS..."
    ssh "$VPS_HOST" "
      cd $VPS_APP_DIR
      cp nginx/ondes.conf.ssl nginx/ondes.conf
    "
  fi

  # Configurer le renouvellement automatique (cron)
  info "Configuration du renouvellement automatique SSL (cron)..."
  ssh "$VPS_HOST" "
    apt-get install -y -qq cron 2>/dev/null || true
    cat > /etc/cron.d/ondes-certbot << CRON_EOF
0 3 * * * root certbot renew --quiet && cd $VPS_APP_DIR && docker compose --env-file .env.prod -f docker-compose.prod.yml exec nginx nginx -s reload
CRON_EOF
    chmod 644 /etc/cron.d/ondes-certbot
    systemctl enable cron 2>/dev/null || systemctl enable crond 2>/dev/null || true
    systemctl start cron 2>/dev/null || systemctl start crond 2>/dev/null || true
  "
  success "Renouvellement SSL automatique configuré (/etc/cron.d/ondes-certbot, 3h00 quotidien)"
}

# ── Build + lancement des containers ─────────────────────
deploy_containers() {
  step "Build et démarrage des containers"

  ssh "$VPS_HOST" "
    cd $VPS_APP_DIR
    echo '→ Pull des images de base...'
    docker compose --env-file .env.prod -f docker-compose.prod.yml pull --ignore-buildable
    echo 'Build de image api...'
    docker compose --env-file .env.prod -f docker-compose.prod.yml build --no-cache api
    echo '→ Arrêt des anciens containers...'
    docker compose --env-file .env.prod -f docker-compose.prod.yml down --remove-orphans || true
    echo '→ Démarrage...'
    docker compose --env-file .env.prod -f docker-compose.prod.yml up -d
  "

  success "Containers démarrés"
}

# ── Attendre Daphne + vérification santé ─────────────────
health_check() {
  step "Vérification de santé"

  info "Attente du démarrage de l'API (max 60s)..."
  local attempts=0
  local max_attempts=12

  while [[ $attempts -lt $max_attempts ]]; do
    if ssh "$VPS_HOST" \
      "cd $VPS_APP_DIR && docker compose --env-file .env.prod -f docker-compose.prod.yml \
       exec -T api python -c \
       \"import urllib.request; urllib.request.urlopen('http://localhost:8000/admin/')\" \
       2>&1 | grep -qv 'Error'"; then
      success "API opérationnelle"
      break
    fi
    attempts=$((attempts + 1))
    info "  Tentative $attempts/$max_attempts — attente 5s..."
    sleep 5
  done

  if [[ $attempts -eq $max_attempts ]]; then
    warn "L'API n'a pas répondu dans les temps. Affichage des logs..."
    ssh "$VPS_HOST" "
      cd $VPS_APP_DIR
      docker compose --env-file .env.prod -f docker-compose.prod.yml logs --tail=50 api
    "
  fi

  # Test HTTPS (si SSL déjà configuré)
  if ssh "$VPS_HOST" "[ -d /etc/letsencrypt/live/$DOMAIN ]" 2>/dev/null; then
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
      --max-time 10 \
      "https://$DOMAIN/admin/" 2>/dev/null || echo "000")
    if [[ "$http_code" =~ ^(200|301|302)$ ]]; then
      success "HTTPS opérationnel → https://$DOMAIN (HTTP $http_code)"
    else
      warn "HTTPS a répondu HTTP $http_code — vérifie la config nginx"
    fi
  fi
}

# ── Nettoyage Docker (images orphelines) ─────────────────
cleanup_docker() {
  info "Nettoyage des images Docker inutilisées..."
  ssh "$VPS_HOST" "docker image prune -f --filter 'until=24h'" || true
}

# ── Afficher les logs ─────────────────────────────────────
show_logs() {
  step "Logs en direct — Ctrl+C pour quitter"
  ssh -t "$VPS_HOST" "
    cd $VPS_APP_DIR
    docker compose --env-file .env.prod -f docker-compose.prod.yml logs -f --tail=100
  "
}

# ── Afficher le statut ────────────────────────────────────
show_status() {
  step "État des containers Ondes"
  ssh "$VPS_HOST" "
    cd $VPS_APP_DIR
    docker compose --env-file .env.prod -f docker-compose.prod.yml ps
    echo ''
    echo 'Utilisation des ressources :'
    docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}' \
      ondes_api ondes_db ondes_redis ondes_nginx 2>/dev/null || true
  "
}

# ── Résumé final ──────────────────────────────────────────
print_summary() {
  echo ""
  echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}${BOLD}║         ✓  Déploiement terminé avec succès        ║${NC}"
  echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${BOLD}API :${NC}    https://$DOMAIN"
  echo -e "  ${BOLD}Admin :${NC}  https://$DOMAIN/admin/"
  echo -e "  ${BOLD}WS :${NC}     wss://$DOMAIN/api/ws/chat/"
  echo ""
  echo -e "  ${BOLD}Logs :${NC}   ./send_to_vps.sh --logs"
  echo -e "  ${BOLD}Status :${NC} ./send_to_vps.sh --status"
  echo ""
}

# ════════════════════════════════════════════════════════════
#  POINT D'ENTRÉE
# ════════════════════════════════════════════════════════════
banner

case "$MODE" in

  # ── Mode : logs ────────────────────────────────────────
  "logs")
    show_logs
    exit 0
    ;;

  # ── Mode : status ──────────────────────────────────────
  "status")
    show_status
    exit 0
    ;;

  # ── Mode : init (première installation) ───────────────
  "init")
    warn "Mode INIT : premier déploiement — configuration SSL incluse"
    echo ""
    preflight_checks
    ensure_docker
    sync_code
    # Lancer uniquement nginx + certbot pour le challenge ACME
    init_ssl
    # Déployer la stack complète avec SSL
    deploy_containers
    health_check
    cleanup_docker
    print_summary
    ;;

  # ── Mode : deploy (mise à jour standard) ──────────────
  "deploy")
    info "Mode DEPLOY : mise à jour du code + rebuild"
    echo ""
    preflight_checks
    ensure_docker
    sync_code
    deploy_containers
    health_check
    cleanup_docker
    print_summary
    ;;

esac
