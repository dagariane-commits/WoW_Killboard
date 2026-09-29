# WoW Killboard — Community Preview
### Tactical Open-World PvP Combat Intelligence Suite
**Version 1.0.0 (Beta)** • *Development Lead: Scott Quick*

---

## ⚔️ Overview
**WoW Killboard** is a high-performance, zero-taint combat intelligence network and live killboard built for World of Warcraft. It provides real-time killmail tracking, open-world bounty contracts, certified 1v1 solo kill verification, squad war rallies, and battleground combat telemetry.

This distribution package is an authorized **Community Playtest Preview**.

---

## 📦 Package Contents
1. **`WoWKillboard-v1.0.0.zip`**  
   The core World of Warcraft addon folder. Runs silently in the background with zero interface lag, zero Blizzard UI taint, and zero "Action Blocked" popups.
2. **`WoWKillboardSync.exe`**  
   The standalone Windows companion app. Automatically discovers your World of Warcraft installation directories across `C:`, `D:`, and `E:` drives and syncs your combat telemetry directly to the web killboard. Requires no installation, no Python, and no manual configuration.
3. **`README.txt` / `README.md`**  
   This tactical specification, operational guide, and license document.

---

## 🛡️ Core Addon Functions & In-Game Interface
Type **/kb** in-game to toggle the main Tactical Command Console. The interface is structured into five operational modules:

### 1. Intel Tab (Live Combat Feed & High Command Execution List)
- **Real-Time Killmails:** Dispatches showing killer, victim, guild, faction, class, level, killing blow ability, and spatial map coordinates.
- **High Command Execution List:** Top 10 Most Wanted blood marks on the realm displayed in a tactical card grid.
- **One-Click Bounty Tracking:** `[⚔ Accept Contract]` / `[✓ Tracking]` buttons to pursue high-value enemy targets.
- **Certified 1v1 Solo Duels:** 15-second sliding temporal clustering algorithm distinguishes true 1v1 solo kills from multi-attacker gang ganks.

### 2. Champions Tab (Realm Leaderboards & Military Honor Ranks)
- **Realm Leaderboards:** Server-wide combatant rankings sorted by honorable kills, K/D ratio, and certified solo kills.
- **Guild Standings:** Guild kill tallies, active rosters, and faction balance war-room telemetry.
- **Classic PvP Military Titles:** Full rank title integration from Private to Grand Marshal / Scout to High Warlord.

### 3. Marks of Spite Tab (Bounties & Realm KOS Blacklist)
- **In-Game Gold Bounties:** Place bounties directly upon being slain or through the tactical interface.
- **Active Contracts:** Open marks with live bounty pots awaiting collection.
- **Hall of Fame:** Record-setting bounty claims and master bounty hunters.
- **Wall of Shame (Blood Debtors):** Realm-wide Kill On Sight (KOS) blacklist for notorious gankers and camp griefers.
- **Automated Redemption:** Slaying a wanted mark automatically pays out the gold reward upon combat verification.

### 4. War Rallies & Call for Backup (SOS Defense)
- **Squad War Rallies:** Muster rallies directly in-game via `/kb rally [objective]`.
- **Elapsed Duration Telemetry:** Real-time running timers and deployment tracking for active squad operations.
- **One-Click SOS Emergency Distress:** Broadcast emergency distress beacon (`/kb sos`) sending instant GPS map coordinates to allies and guildmates when attacked.

### 5. Zone Intel & Tactical Telemetry
- **Spatial Map Telemetry:** Zone hotspots and sector danger ratings across Azeroth.
- **Battleground Metrics:** Real-time damage dealt, healing output, killing blows, and objective control rankings.

---

## ⌨️ Tactical Slash Commands Reference

| Command | Action |
| :--- | :--- |
| `/kb` | Toggle the Main Tactical Command Console |
| `/kb mini` | Toggle the Draggable Mini Tactical Radar HUD |
| `/kb rally [name]` | Muster an open-world squad war rally at your location |
| `/kb sos` | Dispatch an emergency distress beacon with GPS coordinates |
| `/kb sync` | Inspect local SavedVariables telemetry buffer status |
| `/kb testkill` | Generate synthetic combat verification telemetry |
| `/kb help` | Print command summary to the chat window |

---

## 🚀 Quick-Start Installation Guide

### Step 1: Install the In-Game Addon
1. Download and extract `WoWKillboard-v1.0.0.zip`.
2. Copy the resulting `WoWKillboard` folder into your World of Warcraft AddOns directory:
   - **Classic Era / Anniversary:** `World of Warcraft\_classic_era_\Interface\AddOns\`
   - **Forever Beta:** `World of Warcraft\_classic_beta_\Interface\AddOns\`
   - **Modern Retail:** `World of Warcraft\_retail_\Interface\AddOns\`
3. Start the game (or type `/reload` if WoW is already running).
4. Ensure **WoW Killboard** is checked in your AddOns menu.

### Step 2: Run the Windows Companion (Recommended)
1. Run `WoWKillboardSync.exe`.
2. The application will automatically scan your system, detect your active World of Warcraft directories, and silently watch your SavedVariables.
3. Whenever you reload your interface (`/reload`) or log out, your combat kills and bounties sync directly to the realm killboard portal in seconds.
*(Alternatively, you can manually drag-and-drop your `WoWKillboard.lua` file onto the website's Upload tab).*

### Step 3: View the Live Web Killboard
Open your web browser and navigate to the portal:  
**http://13.216.102.148**

---

## 🔒 Architecture & Engine Guardrails
- **Zero Blizzard UI Taint:** Constructed with 100% pure Lua widgets using standard `BackdropTemplate`. Zero XML templates, zero `UISpecialFrames` pollution, and strictly gated against `InCombatLockdown()` to guarantee zero "Action Blocked" popups.
- **Universal Cross-Client Parity:** Single unified codebase supporting WoW Forever Beta, Classic Era, Anniversary Edition, and Modern Retail through dynamic runtime feature detection.
- **Cryptographic Deduplication:** Every kill encounter receives a deterministic 32-bit FNV-1a hash derived from timestamps, combatant GUIDs, and spatial coordinates. Group kills are cleanly merged into a single verified kill record crediting all participants.

---

## 🗺️ Development Roadmap & Moving Forward
We are advancing WoW Killboard through disciplined engineering phases:

- **Phase 1: Community Playtest & Core Telemetry (Active)**  
  Core combat tracking, 1v1 solo verification, Top 10 Most Wanted execution lists, in-game squad rallies, and zero-barrier Windows auto-sync.
- **Phase 2: Cross-Realm Expansion & Multi-Client Telemetry**  
  Multi-realm partition support, deep battleground telemetry correlation, and cross-faction nemesis indexing.
- **Phase 3: Deadly Wilderness Hazards & Guild Feuds (Planned)**  
  Wilderness creature and world boss casualty tracking (Deadly NPCs), alongside automated Guild vs Guild blood feuds and oathbreaker blacklist scorecards.
- **Phase 4: StreamBox Broadcaster HUD (Planned)**  
  A lightweight, transparent OBS / Streamlabs browser overlay delivering instant animated kill alerts and session K/D tickers for live streamers.
- **Phase 5: Advanced Player Armory & Gear Progression (Planned)**  
  Full inspect gear snapshots, talent builds, and historical combat progression dossiers.

---

## ⚖️ Legal Notice, Intellectual Property & Anti-Theft Protection
**Copyright © 2026 Scott Quick / WoW Killboard Development Team. All Rights Reserved.**

### CONFIDENTIAL PLAYTEST PREVIEW
This software, source code, companion binary, UI designs, synchronization protocols, temporal clustering algorithms, and documentation are the proprietary intellectual property of **Scott Quick**.

This package is provided strictly for private evaluation by authorized playtesters. Unauthorized copying, decompilation, disassembly, reverse engineering, redistribution, sub-licensing, public re-hosting, or creation of derivative works without prior express written authorization from Scott Quick is strictly prohibited under United States and international copyright, trade secret, and intellectual property laws.

*World of Warcraft, Warcraft, and Blizzard Entertainment are trademarks or registered trademarks of Blizzard Entertainment, Inc. in the U.S. and/or other countries. This project is an independent combat telemetry software network and is not affiliated with, endorsed by, or sponsored by Blizzard Entertainment, Inc. All addon components are developed in strict compliance with Blizzard's UI & Add-on Development Policy.*
