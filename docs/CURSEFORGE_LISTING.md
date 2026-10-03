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
In-game combat tracker, live kill feed, 1v1 fight detection, local bounties, and leaderboards for Classic and Retail.
```

---

## 3. Project Description (Markdown for CurseForge)

*Copy and paste the markdown block below into the CurseForge Project Description editor:*

```markdown
# WKB (WoW Killboard) - Combat Tracker & Leaderboard
Community Release

Welcome to the release of WKB (WoW Killboard). WKB brings a dedicated killboard and combat tracker directly into your World of Warcraft client. Whether you are fighting in the open world, running battlegrounds, or keeping tabs on dangerous world elites, WKB logs your fights, tracks true 1v1 encounters, manages local bounties, and keeps a running leaderboard right inside the game.

---

### What Works in This Release

#### 1. Live Kill Feed & Fights
- **Kill Tracking**: Logs attacker and victim levels, classes, killing blows, and zone locations.
- **Solo Kill Detection**: Automatically separates genuine 1v1 fights from group ganks.
- **Most Wanted Outlaws**: See high-value targets operating in your current zone.
- **Audio Cues**: Simple sound alerts for kills and deaths.

#### 2. In-Game Leaderboards
- **Honor Rankings**: Track your running kills, deaths, K/D ratio, and estimated honor without leaving the game.
- **Streak & Nemesis Tracking**: Check your current kill streaks and see who kills you most frequently on the enemy faction.
- **Quick Filters**: Filter stats across All, World PvP, Battlegrounds, Arenas, and Duels.

#### 3. Call for Backup & Defense Grouping
- **Call for Help**: Getting jumped while questing? Send an SOS beacon to nearby allies or guildmates with your location.
- **Group Muster**: Quickly invite responding players into a group or raid to fight back.

#### 4. Zone Activity
- **Danger Meter**: Shows which zones currently have the highest player mortality.
- **Hotspot Tracking**: See where the heaviest fights are taking place.

#### 5. PvE Elites & World Hazards
- **Quick Mode Switch**: Toggle between PvP and PvE tracking right from the top header.
- **Deadly Elites**: Track deaths to famous world bosses and dangerous quest elites (Hogger, Son of Arugal, Mor'Ladim, Stitches, Devilsaurs).
- **Environmental Deaths**: Logs deaths from falling, drowning, lava, and fatigue.

---

### Clean & Stable Interface
WKB is built to run smoothly in the background:
- Lightweight interface that never touches or interferes with standard Blizzard action bars or nameplates.
- Safely closes with the Escape key like standard menus.
- Designed to remain stable in active combat without freezing your game or throwing interface errors.

---

### Visual Themes (Classic Stone & ElvUI Dark)
WKB includes two built-in visual styles:
- **Classic WoW Theme (Default)**: Authentic Blizzard dialog stone backgrounds, gold borders, and warm parchment styling.
- **ElvUI Minimalist Theme**: Sleek dark charcoal/black backdrops with high-contrast accents.
- **Switch Anytime**: Toggle instantly in Settings or with `/kb theme` (or right-click the minimap skull button). *Note: As a solo hobbyist project, styling will continue to refine and evolve with your feedback!*

---

### In-Game Slash Commands

| Command | Action |
| :--- | :--- |
| `/kb` or `/killboard` | Open or close the main interface |
| `/kb config` | Open settings, alerts, and sound preferences |
| `/kb theme` | Switch between Classic WoW and ElvUI Dark themes |
| `/kb sos [reason]` | Send an SOS call to nearby allies with your location |
| `/kb stats` | Print your session kill/death stats to chat |
| `/kb reset` | Reset your local combat session history |

---

### Web Killboard & Community Uploads
- **Web Portal**: Visit [wowkillboard.com](https://wowkillboard.com) to view realm leaderboards, outlaws, and combat dossiers.
- **Zero-Install Web Uploader**: Drag and drop your `SavedVariables/WoWKillboard.lua` file at [wowkillboard.com/upload](https://wowkillboard.com/upload) directly in your browser. No desktop software or background processes required!

---

### Compatibility & Feedback
- **Game Versions**: Hands-on testing has primarily been focused in WoW Forever (Classic Beta). The codebase is structured for cross-client parity across Classic Era, Anniversary, and Retail as well. If you encounter any flavor-specific quirks, please let me know!
- **Feedback & Bug Reports**: Since this is an active community release, your feedback is very helpful. If you run into any issues, have suggestions, or want to report a bug, please leave a comment on this project page or visit our GitHub tracker.
```

---

## 4. Screenshot Gallery & Upload Guide

Upload the screenshots located in [`assets/curseforge/`](assets/curseforge/) in this specific order:

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
3. Select `WoWKillboard-v1.0.1.zip` (located in the project root: `WoWKillboard-v1.0.1.zip`).
4. Set **Display Name**: `WKB v1.0.1 (Community Release)`
5. Set **Release Type**: `Release` (or `Beta` if you prefer).
6. Under **Supported Game Versions**, select:
   - `World of Warcraft Classic` (Classic Era `1.15.x`)
   - `Classic Beta` / `Classic Anniversary`
   - `World of Warcraft Mainline` (Retail `11.0.x`)
7. Paste the latest release notes from [`CHANGELOG.md`](CHANGELOG.md) into the **Changelog** field.
8. Click **Submit File**.

> [!NOTE]
> CurseForge conducts human and automated security moderation on all new projects. Initial approval typically takes between **6 to 24 hours**. Once approved, your addon will be instantly downloadable in the CurseForge desktop app and on the CurseForge website.
