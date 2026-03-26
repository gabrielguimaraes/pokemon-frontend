#!/usr/bin/env bash
#
# deploy.sh - Cross-platform deployment script for the Pokemon application
# Compatible with Linux and macOS (bash 3.2+)
#
# Usage:
#   ./deploy.sh [options]
#
# Options:
#   -h, --help          Show this help message
#   -s, --server HOST   Server hostname or IP address
#   -p, --port PORT     SSH port (default: 22)
#   -k, --key PATH      Path to SSH private key
#   -u, --user USER     SSH username (default: testrigor)
#   --skip-build        Skip the build step (deploy existing artifacts)
#   --frontend-only     Deploy only the frontend
#   --backend-only      Deploy only the backend
#
# Environment variables (alternative to flags):
#   DEPLOY_SERVER       Server hostname or IP
#   DEPLOY_SSH_PORT     SSH port
#   DEPLOY_SSH_KEY      Path to SSH private key
#   DEPLOY_USER         SSH username
#   DEPLOY_API_URL      Backend API URL for frontend build
#

set -euo pipefail

# ============================================================
# Configuration — override via flags, env vars, or edit below
# ============================================================
SSH_PORT="${DEPLOY_SSH_PORT:-22}"
PRIVATE_KEY_PATH="${DEPLOY_SSH_KEY:-}"
SERVER="${DEPLOY_SERVER:-}"
USER="${DEPLOY_USER:-testrigor}"
API_URL="${DEPLOY_API_URL:-}"

# Local paths (relative to project root)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." 2>/dev/null && pwd || echo "${SCRIPT_DIR}")"

FRONTEND_DIR="${SCRIPT_DIR}"
BACKEND_DIR="${PROJECT_ROOT}/pokemon-backend"

LOCAL_FRONTEND_BUILD="${FRONTEND_DIR}/build/"
LOCAL_BACKEND_BUNDLE="${BACKEND_DIR}/dist/server.js"

# Remote paths
REMOTE_FRONTEND_PATH="/var/www/pokemon-frontend/"
REMOTE_BACKEND_PATH="/var/www/pokemon-backend/"

# Ports
FRONTEND_PORT=21050
BACKEND_PORT=21051

# Flags
SKIP_BUILD=false
FRONTEND_ONLY=false
BACKEND_ONLY=false

# ============================================================
# Functions
# ============================================================

usage() {
    sed -n '/^# Usage/,/^[^#]/p' "$0" | grep '^#' | sed 's/^# \?//'
    exit 0
}

log() {
    echo ""
    echo "=== $1 ==="
}

error() {
    echo "ERROR: $1" >&2
    exit 1
}

warn() {
    echo "WARNING: $1" >&2
}

check_command() {
    if ! command -v "$1" &>/dev/null; then
        error "'$1' is required but not installed. $2"
    fi
}

detect_os() {
    case "$(uname -s)" in
        Linux*)  echo "linux" ;;
        Darwin*) echo "mac" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *)       echo "unknown" ;;
    esac
}

# ============================================================
# Parse arguments
# ============================================================
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -s|--server)
            SERVER="$2"
            shift 2
            ;;
        -p|--port)
            SSH_PORT="$2"
            shift 2
            ;;
        -k|--key)
            PRIVATE_KEY_PATH="$2"
            shift 2
            ;;
        -u|--user)
            USER="$2"
            shift 2
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --frontend-only)
            FRONTEND_ONLY=true
            shift
            ;;
        --backend-only)
            BACKEND_ONLY=true
            shift
            ;;
        *)
            error "Unknown option: $1. Use --help for usage."
            ;;
    esac
done

# ============================================================
# Validation
# ============================================================
OS=$(detect_os)
echo "Detected OS: ${OS}"

if [[ -z "${SERVER}" ]]; then
    error "Server not specified. Use --server HOST or set DEPLOY_SERVER env var."
fi

check_command "rsync" "Install via: apt install rsync (Linux) or brew install rsync (Mac)"
check_command "ssh" "Install via: apt install openssh-client (Linux) or it should be pre-installed (Mac)"

# Build SSH command
SSH_OPTS="-p ${SSH_PORT}"
if [[ -n "${PRIVATE_KEY_PATH}" ]]; then
    if [[ ! -f "${PRIVATE_KEY_PATH}" ]]; then
        error "SSH key not found: ${PRIVATE_KEY_PATH}"
    fi
    SSH_OPTS="${SSH_OPTS} -i ${PRIVATE_KEY_PATH}"
fi
SSH_CMD="ssh ${SSH_OPTS}"

# macOS rsync compatibility note
if [[ "${OS}" == "mac" ]]; then
    RSYNC_VERSION=$(rsync --version 2>/dev/null | head -1 || echo "unknown")
    echo "rsync version: ${RSYNC_VERSION}"
    # macOS ships with rsync 2.x by default; Homebrew provides rsync 3.x
    # Both work for this use case
fi

# ============================================================
# Build
# ============================================================
if [[ "${SKIP_BUILD}" == false ]]; then
    if [[ "${BACKEND_ONLY}" == false ]]; then
        log "Building Frontend"
        cd "${FRONTEND_DIR}"

        if [[ ! -f "package.json" ]]; then
            error "package.json not found in ${FRONTEND_DIR}"
        fi

        npm install

        if [[ -z "${API_URL}" ]]; then
            API_URL="http://${SERVER}:${BACKEND_PORT}"
            echo "Using default API URL: ${API_URL}"
        fi

        REACT_APP_API_URL="${API_URL}" npm run build

        if [[ ! -d "build" ]]; then
            error "Frontend build failed — build/ directory not found."
        fi
        echo "Frontend build complete."
    fi

    if [[ "${FRONTEND_ONLY}" == false ]]; then
        log "Building Backend"
        cd "${BACKEND_DIR}"

        if [[ ! -f "package.json" ]]; then
            error "package.json not found in ${BACKEND_DIR}"
        fi

        npm install
        npm run build

        if [[ ! -f "dist/server.js" ]]; then
            error "Backend build failed — dist/server.js not found."
        fi
        echo "Backend build complete."
    fi
else
    echo "Skipping build step (--skip-build)."
fi

# ============================================================
# Deploy
# ============================================================
RSYNC_OPTS="-avzh -e"

if [[ "${BACKEND_ONLY}" == false ]]; then
    log "Deploying Frontend"
    if [[ ! -d "${LOCAL_FRONTEND_BUILD}" ]]; then
        error "Frontend build directory not found: ${LOCAL_FRONTEND_BUILD}"
    fi
    rsync ${RSYNC_OPTS} "${SSH_CMD}" --progress --delete \
        "${LOCAL_FRONTEND_BUILD}" "${USER}@${SERVER}:${REMOTE_FRONTEND_PATH}"
    echo "Frontend deployed to ${SERVER}:${REMOTE_FRONTEND_PATH}"
fi

if [[ "${FRONTEND_ONLY}" == false ]]; then
    log "Deploying Backend"
    if [[ ! -f "${LOCAL_BACKEND_BUNDLE}" ]]; then
        error "Backend bundle not found: ${LOCAL_BACKEND_BUNDLE}"
    fi
    rsync ${RSYNC_OPTS} "${SSH_CMD}" --progress \
        "${LOCAL_BACKEND_BUNDLE}" "${USER}@${SERVER}:${REMOTE_BACKEND_PATH}"
    echo "Backend deployed to ${SERVER}:${REMOTE_BACKEND_PATH}"
fi

# ============================================================
# Restart Services
# ============================================================
log "Restarting Services on ${SERVER}"
${SSH_CMD} "${USER}@${SERVER}" << ENDSSH
    set -e

    if [ "${FRONTEND_ONLY}" != "true" ]; then
        echo "Restarting backend (PM2)..."
        cd /var/www/pokemon-backend
        NODE_ENV=production PORT=${BACKEND_PORT} pm2 restart pokemon-api 2>/dev/null || \
        NODE_ENV=production PORT=${BACKEND_PORT} pm2 start server.js --name pokemon-api
        echo "Backend restarted on port ${BACKEND_PORT}."
    fi

    if [ "${BACKEND_ONLY}" != "true" ]; then
        echo "Reloading Nginx..."
        sudo systemctl reload nginx
        echo "Nginx reloaded."
    fi
ENDSSH

# ============================================================
# Done
# ============================================================
log "Deploy Complete"
echo "Frontend: http://${SERVER}:${FRONTEND_PORT}"
echo "Backend:  http://${SERVER}:${BACKEND_PORT}"
echo ""
echo "Verify with:"
echo "  curl http://${SERVER}:${BACKEND_PORT}/health"
echo "  Open http://${SERVER}:${FRONTEND_PORT} in your browser"
