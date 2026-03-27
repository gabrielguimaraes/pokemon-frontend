#
# Pokemon Frontend + Backend Deploy Script (Windows PowerShell)
#
# Usage:
#   .\deploy.ps1 -Server "your-server.com"
#   .\deploy.ps1 -Server "your-server.com" -SshPort 2222 -User "admin"
#

param(
    [Parameter(Mandatory=$true)]
    [string]$Server,

    [int]$SshPort = 22,

    [string]$PrivateKeyPath = "$env:USERPROFILE\.ssh\id_rsa",

    [string]$User = "testrigor"
)

$ErrorActionPreference = "Stop"

# ---- Configuration ----
$LocalFrontendBuild = "build\"
$LocalBackendBundle = "..\pokemon-backend\dist\server.js"
$RemoteFrontendPath = "/var/www/pokemon-frontend/"
$RemoteBackendPath = "/var/www/pokemon-backend/"

# ---- Validation ----
if (-not (Test-Path $PrivateKeyPath)) {
    Write-Error "Private key not found at $PrivateKeyPath"
    exit 1
}

$SshCmd = "ssh -p $SshPort -i `"$PrivateKeyPath`""

# ---- Build ----
Write-Host "=== Building Frontend ===" -ForegroundColor Cyan
if (Test-Path "node_modules") {
    $env:REACT_APP_API_URL = "http://${Server}:21051"
    npm run build
} else {
    npm install
    $env:REACT_APP_API_URL = "http://${Server}:21051"
    npm run build
}

Write-Host ""
Write-Host "=== Building Backend ===" -ForegroundColor Cyan
Push-Location ..\pokemon-backend
if (Test-Path "node_modules") {
    npm run build
} else {
    npm install
    npm run build
}
Pop-Location

# ---- Deploy ----
Write-Host ""
Write-Host "=== Deploying Frontend ===" -ForegroundColor Cyan
& rsync -ravzhe "$SshCmd" --progress --delete `
    $LocalFrontendBuild "${User}@${Server}:${RemoteFrontendPath}"

Write-Host ""
Write-Host "=== Deploying Backend ===" -ForegroundColor Cyan
& rsync -avzhe "$SshCmd" --progress `
    $LocalBackendBundle "${User}@${Server}:${RemoteBackendPath}"

Write-Host ""
Write-Host "=== Restarting Services ===" -ForegroundColor Cyan
& ssh -p $SshPort -i $PrivateKeyPath ${User}@${Server} @"
cd /var/www/pokemon-backend
NODE_ENV=production PORT=21051 pm2 restart pokemon-api 2>/dev/null || \
NODE_ENV=production PORT=21051 pm2 start server.js --name pokemon-api
sudo systemctl reload nginx
"@

Write-Host ""
Write-Host "=== Deploy Complete ===" -ForegroundColor Green
Write-Host "Frontend: http://${Server}:21050"
Write-Host "Backend:  http://${Server}:21051"
