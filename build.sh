#!/usr/bin/env bash
#
# build.sh - Build script for Pokemon Frontend (Linux/macOS)
#
# Builds the React frontend with the specified API URL.
#
# Usage:
#   ./build.sh [--api-url URL] [--clean]
#
# Options:
#   --api-url URL   Backend API URL (default: http://localhost:3001)
#   --clean         Remove existing build artifacts before building
#   -h, --help      Show this help message
#
# Examples:
#   ./build.sh
#   ./build.sh --api-url http://myserver.com:21051
#   ./build.sh --clean --api-url http://192.168.1.100:21051
#

set -euo pipefail

# ─── Defaults ────────────────────────────────────────────────────────────────
API_URL="http://localhost:3001"
CLEAN=false

# ─── Paths ───────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Colors ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# ─── Parse Arguments ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --api-url)
            API_URL="$2"
            shift 2
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        -h|--help)
            sed -n '/^# Usage:/,/^[^#]/p' "$0" | head -n -1 | sed 's/^# \?//'
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# ─── Pre-flight Checks ──────────────────────────────────────────────────────
for cmd in node npm; do
    if ! command -v "$cmd" &>/dev/null; then
        log_error "$cmd is not installed. Please install Node.js (v18+) and npm."
        exit 1
    fi
done

log_info "Node.js version: $(node --version)"
log_info "npm version: $(npm --version)"
echo ""

# ─── Build ───────────────────────────────────────────────────────────────────
cd "$SCRIPT_DIR"

if [ "$CLEAN" = true ]; then
    log_info "Cleaning previous build artifacts..."
    rm -rf build/
fi

log_info "Installing dependencies..."
npm install

log_info "Building frontend with REACT_APP_API_URL=${API_URL}..."
REACT_APP_API_URL="$API_URL" npm run build

if [ -d "build" ]; then
    log_success "Frontend build complete! Output: ${SCRIPT_DIR}/build/"
else
    log_error "Build failed - build/ directory not created."
    exit 1
fi
