#!/usr/bin/env bash
# ==============================================================================
# WoW Killboard — Production Linux VPS Automated Provisioning Script
# Supported OS: Ubuntu 22.04 / 24.04 LTS, Debian 11 / 12
# Recommended Hardware: 1 vCPU, 1GB RAM, 10GB+ SSD ($3.50 - $4.00 / month)
# ==============================================================================
set -euo pipefail

# Visual formatting
BOLD='\033[1m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}"
echo "=================================================================="
echo "    WoW Killboard — Dedicated Linux VPS Bootstrap Installer       "
echo "    FastAPI Backend • Caddy HTTPS • Systemd • Persistent SQLite   "
echo "=================================================================="
echo -e "${NC}"

# Check for root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}[ERROR] This setup script must be run as root (or with sudo).${NC}"
    exit 1
fi

DOMAIN="${1:-}"
if [ -z "$DOMAIN" ]; then
    echo -e "${YELLOW}[PROMPT] Please enter your domain name for automated HTTPS SSL (e.g. killboard.yourdomain.com):${NC}"
    read -rp "Domain: " DOMAIN
fi

if [ -z "$DOMAIN" ]; then
    echo -e "${YELLOW}[WARNING] No domain entered. Falling back to HTTP on port 80 (IP-based access).${NC}"
fi

APP_DIR="/opt/wowkillboard"
APP_USER="wowkillboard"

echo -e "${GREEN}[1/7] Updating system package index and installing base dependencies...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends \
    curl \
    git \
    sqlite3 \
    python3 \
    python3-venv \
    python3-pip \
    ufw \
    ca-certificates \
    debian-keyring \
    debian-archive-keyring \
    apt-transport-https

echo -e "${GREEN}[2/7] Configuring UFW Firewall (Allow SSH, HTTP, HTTPS)...${NC}"
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP Caddy'
ufw allow 443/tcp comment 'HTTPS Caddy'
ufw --force enable

echo -e "${GREEN}[3/7] Installing modern Caddy Web Server (Native HTTP/3 & Automatic Let's Encrypt SSL)...${NC}"
if ! command -v caddy &>/dev/null; then
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg --yes
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
    apt-get update -y
    apt-get install -y caddy
fi

echo -e "${GREEN}[4/7] Creating service user '${APP_USER}' and application directory...${NC}"
if ! id "${APP_USER}" &>/dev/null; then
    useradd -r -s /usr/sbin/nologin -d "${APP_DIR}" -m "${APP_USER}"
fi

mkdir -p "${APP_DIR}/web"
mkdir -p "${APP_DIR}/data"
mkdir -p "${APP_DIR}/backups"

# If repository cloned elsewhere, copy files, else fetch from git
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ "${SCRIPT_DIR}" != "${APP_DIR}" ] && [ -f "${SCRIPT_DIR}/web/server.py" ]; then
    echo -e "${CYAN}[INFO] Deploying from local repository checkout at ${SCRIPT_DIR}...${NC}"
    cp -r "${SCRIPT_DIR}/web" "${APP_DIR}/"
    cp -r "${SCRIPT_DIR}/sync" "${APP_DIR}/" 2>/dev/null || true
    cp -f "${SCRIPT_DIR}/requirements.txt" "${APP_DIR}/" 2>/dev/null || true
fi

echo -e "${GREEN}[5/7] Provisioning Python virtual environment and dependencies...${NC}"
python3 -m venv "${APP_DIR}/venv"
"${APP_DIR}/venv/bin/pip" install --upgrade pip setuptools wheel
if [ -f "${APP_DIR}/requirements.txt" ]; then
    "${APP_DIR}/venv/bin/pip" install -r "${APP_DIR}/requirements.txt"
fi
"${APP_DIR}/venv/bin/pip" install Flask flask-cors gunicorn requests

# Link persistent database to data directory
chown -R "${APP_USER}:${APP_USER}" "${APP_DIR}"

echo -e "${GREEN}[6/7] Installing systemd daemon service: wowkillboard.service...${NC}"
cat <<EOF > /etc/systemd/system/wowkillboard.service
[Unit]
Description=WoW Killboard — Frontline Combat & Marks of Spite Platform
After=network.target

[Service]
Type=simple
User=${APP_USER}
Group=${APP_USER}
WorkingDirectory=${APP_DIR}
Environment="PYTHONUNBUFFERED=1"
Environment="PORT=8080"
Environment="DB_PATH=${APP_DIR}/data/killboard.db"
ExecStart=${APP_DIR}/venv/bin/python web/server.py
Restart=always
RestartSec=5s

# Security Hardening
ProtectSystem=full
PrivateTmp=true
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable wowkillboard.service
systemctl restart wowkillboard.service

echo -e "${GREEN}[7/7] Configuring Caddy Reverse Proxy & HTTPS...${NC}"
if [ -n "$DOMAIN" ]; then
    cat <<EOF > /etc/caddy/Caddyfile
${DOMAIN} {
    # Automatic Let's Encrypt / ZeroSSL HTTPS with HTTP/2 and HTTP/3
    encode zstd gzip

    # Production Security Headers
    header {
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    }

    # Static asset caching
    @static {
        path /static/*
    }
    header @static Cache-Control "public, max-age=86400"

    # API and Web Application Proxy
    reverse_proxy 127.0.0.1:8080 {
        header_up Host {host}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
    }
}
EOF
else
    cat <<EOF > /etc/caddy/Caddyfile
:80 {
    encode zstd gzip

    header {
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
    }

    reverse_proxy 127.0.0.1:8080
}
EOF
fi

systemctl reload caddy

# Set up automated daily SQLite backup cron job
cat <<'EOF' > /usr/local/bin/wowkillboard-backup.sh
#!/usr/bin/env bash
set -euo pipefail
BACKUP_DIR="/opt/wowkillboard/backups"
DB_FILE="/opt/wowkillboard/data/killboard.db"
DATE=$(date +%Y%m%d_%H%M%S)

if [ -f "$DB_FILE" ]; then
    mkdir -p "$BACKUP_DIR"
    sqlite3 "$DB_FILE" ".backup '${BACKUP_DIR}/killboard_${DATE}.db'"
    gzip "${BACKUP_DIR}/killboard_${DATE}.db"
    # Keep last 14 daily backups
    find "$BACKUP_DIR" -name "killboard_*.db.gz" -type f -mtime +14 -delete
fi
EOF
chmod +x /usr/local/bin/wowkillboard-backup.sh

# Cron daily at 03:30 AM
CRON_JOB="30 3 * * * /usr/local/bin/wowkillboard-backup.sh >/dev/null 2>&1"
( crontab -l 2>/dev/null | grep -Fv "wowkillboard-backup.sh" ; echo "$CRON_JOB" ) | crontab -

echo -e "${CYAN}${BOLD}"
echo "=================================================================="
echo "    WoW Killboard — VPS Provisioning Complete!                    "
echo "=================================================================="
echo -e "${NC}"
if [ -n "$DOMAIN" ]; then
    echo -e "  🌐 Public Web Platform:  ${GREEN}https://${DOMAIN}${NC}"
    echo -e "  📡 Ingestion API:        ${GREEN}https://${DOMAIN}/api/killmail${NC}"
else
    SERVER_IP=$(curl -s4 ifconfig.me || echo "YOUR_SERVER_IP")
    echo -e "  🌐 Public Web Platform:  ${GREEN}http://${SERVER_IP}${NC}"
    echo -e "  📡 Ingestion API:        ${GREEN}http://${SERVER_IP}/api/killmail${NC}"
fi
echo ""
echo -e "  ⚙️ Service Status:       systemctl status wowkillboard"
echo -e "  📜 Service Logs:         journalctl -u wowkillboard -f"
echo -e "  🔒 Caddy Status:         systemctl status caddy"
echo -e "  💾 Database Location:    /opt/wowkillboard/data/killboard.db"
echo -e "  📦 Daily Backup Cron:    /usr/local/bin/wowkillboard-backup.sh"
echo "=================================================================="
