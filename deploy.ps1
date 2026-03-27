# =============================================================================
# Pokemon Full-Stack Deploy Script (Frontend + Backend) — PowerShell
# Deploys both frontend and backend to a remote server via rsync
# =============================================================================

param(
    [string]$Server = $env:SERVER,
    [string]$SshPort = $(if ($env:SSH_PORT) { $env:SSH_PORT } else { "22" }),
    [string]$PrivateKeyPath = $env:PRIVATE_KEY_PATH,
    [string]$DeployUser = $(if ($env:DEPLOY_USER) { $env:DEPLOY_USER } else { "testrigor" })
)

$ErrorActionPreference = "Stop"

# Local paths
$LocalFrontendDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LocalBackendDir = Join-Path (Split-Path -Parent $LocalFrontendDir) "pokemon-backend"

# Remote paths
$RemoteFrontendPath = "/var/www/pokemon-frontend/"
$RemoteBackendPath = "/var/www/pokemon-backend/"

# =============================================================================
# Validation
# =============================================================================

if (-not $Server) {
    Write-Error "ERROR: Server is not set. Use -Server parameter or set SERVER env var."
    exit 1
}

if (-not $PrivateKeyPath) {
    Write-Error "ERROR: PrivateKeyPath is not set. Use -PrivateKeyPath parameter or set PRIVATE_KEY_PATH env var."
    exit 1
}

if (-not (Test-Path $PrivateKeyPath)) {
    Write-Error "ERROR: SSH key not found at $PrivateKeyPath"
    exit 1
}

$SshCmd = "ssh -p $SshPort -i $PrivateKeyPath"

# =============================================================================
# Build Frontend
# =============================================================================

Write-Host "=== Building Frontend ===" -ForegroundColor Cyan
Set-Location $LocalFrontendDir
npm install
$env:REACT_APP_API_URL = "http://${Server}:21051"
npm run build

# =============================================================================
# Build Backend
# =============================================================================

Write-Host ""
Write-Host "=== Building Backend ===" -ForegroundColor Cyan
Set-Location $LocalBackendDir
npm install
npm run build

# =============================================================================
# Deploy Frontend
# =============================================================================

Write-Host ""
Write-Host "=== Deploying Frontend ===" -ForegroundColor Cyan
rsync -ravzhe "$SshCmd" --progress --delete `
  "$LocalFrontendDir/build/" "${DeployUser}@${Server}:${RemoteFrontendPath}"

# =============================================================================
# Deploy Backend
# =============================================================================

Write-Host ""
Write-Host "=== Deploying Backend ===" -ForegroundColor Cyan
rsync -avzhe "$SshCmd" --progress `
  "$LocalBackendDir/dist/server.js" "${DeployUser}@${Server}:${RemoteBackendPath}"

# =============================================================================
# Restart Services
# =============================================================================

Write-Host ""
Write-Host "=== Restarting Services ===" -ForegroundColor Cyan
& ssh -p $SshPort -i $PrivateKeyPath "${DeployUser}@${Server}" @"
cd /var/www/pokemon-backend
NODE_ENV=production PORT=21051 pm2 restart pokemon-api 2>/dev/null || NODE_ENV=production PORT=21051 pm2 start server.js --name pokemon-api
sudo systemctl reload nginx
"@

Write-Host ""
Write-Host "=== Deploy Complete ===" -ForegroundColor Green
Write-Host "Frontend: http://${Server}:21050"
Write-Host "Backend:  http://${Server}:21051"
