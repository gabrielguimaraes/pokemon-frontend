#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Pokemon Full-Stack Deploy Script (Frontend + Backend)
# Deploys both frontend and backend to a remote server via rsync
# =============================================================================

# Configuration — set these before running or export as environment variables
SSH_PORT="${SSH_PORT:-22}"
PRIVATE_KEY_PATH="${PRIVATE_KEY_PATH:-}"
SERVER="${SERVER:-}"
DEPLOY_USER="${DEPLOY_USER:-testrigor}"

# Local paths
LOCAL_FRONTEND_DIR="$(cd "$(dirname "$0")" && pwd)"
LOCAL_BACKEND_DIR="$(cd "$(dirname "$0")/../pokemon-backend" && pwd)"

# Remote paths
REMOTE_FRONTEND_PATH="/var/www/pokemon-frontend/"
REMOTE_BACKEND_PATH="/var/www/pokemon-backend/"

# =============================================================================
# Validation
# =============================================================================

if [ -z "$SERVER" ]; then
  echo "ERROR: SERVER is not set. Export it or edit this script."
  echo "  export SERVER=your-server-ip"
  exit 1
fi

if [ -z "$PRIVATE_KEY_PATH" ]; then
  echo "ERROR: PRIVATE_KEY_PATH is not set. Export it or edit this script."
  echo "  export PRIVATE_KEY_PATH=/path/to/your/key"
  exit 1
fi

if [ ! -f "$PRIVATE_KEY_PATH" ]; then
  echo "ERROR: SSH key not found at $PRIVATE_KEY_PATH"
  exit 1
fi

SSH_CMD="ssh -p ${SSH_PORT} -i ${PRIVATE_KEY_PATH}"

# =============================================================================
# Build Frontend
# =============================================================================

echo "=== Building Frontend ==="
cd "$LOCAL_FRONTEND_DIR"
npm install
REACT_APP_API_URL="http://${SERVER}:21051" npm run build

# =============================================================================
# Build Backend
# =============================================================================

echo ""
echo "=== Building Backend ==="
cd "$LOCAL_BACKEND_DIR"
npm install
npm run build

# =============================================================================
# Deploy Frontend
# =============================================================================

echo ""
echo "=== Deploying Frontend ==="
rsync -ravzhe "${SSH_CMD}" --progress --delete \
  "${LOCAL_FRONTEND_DIR}/build/" "${DEPLOY_USER}@${SERVER}:${REMOTE_FRONTEND_PATH}"

# =============================================================================
# Deploy Backend
# =============================================================================

echo ""
echo "=== Deploying Backend ==="
rsync -avzhe "${SSH_CMD}" --progress \
  "${LOCAL_BACKEND_DIR}/dist/server.js" "${DEPLOY_USER}@${SERVER}:${REMOTE_BACKEND_PATH}"

# =============================================================================
# Restart Services
# =============================================================================

echo ""
echo "=== Restarting Services ==="
${SSH_CMD} "${DEPLOY_USER}@${SERVER}" << 'ENDSSH'
  cd /var/www/pokemon-backend
  NODE_ENV=production PORT=21051 pm2 restart pokemon-api 2>/dev/null || \
  NODE_ENV=production PORT=21051 pm2 start server.js --name pokemon-api
  sudo systemctl reload nginx
ENDSSH

echo ""
echo "=== Deploy Complete ==="
echo "Frontend: http://${SERVER}:21050"
echo "Backend:  http://${SERVER}:21051"
