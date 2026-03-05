# Pokemon Project — Production Deployment

## Architecture

```
Dev Machine                    Server (Linux)
┌──────────────────────┐                 ┌──────────────────────────────┐
│ frontend/            │                 │                              │
│   npm run build ─────┼── rsync ──────> │ /var/www/pokemon-frontend/   │
│   → build/           │                 │   Nginx :21050 (static files)│
│                      │                 │                              │
│ backend/             │                 │ /var/www/pokemon-backend/    │
│   npm run build ─────┼── rsync ──────> │   PM2 + Node :21051 (API)   │
│   → dist/server.js   │                 │                              │
└──────────────────────┘                 └──────────────────────────────┘
```

| Service  | Port  | Technology          |
|----------|-------|---------------------|
| Frontend | 21050 | Nginx (static files)|
| Backend  | 21051 | Node.js via PM2     |

---

## 1. One-Time Server Setup

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

## 2. Build Locally (Dev Machine)

Run these in PowerShell before every deploy.

### 2.1 Build Frontend

```powershell
cd pokemon_project\frontend
npm install
$env:REACT_APP_API_URL="http://<server>:21051"; npm run build
```

This produces the `frontend\build\` folder with optimized static files.

### 2.2 Build Backend

```powershell
cd pokemon_project\backend
npm install
npm run build
```

This bundles everything (Express, CORS, app code) into a single `backend\dist\server.js` file.
No `node_modules` needed on the server.

---

## 3. Deploy

From Git Bash:

deploy script
```
#!/usr/bin/env bash

SSH_PORT=
PRIVATE_KEY_PATH=
SERVER=
USER=testrigor

LOCAL_FRONTEND_BUILD=pokemon_project/frontend/build/
LOCAL_BACKEND_BUNDLE=pokemon_project/backend/dist/server.js

REMOTE_FRONTEND_PATH=/var/www/pokemon-frontend/
REMOTE_BACKEND_PATH=/var/www/pokemon-backend/

SSH_CMD="ssh -p ${SSH_PORT} -i ${PRIVATE_KEY_PATH}"

echo "=== Deploying Frontend ==="
rsync -ravzhe "${SSH_CMD}" --progress --delete \
  ${LOCAL_FRONTEND_BUILD} ${USER}@${SERVER}:${REMOTE_FRONTEND_PATH}

echo ""
echo "=== Deploying Backend ==="
rsync -avzhe "${SSH_CMD}" --progress \
  ${LOCAL_BACKEND_BUNDLE} ${USER}@${SERVER}:${REMOTE_BACKEND_PATH}

echo ""
echo "=== Restarting services ==="
${SSH_CMD} ${USER}@${SERVER} << 'ENDSSH'
  cd /var/www/pokemon-backend
  NODE_ENV=production PORT=21051 pm2 restart pokemon-api 2>/dev/null || \
  NODE_ENV=production PORT=21051 pm2 start server.js --name pokemon-api
  sudo systemctl reload nginx
ENDSSH

echo ""
echo "=== Deploy complete ==="
echo "Frontend: http://${SERVER}:21050"
echo "Backend:  http://${SERVER}:21051"
```

```bash
bash deploy.sh
```

The script uploads the built artifacts via rsync and restarts the services.

### What gets uploaded

| Artifact                 | Size   | Destination on server        |
|--------------------------|--------|------------------------------|
| `frontend/build/*`      | ~1 MB  | `/var/www/pokemon-frontend/` |
| `backend/dist/server.js`| ~1 MB  | `/var/www/pokemon-backend/`  |

No source code, no `node_modules`, no `npm install` on the server.

---

## 4. Verify

```bash
# Backend health check
curl http://<server>:21051/health

# Frontend
# Open http://<server>:21050 in your browser
```

---

## 5. Useful Server Commands

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

## 6. Troubleshooting

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
