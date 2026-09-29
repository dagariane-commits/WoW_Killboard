# Dedicated Linux VPS Deployment Runbook

## Executive Summary & Architecture
This operational runbook details how to deploy the **WoW Killboard** web platform and ingestion backend to an independent, dedicated Linux Virtual Private Server (VPS) for **$3.50 – $4.00 / month**.

### Advantages Over Shared / Free Tier (Render):
- **0ms Cold-Start Latency**: The server never spins down or sleeps after 15 minutes of inactivity. Instant page loads for all players.
- **Persistent High-Speed SSD Storage**: SQLite database (`killboard.db`) resides on local NVMe/SSD storage and is never lost during reboots or container redeployments.
- **Automated HTTPS & HTTP/3**: Native modern Caddy reverse proxy automatically provisions and renews SSL/TLS certificates via Let's Encrypt / ZeroSSL with zero manual Certbot maintenance.
- **Complete Infrastructure Ownership**: Full root control, automated daily database backups, and custom domain mapping.

---

## Recommended VPS Providers ($3.50 – $4.00 / Month)

| Provider | Plan | Specs | Price | Location Recommendation |
| :--- | :--- | :--- | :--- | :--- |
| **AWS Lightsail** | 512MB RAM | 1 vCPU, 512MB RAM, 20GB SSD, 1TB Transfer | **$3.50 / mo** | us-east-1 (N. Virginia) or us-west-2 (Oregon) |
| **DigitalOcean** | Basic Droplet | 1 vCPU, 512MB RAM, 10GB NVMe SSD, 500GB Transfer | **$4.00 / mo** | NYC3, SFO3, or FRA1 |
| **Hetzner Cloud** | CX22 | 2 vCPU, 4GB RAM, 40GB NVMe SSD, 20TB Transfer | **€3.79 / mo** (~$4.10) | Nuremberg, Falkenstein, or Hillsboro (US) |
| **Linode / Akamai** | Nanode 1GB | 1 vCPU, 1GB RAM, 25GB SSD, 1TB Transfer | **$5.00 / mo** | Newark, Fremont, Frankfurt |

> **Recommended Choice**: **AWS Lightsail ($3.50/mo)** or **DigitalOcean ($4.00/mo)** with **Ubuntu 24.04 LTS** or **Debian 12**.

---

## 1-Command Automated Installation

### Step 1: Provision the VPS Instance
1. Log into your chosen provider (e.g., DigitalOcean, AWS Lightsail, or Hetzner).
2. Create a new instance:
   - **OS**: Ubuntu 24.04 LTS (x64) or Debian 12.
   - **Plan**: $3.50 or $4.00/month tier.
   - **Authentication**: SSH Key (Recommended) or Root Password.
3. Note your server's public IPv4 address (e.g., `198.51.100.42`).

### Step 2: Configure Domain DNS (Optional but Recommended)
In your domain registrar (Cloudflare, Namecheap, Google Domains, etc.), add an **A Record**:
- **Type**: `A`
- **Name**: `killboard` (or `@` for root)
- **Content**: `198.51.100.42` (your VPS public IP)
- **TTL**: Auto / 300s

### Step 3: Run the Bootstrap Script
SSH into your server:
```bash
ssh root@YOUR_SERVER_IP
```

Run the automated installer:
```bash
# Clone the repository
git clone https://github.com/YOUR_USER/WoW_Killboard.git /root/WoW_Killboard
cd /root/WoW_Killboard

# Execute the automated VPS setup script (pass your domain name)
bash deploy/setup_vps.sh killboard.yourdomain.com
```

If you do not have a domain yet, run:
```bash
bash deploy/setup_vps.sh
```
*(Caddy will serve HTTP directly over your server's IP address on port 80)*.

---

## System Architecture & Services

The installer configures four key components on the server:

```
[ Internet / Browser & WoWKillboardSync.exe ]
                       │
             HTTPS :443 / HTTP :80
                       ▼
       [ Caddy Web Server / Reverse Proxy ]
           (Automatic Let's Encrypt SSL)
                       │
              HTTP :8080 (Localhost)
                       ▼
    [ systemd: wowkillboard.service (FastAPI) ]
                       │
                       ▼
  [ Persistent SSD Storage: /opt/wowkillboard/data/killboard.db ]
                       │
             Daily Cron (03:30 AM)
                       ▼
  [ Compressed Backups: /opt/wowkillboard/backups/*.db.gz ]
```

---

## Connecting Desktop Sync (`WoWKillboardSync.exe`)

Once your VPS is online, tell your desktop sync agent to transmit combat telemetry to your new dedicated VPS instead of Render:

### Method 1: Local Configuration File (`wowkb_sync_config.json`)
Create a file named `wowkb_sync_config.json` in the same directory as `WoWKillboardSync.exe`:
```json
{
  "api_url": "https://killboard.yourdomain.com"
}
```

### Method 2: Environment Variable
```powershell
[System.Environment]::SetEnvironmentVariable('WOWKB_API_URL', 'https://killboard.yourdomain.com', 'User')
```

---

## Maintenance & Operations

### Checking Service Health
```bash
# Check FastAPI service status
systemctl status wowkillboard

# Tail live application logs
journalctl -u wowkillboard -f

# Check Caddy web server & SSL certificate status
systemctl status caddy
```

### Restarting the Application
```bash
systemctl restart wowkillboard
```

### Updating to the Latest Code
```bash
sudo git config --global --add safe.directory /opt/wowkillboard
cd /opt/wowkillboard
sudo git pull origin main
sudo systemctl restart wowkillboard
```

### Database Backups
Automated backups run daily at 03:30 AM via `/usr/local/bin/wowkillboard-backup.sh`. Backups older than 14 days are automatically pruned.
To run an immediate manual backup:
```bash
/usr/local/bin/wowkillboard-backup.sh
ls -lh /opt/wowkillboard/backups/
```
