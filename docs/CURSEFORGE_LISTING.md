# WoW Killboard — CurseForge Project Listing & Submission Kit

This kit contains the exact copy, category settings, screenshot captions, and file upload instructions needed to submit **WoW Killboard** to the [CurseForge Author Portal](https://authors.curseforge.com/).

---

## 1. Project Metadata Settings

| Field | Value | Notes |
| :--- | :--- | :--- |
| **Game** | `World of Warcraft` | |
| **Project Name** | `WoW Killboard` | |
| **Project Slug** | `wow-killboard` (auto-generated) | |
| **Primary Category** | `PvP` | Core categorization |
| **Secondary Categories** | `Combat`, `Guild`, `Information` / `Data Export` | Maximizes search visibility |
| **License** | `GNU General Public License v3.0 (GPLv3)` | Open standard |
| **Default Branch** | `main` | |

---

## 2. Short Summary (Tagline)

```text
Frontline PvP & PvE Combat Intelligence, Live Killmail Feed, Blood Bounties, Apex Bestiary, Faction War Horn, and In-Game Leaderboards with zero UI taint.
```

---

## 3. Project Description (Markdown for CurseForge)

*Copy and paste the markdown block below into the CurseForge Project Description editor:*

```markdown
# ⚔️ WoW Killboard — Frontline Combat Intelligence & War Room

**WoW Killboard** transforms your World of Warcraft client into a high-octane PvP & PvE tactical operations center. Engineered for true faction loyalty, competitive ranking, and open-world survival, WoW Killboard captures every lethal engagement with microsecond precision, provides certified 1v1 duel validation, streams live killfeeds, and manages server-wide bounty contracts.

Built from the ground up under a strict **Zero Blizzard UI Taint** architecture, WoW Killboard uses 100% anonymous pure Lua frames and `"BackdropTemplate"` to guarantee zero "Action Blocked" popups and rock-solid combat frame rate stability.

---

### 🔥 Core Features

#### 1. 📡 Tactical Intel & Live Killmail Feed
- **Cryptographic Kill Tracking**: Every kill is recorded with attacker/victim levels, classes, guild affiliations, killing blows, and GPS coordinates.
- **Certified 1v1 Solo Detection**: Proprietary 15-second temporal clustering algorithm distinguishes certified solo 1v1 victories from gang ganks.
- **Most Wanted Outlaws**: Live bounty cards highlight high-value targets operating in your active warzone.
- **Micro-Inspect Sound Cues**: Distinctive Alliance and Horde audio cues announce frontline kills and enemy defeats.

#### 2. 🏆 Defenders of Azeroth (In-Game Leaderboards)
- **Faction Honor Rankings**: Track running kills, deaths, K/D ratios, and estimated honor without opening external web browsers.
- **Streak & Nemesis Tracking**: View your current kill streaks and pinpoint your personal Nemesis across the battlefield.
- **Multi-Mode Filter Pills**: Instantly filter combat data across **All**, **World PvP**, **Battlegrounds**, **Arenas**, and **Duels**.

#### 3. 📯 Vanguard Rally & Faction War Horn
- **One-Click Call for Backup**: Under attack in the open world? Send a faction-wide SOS beacon broadcasting your exact zone and coordinates.
- **Automated Raid Muster**: Rally friendly combatants into an instant defense vanguard with automated raid invites.
- **Tactical Distress Radar**: Displays distance and bearing to allies requesting urgent reinforcements.

#### 4. 🗺️ Zone Intel & Conflict Hotspots
- **Frontline Danger Index**: Live heatmaps categorize zones into Extreme, High, and Moderate threat levels based on real-time mortality.
- **Territory Mortality Metrics**: See where the faction conflict is fiercest (Stranglethorn Vale, Hillsbrad Foothills, Blackrock Mountain).

#### 5. 🛡️ Dual-Engine: The Apex Bestiary & PvE Casualties
- **Instant Mode Switching**: Easily toggle between `[ ⚔️ PvP ]` and `[ 🛡️ PvE ]` rulesets with a single header click.
- **The Apex Bestiary**: Track deaths caused by legendary world elites (Hogger, Son of Arugal, Mor'Ladim, Stitches, Devilsaurs).
- **Environmental Hazard Tracking**: Full forensic logging for lethal falls, drowning, lava, and wilderness traps.
- **Rescue Beacons**: Request help from nearby players when overwhelmed by high-density elite packs.

---

### 🛡️ Zero UI Taint Guarantee
- **Zero XML Panel Templates**: Never inherits from `BasicFrameTemplateWithInset` or `UIPanelButtonTemplate`.
- **Zero `UISpecialFrames` Pollution**: Key listeners safely intercept the `ESCAPE` key without tainting protected Blizzard frames.
- **Combat Lockdown Gating**: Strictly adheres to `InCombatLockdown()` routines to ensure zero protected action blocks during arena or raid combat.

---

### ⌨️ Slash Commands

| Command | Action |
| :--- | :--- |
| `/kb` or `/killboard` | Toggle the main WoW Killboard interface |
| `/kb config` | Open the tactical settings and audio preferences |
| `/kb sos [reason]` | Broadcast an urgent Vanguard Rally beacon to friendly faction players |
| `/kb reset` | Reset saved combat database (prompts for confirmation) |
| `/kb stats` | Print running session kills and K/D ratio to chat |

---

### 🌐 Cross-Client Parity & Optional Web Platform
- **Supported Client Flavors**:
  - **WoW Classic Beta & WoW Forever** (`1.15.x`)
  - **Classic Era** (`1.15.x`)
  - **20th Anniversary Edition** (`1.15.x`)
  - **Modern Retail** (`11.x`)
- **Companion Desktop Sync & Web Killboard**:
  Players who want their combat kills streamed to a public web killboard and Discord war room can optionally use the standalone, zero-install `WoWKillboardSync.exe`. No Python or complex setup required!
```

---

## 4. Screenshot Gallery & Upload Guide

Upload the 5 screenshots located in [`assets/curseforge/`](file:///c:/Users/SQUICK/WoW_Killboard/assets/curseforge/) in this specific order:

| File | Title / Caption | Description |
| :--- | :--- | :--- |
| `01_live_killfeed_tactical_intel.png` | **Tactical Intel & Live Killfeed** | Real-time combat killmails, certified 1v1 indicators, and Most Wanted outlaw cards. |
| `02_defenders_of_azeroth_leaderboard.png` | **Defenders of Azeroth Leaderboard** | Live in-game player rankings, K/D ratios, killing streaks, and faction honor standing. |
| `03_vanguard_rally_war_horn.png` | **Vanguard Rally (Faction War Horn)** | 1-click faction defense beacon with automated raid invites and GPS coordination. |
| `04_zone_intel_conflict_hotspots.png` | **Zone Intel & Conflict Hotspots** | Territory danger index and mortality heatmaps tracking active warzones. |
| `05_apex_bestiary_pve_hazards.png` | **Apex Bestiary & Wilderness Hazards** | PvE casualty tracking, lethal mob executioners, and environmental hazards. |
| `06_global_web_killboard_portal.png` | **Global Web Killboard Platform** | Live cloud killboard, Most Wanted outlaws, recent combat feed, and guild statistics. |

---

## 5. File Upload Instructions (`File` Tab)

1. Navigate to the **File** tab on your newly created CurseForge project.
2. Click **Upload File**.
3. Select `WoWKillboard-v1.0.0.zip` (located in the project root: `C:\Users\SQUICK\WoW_Killboard\WoWKillboard-v1.0.0.zip`).
4. Set **Display Name**: `WoW Killboard v1.0.0`
5. Set **Release Type**: `Release` (or `Beta` if you prefer early beta staging).
6. Under **Supported Game Versions**, select:
   - `World of Warcraft Classic` (Classic Era `1.15.x`)
   - `Classic Beta` / `Classic Anniversary`
   - `World of Warcraft Mainline` (Retail `11.0.x`)
7. Paste the latest release notes from [`CHANGELOG.md`](file:///c:/Users/SQUICK/WoW_Killboard/CHANGELOG.md) into the **Changelog** field.
8. Click **Submit File**.

> [!NOTE]
> CurseForge conducts human and automated security moderation on all new projects. Initial approval typically takes between **6 to 24 hours**. Once approved, your addon will be instantly downloadable in the CurseForge desktop app and on the CurseForge website.
