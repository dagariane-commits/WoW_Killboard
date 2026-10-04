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
# WoW Killboard (WKB)

**WoW Killboard** brings a dedicated combat tracker, live kill feed, and leaderboard directly into your World of Warcraft client. Track your open-world battles, log certified 1v1 encounters, see who is dominating your zone, and view real-time leaderboards right inside the game.

### Key Features
* **Live Combat Tracking:** Automatically logs attacker and victim levels, classes, killing blows, and fight locations.
* **1v1 Solo Detection:** Accurately distinguishes certified 1v1 solo fights from group ganks.
* **In-Game Leaderboards:** Track your kills, deaths, K/D ratio, and kill streaks without opening a browser.
* **Zone Danger Intel:** See active conflict hotspots and high-value enemy outlaws operating in your zone.
* **Call for Backup (`/warhorn`):** Sound an emergency SOS beacon to nearby allies or guildmates with your location.
* **PvE Elites & Hazards:** Toggle to PvE mode to track deaths to lethal world bosses/elites (Hogger, Son of Arugal, Stitches) and environmental hazards.
* **Two Visual Themes:** Switch between authentic **Classic WoW Stone** (default) and **ElvUI Minimalist Dark** right in settings.

### How to Use
* Type **/kb** or **/killboard** (or click the minimap skull) to open the dashboard.
* Type **/kb theme** (or right-click the minimap skull) to toggle between Classic and Dark visual themes.
* Type **/warhorn** to call for backup when jumped in open-world PvP.
* Type **/kb config** to adjust audio cues, alerts, and display options.

### Optional Web Leaderboards
Visit **[wowkillboard.com](https://wowkillboard.com)** to check out realm-wide leaderboards, outlaws, and character dossiers. You can sync your stats by dragging and dropping your `WoWKillboard.lua` file directly at **[wowkillboard.com/upload](https://wowkillboard.com/upload)** — 100% browser-based with zero background software needed.

### Compatibility & Feedback
* **Game Flavors:** Hands-on testing has primarily been focused in **WoW Forever (Classic Beta)**. The codebase is written with parity in mind for **Classic Era**, **Anniversary**, and **Retail** as well.
* **Community Driven:** I'm an indie hobbyist learning and building this for fun. If you run into any quirks or have suggestions, please leave a comment!
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

> [!IMPORTANT]
> **CurseForge & Git Lockstep Parity (MANDATORY)**:
> Whenever you push or upload an update to CurseForge, you **MUST** ensure the exact same code and zip are committed, tagged, and pushed to GitHub (`git tag -a v1.0.2 -m "..."` and `git push origin main --tags`). Users downloading from GitHub or CurseForge must always experience identical features, styling, and bug fixes.

1. Navigate to the **File** tab on your CurseForge project dashboard.
2. Click **Upload File**.
3. Select `WoWKillboard-v1.0.2.zip` (located in the project root: `WoWKillboard-v1.0.2.zip`).
4. Set **Display Name**: `WKB v1.0.2 (Community Release)`
5. Set **Release Type**: `Release` (or `Beta` if you prefer).
6. Under **Supported Game Versions**, select:
   - `World of Warcraft Classic` (Classic Era `1.15.x`)
   - `Classic Beta` / `Classic Anniversary`
   - `World of Warcraft Mainline` (Retail `11.0.x`)
7. Paste the latest release notes from [`CHANGELOG.md`](CHANGELOG.md) into the **Changelog** field.
8. Click **Submit File**.

> [!NOTE]
> CurseForge conducts human and automated security moderation on all new projects. Initial approval typically takes between **6 to 24 hours**. Once approved, your addon will be instantly downloadable in the CurseForge desktop app and on the CurseForge website.
