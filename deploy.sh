#!/usr/bin/env bash
set -euo pipefail

#
# Pokemon Frontend + Backend Deploy Script (Linux/Mac)
#
# Usage:
#   ./deploy.sh
#   SSH_PORT=2222 SERVER=myserver.com ./deploy.sh
#

# ---- Configuration (override via environment variables) ----
SSH_PORT="${SSH_PORT:-22}"
PRIVATE_KEY_PATH="${PRIVATE_KEY_PATH:-$HOME/.ssh/id_rsa}"
SERVER="${SERVER:-}"
DEPLOY_USER_NAME="${DEPLOY_USER:-testrigor}"

LOCAL_FRONTEND_BUILD="build/"
LOCAL_BACKEND_BUNDLE="../pokemon-backend/dist/server.js"

REMOTE_FRONTEND_PATH="/var/www/pokemon-frontend/"
REMOTE_BACKEND_PATH="/var/www/pokemon-backend/"

# ---- Validation ----
if [ -z "$SERVER" ]; then
  echo "ERROR: SERVER is not set."
  echo "Usage: SERVER=your-server.com ./deploy.sh"
  echo ""
  echo "Environment variables:"
  echo "  SERVER            (required) Remote server hostname or IP"
  echo "  SSH_PORT          (default: 22) SSH port"
  echo "  PRIVATE_KEY_PATH  (default: ~/.ssh/id_rsa) Path to SSH private key"
  echo "  DEPLOY_USER       (default: testrigor) SSH username"
  exit 1
fi

if [ ! -f "$PRIVATE_KEY_PATH" ]; then
  echo "ERROR: Private key not found at $PRIVATE_KEY_PATH"
  exit 1
fi

SSH_CMD="ssh -p ${SSH_PORT} -i ${PRIVATE_KEY_PATH}"

# ---- Build ----
echo "=== Building Frontend ==="
export REACT_APP_API_URL="http://${SERVER}:21051"
if [ -d "node_modules" ]; then
  npm run build
else
  npm install && npm run build
fi

echo ""
echo "=== Building Backend ==="
cd ../pokemon-backend
if [ -d "node_modules" ]; then
  npm run build
else
  npm install && npm run build
fi
cd ../pokemon-frontend

# ---- Deploy ----
echo ""
echo "=== Deploying Frontend ==="
rsync -ravzhe "${SSH_CMD}" --progress --delete \
  "${LOCAL_FRONTEND_BUILD}" "${DEPLOY_USER_NAME}@${SERVER}:${REMOTE_FRONTEND_PATH}"

echo ""
echo "=== Deploying Backend ==="
rsync -avzhe "${SSH_CMD}" --progress \
  "${LOCAL_BACKEND_BUNDLE}" "${DEPLOY_USER_NAME}@${SERVER}:${REMOTE_BACKEND_PATH}"

echo ""
echo "=== Restarting Services ==="
${SSH_CMD} ${DEPLOY_USER_NAME}@${SERVER} << 'ENDSSH'
  cd /var/www/pokemon-backend
  NODE_ENV=production PORT=21051 pm2 restart pokemon-api 2>/dev/null || \
  NODE_ENV=production PORT=21051 pm2 start server.js --name pokemon-api
  sudo systemctl reload nginx
ENDSSH

echo ""
echo "=== Deploy Complete ==="
echo "Frontend: http://${SERVER}:21050"
echo "Backend:  http://${SERVER}:21051"
