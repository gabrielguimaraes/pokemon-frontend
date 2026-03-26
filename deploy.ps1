# Pokemon Project Deploy Script (Windows PowerShell)
# Usage: .\deploy.ps1
#
# Configure the variables below before first use.

param(
    [string]$Server = $env:SERVER,
    [string]$SshPort = $(if ($env:SSH_PORT) { $env:SSH_PORT } else { "22" }),
    [string]$PrivateKeyPath = $(if ($env:PRIVATE_KEY_PATH) { $env:PRIVATE_KEY_PATH } else { "$env:USERPROFILE\.ssh\id_rsa" }),
    [string]$User = $(if ($env:DEPLOY_USER) { $env:DEPLOY_USER } else { "testrigor" })
)

$ErrorActionPreference = "Stop"

$LocalFrontendBuild = "build/"
$LocalBackendBundle = "../pokemon-backend/dist/server.js"

$RemoteFrontendPath = "/var/www/pokemon-frontend/"
$RemoteBackendPath = "/var/www/pokemon-backend/"

if (-not $Server) {
    Write-Host "Error: Server is not set. Pass -Server <ip> or set SERVER env var." -ForegroundColor Red
    exit 1
}

# -- Build Frontend ----------------------------------------------------------
Write-Host "=== Building Frontend ===" -ForegroundColor Cyan
npm install
$env:REACT_APP_API_URL = "http://${Server}:21051"
npm run build

# -- Build Backend -----------------------------------------------------------
Write-Host ""
Write-Host "=== Building Backend ===" -ForegroundColor Cyan
Push-Location "..\pokemon-backend"
npm install
npm run build
Pop-Location

# -- Deploy Frontend ---------------------------------------------------------
Write-Host ""
Write-Host "=== Deploying Frontend ===" -ForegroundColor Cyan
rsync -ravzhe "ssh -p $SshPort -i $PrivateKeyPath" --progress --delete `
  $LocalFrontendBuild "${User}@${Server}:${RemoteFrontendPath}"

# -- Deploy Backend ----------------------------------------------------------
Write-Host ""
Write-Host "=== Deploying Backend ===" -ForegroundColor Cyan
rsync -avzhe "ssh -p $SshPort -i $PrivateKeyPath" --progress `
  $LocalBackendBundle "${User}@${Server}:${RemoteBackendPath}"

# -- Restart Services --------------------------------------------------------
Write-Host ""
Write-Host "=== Restarting services ===" -ForegroundColor Cyan
ssh -p $SshPort -i $PrivateKeyPath "${User}@${Server}" @"
cd /var/www/pokemon-backend
NODE_ENV=production PORT=21051 pm2 restart pokemon-api 2>/dev/null || \
NODE_ENV=production PORT=21051 pm2 start server.js --name pokemon-api
sudo systemctl reload nginx
"@

Write-Host ""
Write-Host "=== Deploy complete ===" -ForegroundColor Green
Write-Host "Frontend: http://${Server}:21050"
Write-Host "Backend:  http://${Server}:21051"
