# WoW Killboard — zKillboard for World of Warcraft

[![Release](https://img.shields.io/badge/Release-v1.0.0-00e5ff.svg)](CHANGELOG.md)
[![WoW Flavors](https://img.shields.io/badge/WoW-Forever%20%7C%20Classic%20Era%20%7C%20Anniversary%20%7C%20Retail-ffd700.svg)](docs/TAINT_AND_COMPATIBILITY.md)
[![Taint Security](https://img.shields.io/badge/Blizzard%20UI%20Taint-Zero%20%28100%25%20Clean%29-00ff66.svg)](docs/TAINT_AND_COMPATIBILITY.md)
[![Desktop Sync](https://img.shields.io/badge/Desktop%20Sync-Standalone%20EXE-blue.svg)](dist/WoWKillboardSync.exe)
[![License](https://img.shields.io/badge/License-GPLv3-lightgrey.svg)](LICENSE)

An enterprise-grade PvP combat intelligence suite, in-game running leaderboard, bounty escrow platform, and real-time web telemetry network inspired directly by **EVE Online's zKillboard.com**, purpose-built for **World of Warcraft: Forever**, **Classic Era**, **Anniversary**, and modern **Retail** clients.

---

## Technical Documentation & Wiki

Comprehensive technical documentation is maintained in the [`docs/`](docs/) directory:

- 📖 **[Master Technical Wiki](docs/README.md)** — Architectural index and developer portal.
- 🏛️ **[System Architecture Specification](docs/ARCHITECTURE.md)** — In-depth breakdown of the 3-tier model, data contracts, and FNV-1a hashing.
- ⚔️ **[Combat Telemetry & Gang Engine](docs/COMBAT_ENGINE.md)** — 15-second sliding gang clustering, 1v1 duels, and BG scoreboard telemetry.
- 💰 **[Bounty Escrow & Oathbreaker Ledger](docs/BOUNTY_SYSTEM.md)** — Bounty contracts, "Wall of Shame", anti-win-trade rules, and debtor radar.
- 🛡️ **[Taint Security & Compatibility](docs/TAINT_AND_COMPATIBILITY.md)** — Complete guide to our zero-taint standard across all 4 WoW client flavors.
- 🗺️ **[Forward Strategic Roadmap](docs/ROADMAP.md)** — Phased roadmap covering public launch, guild war rooms, and ranked seasons.
- 🚀 **[Public Release & Distribution Playbook](docs/PUBLIC_RELEASE_PLAYBOOK.md)** — Guide for packaging, CurseForge/Wago distribution, and hosting.
- 📝 **[Semantic Version Change Log](CHANGELOG.md)** — Full changelog trail from initial prototype to v1.0.0 release.
- 🤝 **[Contributing Guidelines](CONTRIBUTING.md)** — Development standards and PR checklist for open-source contributors.
- ⚖️ **[Legal, Safety & Compliance Guide](docs/LEGAL_AND_COMPLIANCE.md)** — Authorship, Blizzard Add-on Policy compliance, zero PII, and anti-cheat safety.

---

## Architecture at a Glance

Because World of Warcraft addons operate in an isolated Lua sandbox without raw outbound socket capabilities, WoW Killboard operates across three synchronized tiers:

```mermaid
flowchart TD
    subgraph Client ["World of Warcraft Client (In-Game Addon)"]
        CL["Combat Log & System Chat\n(SWING, SPELL, DUEL, HONOR)"] --> CT["Combat Tracker Engine"]
        US["Proximity Unit Scanner\n(Level, Class, Guild, Target/Mouseover)"] --> CT
        GPS["C_Map Telemetry\n(Normalized X, Y, MapID)"] --> CT
        CT --> KM["Killmail Generator\n(FNV-1a Hash, Solo vs Gang)"]
        KM --> BE["Bounty & Debt Engine\n(Wanted Sirens, Escrow/C.O.D.)"]
        KM --> P2P["P2P Sync\n(C_ChatInfo Addon Channels)"]
        KM --> IGUI["Tactical Dashboard\n(/kb or Minimap Icon)"]
        KM --> SV["SavedVariables\n(WoWKillboardDB.lua)"]
    end

    subgraph Desktop ["Desktop Ingestion Agent (Zero-Config EXE)"]
        SV --> Watcher["WoWKillboardSync.exe\n(Multi-Drive Auto-Discovery)"]
        Watcher --> API["HTTPS REST Ingestion"]
    end

    subgraph Web ["zKillboard Web Platform"]
        API --> Server["web/server.py (Flask API + SQLite)"]
        Server --> WebUI["Tactical Dark Web UI\n(Live Ticker, BGs, Bounties, Wall of Shame)"]
    end
```

---

## Core Feature Highlights

### 1. In-Game Addon (`Addon/WoWKillboard/`)
- **Dual Theme Architecture (Classic WoW & ElvUI Minimalist)**:
  - **Classic WoW Theme**: Authentic Blizzard dialog stone backgrounds, gold/brass bevels (`UI-DialogBox-Border`), and warm parchment tooltips.
  - **ElvUI Minimalist Theme**: Sleek obsidian dark gunmetal backdrop with 1px razor borders and high-contrast cyan accents.
  - **Instant 1-Click Switcher**: Toggle between themes instantly in-game via the header button `[Theme: Classic]` / `[Theme: ElvUI]` or `/killboard theme`.
- **Zero-Taint Isolated Dashboard (`/kb`)**:
  - 100% template-free Lua design. Zero XML template dependencies. Zero `UISpecialFrames` pollution.
  - Safe ESC key event propagation (`SetPropagateKeyboardInput`).
  - Guaranteed **88px clear margin** eliminating navigation tab and filter button overlap.
- **Balanced 3-Card Tactical Stat Header**:
  - `SESSION COMBAT K/D` (Cyan) — Active session kills, deaths, and K/D ratio.
  - `1v1 DUELS RECORD` (Gold) — Dedicated duel tracking (wins, losses, win %).
  - `BATTLEGROUNDS RECORD` (Blue) — Battleground matches (wins, losses, win %).
- **1v1 Duel Match Engine**:
  - Automatically captures duel outcomes (knockouts and forfeits) via `CHAT_MSG_SYSTEM`.
  - Mints certified duel killmails with exact location GPS tags.
- **Temporal Hostile Gang Clustering**:
  - Sliding 15-second window correlates all hostile combatants engaging a victim to distinguish certified 1v1 solo kills from gang ganks.
- **Battleground Telemetry**:
  - Scoreboard integration (`UPDATE_BATTLEFIELD_SCORE`): Real-time damage done, healing done, and objective scores.
- **Guild War Tracking & In-Game Leaderboards**:
  - In-game guild affiliation indexing via `GetGuildInfo(unit)`.
  - In-game Top War Guilds ranking table inside the `/kb` dashboard.
- **Bounty Escrow, Delayed Last-Seen Intel & Debt Ledger**:
  - Place gold bounties (`/kb bounty <Target> <Gold>`).
  - **Delayed Last-Seen Vicinity**: Bounty rows display the last confirmed combat zone and elapsed time (`Last Sighted: Stranglethorn Vale ~14m ago`).
  - Anti-win-trade heuristics (level deltas, guild collusion protection, duplicate kill cooldowns).
  - Oathbreaker state machine: Debtor sirens (`PlaySound(8959)`) and screen alarms when an Oathbreaker is near.
  - 1-click mail redemption portal with a 10% administrative fee.

### 2. Desktop Ingestion Agent (`WoWKillboardSync.exe`)
- **Standalone Windows Executable**: Zero Python installation required for players.
- **Multi-Drive Auto-Discovery**: Automatically discovers `SavedVariables/WoWKillboard.lua` across `C:`, `D:`, and `E:` drives for Retail, Classic, Classic Era, and Forever Beta.
- **Streaming Lua Tokenizer**: High-speed recursive-descent parser.

### 3. zKillboard-Style Web Intelligence Platform (`web/`)
- **Live Kill Ticker**: Tactical dark-slate UI modeled directly on **zkillboard.com**.
- **Bounty Hall of Fame & Records**: Dedicated 4-card leaderboards (`/api/bounties/leaderboards`) celebrating Top Bounty Hunters, Highest Bounty Contracts, Most Elusive Outlaws, and Fastest Collected Manhunts.
- **Delayed Last-Seen Intel & Tiered Recon**: Public contracts show confirmed combat Zone (e.g. `Last Sighted: Stranglethorn Vale ~14m ago`), with exact Subzone landmark (`Booty Bay`) unlocked for community supporters.
- **Interactive Character Combat Dossiers**: Click any character name to view lifetime kills, deaths, K/D, solo kills, damage/healing meters, and historical guild affiliation timeline.
- **External Armory Links**: 1-click links to Official Blizzard Armory, Classic Vanilla Armory (`Ironforge.pro`), and Warcraft Logs.
- **Guild War Leaderboards & Guild Dossiers**: Dedicated Guilds tab ranking top guilds by kills, deaths, K/D, and active combatant count, with roster inspection.
- **Combat Dossiers**: Click any killmail to open detailed combatant cards, damage meters, and location telemetry.
- **Wall of Shame**: Pinned public registry of Oathbreakers in default with days-in-default counters.
- **Battleground Gladiators**: Ranked leaderboards for Top Damage Dealers and Combat Medics.
- **StreamBox Native OBS Overlay**: Direct `/streambox/<CharacterName>` overlay for OBS Studio and Twitch/YouTube streamers with transparent background and auto-updating kill/death ticker.
- **zKillboard Docs & Intelligence Hub**: 7-section informational hub and global footer covering Features, FAQ, About, Delayed Intel, Supporter/Payments, StreamBox Generator, and Legal/Fair Play policies.
- **100% Ad-Free Experience**: Zero commercial banners, tracking scripts, or ad networks. Supported entirely through voluntary contributions to **Forged By Valor (501(c)(3))** empowering veteran mental health through gaming.

---

## Directory Layout

```text
WoW_Killboard/
├── Addon/
│   └── WoWKillboard/
│       ├── WoWKillboard.toc         # Multi-client TOC descriptor (11503, 11504, 110002)
│       ├── Config.lua               # Constants, sound IDs, class colors
│       ├── Utils.lua                # FNV-1a hash generator, formatters, GPS resolution
│       ├── UnitScanner.lua          # Proximity level/class/guild cache
│       ├── CombatTracker.lua        # Combat log, gang clustering, duel/BG telemetry
│       ├── Killmail.lua             # Standardized killmail model & persistence
│       ├── BountyEngine.lua         # Bounties, anti-win-trade, debtor sirens
│       ├── Sync.lua                 # P2P Addon networking (C_ChatInfo)
│       ├── Leaderboard.lua          # Multi-mode rankings (All / World / BG / Duel)
│       ├── UI.lua                   # 100% taint-free dark dashboard (/kb)
│       └── Core.lua                 # Lifecycle, slash commands, minimap button
├── docs/                            # Comprehensive Technical Wiki
│   ├── README.md                    # Master Wiki index & portal
│   ├── ARCHITECTURE.md              # 3-tier architectural specification
│   ├── COMBAT_ENGINE.md             # Combat logging & gang clustering details
│   ├── BOUNTY_SYSTEM.md             # Escrow, debt ledger & debtor radar
│   ├── TAINT_AND_COMPATIBILITY.md   # Zero-taint philosophy & client matrix
│   ├── ROADMAP.md                   # Strategic forward plan (Phases 1-4)
│   └── PUBLIC_RELEASE_PLAYBOOK.md   # Packaging & distribution guide
├── sync/
│   └── watcher.py                   # SavedVariables file watcher & Lua parser
├── web/
│   ├── server.py                    # Flask REST API & SQLite persistence
│   └── static/
│       ├── index.html               # Responsive web interface
│       ├── app.js                   # Reactive state controller
│       └── style.css                # Dark zKillboard styling
├── tests/
│   ├── test_pipeline.py             # End-to-end pipeline test suite
│   ├── test_watcher_parser.py       # Lua parser unit tests
│   └── validate_lua.py              # Automated Lua syntax & bracket validator
├── CHANGELOG.md                     # Semantic version change log
├── CONTRIBUTING.md                  # Open-source contribution guidelines
├── WoWKillboardSync.exe             # Pre-compiled standalone sync binary (8.8 MB)
└── WoWKillboard-v1.0.0.zip          # Production-ready addon release package
```

---

## Quickstart Guide

### 1. In-Game Addon Installation
1. Download [`WoWKillboard-v1.0.0.zip`](file:///c:/Users/SQUICK/WoW_Killboard/WoWKillboard-v1.0.0.zip) and extract it into your World of Warcraft AddOns directory:
   - **Forever Beta**: `World of Warcraft/_classic_beta_/Interface/AddOns/WoWKillboard`
   - **Classic Era**: `World of Warcraft/_classic_era_/Interface/AddOns/WoWKillboard`
   - **Anniversary**: `World of Warcraft/_anniversary_/Interface/AddOns/WoWKillboard`
   - **Modern Retail**: `World of Warcraft/_retail_/Interface/AddOns/WoWKillboard`
2. Start WoW and ensure **WoW Killboard** is checked in your AddOns menu.
3. In-game commands:
   - `/killboard` or `/wowkb` — Open the Killboard dashboard.
   - `/killboard theme [classic|elvui]` — Switch between Classic WoW and ElvUI themes.
   - `/killboard stats` — View current session damage, healing, kills, and K/D.
   - `/killboard bounty <Name> <Gold>` — Place a bounty on an enemy player.
   - `/killboard reset` — Clear local kill database.

### 2. Standalone Desktop Sync (Zero-Python)
1. Launch [`WoWKillboardSync.exe`](file:///c:/Users/SQUICK/WoW_Killboard/dist/WoWKillboardSync.exe).
2. The agent automatically detects your WoW installation and begins monitoring `SavedVariables/WoWKillboard.lua`.
3. Whenever you reload (`/reload`) or log out of WoW, new combat kills and bounties sync automatically to the web platform.

### 3. Running the Local Web Server (For Developers)
```bash
# Install dependencies
pip install -r requirements.txt

# Start the Flask web platform
python web/server.py
```
Open **`http://localhost:8080`** in your browser.

### 4. Running Automated Tests
```bash
# Validate all 10 Lua files for syntax compliance
python tests/validate_lua.py

# Run complete end-to-end test suite
python -m unittest discover tests
```

---

## Legal, Safety & Privacy Compliance

- **Sole Authorship & Ownership**: Architected and created by **Scott Quick** (Founder & Executive Director of **Forged By Valor**, a registered 501(c)(3) organization).
- **Blizzard Add-on Policy Compliant**: 100% free of charge, open-source visible code, zero in-game commercial ads, zero in-game donation solicitations, and zero real-money trading (RMT).
- **Anti-Cheat & Warden Safe**: Operates purely within Blizzard's sandboxed Lua environment. Zero process memory reading/writing, zero DLL injection, and zero executable patching. The desktop sync agent reads plain-text SavedVariables files from disk (identical to *Warcraft Logs* and *Raider.IO*).
- **Zero PII (Personally Identifiable Information)**: Does not collect, transmit, or store real names, emails, IP addresses, BattleTags, account credentials, or hardware IDs.
- **Trademark Notice**: *World of Warcraft, Warcraft, Battle.net, and Blizzard Entertainment are trademarks or registered trademarks of Blizzard Entertainment, Inc. in the U.S. and/or other countries. WoW Killboard is not affiliated with, authorized by, sponsored by, or endorsed by Blizzard Entertainment, Inc.*
- Detailed compliance audit: See [`docs/LEGAL_AND_COMPLIANCE.md`](docs/LEGAL_AND_COMPLIANCE.md).

---

## License

This project is licensed under the GNU General Public License v3.0 (GPLv3). Copyright (c) 2026 Scott Quick / Forged By Valor, 501(c)(3). See [LICENSE](LICENSE) for details.
