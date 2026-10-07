# WoW Killboard — Community Release Quickstart Guide

Welcome to **WoW Killboard**! This guide gets you up and running in under 2 minutes.

---

## ⚡ Quickstart: 3-Step Setup

```mermaid
flowchart LR
    S1["1. Install Addon\nExtract to Interface\\AddOns"] --> S2["2. Sync to Web\nBrowser Drag & Drop OR Optional App"]
    S2 --> S3["3. Slay & View Live\nEngage in combat & view Killboard"]
```

### Step 1: Install the In-Game Addon (100% Pure Lua)
1. Download **`WoWKillboard-v1.0.5.zip`** (or install via CurseForge: search `wkb`).
2. Extract the `WoWKillboard` folder directly into your World of Warcraft AddOns directory:
   - **WoW Forever / Classic Beta**: `World of Warcraft\_classic_beta_\Interface\AddOns\`
   - **Classic Era**: `World of Warcraft\_classic_era_\Interface\AddOns\`
   - **Anniversary**: `World of Warcraft\_anniversary_\Interface\AddOns\`
   - **Modern Retail**: `World of Warcraft\_retail_\Interface\AddOns\`
3. Launch World of Warcraft. On your character selection screen, ensure **WoW Killboard** is checked in the **AddOns** menu.

### Step 2: Synchronize to the Web Killboard

#### Method A: Web Drag-and-Drop (Zero Installation • Recommended)
No downloads or background processes required:
1. Open the [WoW Killboard Web Uploader](https://wowkillboard.com/upload) in your browser.
2. Drag and drop your `SavedVariables\WoWKillboard.lua` file directly into the upload area:
   `World of Warcraft\<flavor>\WTF\Account\<AccountName>\SavedVariables\WoWKillboard.lua`
3. Your combat history and leaderboards update immediately.

#### Method B: Optional Desktop Companion App (`WoWKillboardSync.exe`)
For automated background syncing whenever you reload or log out:
1. Download **`WoWKillboardSync.exe`** from GitHub Releases.
2. Double-click to launch it. The companion automatically discovers your WoW installation across drives `C:`, `D:`, and `E:`.
3. **Windows Security Notice**: Because this is an open-source tool without an enterprise certificate, Windows may prompt on first run:
   - **Windows Defender SmartScreen**: Click **More info** → **Run anyway**.
   - **Windows 11 Smart App Control**: If blocked with no "Run anyway" button, right-click `WoWKillboardSync.exe` in Downloads → select **Properties** → check the **"Unblock"** checkbox at the bottom → click **OK**, then double-click to launch.

### Step 3: Slay & Track Live
- In-Game Commands:
  - Click the **PvP Skull Minimap Button** (or type `/wowkb` or `/killboard`) to open the **Frontline War Room Dashboard**.
  - **Right-click the Minimap Button** to toggle between **Classic WoW** and **ElvUI Minimalist** visual themes!
  - Slay an enemy player in open world, duels, or battlegrounds to trigger the **Frontline Kill Banner** on your screen.
  - Sound the War Horn with `/warhorn` or `/kbsos` to rally your guild and party when overwhelmed.
- View the Web Killboard:
  - Open the live web portal in your browser to inspect the **Tactical Intel Feed**, **Hall of Legends**, **Marks of Spite**, and **Character Dossiers**.

---

## 🎮 In-Game Controls & Chat Commands

| Command | Action |
| :--- | :--- |
| `/killboard` or `/wowkb` | Toggle the War Room Dashboard |
| `/killboard alerts` or `/wowkb alerts` | Open Frontline Combat Alerts & Radar Settings (or click `⚙️ Alerts` in header) |
| `/killboard move` or `/wowkb move` | Unlock/lock Kill Banner to drag and reposition anywhere on screen |
| `/killboard test` or `/wowkb test` | Fire preview Kill Banner with sound and raid warning |
| `/killboard theme` | Toggle between Classic WoW and ElvUI Minimalist themes |
| `/kb welcome [reset\|on\|off]` or `/kb beta` | Open or toggle the Early Beta Preview & Feedback guide on login |
| `/kb changelog` or `/kb update` | Open What's New & Version Changelog modal |
| `/armory [Name]` | Inspect detailed combat dossier for any combatant |
| `/kb profile [Name]` | Copy web profile dossier URL for yourself or target |
| `/kb claim <code>` | Verify character ownership token from web platform (follow with `/reload`) |
| `/spot` or `/scout` | Broadcast enemy sighting with coordinates to allies |
| `/warhorn` or `/kbsos` | Trigger Call to Arms SOS emergency rally beacon |
| `/warhorn stop` | Stand down active War Horn muster |
| `/killboard kos` | Review or manage realm KOS Blacklist |
| `/killboard bounty` | Issue a Mark of Spite on an enemy target |
| `/kb testkill` | Simulate an open-world PvP kill to test your feed & banner |
| `/kb stress [N]` | Simulate N (default 25) combat encounters to benchmark FPS and memory |
| `/kb reset` | Reset local battle history and cached realm totals to 0 |
| `/kb bug [text]` or `/kb report` | Submit instant in-game bug report to AI Diagnostician |

> [!TIP]
> You can also reset your local database anytime with 1 click: open `/kb` &rarr; click **`Settings`** &rarr; scroll to **`5. Database Management`** &rarr; click **`[Reset Local Database]`**!

---

## 🛠️ Frequently Asked Questions & Troubleshooting

### Q: Why don't I see the Welcome pop-up every time I log in?
The Welcome dialog is an **onboarding and preview guide** that automatically displays on your first login. To avoid annoying players, it intentionally suppresses itself after you've seen or dismissed it.
- To view it anytime, type **`/kb welcome`** or **`/kb beta`**.
- To re-enable it for your next login, type **`/kb welcome reset`** (or uncheck *"Do not show again on login"* inside the window).
- To read the latest patch notes, type **`/kb changelog`** or **`/kb update`**.

### Q: How do I verify and lock character ownership?
1. In World of Warcraft on your character, enter: `/kb claim <CODE>` (e.g. your secret ownership token).
2. Type **`/reload`** in game. `WoWKillboardSync.exe` (or the web uploader) ingests the token and locks ownership to your character GUID.
3. The platform authenticates your character dossier, unlocking verified owner badge indicators.

### Q: Does the desktop sync require Python installed?
**No.** `WoWKillboardSync.exe` is a standalone, self-contained Windows binary. No Python, terminal, or environment setup is needed. You can also skip the desktop app entirely by using the browser uploader at [wowkillboard.com/upload](https://wowkillboard.com/upload).

### Q: Why didn't my kill immediately appear on the web platform?
World of Warcraft only writes `SavedVariables` to disk when you **log out**, **exit the game**, or type **`/reload`**. Simply type `/reload` after a battle to push your kills immediately to the server.

### Q: Will this addon cause UI lag or taint during raid / combat?
**Zero.** WoW Killboard is engineered under strict **Zero Blizzard UI Taint** guardrails:
- Pure Lua widgets with `BackdropTemplate` (zero XML templates).
- Zero `UISpecialFrames` global table pollution.
- Strict `InCombatLockdown()` gating on all frame modifications, sizing, and restricted chat broadcasts (`"CHANNEL"`, `"SAY"`, `"YELL"`).
- Pre-allocated Kill Banner frames requiring zero memory allocation in combat.

---

## 💬 Beta Feedback & Automated AI Bug Reporting
Found an issue, interface anomaly, or combat discrepancy?
- **In-Game (Instant AI Diagnosis)**: Click the **`[Report Bug]`** button in the addon header bar, or type `/kb bug [details]`. Your telemetry and description will be captured and analyzed by our Automated AI Diagnostician!
- **Web Platform**: Review active tickets, root-cause analyses, and suggested surgical fixes under **Field Bug Dispatches** in the web footer.
- **Direct Feedback**: Send questions or suggestions directly to **Dagariane**.
