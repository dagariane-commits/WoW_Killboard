# WoW Killboard — Master AI Session Handoff & Continuity Brief

> **Target Audience**: Any AI assistant (Antigravity, Gemini, Claude, etc.) picking up this session.
> **Last Synchronized**: 2026-09-29 21:15:00 EDT
> **Git Status**: Branch `main` at commit `ab5c010` (Clean working tree, synced with `origin/main`).
> **Developer & Lead**: Scott Quick.

---

## 1. Non-Negotiable Operational Guardrails
1. **Zero Mention Rule (Strict)**: Absolutely **ZERO** mention of 501(c)(3), non-profit, Forged By Valor, or FBV. This is an entirely independent, personal gaming project.
2. **BLUF Communication**: Always provide Bottom Line Up Front conclusions, actionable steps, and exact commands before deep technical dives.
3. **Zero Blizzard UI Taint**: 
   - Never inherit from XML templates (`BasicFrameTemplateWithInset`, `UIPanelButtonTemplate`, `UIPanelCloseButton`, etc.).
   - All UI widgets must be 100% pure Lua using `"BackdropTemplate"`.
   - Never touch `UISpecialFrames`. Use custom key listeners on the parent frame (`SetPropagateKeyboardInput`) to intercept `ESCAPE` safely.
   - Any routine modifying frames, mouse interaction, anchors, or sizes must check `if InCombatLockdown() then return end`.
4. **Cross-Client Parity**:
   - Single unified codebase across all 4 flavors:
     1. WoW Forever Beta (`_classic_beta_` / `WowB.exe`)
     2. Classic Era (`_classic_era_` / `WowClassic.exe`)
     3. Anniversary (`_anniversary_` / `WowClassic.exe`)
     4. Modern Retail (`_retail_` / `Wow.exe`)
   - Feature gate using dynamic runtime feature detection (`type(CombatLogGetCurrentEventInfo) == "function"`), never fragile version string parsing.
5. **Zero Documentation Drift**:
   - Update `CHANGELOG.md` (Keep a Changelog v1.1.0 standard) on every change.
   - Update `docs/` and `README.md` if user-facing behavior or architecture changes.
6. **Mandatory Automated Verification**:
   - Always run `python tests/validate_lua.py` (Must return `[PASS]` for all Lua files).
   - Always run `python -m unittest discover tests` (Must return `OK`).
   - Always run `python scripts/deploy.py` to sync all 4 client directories and update `WoWKillboard-v1.0.0.zip`.

---

## 2. Infrastructure & Dedicated VPS Status (AWS Lightsail)
Scott Quick has provisioned the dedicated production VPS instance on AWS Lightsail:

| Parameter | Current Value / State |
| :--- | :--- |
| **Cloud Provider** | AWS Lightsail (Ubuntu 24.04 LTS) |
| **Instance Name** | `wowkillboard-vps` |
| **Instance Plan** | General Purpose (1 GB RAM, 2 vCPUs, 40 GB SSD) |
| **Static IPv4 Address** | **`13.216.102.148`** (Permanently attached) |
| **Firewall Rules** | Port 22 (SSH), Port 80 (HTTP), Port 443 (HTTPS) all open |
| **Domain Status** | Configured for direct IP access on `http://13.216.102.148/` (Preparing for custom domain & CurseForge) |
| **Service Daemon** | systemd: `wowkillboard.service` (Flask REST API + SQLite) |
| **Reverse Proxy** | Caddy v2 (Port 80/443 -> Localhost:8080) |

### Synchronizing the VPS to Latest Code:
Inside the Lightsail browser SSH terminal (`ubuntu@wowkillboard-vps`), run:
```bash
cd /opt/wowkillboard && sudo git fetch origin main && sudo git reset --hard origin/main && sudo systemctl restart wowkillboard
```

### Remote Database Reset Command:
To wipe all tables (`kills`, `bounties`, `characters`, `character_claims`, etc.) back to 0:
```powershell
Invoke-RestMethod -Uri "http://13.216.102.148/api/admin/reset" -Method Post -ContentType "application/json" -Body '{"secret":"wowkb_archivist_secret"}'
```

---

## 3. Local Workspace & Daemon State
- **Workspace Path**: `C:\Users\SQUICK\WoW_Killboard`
- **Active Background Daemons**:
  - `sync/watcher.py` (Task watching local SavedVariables).
  - `web/server.py` (Local web server running at `http://127.0.0.1:8080`).
- **Local WoW Client Deployment Targets**:
  - `D:\World of Warcraft\_classic_beta_\Interface\AddOns\WoWKillboard\`
  - `D:\World of Warcraft\_classic_era_\Interface\AddOns\WoWKillboard\`
  - `D:\World of Warcraft\_anniversary_\Interface\AddOns\WoWKillboard\`
  - `D:\World of Warcraft\_retail_\Interface\AddOns\WoWKillboard\`
- **Distribution Package**: `C:\Users\SQUICK\WoW_Killboard\WoWKillboard-v1.0.0.zip`

---

## 4. Key Systems & Recent Implementation Summary

### A. In-Game 1-Click Database Reset (`UI.lua`)
- Added Section `5. Database Management` to the Settings dialog (`/kb` -> `Settings`).
- Red **`[Reset Local Database]`** button wipes local combat records (`WoWKillboardDB.kills`), resets cached realm carnage to 0, clears session stats, and refreshes the UI immediately without requiring a `/reload`.

### B. Multi-Tier Stress Testing Suite (`scripts/stress_test.py`, `docs/STRESS_TESTING.md`)
- **Tier 1 (Addon)**: `/kb stress [N]` injects up to 250 verified synthetic kills into memory in 1 frame, measuring execution time (`debugprofilestop`) and memory delta (`collectgarbage`).
- **Tier 2 (Parser)**: `python scripts/stress_test.py --mode parser` benchmarks `LuaTableParser`, achieving **7,200+ records/second** parsing throughput across 2,500 kill payloads.
- **Tier 3 (API Concurrency)**: Multi-threaded load tester (`ThreadPoolExecutor`) measuring RPS and latency percentiles. Benched on AWS Lightsail: **168.9 RPS (Reads)**, **82.6 RPS (Writes)**, and **159.9 RPS (Mixed)** with **100% success rate and 0 lock errors**.

### C. SQLite Write-Ahead Logging (WAL) Hardening (`web/server.py`)
- Configured `PRAGMA journal_mode=WAL;`, `PRAGMA busy_timeout = 10000;`, and `PRAGMA synchronous = NORMAL;` in `get_db()`.
- Eliminates database file locking under concurrent ingestion bursts.

### D. Decoupled Dual-Tier Web Header (`index.html`, `style.css`)
- Separated header into Tier 1 (Brand, Factions, Theater, Mode Filters, Claim) and Tier 2 (Dedicated Navigation Sub-Rail).
- Eliminates tab squishing and text truncation (e.g. `Def`) at 150%+ zoom levels.

### E. Dynamic Most Wanted Grid Sizing (`app.js`)
- Dynamically scales bounty cards: renders 1 single row of 5 slots when $\le 5$ bounties exist, pulling the combat feed up by ~180px and eliminating empty-state clutter.

### F. Complete Database Wipe Lifecycle (`web/server.py`)
- `wipe_database()` drops and re-creates all tables: `kills`, `platform_stats`, `bounties`, `bounty_acceptances`, `debt_ledger`, `character_guild_history`, `characters`, `character_claims`, `distress_beacons`, `guild_events`, `guild_discord_configs`, `blood_feuds`, `kos_blacklist`, `kos_deserters`, `intel_sightings`, `pve_deaths`, and `bug_reports`.
- Linked **`Admin Console`** directly in the web footer navigation rail.

### G. Runtime Kill History Self-Healing (`Core.lua`)
- Implemented `KB:SanitizeKillHistory()` on addon initialization to auto-prune victim self-insertion from historical kills and restore Druid/healer assists.

### H. PvE Death Isolation (`CombatTracker.lua`)
- Initialized `damageSources = {}` and `maxNpcDamage = 0` in `ProcessDeath`, resolving nil `pairs` crashes on open-world creature deaths.

---

## 5. Next Steps for Release (Domain & CurseForge)
1. **Domain Registration**: Register domain (e.g., `wowkillboard.com` via Cloudflare).
2. **Point DNS**: Add A-Record for `@` and `api` to `13.216.102.148`.
3. **SSL & URL Update**: Update `KB.WebDomain` in `Config.lua` and `DEFAULT_PROD_URL` in `watcher.py`, rebuild `WoWKillboardSync.exe`.
4. **Publish to CurseForge**: Upload `WoWKillboard-v1.0.0.zip` to CurseForge Author Portal under `PvP / Combat / Information`.
