#
# build.ps1 - Build script for Pokemon Frontend (Windows)
#
# Builds the React frontend with the specified API URL.
#
# Usage:
#   .\build.ps1 [-ApiUrl <url>] [-Clean]
#
# Examples:
#   .\build.ps1
#   .\build.ps1 -ApiUrl http://myserver.com:21051
#   .\build.ps1 -Clean -ApiUrl http://192.168.1.100:21051
#

param(
    [string]$ApiUrl = "http://localhost:3001",
    [switch]$Clean
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# ─── Functions ───────────────────────────────────────────────────────────────
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# ─── Pre-flight Checks ──────────────────────────────────────────────────────
foreach ($cmd in @("node", "npm")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-ErrorMessage "$cmd is not installed. Please install Node.js (v18+) and npm."
        exit 1
    }
}

Write-Info "Node.js version: $(node --version)"
Write-Info "npm version: $(npm --version)"
Write-Host ""

# ─── Build ───────────────────────────────────────────────────────────────────
Push-Location $ScriptDir

try {
    if ($Clean -and (Test-Path "build")) {
        Write-Info "Cleaning previous build artifacts..."
        Remove-Item -Recurse -Force "build"
    }

    Write-Info "Installing dependencies..."
    & npm install
    if ($LASTEXITCODE -ne 0) { throw "npm install failed" }

    Write-Info "Building frontend with REACT_APP_API_URL=$ApiUrl..."
    $env:REACT_APP_API_URL = $ApiUrl
    & npm run build
    if ($LASTEXITCODE -ne 0) { throw "npm run build failed" }

    if (Test-Path "build") {
        Write-Success "Frontend build complete! Output: $ScriptDir\build\"
    }
    else {
        Write-ErrorMessage "Build failed - build/ directory not created."
        exit 1
    }
}
finally {
    Remove-Item Env:\REACT_APP_API_URL -ErrorAction SilentlyContinue
    Pop-Location
}
