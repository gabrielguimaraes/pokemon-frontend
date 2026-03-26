# Pokemon Project — Production Deployment

Cross-platform deployment guide for deploying the Pokemon full-stack application (React frontend + Express backend) from **Linux**, **Windows**, or **macOS** to a remote Linux server.

## Architecture

```
Dev Machine (Linux/Mac/Windows)         Server (Linux)
┌──────────────────────────┐           ┌──────────────────────────────┐
│ frontend/                │           │                              │
│   npm run build ─────────┼─ deploy ──│ /var/www/pokemon-frontend/   │
│   → build/               │           │   Nginx :21050 (static files)│
│                          │           │                              │
│ backend/                 │           │ /var/www/pokemon-backend/    │
│   npm run build ─────────┼─ deploy ──│   PM2 + Node :21051 (API)   │
│   → dist/server.js       │           │                              │
└──────────────────────────┘           └──────────────────────────────┘
```

| Service  | Port  | Technology           |
|----------|-------|----------------------|
| Frontend | 21050 | Nginx (static files) |
| Backend  | 21051 | Node.js via PM2      |

---

## Prerequisites

### All Platforms

- **Node.js 18 LTS** or later (for building frontend and backend)
- **npm** (comes with Node.js)
- **SSH access** to the target Linux server

### Linux

- `rsync` (usually pre-installed, or: `sudo apt install rsync`)
- `ssh` (usually pre-installed, or: `sudo apt install openssh-client`)
- `bash` 4.0+

### macOS

- `rsync` (pre-installed; optionally upgrade via `brew install rsync` for rsync 3.x)
- `ssh` (pre-installed)
- `bash` 3.2+ (pre-installed) or `zsh` (default on macOS Catalina+)
- Optional: Install Homebrew for easier dependency management: https://brew.sh

### Windows

- **Windows 10 version 1809+** or **Windows 11** (for built-in OpenSSH)
- **OpenSSH Client** — enable via: Settings → Apps → Optional Features → OpenSSH Client
- **PowerShell 5.1+** (pre-installed on Windows 10+)
- Optional: **Git Bash** (from Git for Windows) if you prefer using `deploy.sh` instead of `deploy.ps1`
- Optional: **WSL** (Windows Subsystem for Linux) for a full Linux environment on Windows

---

## 1. One-Time Server Setup

These steps are performed once on the target Linux server.

### 1.1 Install Node.js

```bash
# Using nvm (recommended)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc
nvm install 18
```

### 1.2 Install PM2

```bash
sudo npm install -g pm2
```

### 1.3 Install Nginx

```bash
sudo apt install -y nginx
```

### 1.4 Create directories

```bash
sudo mkdir -p /var/www/pokemon-frontend
sudo mkdir -p /var/www/pokemon-backend
sudo chown -R testrigor:testrigor /var/www/pokemon-frontend
sudo chown -R testrigor:testrigor /var/www/pokemon-backend
```

### 1.5 Configure Nginx

Create the config file:

```bash
sudo nano /etc/nginx/sites-available/pokemon
```

Paste this:

```nginx
server {
    listen 21050;
    server_name _;

    root /var/www/pokemon-frontend;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

Enable it and restart:

```bash
sudo ln -s /etc/nginx/sites-available/pokemon /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx
```

### 1.6 Set up PM2 to survive reboots

After the first deploy (step 3), run:

```bash
pm2 save
pm2 startup
```

Follow the command it prints to enable auto-start on boot.

---

## 2. Deploy Scripts

Three deployment scripts are provided. Use the one that matches your operating system:

| Script        | Platform         | Tool used for transfer |
|---------------|------------------|----------------------|
| `deploy.sh`   | Linux, macOS, Git Bash (Windows) | rsync over SSH       |
| `deploy.ps1`  | Windows (PowerShell)             | scp over SSH (OpenSSH) |
| `deploy.bat`  | Windows (CMD)                    | Calls deploy.ps1     |

### 2.1 Deploy from Linux or macOS

```bash
# Make the script executable (first time only)
chmod +x deploy.sh

# Basic deployment
./deploy.sh --server <SERVER_IP> --key ~/.ssh/id_rsa

# With custom SSH port and user
./deploy.sh --server <SERVER_IP> --port 2222 --key ~/.ssh/id_rsa --user admin

# Skip build (deploy existing artifacts)
./deploy.sh --server <SERVER_IP> --key ~/.ssh/id_rsa --skip-build

# Deploy only frontend or backend
./deploy.sh --server <SERVER_IP> --key ~/.ssh/id_rsa --frontend-only
./deploy.sh --server <SERVER_IP> --key ~/.ssh/id_rsa --backend-only
```

You can also use environment variables instead of flags:

```bash
export DEPLOY_SERVER=192.168.1.100
export DEPLOY_SSH_PORT=22
export DEPLOY_SSH_KEY=~/.ssh/id_rsa
export DEPLOY_USER=testrigor
export DEPLOY_API_URL=http://192.168.1.100:21051

./deploy.sh
```

#### macOS-Specific Notes

- macOS ships with rsync 2.6.x by default. This works fine for deployment.
- For faster transfers, install rsync 3.x via Homebrew: `brew install rsync`
- macOS uses `zsh` as the default shell since Catalina, but `deploy.sh` uses `#!/usr/bin/env bash` so it will use `bash` regardless.
- If deploying to a local macOS machine (instead of a Linux server), use `launchd` instead of `systemd`/PM2 for process management.

### 2.2 Deploy from Windows (PowerShell)

```powershell
# Basic deployment
.\deploy.ps1 -Server <SERVER_IP> -KeyPath C:\Users\you\.ssh\id_rsa

# With custom SSH port and user
.\deploy.ps1 -Server <SERVER_IP> -SshPort 2222 -KeyPath C:\Users\you\.ssh\id_rsa -User admin

# Skip build (deploy existing artifacts)
.\deploy.ps1 -Server <SERVER_IP> -KeyPath C:\Users\you\.ssh\id_rsa -SkipBuild

# Deploy only frontend or backend
.\deploy.ps1 -Server <SERVER_IP> -KeyPath C:\Users\you\.ssh\id_rsa -FrontendOnly
.\deploy.ps1 -Server <SERVER_IP> -KeyPath C:\Users\you\.ssh\id_rsa -BackendOnly

# Custom API URL
.\deploy.ps1 -Server <SERVER_IP> -KeyPath C:\Users\you\.ssh\id_rsa -ApiUrl "http://myserver:21051"
```

If PowerShell script execution is restricted, run with:

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy.ps1 -Server <SERVER_IP> -KeyPath <KEY_PATH>
```

### 2.3 Deploy from Windows (CMD)

```cmd
deploy.bat -Server <SERVER_IP> -KeyPath C:\Users\you\.ssh\id_rsa
```

The `.bat` file is a thin wrapper that calls `deploy.ps1` with the same arguments.

### 2.4 Deploy from Windows (Git Bash / WSL)

If you have **Git Bash** (from Git for Windows) or **WSL** installed, you can use the Linux script:

```bash
# Git Bash
bash deploy.sh --server <SERVER_IP> --key /c/Users/you/.ssh/id_rsa

# WSL
./deploy.sh --server <SERVER_IP> --key ~/.ssh/id_rsa
```

---

## 3. Build Locally (Manual)

If you prefer to build manually before deploying with `--skip-build`:

### 3.1 Build Frontend

**Linux / macOS:**
```bash
cd pokemon-frontend
npm install
REACT_APP_API_URL="http://<server>:21051" npm run build
```

**Windows (PowerShell):**
```powershell
cd pokemon-frontend
npm install
$env:REACT_APP_API_URL="http://<server>:21051"; npm run build
```

**Windows (CMD):**
```cmd
cd pokemon-frontend
npm install
set REACT_APP_API_URL=http://<server>:21051 && npm run build
```

This produces the `build/` folder with optimized static files.

### 3.2 Build Backend

**All platforms:**
```bash
cd pokemon-backend
npm install
npm run build
```

This bundles everything (Express, CORS, app code) into a single `dist/server.js` file.
No `node_modules` needed on the server.

---

## 4. What Gets Uploaded

| Artifact                  | Size   | Destination on server        |
|---------------------------|--------|------------------------------|
| `frontend/build/*`       | ~1 MB  | `/var/www/pokemon-frontend/` |
| `backend/dist/server.js` | ~1 MB  | `/var/www/pokemon-backend/`  |

No source code, no `node_modules`, no `npm install` on the server.

---

## 5. Verify

```bash
# Backend health check
curl http://<server>:21051/health

# Frontend
# Open http://<server>:21050 in your browser
```

---

## 6. Useful Server Commands

```bash
# Check backend status
pm2 status

# View backend logs
pm2 logs pokemon-api

# Restart backend
NODE_ENV=production PORT=21051 pm2 restart pokemon-api

# Stop backend
pm2 stop pokemon-api

# Check Nginx status
sudo systemctl status nginx

# Reload Nginx config (after editing)
sudo systemctl reload nginx

# View Nginx error logs
sudo tail -f /var/log/nginx/error.log
```

---

## 7. Troubleshooting

### All Platforms

**Frontend shows blank page or API errors:**
- Verify the backend is running: `curl http://<server>:21051/health`
- Check that `REACT_APP_API_URL` was set correctly during the frontend build

**Port already in use:**
- Find the process: `sudo lsof -i :21051`
- Kill it: `pm2 delete pokemon-api` then redeploy

**Nginx returns 502 or 404:**
- Check config syntax: `sudo nginx -t`
- Check the root path exists: `ls /var/www/pokemon-frontend/index.html`

**PM2 process keeps crashing:**
- Check logs: `pm2 logs pokemon-api --lines 50`
- Test manually: `cd /var/www/pokemon-backend && NODE_ENV=production PORT=21051 node server.js`

**Node.js version issue (react-scripts build fails):**
- react-scripts 5.0.1 requires Node 18 LTS
- Use nvm to switch: `nvm use 18` before building the frontend

### Linux-Specific

**rsync not found:**
```bash
sudo apt install rsync    # Debian/Ubuntu
sudo yum install rsync    # RHEL/CentOS
```

### macOS-Specific

**rsync warnings about extended attributes:**
```bash
# Use --no-perms --no-owner --no-group flags or upgrade rsync:
brew install rsync
```

**bash version too old:**
```bash
# Check version
bash --version
# Upgrade if needed
brew install bash
```

### Windows-Specific

**ssh: command not found:**
- Enable OpenSSH Client: Settings → Apps → Optional Features → Add a Feature → OpenSSH Client
- Or install Git for Windows which includes Git Bash with SSH support

**PowerShell execution policy error:**
```powershell
# Run with bypass
powershell -ExecutionPolicy Bypass -File .\deploy.ps1 -Server <SERVER_IP> -KeyPath <KEY_PATH>

# Or change the policy permanently (admin PowerShell)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**scp: Permission denied:**
- Ensure the SSH key has correct permissions. On Windows, right-click the key file → Properties → Security → ensure only your user has access.
- Try: `icacls <keyfile> /inheritance:r /grant:r "%USERNAME%:R"`

**Line ending issues (CRLF vs LF):**
- If using Git Bash with `deploy.sh`, ensure the file has LF line endings
- Configure Git: `git config core.autocrlf input`

---

## 8. npm Deploy Scripts

Both `package.json` files include deploy-related npm scripts for convenience:

**Frontend (`pokemon-frontend/package.json`):**
```bash
npm run deploy              # Deploy using deploy.sh (Linux/Mac)
npm run deploy:skip-build   # Deploy without rebuilding
```

**Backend (`pokemon-backend/package.json`):**
```bash
npm run deploy              # Deploy using deploy.sh (Linux/Mac)
npm run deploy:skip-build   # Deploy without rebuilding
```

> Note: npm scripts use `deploy.sh` which requires bash. On Windows, use the PowerShell script directly or run through Git Bash / WSL.
