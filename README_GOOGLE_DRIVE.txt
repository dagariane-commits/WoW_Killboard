================================================================================
                       WoW Killboard — Community Preview
               Tactical Open-World PvP Combat Intelligence Suite
                              Version 1.0.0 (Beta)
================================================================================

OVERVIEW
--------------------------------------------------------------------------------
WoW Killboard is a high-performance, zero-taint combat intelligence network 
and live killboard built for World of Warcraft. It provides real-time killmail 
tracking, open-world bounty contracts, certified 1v1 solo kill verification, 
squad war rallies, and battleground combat telemetry.

This distribution package is an authorized Community Playtest Preview.


PACKAGE CONTENTS
--------------------------------------------------------------------------------
1. WoWKillboard-v1.0.0.zip
   The core World of Warcraft addon folder. Runs silently in the background 
   with zero interface lag, zero Blizzard UI taint, and zero "Action Blocked" popups.

2. WoWKillboardSync.exe
   The standalone Windows companion app. Automatically discovers your World of 
   Warcraft installation directories across C:, D:, and E: drives and syncs your 
   combat telemetry directly to the web killboard. Requires no installation, 
   no Python, and no manual configuration.

3. README.txt
   This tactical specification, operational guide, and license document.


CORE ADDON FUNCTIONS & IN-GAME INTERFACE
--------------------------------------------------------------------------------
Type /kb in-game to toggle the main Tactical Command Console.
The interface is structured into five operational modules:

1. INTEL TAB (Live Combat Feed & High Command Execution List)
   - Real-time combat dispatches showing killer, victim, guild, faction, class, 
     level, killing blow ability, and spatial map coordinates.
   - High Command Execution List: Top 10 Most Wanted blood marks on the realm.
   - One-click [Accept Contract] tracking to hunt high-value enemy targets.
   - Precise 15-second sliding temporal clustering distinguishing certified 1v1 
     solo kills from multi-attacker gang ganks.

2. CHAMPIONS TAB (Realm Leaderboards & Military Honor Ranks)
   - Server-wide combatant rankings sorted by honorable kills, K/D ratio, and 
     certified solo duels.
   - Guild standings and faction balance war-room telemetry.
   - Classic PvP Military Rank titles (Private to Grand Marshal / Scout to High Warlord).

3. MARKS OF SPITE TAB (Bounties & Realm KOS Blacklist)
   - In-game gold bounties placed directly upon being slain or through the UI.
   - Active Contracts: Open marks with live bounty pots awaiting collection.
   - Hall of Fame: Record-setting bounty claims and master bounty hunters.
   - Wall of Shame (Blood Debtors): Realm-wide Kill On Sight (KOS) blacklist for 
     notorious gankers and camp griefers.
   - Automated bounty redemption: Slaying a wanted mark automatically pays out 
     the gold reward upon combat verification.

4. WAR RALLIES & CALL FOR BACKUP (SOS Defense)
   - Squad war rallies mustered directly in-game via `/kb rally [objective]`.
   - Real-time elapsed duration and countdown telemetry for active rally operations.
   - One-click SOS emergency distress beacon (`/kb sos`) broadcasting instant 
     GPS map coordinates to allies and guildmates when attacked.

5. ZONE INTEL & TACTICAL TELEMETRY
   - Spatial sector telemetry and hot-spot danger ratings across Azeroth.
   - Battleground combat metrics: Real-time damage dealt, healing output, 
     killing blows, and objective control rankings.


TACTICAL SLASH COMMANDS REFERENCE
--------------------------------------------------------------------------------
  /kb               - Toggle the Main Tactical Command Console
  /kb mini          - Toggle the Draggable Mini Tactical Radar HUD
  /kb rally [name]  - Muster an open-world squad war rally at your location
  /kb sos           - Dispatch an emergency distress beacon with GPS coordinates
  /kb sync          - Inspect local SavedVariables telemetry buffer status
  /kb testkill      - Generate synthetic combat verification telemetry
  /kb help          - Print command summary to the chat window


QUICK-START INSTALLATION GUIDE
--------------------------------------------------------------------------------
STEP 1: INSTALL THE ADDON
  1. Extract `WoWKillboard-v1.0.0.zip`.
  2. Copy the resulting `WoWKillboard` folder into your WoW AddOns directory:
     - Classic Era / Anniversary:
       World of Warcraft\_classic_era_\Interface\AddOns\
     - Forever Beta:
       World of Warcraft\_classic_beta_\Interface\AddOns\
     - Modern Retail:
       World of Warcraft\_retail_\Interface\AddOns\
  3. Start the game (or type `/reload` if WoW is already running).
  4. Ensure "WoW Killboard" is checked in your AddOns menu.

STEP 2: RUN THE WINDOWS COMPANION (OPTIONAL BUT RECOMMENDED)
  1. Run `WoWKillboardSync.exe`.
  2. The application will automatically scan your system, detect your active 
     World of Warcraft directories, and silently watch your SavedVariables.
  3. Whenever you reload your interface (`/reload`) or log out, your combat kills 
     and bounties sync directly to the realm killboard portal in seconds.
  (Alternatively, you can manually drag-and-drop your WoWKillboard.lua file 
   onto the website's Upload tab).

STEP 3: VIEW THE LIVE WEB KILLBOARD
  Open your web browser and navigate to the portal address:
  http://13.216.102.148
  (or your designated realm portal link).


ARCHITECTURE & ENGINE GUARDRAILS
--------------------------------------------------------------------------------
- Zero Blizzard UI Taint:
  The addon is constructed with 100% pure Lua widgets using standard 
  BackdropTemplate. It contains zero XML templates, zero UISpecialFrames 
  pollution, and strictly respects InCombatLockdown() gating to ensure your 
  game client never suffers UI taint or blocked action errors.

- Universal Cross-Client Parity:
  Single unified codebase supporting WoW Forever Beta, Classic Era, 
  Anniversary Edition, and Modern Retail through dynamic runtime feature 
  detection.

- Cryptographic Deduplication:
  Every kill encounter is stamped with a deterministic 32-bit FNV-1a hash 
  derived from timestamps, combatant GUIDs, and spatial coordinates. When 
  multiple raid or squad members log the same battle, the engine merges them 
  into a single verified kill record crediting all participants.


DEVELOPMENT ROADMAP & MOVING FORWARD
--------------------------------------------------------------------------------
We are building WoW Killboard through disciplined engineering phases:

- PHASE 1: COMMUNITY PLAYTEST & CORE TELEMETRY (ACTIVE)
  Deploying core combat tracking, 1v1 solo verification, Top 10 Most Wanted 
  execution lists, in-game squad rallies, and zero-barrier Windows auto-sync.

- PHASE 2: CROSS-REALM EXPANSION & MULTI-CLIENT TELEMETRY
  Expanding multi-realm partition support, deep battleground telemetry 
  correlation, and cross-faction nemesis indexing.

- PHASE 3: DEADLY WILDERNESS HAZARDS & GUILD FEUDS (PLANNED)
  Integrating lethal wilderness creature and world boss casualty tracking 
  (Deadly NPCs), alongside automated Guild vs Guild blood feuds and 
  oathbreaker blacklist scorecards.

- PHASE 4: STREAMBOX BROADCASTER HUD (PLANNED)
  A lightweight, transparent OBS / Streamlabs browser overlay delivering 
  instant animated kill alerts and session K/D tickers for live streamers.

- PHASE 5: ADVANCED PLAYER ARMORY & GEAR PROGRESSION (PLANNED)
  Full inspect gear snapshots, talent builds, and historical combat 
  progression dossiers.


LEGAL NOTICE, INTELLECTUAL PROPERTY & ANTI-THEFT PROTECTION
--------------------------------------------------------------------------------
Copyright (c) 2026 Scott Quick / WoW Killboard Development Team.
All Rights Reserved.

CONFIDENTIAL PLAYTEST PREVIEW:
This software, source code, companion binary, UI designs, synchronization 
protocols, temporal clustering algorithms, and documentation are the proprietary 
intellectual property of Scott Quick. 

This package is provided strictly for private evaluation by authorized playtesters. 
Unauthorized copying, decompilation, disassembly, reverse engineering, redistribution, 
sub-licensing, public re-hosting, or creation of derivative works without prior 
express written authorization is strictly prohibited under United States and 
international copyright, trade secret, and intellectual property laws.

World of Warcraft, Warcraft, and Blizzard Entertainment are trademarks or 
registered trademarks of Blizzard Entertainment, Inc. in the U.S. and/or other 
countries. This project is an independent combat telemetry software network and 
is not affiliated with, endorsed by, or sponsored by Blizzard Entertainment, Inc. 
All addon components are developed in strict compliance with Blizzard's 
UI & Add-on Development Policy.
================================================================================
