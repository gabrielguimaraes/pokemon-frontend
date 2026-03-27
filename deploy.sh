#!/usr/bin/env bash
#
# deploy.sh - Cross-platform deployment script for Pokemon Full-Stack App
#
# Deploys the frontend (React) and backend (Node.js/Express) to a remote
# Linux server using rsync over SSH. Works on Linux and macOS.
#
# Usage:
#   ./deploy.sh [options]
#
# Options:
#   -s, --server SERVER         Remote server hostname or IP (required)
#   -p, --port PORT             SSH port (default: 22)
#   -k, --key KEY_PATH          Path to SSH private key (required)
#   -u, --user USER             SSH username (default: testrigor)
#   -f, --frontend-only         Deploy only the frontend
#   -b, --backend-only          Deploy only the backend
#   --skip-build                Skip the build step (deploy pre-built artifacts)
#   --api-url URL               Backend API URL for frontend build (default: http://<server>:21051)
#   -h, --help                  Show this help message
#
# Examples:
#   ./deploy.sh -s 192.168.1.100 -p 2222 -k ~/.ssh/id_rsa
#   ./deploy.sh -s myserver.com -k ~/.ssh/deploy_key --frontend-only
#   ./deploy.sh -s myserver.com -k ~/.ssh/deploy_key --skip-build
#

set -euo pipefail

# ─── Defaults ────────────────────────────────────────────────────────────────
SSH_PORT="22"
PRIVATE_KEY_PATH=""
SERVER=""
USER="testrigor"
DEPLOY_FRONTEND=true
DEPLOY_BACKEND=true
SKIP_BUILD=false
API_URL=""

# ─── Paths ───────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="${SCRIPT_DIR}"
BACKEND_DIR="${SCRIPT_DIR}/../pokemon-backend"

LOCAL_FRONTEND_BUILD="${FRONTEND_DIR}/build/"
LOCAL_BACKEND_BUNDLE="${BACKEND_DIR}/dist/server.js"

REMOTE_FRONTEND_PATH="/var/www/pokemon-frontend/"
REMOTE_BACKEND_PATH="/var/www/pokemon-backend/"

# ─── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ─── Functions ───────────────────────────────────────────────────────────────
usage() {
    sed -n '/^# Usage:/,/^#$/p' "$0" | sed 's/^# \?//'
    echo ""
    sed -n '/^# Options:/,/^#$/p' "$0" | sed 's/^# \?//'
    echo ""
    sed -n '/^# Examples:/,/^[^#]/p' "$0" | head -n -1 | sed 's/^# \?//'
    exit 0
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

check_dependencies() {
    local missing=()
    for cmd in rsync ssh npm node; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing required dependencies: ${missing[*]}"
        log_error "Please install them before running this script."
        exit 1
    fi
}

validate_args() {
    if [ -z "$SERVER" ]; then
        log_error "Server address is required. Use -s or --server."
        echo "Run '$0 --help' for usage information."
        exit 1
    fi

    if [ -z "$PRIVATE_KEY_PATH" ]; then
        log_error "SSH private key path is required. Use -k or --key."
        echo "Run '$0 --help' for usage information."
        exit 1
    fi

    if [ ! -f "$PRIVATE_KEY_PATH" ]; then
        log_error "SSH key not found: $PRIVATE_KEY_PATH"
        exit 1
    fi

    if [ -z "$API_URL" ]; then
        API_URL="http://${SERVER}:21051"
    fi
}

build_frontend() {
    log_info "Building frontend..."
    cd "$FRONTEND_DIR"

    if [ ! -d "node_modules" ]; then
        log_info "Installing frontend dependencies..."
        npm install
    fi

    REACT_APP_API_URL="$API_URL" npm run build

    if [ ! -d "$LOCAL_FRONTEND_BUILD" ]; then
        log_error "Frontend build failed - build/ directory not found."
        exit 1
    fi

    log_success "Frontend build complete."
}

build_backend() {
    log_info "Building backend..."
    cd "$BACKEND_DIR"

    if [ ! -d "node_modules" ]; then
        log_info "Installing backend dependencies..."
        npm install
    fi

    npm run build

    if [ ! -f "$LOCAL_BACKEND_BUNDLE" ]; then
        log_error "Backend build failed - dist/server.js not found."
        exit 1
    fi

    log_success "Backend build complete."
}

deploy_frontend() {
    log_info "Deploying frontend to ${SERVER}..."

    if [ ! -d "$LOCAL_FRONTEND_BUILD" ]; then
        log_error "Frontend build directory not found: $LOCAL_FRONTEND_BUILD"
        log_error "Run the build first or remove --skip-build."
        exit 1
    fi

    rsync -ravzhe "ssh -p ${SSH_PORT} -i ${PRIVATE_KEY_PATH}" \
        --progress --delete \
        "${LOCAL_FRONTEND_BUILD}" "${USER}@${SERVER}:${REMOTE_FRONTEND_PATH}"

    log_success "Frontend deployed successfully."
}

deploy_backend() {
    log_info "Deploying backend to ${SERVER}..."

    if [ ! -f "$LOCAL_BACKEND_BUNDLE" ]; then
        log_error "Backend bundle not found: $LOCAL_BACKEND_BUNDLE"
        log_error "Run the build first or remove --skip-build."
        exit 1
    fi

    rsync -avzhe "ssh -p ${SSH_PORT} -i ${PRIVATE_KEY_PATH}" \
        --progress \
        "${LOCAL_BACKEND_BUNDLE}" "${USER}@${SERVER}:${REMOTE_BACKEND_PATH}"

    log_success "Backend deployed successfully."
}

restart_services() {
    log_info "Restarting services on ${SERVER}..."

    local SSH_CMD="ssh -p ${SSH_PORT} -i ${PRIVATE_KEY_PATH}"

    ${SSH_CMD} "${USER}@${SERVER}" << 'ENDSSH'
cd /var/www/pokemon-backend
NODE_ENV=production PORT=21051 pm2 restart pokemon-api 2>/dev/null || \
NODE_ENV=production PORT=21051 pm2 start server.js --name pokemon-api
sudo systemctl reload nginx
ENDSSH

    log_success "Services restarted successfully."
}

# ─── Parse Arguments ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
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
        -f|--frontend-only)
            DEPLOY_BACKEND=false
            shift
            ;;
        -b|--backend-only)
            DEPLOY_FRONTEND=false
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --api-url)
            API_URL="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Run '$0 --help' for usage information."
            exit 1
            ;;
    esac
done

# ─── Main ────────────────────────────────────────────────────────────────────
echo ""
echo "========================================="
echo "  Pokemon App Deployment (Linux/macOS)"
echo "========================================="
echo ""

check_dependencies
validate_args

log_info "Server:    ${SERVER}"
log_info "SSH Port:  ${SSH_PORT}"
log_info "User:      ${USER}"
log_info "API URL:   ${API_URL}"
echo ""

# Build phase
if [ "$SKIP_BUILD" = false ]; then
    if [ "$DEPLOY_FRONTEND" = true ]; then
        build_frontend
    fi
    if [ "$DEPLOY_BACKEND" = true ]; then
        build_backend
    fi
    echo ""
fi

# Deploy phase
if [ "$DEPLOY_FRONTEND" = true ]; then
    deploy_frontend
fi

if [ "$DEPLOY_BACKEND" = true ]; then
    deploy_backend
fi

echo ""

# Restart services
restart_services

echo ""
echo "========================================="
log_success "Deploy complete!"
echo "========================================="
echo ""
echo "  Frontend: http://${SERVER}:21050"
echo "  Backend:  http://${SERVER}:21051"
echo ""
