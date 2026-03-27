#!/usr/bin/env bash
#
# setup-server.sh - Initial Linux server provisioning for Pokemon App
#
# Sets up a fresh Linux server with Nginx and PM2 for hosting the
# Pokemon full-stack application. Run this once on the target server.
#
# Usage:
#   sudo ./setup-server.sh [options]
#
# Options:
#   --user USER    System user to own app directories (default: testrigor)
#   --skip-nginx   Skip Nginx installation and configuration
#   --skip-pm2     Skip PM2 installation
#   -h, --help     Show this help message
#
# Prerequisites:
#   - Ubuntu/Debian-based Linux distribution
#   - Node.js (v18+) and npm installed
#   - Root or sudo access
#
# Examples:
#   sudo ./setup-server.sh
#   sudo ./setup-server.sh --user deploy
#   sudo ./setup-server.sh --skip-nginx
#

set -euo pipefail

# ─── Defaults ────────────────────────────────────────────────────────────────
APP_USER="testrigor"
SKIP_NGINX=false
SKIP_PM2=false

FRONTEND_PORT=21050
BACKEND_PORT=21051
FRONTEND_DIR="/var/www/pokemon-frontend"
BACKEND_DIR="/var/www/pokemon-backend"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NGINX_CONF_SOURCE="${SCRIPT_DIR}/nginx-pokemon.conf"

# ─── Colors ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# ─── Parse Arguments ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --user)
            APP_USER="$2"
            shift 2
            ;;
        --skip-nginx)
            SKIP_NGINX=true
            shift
            ;;
        --skip-pm2)
            SKIP_PM2=true
            shift
            ;;
        -h|--help)
            sed -n '/^# Usage:/,/^[^#]/p' "$0" | head -n -1 | sed 's/^# \?//'
            echo ""
            sed -n '/^# Options:/,/^[^#]/p' "$0" | head -n -1 | sed 's/^# \?//'
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# ─── Pre-flight Checks ──────────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root (use sudo)."
    exit 1
fi

if ! command -v node &>/dev/null; then
    log_error "Node.js is not installed. Please install Node.js v18+ first."
    log_info "Recommended: curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - && sudo apt install -y nodejs"
    exit 1
fi

if ! command -v npm &>/dev/null; then
    log_error "npm is not installed. Please install Node.js and npm first."
    exit 1
fi

echo ""
echo "========================================="
echo "  Pokemon App Server Setup"
echo "========================================="
echo ""
log_info "App user:      ${APP_USER}"
log_info "Frontend port: ${FRONTEND_PORT}"
log_info "Backend port:  ${BACKEND_PORT}"
log_info "Node.js:       $(node --version)"
echo ""

# ─── Step 1: Install PM2 ────────────────────────────────────────────────────
if [ "$SKIP_PM2" = false ]; then
    log_info "Installing PM2 globally..."
    if command -v pm2 &>/dev/null; then
        log_warn "PM2 is already installed: $(pm2 --version)"
    else
        npm install -g pm2
        log_success "PM2 installed successfully."
    fi
else
    log_warn "Skipping PM2 installation."
fi

# ─── Step 2: Install Nginx ──────────────────────────────────────────────────
if [ "$SKIP_NGINX" = false ]; then
    log_info "Installing Nginx..."
    if command -v nginx &>/dev/null; then
        log_warn "Nginx is already installed: $(nginx -v 2>&1)"
    else
        apt-get update -qq
        apt-get install -y nginx
        log_success "Nginx installed successfully."
    fi
else
    log_warn "Skipping Nginx installation."
fi

# ─── Step 3: Create App Directories ─────────────────────────────────────────
log_info "Creating application directories..."

mkdir -p "$FRONTEND_DIR"
mkdir -p "$BACKEND_DIR"

# Ensure the user exists
if ! id "$APP_USER" &>/dev/null; then
    log_warn "User '$APP_USER' does not exist. Creating..."
    useradd -m -s /bin/bash "$APP_USER"
    log_success "User '$APP_USER' created."
fi

chown -R "${APP_USER}:${APP_USER}" "$FRONTEND_DIR"
chown -R "${APP_USER}:${APP_USER}" "$BACKEND_DIR"

log_success "Directories created and owned by ${APP_USER}:"
log_info "  Frontend: ${FRONTEND_DIR}"
log_info "  Backend:  ${BACKEND_DIR}"

# ─── Step 4: Configure Nginx ────────────────────────────────────────────────
if [ "$SKIP_NGINX" = false ]; then
    log_info "Configuring Nginx..."

    NGINX_CONF_DEST="/etc/nginx/sites-available/pokemon"
    NGINX_ENABLED="/etc/nginx/sites-enabled/pokemon"

    if [ -f "$NGINX_CONF_SOURCE" ]; then
        cp "$NGINX_CONF_SOURCE" "$NGINX_CONF_DEST"
        log_info "Copied nginx config from ${NGINX_CONF_SOURCE}"
    else
        # Generate the config inline if the file is not present
        cat > "$NGINX_CONF_DEST" << 'NGINX_EOF'
server {
    listen 21050;
    server_name _;

    root /var/www/pokemon-frontend;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINX_EOF
        log_info "Generated Nginx config at ${NGINX_CONF_DEST}"
    fi

    # Enable the site
    if [ ! -L "$NGINX_ENABLED" ]; then
        ln -s "$NGINX_CONF_DEST" "$NGINX_ENABLED"
    fi

    # Remove default site if it conflicts
    if [ -L "/etc/nginx/sites-enabled/default" ]; then
        log_info "Default Nginx site is enabled (will not be removed)."
    fi

    # Test and restart
    nginx -t
    systemctl restart nginx
    systemctl enable nginx

    log_success "Nginx configured and running on port ${FRONTEND_PORT}."
fi

# ─── Step 5: PM2 Startup ────────────────────────────────────────────────────
if [ "$SKIP_PM2" = false ]; then
    log_info "Setting up PM2 startup..."
    pm2 startup systemd -u "$APP_USER" --hp "/home/${APP_USER}" || true
    log_success "PM2 startup configured."
    log_info "After first deploy, run: pm2 save (as ${APP_USER})"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo "========================================="
log_success "Server setup complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. Build the frontend and backend on your dev machine"
echo "  2. Run deploy.sh to deploy to this server"
echo "  3. After first deploy, run 'pm2 save' as ${APP_USER}"
echo ""
echo "Services will be available at:"
echo "  Frontend: http://$(hostname -I | awk '{print $1}'):${FRONTEND_PORT}"
echo "  Backend:  http://$(hostname -I | awk '{print $1}'):${BACKEND_PORT}"
echo ""
