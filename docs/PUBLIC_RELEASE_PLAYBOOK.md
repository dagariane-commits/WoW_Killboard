# Public Release & Distribution Playbook

This playbook provides the operational procedures for packaging, publishing, hosting, and distributing **WoW Killboard** to the worldwide World of Warcraft community.

---

## 0. Domain & Pre-Flight Release Sequence (Domain First)

Before submitting the addon archive to CurseForge, execute the release sequence in this strict order:

```mermaid
flowchart TD
    S1["1. Register Domain\n(e.g. wowkillboard.com via Cloudflare)"] --> S2["2. Point DNS A-Record\nMap @ and api to <YOUR_VPS_PUBLIC_IP>"]
    S2 --> S3["3. Automatic HTTPS / SSL\nCaddy provisions Let's Encrypt certificate"]
    S3 --> S4["4. Update In-Game URLs\nSet KB.WebDomain in Config.lua & recompile Sync.exe"]
    S4 --> S5["5. Rebuild & Submit\nWoWKillboard-v1.0.5.zip to CurseForge"]
```

### Why Domain First?
1. **CurseForge Human Moderation**: Addons linking to trusted, branded HTTPS domains pass human review faster than raw IP addresses.
2. **Zero Browser "Not Secure" Warnings**: When players click `/kb web`, `/armory`, or `/feedback`, browsers open a green padlock connection (`https://`).
3. **No Re-Submission Overhead**: Registering the domain first means the initially published addon zip is permanent, avoiding immediate version increments.

---

## 1. Addon Packaging & Manifest Standards

### The Interface Number Reference
Blizzard uses client interface numbers in the `.toc` file to notify users if an addon is out of date:
- **Classic Era / Anniversary (1.15.x)**: `11506`, `11507`
- **Forever Beta**: `16001`
- **Retail (11.x)**: `110007`

The `WoWKillboard.toc` manifest includes multi-client declarations:
```text
## Interface: 11506, 11507, 110007, 16001
## Title: WoW Killboard
## Notes: Community killboard tracking PvP kills, 1v1 duels, battlegrounds, bounties, and PvE deaths.
## Version: 1.0.5
## Author: Dagariane
## SavedVariables: WoWKillboardDB, WoWKillboardSettings, WoWKillboardDebtLedger, WoWKillboardBounties, WoWKillboardDistress, WoWKillboardEvents
```

### Packaging Script
Run [`package_addon.bat`](../package_addon.bat) or PowerShell:
```powershell
Compress-Archive -Path "Addon\WoWKillboard" -DestinationPath "WoWKillboard-v1.0.5.zip" -Force
```

---

## 2. Portal Distribution Channels

### A. CurseForge / Overwolf

> [!IMPORTANT]
> **CurseForge & Git Lockstep Parity (MANDATORY PROCEDURE)**:
> Whenever you push or upload an update to CurseForge, you **MUST** ensure the exact identical release is committed, tagged (`git tag -a vX.Y.Z -m "Release vX.Y.Z"`), and pushed to GitHub (`git push origin main --tags`).
> - CurseForge and GitHub must never drift out of sync.
> - The packaged zip (e.g., `WoWKillboard-v1.0.5.zip`) must be generated from the exact committed source tree.
> - Release zips must be mirrored to repository root and `web/static/` via `python scripts/deploy.py` so the direct download button on wowkillboard.com delivers the same build.

1. Log into the [CurseForge Author Portal](https://authors.curseforge.com/).
2. Create New Project -> Category: `PvP` / `Combat` / `Information`.
3. Description template:
   > Hey everyone! I'm just a dude who used AI to help create my very first World of Warcraft addon.
   >
   > **WoW Killboard** is a community killboard that tracks your open-world PvP kills, certified 1v1 duels, battleground stats, blood bounties, and wilderness PvE deaths. It works across WoW Forever, Classic Era, Anniversary, and Retail.
   >
   > I really hope you like it! Please drop your feedback, feature ideas, or bug reports on CurseForge or our website so I can continue enhancing it.
4. Upload `WoWKillboard-v1.0.5.zip`.
5. Supported Flavors: Select `WoW Classic`, `Classic Era`, and `Mainline`.
6. Upload promotional banner (`../assets/curseforge/logo.png`) and in-game UI screenshots.

### B. Wago.io
1. Access [Wago Addons](https://addons.wago.io/).
2. Connect GitHub repository for automated release ingestion via webhooks.
3. Every tagged GitHub release (`v1.0.5`) automatically updates Wago.

### C. WowInterface
1. Create listing under `PvP / Combat Log` category.
2. Provide direct download mirror.

---

## 3. Desktop Sync Distribution (`WoWKillboardSync.exe`)

Players who want their combat data to sync automatically to the public web killboard do not need Python.

### Building the Executable
Use [`Build_Desktop_Sync_EXE.bat`](../Build_Desktop_Sync_EXE.bat):
```cmd
pyinstaller --onefile --name "WoWKillboardSync" sync\watcher.py
```
- Produces a single, self-contained **8.8 MB** binary in `dist/WoWKillboardSync.exe`.
- Distribute this binary on GitHub Releases and the web platform download page.

### End-User Experience
1. Download `WoWKillboardSync.exe`.
2. Double-click the file.
3. The executable auto-scans drives `C:`, `D:`, and `E:`, detects `WTF/Account/*/SavedVariables/WoWKillboard.lua`, and begins streaming telemetry to `https://wowkillboard.com`.

---

## 4. Web Platform Deployment (Production Cloud)

The web tier is containerized and cloud-ready via the included [`Dockerfile`](../Dockerfile).

### Production Deployment Options

#### Option A: Docker on Any Linux VPS (DigitalOcean / Linode / AWS)
```bash
# Build the container
docker build -t wow-killboard .

# Run with persistent volume for SQLite
docker run -d \
  -p 80:8080 \
  -v /var/data/killboard:/app/data \
  --name killboard \
  wow-killboard
```

#### Option B: Platform as a Service (Railway / Render / Fly.io)
Deploy directly using the repository's [`Procfile`](../Procfile):
```text
web: gunicorn -w 4 -b 0.0.0.0:$PORT web.server:app
```

---

## 5. Discord Webhook Integration

Guilds and communities can stream real-time kills to their Discord server by hooking into the Flask server's `/api/sync/push` endpoint.

### Embed Payload Specification
```json
{
  "embeds": [{
    "title": "⚔️ Confirmed Killmail: Dagariane defeated Xxroguexx",
    "description": "Certified Solo Kill in Stranglethorn Vale (54.2, 71.8)",
    "color": 65519,
    "fields": [
      { "name": "Killer", "value": "Dagariane (Level 60 Paladin)", "inline": true },
      { "name": "Victim", "value": "Xxroguexx (Level 60 Rogue)", "inline": true },
      { "name": "Engagement", "value": "Open World PvP", "inline": true }
    ],
    "footer": { "text": "WoW Killboard v1.0.0" }
  }]
}
```
This turns any guild's Discord server into a live PvP War Room.

---

## 6. GitHub Security & Automated CI/CD Protocol

The repository is hardened with GitHub Advanced Security and continuous verification workflows:

### A. GitHub Advanced Security CodeQL Scanning (`.github/workflows/codeql.yml`)
- **Matrix Analysis**: Performs deep AST code analysis across Python (backend services, API routes, data parser) and JavaScript (interactive web portal UI).
- **Automated Triggers**: Runs on every pull request and push targeting `main`, as well as a weekly automated Monday cron audit (`0 12 * * 1`).
- **SARIF Alert Integration**: Automatically publishes vulnerability findings directly to GitHub Security Center.

### B. Secret Scanning & Push Protection
- **Status**: Enabled across the repository.
- **Push Protection**: Blocks commits containing accidentally exposed tokens, Discord webhook URLs, or cloud credentials before they reach the remote repository.
- **OpSec Guardrails**: Telemetry payloads and server configs strictly utilize environment variables (`DISCORD_DEFENSE_WEBHOOK_URL`, `ADMIN_SECRET_KEY`) or local untracked config files (`wowkb_sync_config.json`).

### C. Continuous Integration Test Suite (`.github/workflows/ci.yml`)
- **Automated Verification**: Automatically runs on every push and PR using Python 3.12 on `ubuntu-latest`.
- **Lua Validation**: Executes `tests/validate_lua.py` to ensure all 13 addon modules compile cleanly with zero syntax errors or Blizzard UI taint.
- **Unit Testing**: Executes `python -m unittest discover tests` to guarantee 100% test passing across the 20-point regression suite.

