# WoW Killboard — Master AI Session Handoff & Continuity Brief

> **Target Audience**: Any AI assistant (Antigravity, Gemini, Claude, etc.) picking up this session.
> **Last Synchronized**: 2026-09-27 14:32:00 EDT
> **Git Status**: Branch `main` at commit `9b93905` (Clean working tree, synced with `origin/main`).
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
| **Domain Status** | No custom domain yet. Configured for direct IP access on `http://13.216.102.148/` |
| **Bootstrap Script** | `deploy/setup_vps.sh` (Refined, supports blank domain for direct IP fallback) |

### Exact Deployment Command on the VPS:
Inside the Lightsail browser SSH terminal (`ubuntu@wowkillboard-vps`), run:
```bash
sudo git clone https://github.com/dagariane-commits/WoW_Killboard.git /opt/wowkillboard
cd /opt/wowkillboard
sudo bash deploy/setup_vps.sh ""
```
This automatically installs Python 3, venv, Caddy web server, registers `wowkillboard.service` via systemd, and binds the web app to port 80.

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

## 4. Key Components & Implementation Summary

### A. Mark of Spite Currency Overhaul (`BountyEngine.lua`, `UI.lua`)
- Allows exact declaration in **Gold, Silver, and Copper**.
- Input form has dedicated `Target Name` editbox, discrete numeric editboxes for `[ G ]`, `[ S ]`, `[ C ]` with coin textures, and `[Declare Mark]` / `[Cancel]` buttons.
- `PlaceBounty` calculates exact copper (`(gold * 10000) + (silver * 100) + copper`).
- All user-facing terminology changed from "Blood Bounty" to "Mark of Spite" / "Mark".

### B. Classic Theme Header Plate Fix (`UI.lua`)
- Prevented `ApplyTheme()` from overwriting `UI.TitleText` with the 45-character `GetClientFlavorTitle()`.
- Title text is strictly `"WoW Killboard"` centered inside the 320px arched header plate (`Interface\DialogFrame\UI-DialogBox-Header`).
- Realm and version information is displayed below in `UI.SubtitleText`.

### C. Alert Anchor Visual Transparency (`UI.lua`)
- Removed the harsh solid yellow border (`SetBackdropBorderColor(0, 0, 0, 0)`).
- Anchor backdrop is semi-transparent (`alpha 0.60`).

### D. Radar HUD Floating Widget (`UI.lua`, `UnitScanner.lua`)
- Replaced chat spam with a draggable floating radar widget (`WoWKillboardRadarHUD`).
- Toggled via `/kb radar` or `/kbradar`. Auto-fades after 15s of inactivity.

### E. 100% Solo Purity Algorithm (`CombatTracker.lua`)
- Guarantees 100% solo kills have zero external damage, zero external friendly heals, zero external buffs, zero external CC/debuffs within 30 seconds.

### F. Character Claiming & Ownership Protection (`web/server.py`, `web/static/app.js`)
- Protects characters from being claimed by unauthorized users.
- Tier 1: Official Battle.net OAuth 2.0 (`/api/auth/bnet`) verifying owned character GUIDs.
- Tier 2: In-game secret token challenge (`/kb claim <code>`) where only the active in-game character can execute the command.

---

## 5. Next Steps When Starting a New Session
1. **VPS Deployment Check**:
   - Check if Scott ran the 3 commands on his Lightsail VPS terminal (`sudo git clone ... && sudo bash deploy/setup_vps.sh ""`).
   - Verify if `http://13.216.102.148` is responding.
2. **Domain Mapping (When Scott is ready)**:
   - When a domain is purchased/attached, add an A-Record to `13.216.102.148` and run:
     `sudo bash /opt/wowkillboard/deploy/setup_vps.sh yourdomain.com`
3. **In-Game Playtesting**:
   - Have Scott test `/reload` in game to observe the clean Classic title plate, the semi-transparent alert anchor (`/wowkb move`), and issuing a Mark of Spite in G/S/C.
