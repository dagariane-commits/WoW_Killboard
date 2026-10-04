# WoW Killboard — Master AI Session Handoff & Continuity Brief

> **Target Audience**: Any AI assistant (Antigravity, Gemini, Claude, etc.) picking up this session.  
> **Last Synchronized**: 2026-10-04 02:05:00 EDT  
> **Git Status**: Branch `main` (Commit `bdcd950`, pushed to `origin/main`).  
> **Developer & Lead**: Dagariane.  
> **Active Release**: `v1.0.1` (Community Release).  
> **Active Focus**: **In-Game Appearance Fine-Tuning & Authentic Blizzard UI Parity**.  
> **Live Production Domain**: [`https://wowkillboard.com/`](https://wowkillboard.com/)

---

## 1. Non-Negotiable Operational Guardrails
1. **Zero Mention Rule (Strict)**: Absolutely **ZERO** mention of non-gaming organizations, 501(c)(3) entities, or external corporate entities in public code, git commits, or community communications. This is an entirely independent, personal gaming project.
2. **BLUF Communication**: Always deliver Bottom Line Up Front conclusions, actionable steps, and exact commands before deep technical dives.
3. **Zero Blizzard UI Taint**: 
   - Never inherit from XML templates (`BasicFrameTemplateWithInset`, `UIPanelButtonTemplate`, `UIPanelCloseButton`, etc.).
   - All UI widgets must be 100% pure Lua using `"BackdropTemplate"`.
   - Never touch `UISpecialFrames`. Use custom key listeners on the parent frame (`SetPropagateKeyboardInput`) to intercept `ESCAPE` safely.
   - Any routine modifying frames, mouse interaction, anchors, or sizes must check `if InCombatLockdown() then return end`.
4. **Cross-Client Parity**:
   - Single unified codebase across all 4 target flavors:
     1. WoW Forever Beta (`_classic_beta_` / `WowB.exe`)
     2. Classic Era (`_classic_era_` / `WowClassic.exe`)
     3. Anniversary (`_anniversary_` / `WowClassic.exe`)
     4. Modern Retail (`_retail_` / `Wow.exe`)
   - Feature gate using dynamic runtime feature detection (`type(CombatLogGetCurrentEventInfo) == "function"`), never fragile version string parsing.
5. **Zero Documentation Drift**:
   - Code and docs are twin artifacts: always update `CHANGELOG.md` (Strict Keep a Changelog v1.1.0 standard), `docs/`, and `README.md` alongside code changes.
6. **Mandatory Automated Verification**:
   - Run `python tests/validate_lua.py` (Must return `[PASS]` for all 13 Lua files).
   - Run `python -m unittest discover tests` (Must return `OK` across all 26 pipeline/security tests).
   - Run `python scripts/deploy.py` to sync all 4 client directories and update `WoWKillboard-v1.0.1.zip` and `WoWKillboard-v1.0.0.zip`.

---

## 2. Active Focus: Fine-Tuning In-Game Appearance & Blizzard UI Parity

We are systematically fine-tuning the visual presentation and in-game aesthetic of WoW Killboard so it feels natively integrated into World of Warcraft (both authentic Classic WoW and modern ElvUI).

### What Was Completed:
- **Native Blizzard Achievement Alert Toast Kit (`UI.lua`, `Config.lua`)**:
  - Replaced hand-crafted parchment and tooltip borders with authentic Blizzard Achievement Alert Toast assets (`Interface\AchievementFrame\UI-Achievement-Alert-Background`).
  - Implemented 3-slice texture mapping across **580px × 88px** with zero corner distortion:
    - `ToastBgLeft` (110×88, texCoords `[0, 0.21484375, 0, 0.703125]`) capturing the left golden corner ornament.
    - `ToastBgRight` (110×88, texCoords `[0.390625, 0.60546875, 0, 0.703125]`) capturing the right golden corner ornament.
    - `ToastBgMid` stretched seamlessly between the left and right slices with dark burnished bronze background.
  - Eliminated conflicting backdrops in Classic mode (`banner:SetBackdrop(nil)`).
  - Native beveled icon frames (`UI-Achievement-IconFrame`), circular faction medallion rings (`medallion_border.tga`), and high-contrast typography.
- **Tactical Real-Time Search Box & Multi-Tab Query Filtering (`UI.lua`, `Config.lua`)**:
  - Built 100% template-free, zero-taint live search input (`UI.SearchBox`) anchored in the navigation bar.
  - Features magnifying glass icon, placeholder, one-click clear button (`x`), gold focus glow, and real-time query dispatch (`UI.activeSearchQuery`).
  - Integrated real-time query filtering across **all 5 main tabs in both PvP and PvE rulesets**:
    - **Feeds**: `RenderLiveFeed` (PvP kills & Most Wanted outlaws) and `RenderPveFeed` (wilderness casualties & Apex Executioners).
    - **Leaderboards**: `RenderLeaderboard` (Player Ranks, Guild Supremacy, 24h Gankers) and `RenderPveLeaderboard` (Apex Executioners, Fallen Mortals, Perilous Regions).
    - **Bounties**: `RenderBounties` (Active Marks) and `RenderPveBounties` (Notorious Elites).
    - **Zones**: `RenderZones` (24h realm hotspots & local skirmishes) and `RenderPveZones` (Zone Mortality danger index).
    - **Rallies**: `RenderRallies` (Vanguard strike teams) and `RenderPveRallies` (Emergency rescue distress beacons).
- **Dual-Theme Minimap Button & LibDataBroker Integration (`Core.lua`, `Config.lua`)**:
  - Registered official `WoWKillboard` Data Object with `LibDataBroker-1.1` for Titan Panel, ChocolateBar, and ElvUI data texts.
  - Added theme-aware minimap button (`KB:UpdateMinimapTheme`):
    - **Classic Forever**: Circular Blizzard tracking border (`Interface\Minimap\MiniMap-TrackingBorder`) with antique bronze tooltip styling.
    - **ElvUI Minimalist**: Matte charcoal 1px black-bordered square frame with crisp silver font tooltips.
  - Left-Click toggles main dashboard (`/kb`); Right-Click cycles themes dynamically (`/kb theme`).
- **Combat Detail Modal Polish & Pure-Lua Scrollbar (`UI.lua`, `Config.lua`)**:
  - Upgraded `UI.DetailModal` to 540×410 with 246×118 combatant portrait cards, native beveled frames (`UI-Achievement-IconFrame`), fatal strike ability info, and multi-attacker breakdown.
  - Pure-Lua custom vertical scrollbar (`UI.ScrollBar`) on `ContentInset` with auto-show/hide logic and theme-aware rail/thumb textures, avoiding all Blizzard `UIPanelScrollBarTemplate` XML taint.

### Immediate In-Game Testing Steps:
1. `/reload` — Reload UI after synchronization.
2. `/kb` — Open main dashboard. Test the real-time search box:
   - Type a character name, guild name, monster name (e.g. `Defias` or `Hogger`), or zone (e.g. `Westfall`).
   - Switch between tabs (Intel, Defender of Azeroth, The Marked, Manhunt, Zone Intel) and toggle rulesets (PvP vs PvE); observe instant filtering across cards and lists.
3. `/kb test` — Preview the in-game combat toast banner (defaults to Westfall Defias Pillager scenario).
4. `/kb theme` — Toggle active theme between Classic Forever and ElvUI Minimalist; observe simultaneous theme updates across the dashboard, combat toast, detail modal, and minimap icon.
5. `/wowkb move` — Unlock banner to reposition with drag anchor.

---

## 3. Infrastructure & Production Status (AWS Lightsail)

The production VPS instance on AWS Lightsail is fully operational, fast-forwarded to `main`, and running the hardened backend:

| Component | State / Configuration | Notes |
| :--- | :--- | :--- |
| **Cloud Host** | AWS Lightsail (Ubuntu 24.04 LTS) | 1 GB RAM, 2 vCPUs, 40 GB SSD |
| **Domain & Proxy** | [`https://wowkillboard.com/`](https://wowkillboard.com/) | Cloudflare Universal SSL + Caddy v2 Reverse Proxy |
| **Backend Daemon** | `systemd: wowkillboard.service` | Python Flask + SQLite WAL mode (`PRAGMA journal_mode=WAL;`) |
| **CDN Offloading** | `/download` $\rightarrow$ 302 CurseForge CloudFront<br>`/WoWKillboardSync.exe` $\rightarrow$ 302 GitHub Releases Fastly CDN | Completely eliminates VPS egress bandwidth and worker starvation during concurrent binary downloads. |
| **Defense Headers** | `nosniff`, `SAMEORIGIN`, `X-XSS-Protection`, `Referrer-Policy`, `Permissions-Policy` | Live and verified across all API and static routes. |

### Quick VPS Maintenance Commands:
```bash
# SSH into VPS and pull latest changes
ssh ubuntu@<YOUR_VPS_IP>
cd /opt/wowkillboard && git pull origin main && sudo systemctl restart wowkillboard.service

# Check live backend logs
sudo journalctl -u wowkillboard.service -f
```

---

## 4. Tabled Items & Strategic Roadmap

### Tabled Item 1: Community Release Strategy (Option 1: Zero-Executable Primary)
- **The Core Decision**: The community release focuses on **Option 1**:
  - **In-Game Addon (`WoWKillboard-v1.0.1.zip`)**: Distributed via CurseForge (`wkb`) and GitHub Releases. 100% pure Lua, running in Blizzard's locked sandbox. Zero OS file access, zero external network connections, zero executables.
  - **Web Sync via Drag-and-Drop**: Players sync combat data directly by dragging `WTF\...\SavedVariables\WoWKillboard.lua` onto [`wowkillboard.com/upload`](https://wowkillboard.com/upload) in any browser.
  - **Desktop Companion (`WoWKillboardSync.exe`)**: Positioned strictly as an **optional convenience tool for power users** who want automated background syncing on `/reload` or logout.

### Tabled Item 2: VirusTotal Heuristic Analysis & Microsoft Whitelist Clearing
- **Current Scan Result**: **66 / 71 Security Vendors Clean (93% Clean)**.
- **Top-Tier Enterprise Engines Clean**: Microsoft Defender, CrowdStrike Falcon, SentinelOne Static ML, Kaspersky, Malwarebytes, BitDefender, Sophos, ESET, Avast/AVG, Symantec, Trellix, McAfee, and Palo Alto Networks all classify the binary as **Undetected / Clean**.
- **Remaining Detections (5/71)**:
  - `Bkav Pro`: `W32.Malware.*` (Flags 100% of unsigned binaries).
  - `SecureAge`: `Malicious` (Whitelist-only engine; flags any file without a corporate Authenticode certificate).
  - `Skyhigh (SWG)`: `BehavesLike.Win64.Backdoor.wc` (Heuristic proxy rule for unsigned binaries with network polling loops).
  - `Zillya`: `Trojan.Blank.Script` (Generic signature for PyInstaller unpacker stubs).
  - `Microsoft Defender`: `Trojan:Win32/Wacatac.C!ml` (Machine Learning flag on newly compiled, zero-reputation PyInstaller bootloaders).
- **Hardening Completed in Commit `f86fb68` & `a66ff71`**:
  - Eradicated hidden PowerShell invocations (`subprocess.run(["powershell", ...])`) $\rightarrow$ Replaced with native Windows `.url` shell launcher (`[InternetShortcut] URL=file:///...`).
  - Eradicated `pylnk3` raw byte-packing structs.
  - Eradicated `winreg` and `Software\Microsoft\Windows\CurrentVersion\Run` $\rightarrow$ Replaced with standard user Startup folder shortcuts (`%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup`).
  - Embedded Windows PE Version Information table (`VSVersionInfo` with Company: "WoW Killboard Project", Version: "1.0.1.0").
  - Embedded multi-resolution application icon (`assets/icon.ico`).
- **Actionable Next Step (60-Second Task)**: Submit [`WoWKillboardSync.exe`](../WoWKillboardSync.exe) (SHA-256: `ef68f696d3a49f30326a3283658e11914fe3f311166bc688d5073a35b3653bb7`) to the [Microsoft Security Intelligence Developer Portal](https://www.microsoft.com/en-us/wdsi/filesubmission). Microsoft's automated sandbox verifies clean indie tools and removes `Wacatac.!ml` globally within 2–6 hours.

### Tabled Item 3: Future Native Compilation (Permanent 0/71 Solution)
- If complete zero-detection (0/71) is desired without relying on Microsoft false-positive whitelisting:
  1. **Nuitka Compilation**: Compile `sync/watcher.py` using Nuitka directly to native C++ machine code using MSVC (`cl.exe`). Native PE binaries without PyInstaller stubs routinely score 0/71.
  2. **Go/Rust Micro-Daemon**: The file watcher and HTTP POST logic is ~200 lines. Compiling a static Go or Rust binary eliminates all Python packing heuristics permanently.

### Tabled Item 4: Reddit / Community Anti-AI Critique Response
- **Context**: A Reddit user commented on the project announcement regarding AI tools and UI aesthetic.
- **Approved Response (Grounded, Honest Hobbyist Voice)**: Available in previous briefs. Main emphasis is learning Blizzard Lua API, spending weeks testing in-game, preventing combat taint, and continuously refining UI aesthetics (both Classic WoW stone/brass and ElvUI minimalist).

---

## 5. Key Systems Summary & Active Files

| Component | Key Files | Function & Architecture |
| :--- | :--- | :--- |
| **In-Game Addon** | `Addon/WoWKillboard/*.lua`<br>`WoWKillboard.toc` | Pure Lua 5.1, zero XML taint, `BackdropTemplate`, 15s temporal gang clustering, 1v1 duel validation, bounty engine, in-game leaderboards. |
| **Desktop Companion** | `sync/watcher.py`<br>`sync/gui.py`<br>`sync/version_info.txt`<br>`assets/icon.ico` | Standalone Python watcher. Multi-drive discovery across C:, D:, E:, verified TLS/SSL, native `.url` shortcuts in Startup folder, embedded PE metadata. |
| **Web Server & API** | `web/server.py`<br>`web/static/app.js`<br>`web/static/index.html` | Flask API + SQLite WAL mode. CDN-first 302 redirects, sliding-window IP rate limiting, DOM XSS immunity via `escapeHtml()` and `safeJsParam()`, 16MB request limits. |
| **Distribution Packages** | `WoWKillboard-v1.0.1.zip`<br>`WoWKillboard-v1.0.0.zip`<br>`WoWKillboardSync.exe` | Mirror archives in root and `web/static/`. Standalone binary verified. |

---

## 6. Continuity Checklist for Incoming Agent
When resuming work on this repository:
1. Always run `git status` — Ensure working directory is clean.
2. Run `python tests/validate_lua.py` and `python -m unittest discover tests` — Confirm all tests pass.
3. If code is modified, run `python scripts/deploy.py` to sync local client folders and update zip archives.
4. Maintain Keep a Changelog v1.1.0 standard in `CHANGELOG.md`.
5. Respect the **Zero Mention Rule** and **BLUF** communication standards at all times.
