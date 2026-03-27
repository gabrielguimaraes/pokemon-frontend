#
# deploy.ps1 - Windows PowerShell deployment script for Pokemon Full-Stack App
#
# Deploys the frontend (React) and backend (Node.js/Express) to a remote
# Linux server using SSH/SCP. Works on Windows 10+ with OpenSSH.
#
# Usage:
#   .\deploy.ps1 -Server <hostname> -KeyPath <path> [-Port <port>] [-User <user>]
#                [-FrontendOnly] [-BackendOnly] [-SkipBuild] [-ApiUrl <url>]
#
# Examples:
#   .\deploy.ps1 -Server 192.168.1.100 -KeyPath C:\Users\me\.ssh\id_rsa -Port 2222
#   .\deploy.ps1 -Server myserver.com -KeyPath ~\.ssh\deploy_key -FrontendOnly
#   .\deploy.ps1 -Server myserver.com -KeyPath ~\.ssh\deploy_key -SkipBuild
#

param(
    [Parameter(Mandatory = $true)]
    [string]$Server,

    [Parameter(Mandatory = $true)]
    [string]$KeyPath,

    [int]$Port = 22,

    [string]$User = "testrigor",

    [switch]$FrontendOnly,

    [switch]$BackendOnly,

    [switch]$SkipBuild,

    [string]$ApiUrl = ""
)

# ─── Strict Mode ─────────────────────────────────────────────────────────────
$ErrorActionPreference = "Stop"

# ─── Paths ───────────────────────────────────────────────────────────────────
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$FrontendDir = $ScriptDir
$BackendDir = Join-Path $ScriptDir "..\pokemon-backend"

$LocalFrontendBuild = Join-Path $FrontendDir "build"
$LocalBackendBundle = Join-Path $BackendDir "dist\server.js"

$RemoteFrontendPath = "/var/www/pokemon-frontend/"
$RemoteBackendPath = "/var/www/pokemon-backend/"

# ─── Flags ───────────────────────────────────────────────────────────────────
$DeployFrontend = -not $BackendOnly
$DeployBackend = -not $FrontendOnly

if ([string]::IsNullOrEmpty($ApiUrl)) {
    $ApiUrl = "http://${Server}:21051"
}

# ─── Functions ───────────────────────────────────────────────────────────────
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Test-Command {
    param([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

function Test-Dependencies {
    $missing = @()

    foreach ($cmd in @("ssh", "scp", "npm", "node")) {
        if (-not (Test-Command $cmd)) {
            $missing += $cmd
        }
    }

    if ($missing.Count -gt 0) {
        Write-ErrorMessage "Missing required dependencies: $($missing -join ', ')"
        Write-ErrorMessage "Please install them before running this script."
        Write-ErrorMessage "Note: OpenSSH is built into Windows 10+. Enable it via Settings > Optional Features."
        exit 1
    }
}

function Test-Arguments {
    $resolvedKeyPath = Resolve-Path $KeyPath -ErrorAction SilentlyContinue
    if (-not $resolvedKeyPath) {
        Write-ErrorMessage "SSH key not found: $KeyPath"
        exit 1
    }
    $script:KeyPath = $resolvedKeyPath.Path
}

function Invoke-SshCommand {
    param([string]$Command)
    & ssh -p $Port -i $KeyPath "${User}@${Server}" $Command
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMessage "SSH command failed with exit code $LASTEXITCODE"
        exit 1
    }
}

function Build-Frontend {
    Write-Info "Building frontend..."
    Push-Location $FrontendDir

    try {
        if (-not (Test-Path "node_modules")) {
            Write-Info "Installing frontend dependencies..."
            & npm install
            if ($LASTEXITCODE -ne 0) { throw "npm install failed" }
        }

        $env:REACT_APP_API_URL = $ApiUrl
        & npm run build
        if ($LASTEXITCODE -ne 0) { throw "npm run build failed" }

        if (-not (Test-Path $LocalFrontendBuild)) {
            throw "Frontend build failed - build/ directory not found."
        }

        Write-Success "Frontend build complete."
    }
    finally {
        Pop-Location
        Remove-Item Env:\REACT_APP_API_URL -ErrorAction SilentlyContinue
    }
}

function Build-Backend {
    Write-Info "Building backend..."
    Push-Location $BackendDir

    try {
        if (-not (Test-Path "node_modules")) {
            Write-Info "Installing backend dependencies..."
            & npm install
            if ($LASTEXITCODE -ne 0) { throw "npm install failed" }
        }

        & npm run build
        if ($LASTEXITCODE -ne 0) { throw "npm run build failed" }

        if (-not (Test-Path $LocalBackendBundle)) {
            throw "Backend build failed - dist/server.js not found."
        }

        Write-Success "Backend build complete."
    }
    finally {
        Pop-Location
    }
}

function Deploy-Frontend {
    Write-Info "Deploying frontend to ${Server}..."

    if (-not (Test-Path $LocalFrontendBuild)) {
        Write-ErrorMessage "Frontend build directory not found: $LocalFrontendBuild"
        Write-ErrorMessage "Run the build first or remove -SkipBuild."
        exit 1
    }

    # Use scp to recursively copy the build directory
    & scp -P $Port -i $KeyPath -r "${LocalFrontendBuild}\*" "${User}@${Server}:${RemoteFrontendPath}"
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMessage "Frontend deployment failed."
        exit 1
    }

    Write-Success "Frontend deployed successfully."
}

function Deploy-Backend {
    Write-Info "Deploying backend to ${Server}..."

    if (-not (Test-Path $LocalBackendBundle)) {
        Write-ErrorMessage "Backend bundle not found: $LocalBackendBundle"
        Write-ErrorMessage "Run the build first or remove -SkipBuild."
        exit 1
    }

    & scp -P $Port -i $KeyPath $LocalBackendBundle "${User}@${Server}:${RemoteBackendPath}"
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMessage "Backend deployment failed."
        exit 1
    }

    Write-Success "Backend deployed successfully."
}

function Restart-Services {
    Write-Info "Restarting services on ${Server}..."

    $remoteCommand = @"
cd /var/www/pokemon-backend && \
NODE_ENV=production PORT=21051 pm2 restart pokemon-api 2>/dev/null || \
NODE_ENV=production PORT=21051 pm2 start server.js --name pokemon-api && \
sudo systemctl reload nginx
"@

    Invoke-SshCommand $remoteCommand
    Write-Success "Services restarted successfully."
}

# ─── Main ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=========================================" -ForegroundColor White
Write-Host "  Pokemon App Deployment (Windows)" -ForegroundColor White
Write-Host "=========================================" -ForegroundColor White
Write-Host ""

Test-Dependencies
Test-Arguments

Write-Info "Server:    $Server"
Write-Info "SSH Port:  $Port"
Write-Info "User:      $User"
Write-Info "API URL:   $ApiUrl"
Write-Host ""

# Build phase
if (-not $SkipBuild) {
    if ($DeployFrontend) {
        Build-Frontend
    }
    if ($DeployBackend) {
        Build-Backend
    }
    Write-Host ""
}

# Deploy phase
if ($DeployFrontend) {
    Deploy-Frontend
}

if ($DeployBackend) {
    Deploy-Backend
}

Write-Host ""

# Restart services
Restart-Services

Write-Host ""
Write-Host "=========================================" -ForegroundColor White
Write-Success "Deploy complete!"
Write-Host "=========================================" -ForegroundColor White
Write-Host ""
Write-Host "  Frontend: http://${Server}:21050" -ForegroundColor Green
Write-Host "  Backend:  http://${Server}:21051" -ForegroundColor Green
Write-Host ""
