#!/bin/bash
# scripts/deploy.sh — run this locally (Git Bash on Windows)
# Syncs changed files to Lightsail and triggers the server build.
#
# Usage:
#   bash scripts/deploy.sh             # sync all & build
#   bash scripts/deploy.sh --frontend  # sync frontend/ only
#   bash scripts/deploy.sh --lms       # sync lms/ only

set -e

KEY="C:/Users/A103605/Projects/FrappleLMS/ec2/frappe-lms-key.pem"
HOST="ec2-user@13.213.150.153"
REMOTE_DIR="/opt/frappe-lms"
LOCAL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

G="\033[0;32m"; Y="\033[0;33m"; N="\033[0m"
log()  { echo -e "${G}[local] ${N} $1"; }
warn() { echo -e "${Y}[warn]  ${N} $1"; }

SSH="ssh -i \"$KEY\" -o StrictHostKeyChecking=no"
SCP="scp -i \"$KEY\" -o StrictHostKeyChecking=no"

# Parse flags
SYNC_FRONTEND=true
SYNC_LMS=true
if [[ "$1" == "--frontend" ]]; then SYNC_LMS=false; fi
if [[ "$1" == "--lms" ]]; then SYNC_FRONTEND=false; fi

# ── 1. Ensure remote staging dir exists ───────────────────────────────────
log "Preparing remote staging directory..."
eval "$SSH $HOST" "sudo mkdir -p $REMOTE_DIR/src && sudo chown ec2-user:ec2-user $REMOTE_DIR/src"

# ── 2. Upload frontend/ ────────────────────────────────────────────────────
if $SYNC_FRONTEND; then
  log "Uploading frontend/ (~may take a moment for node_modules-free diff)..."
  # Use tar + ssh pipe — faster than recursive scp, avoids node_modules
  cd "$LOCAL_ROOT"
  tar czf - \
    --exclude='frontend/node_modules' \
    --exclude='frontend/dist' \
    --exclude='frontend/.vite' \
    frontend/ \
  | eval "$SSH $HOST" "sudo mkdir -p $REMOTE_DIR/src && cd $REMOTE_DIR/src && tar xzf -"
  log "frontend/ uploaded."
fi

# ── 3. Upload lms/ ─────────────────────────────────────────────────────────
if $SYNC_LMS; then
  log "Uploading lms/ ..."
  cd "$LOCAL_ROOT"
  tar czf - \
    --exclude='lms/__pycache__' \
    --exclude='lms/*.pyc' \
    --exclude='lms/public/dist' \
    lms/ \
  | eval "$SSH $HOST" "cd $REMOTE_DIR/src && tar xzf -"
  log "lms/ uploaded."
fi

# ── 4. Upload server deploy script (always keep it current) ───────────────
log "Uploading deploy.sh to server..."
eval "$SCP \"$LOCAL_ROOT/docker/deploy.sh\" $HOST:/tmp/deploy.sh"
eval "$SSH $HOST" "sudo mv /tmp/deploy.sh $REMOTE_DIR/deploy.sh && sudo chmod +x $REMOTE_DIR/deploy.sh"

# ── 5. Trigger server-side build ──────────────────────────────────────────
log "Triggering server build..."
eval "$SSH $HOST" "cd $REMOTE_DIR && sudo bash deploy.sh SIT-UI"
