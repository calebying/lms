#!/bin/bash
# deploy.sh — runs on the Lightsail server
# Usage: sudo bash /opt/frappe-lms/deploy.sh [branch]
#
# Expects source files already staged at /opt/frappe-lms/src/
# by the local scripts/deploy.sh (or scripts/deploy.ps1).

set -e

COMPOSE_DIR="/opt/frappe-lms"
SRC_DIR="$COMPOSE_DIR/src"
# frappe-bench is the ACTIVE bench dir (real directory, not a symlink);
# frappe-persist is the Docker volume — sync both so changes survive restarts.
APP_PATH="/home/frappe/frappe-bench/apps/lms"
APP_PATH_PERSIST="/home/frappe/frappe-persist/apps/lms"
SITE="lms.localhost"
BRANCH="${1:-SIT-UI}"
SERVICE="frappe"

# Colours
G="\033[0;32m"; Y="\033[0;33m"; R="\033[0;31m"; N="\033[0m"
log()  { echo -e "${G}[deploy]${N} $1"; }
warn() { echo -e "${Y}[warn]  ${N} $1"; }
die()  { echo -e "${R}[error] ${N} $1"; exit 1; }

cd "$COMPOSE_DIR"

# ── 1. Verify container is running ────────────────────────────────────────
log "Checking container status..."
docker compose ps "$SERVICE" | grep -q "Up" \
  || die "Container '$SERVICE' is not running. Run: sudo docker compose up -d"

# ── 2. Copy source files into container ───────────────────────────────────
if [ -d "$SRC_DIR/lms" ]; then
  log "Syncing lms/ into container (bench + persist)..."
  docker compose cp "$SRC_DIR/lms/." "$SERVICE:$APP_PATH/lms/"
  docker compose cp "$SRC_DIR/lms/." "$SERVICE:$APP_PATH_PERSIST/lms/" 2>/dev/null || true
else
  warn "No lms/ dir in $SRC_DIR — skipping Python app sync"
fi

if [ -d "$SRC_DIR/frontend" ]; then
  log "Syncing frontend/ into container (bench + persist)..."
  docker compose cp "$SRC_DIR/frontend/." "$SERVICE:$APP_PATH/frontend/"
  docker compose cp "$SRC_DIR/frontend/." "$SERVICE:$APP_PATH_PERSIST/frontend/" 2>/dev/null || true
else
  warn "No frontend/ dir in $SRC_DIR — skipping frontend sync"
fi

# ── 3. Build Vite/Vue frontend bundle ─────────────────────────────────────
log "Building frontend assets (this takes ~2-3 min)..."
docker compose exec -T "$SERVICE" bash -c "
  export PATH=\"\${NVM_DIR}/versions/node/\${NODE_VERSION_DEVELOP}/bin/:\${PATH}\"
  cd /home/frappe/frappe-bench
  NODE_OPTIONS=--max-old-space-size=1536 bench build --app lms --production
" && log "Frontend build complete." || die "Frontend build failed — check logs above."

# ── 4. Migrate to register new public assets (CSS/JS) ─────────────────────
log "Running bench migrate..."
docker compose exec -T "$SERVICE" bash -c "
  cd /home/frappe/frappe-bench
  bench --site $SITE migrate
" && log "Migrate complete."

# ── 5. Clear site cache ───────────────────────────────────────────────────
log "Clearing site cache..."
docker compose exec -T "$SERVICE" bash -c "
  bench --site $SITE clear-cache
"

log "✓ Deploy complete → http://13.213.150.153:8000/lms"
