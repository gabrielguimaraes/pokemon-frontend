#!/usr/bin/env bash

# Pokemon Project Deploy Script (Linux/Mac)
# Usage: bash deploy.sh
#
# Configure the variables below before first use.

set -euo pipefail

# -- Configuration -----------------------------------------------------------
SSH_PORT="${SSH_PORT:-22}"
PRIVATE_KEY_PATH="${PRIVATE_KEY_PATH:-~/.ssh/id_rsa}"
SERVER="${SERVER:-}"
REMOTE_USER="${DEPLOY_USER:-testrigor}"

LOCAL_FRONTEND_BUILD="build/"
LOCAL_BACKEND_BUNDLE="../pokemon-backend/dist/server.js"

REMOTE_FRONTEND_PATH="/var/www/pokemon-frontend/"
REMOTE_BACKEND_PATH="/var/www/pokemon-backend/"

SSH_CMD="ssh -p ${SSH_PORT} -i ${PRIVATE_KEY_PATH}"
# ----------------------------------------------------------------------------

if [ -z "${SERVER}" ]; then
  echo "Error: SERVER is not set. Export SERVER=<ip> or edit this script."
  exit 1
fi

echo "=== Building Frontend ==="
npm install
REACT_APP_API_URL="http://${SERVER}:21051" npm run build

echo ""
echo "=== Building Backend ==="
(cd ../pokemon-backend && npm install && npm run build)

echo ""
echo "=== Deploying Frontend ==="
rsync -ravzhe "${SSH_CMD}" --progress --delete \
  "${LOCAL_FRONTEND_BUILD}" "${REMOTE_USER}@${SERVER}:${REMOTE_FRONTEND_PATH}"

echo ""
echo "=== Deploying Backend ==="
rsync -avzhe "${SSH_CMD}" --progress \
  "${LOCAL_BACKEND_BUNDLE}" "${REMOTE_USER}@${SERVER}:${REMOTE_BACKEND_PATH}"

echo ""
echo "=== Restarting services ==="
${SSH_CMD} "${REMOTE_USER}@${SERVER}" << 'ENDSSH'
  cd /var/www/pokemon-backend
  NODE_ENV=production PORT=21051 pm2 restart pokemon-api 2>/dev/null || \
  NODE_ENV=production PORT=21051 pm2 start server.js --name pokemon-api
  sudo systemctl reload nginx
ENDSSH

echo ""
echo "=== Deploy complete ==="
echo "Frontend: http://${SERVER}:21050"
echo "Backend:  http://${SERVER}:21051"
