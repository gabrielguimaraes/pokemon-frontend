#Requires -Version 5.1
<#
.SYNOPSIS
    Cross-platform deployment script for the Pokemon application (Windows).

.DESCRIPTION
    Builds and deploys the Pokemon frontend and backend to a remote Linux server
    using OpenSSH (built into Windows 10+) and SCP/SSH.

.PARAMETER Server
    The target server hostname or IP address.

.PARAMETER SshPort
    SSH port on the target server (default: 22).

.PARAMETER KeyPath
    Path to the SSH private key file.

.PARAMETER User
    SSH username (default: testrigor).

.PARAMETER ApiUrl
    Backend API URL for the frontend build. Defaults to http://<Server>:21051.

.PARAMETER SkipBuild
    Skip the build step and deploy existing artifacts.

.PARAMETER FrontendOnly
    Deploy only the frontend.

.PARAMETER BackendOnly
    Deploy only the backend.

.EXAMPLE
    .\deploy.ps1 -Server 192.168.1.100 -KeyPath C:\Users\me\.ssh\id_rsa

.EXAMPLE
    .\deploy.ps1 -Server myserver.com -SshPort 2222 -User admin -SkipBuild

.EXAMPLE
    .\deploy.ps1 -Server myserver.com -KeyPath ~/.ssh/id_rsa -FrontendOnly
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Server,

    [int]$SshPort = 22,

    [string]$KeyPath = "",

    [string]$User = "testrigor",

    [string]$ApiUrl = "",

    [switch]$SkipBuild,

    [switch]$FrontendOnly,

    [switch]$BackendOnly
)

$ErrorActionPreference = "Stop"

# ============================================================
# Configuration
# ============================================================
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$FrontendDir = $ScriptDir
$BackendDir = Join-Path $ProjectRoot "pokemon-backend"

$LocalFrontendBuild = Join-Path $FrontendDir "build"
$LocalBackendBundle = Join-Path $BackendDir "dist\server.js"

$RemoteFrontendPath = "/var/www/pokemon-frontend/"
$RemoteBackendPath = "/var/www/pokemon-backend/"

$FrontendPort = 21050
$BackendPort = 21051

# ============================================================
# Helper Functions
# ============================================================
function Write-Log {
    param([string]$Message)
    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor Cyan
}

function Write-ErrorAndExit {
    param([string]$Message)
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

function Test-CommandExists {
    param([string]$Command)
    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

# ============================================================
# Validation
# ============================================================
Write-Host "Detected OS: Windows (PowerShell $($PSVersionTable.PSVersion))"

# Check for SSH
if (-not (Test-CommandExists "ssh")) {
    Write-ErrorAndExit "OpenSSH client is not available. Enable it via Settings > Apps > Optional Features > OpenSSH Client."
}

# Check for SCP
if (-not (Test-CommandExists "scp")) {
    Write-ErrorAndExit "SCP is not available. It should be installed with OpenSSH Client."
}

# Build SSH options
$SshOpts = @("-p", $SshPort)
if ($KeyPath -ne "") {
    if (-not (Test-Path $KeyPath)) {
        Write-ErrorAndExit "SSH key not found: $KeyPath"
    }
    $SshOpts += @("-i", $KeyPath)
}

# Default API URL
if ($ApiUrl -eq "") {
    $ApiUrl = "http://${Server}:${BackendPort}"
    Write-Host "Using default API URL: $ApiUrl"
}

# ============================================================
# Build
# ============================================================
if (-not $SkipBuild) {
    if (-not $BackendOnly) {
        Write-Log "Building Frontend"
        Push-Location $FrontendDir

        if (-not (Test-Path "package.json")) {
            Write-ErrorAndExit "package.json not found in $FrontendDir"
        }

        npm install
        if ($LASTEXITCODE -ne 0) { Write-ErrorAndExit "npm install failed for frontend." }

        $env:REACT_APP_API_URL = $ApiUrl
        npm run build
        if ($LASTEXITCODE -ne 0) { Write-ErrorAndExit "Frontend build failed." }
        $env:REACT_APP_API_URL = $null

        if (-not (Test-Path "build")) {
            Write-ErrorAndExit "Frontend build failed - build/ directory not found."
        }
        Write-Host "Frontend build complete."
        Pop-Location
    }

    if (-not $FrontendOnly) {
        Write-Log "Building Backend"
        Push-Location $BackendDir

        if (-not (Test-Path "package.json")) {
            Write-ErrorAndExit "package.json not found in $BackendDir"
        }

        npm install
        if ($LASTEXITCODE -ne 0) { Write-ErrorAndExit "npm install failed for backend." }

        npm run build
        if ($LASTEXITCODE -ne 0) { Write-ErrorAndExit "Backend build failed." }

        if (-not (Test-Path "dist\server.js")) {
            Write-ErrorAndExit "Backend build failed - dist\server.js not found."
        }
        Write-Host "Backend build complete."
        Pop-Location
    }
}
else {
    Write-Host "Skipping build step (-SkipBuild)."
}

# ============================================================
# Deploy
# ============================================================

# Use SCP for file transfer (available by default on Windows 10+)
# Note: For large deployments, consider installing rsync via WSL or Git Bash

if (-not $BackendOnly) {
    Write-Log "Deploying Frontend"

    if (-not (Test-Path $LocalFrontendBuild)) {
        Write-ErrorAndExit "Frontend build directory not found: $LocalFrontendBuild"
    }

    # Upload frontend build artifacts using SCP
    $ScpArgs = @("-P", $SshPort, "-r")
    if ($KeyPath -ne "") {
        $ScpArgs += @("-i", $KeyPath)
    }

    # First, clean remote directory
    $CleanCmd = "rm -rf ${RemoteFrontendPath}* 2>/dev/null; mkdir -p ${RemoteFrontendPath}"
    & ssh @SshOpts "${User}@${Server}" $CleanCmd
    if ($LASTEXITCODE -ne 0) { Write-ErrorAndExit "Failed to clean remote frontend directory." }

    # Upload build files
    & scp @ScpArgs "${LocalFrontendBuild}\*" "${User}@${Server}:${RemoteFrontendPath}"
    if ($LASTEXITCODE -ne 0) { Write-ErrorAndExit "Frontend deployment failed." }

    Write-Host "Frontend deployed to ${Server}:${RemoteFrontendPath}"
}

if (-not $FrontendOnly) {
    Write-Log "Deploying Backend"

    if (-not (Test-Path $LocalBackendBundle)) {
        Write-ErrorAndExit "Backend bundle not found: $LocalBackendBundle"
    }

    # Ensure remote directory exists
    $MkdirCmd = "mkdir -p ${RemoteBackendPath}"
    & ssh @SshOpts "${User}@${Server}" $MkdirCmd

    # Upload backend bundle
    $ScpArgs = @("-P", $SshPort)
    if ($KeyPath -ne "") {
        $ScpArgs += @("-i", $KeyPath)
    }
    & scp @ScpArgs $LocalBackendBundle "${User}@${Server}:${RemoteBackendPath}"
    if ($LASTEXITCODE -ne 0) { Write-ErrorAndExit "Backend deployment failed." }

    Write-Host "Backend deployed to ${Server}:${RemoteBackendPath}"
}

# ============================================================
# Restart Services
# ============================================================
Write-Log "Restarting Services on $Server"

$RestartCommands = @()

if (-not $FrontendOnly) {
    $RestartCommands += "cd /var/www/pokemon-backend && NODE_ENV=production PORT=${BackendPort} pm2 restart pokemon-api 2>/dev/null || NODE_ENV=production PORT=${BackendPort} pm2 start server.js --name pokemon-api"
}

if (-not $BackendOnly) {
    $RestartCommands += "sudo systemctl reload nginx"
}

$RemoteCmd = $RestartCommands -join " && "
& ssh @SshOpts "${User}@${Server}" $RemoteCmd
if ($LASTEXITCODE -ne 0) {
    Write-Host "WARNING: Service restart may have partially failed. Check server logs." -ForegroundColor Yellow
}

# ============================================================
# Done
# ============================================================
Write-Log "Deploy Complete"
Write-Host "Frontend: http://${Server}:${FrontendPort}"
Write-Host "Backend:  http://${Server}:${BackendPort}"
Write-Host ""
Write-Host "Verify with:"
Write-Host "  curl http://${Server}:${BackendPort}/health"
Write-Host "  Open http://${Server}:${FrontendPort} in your browser"
