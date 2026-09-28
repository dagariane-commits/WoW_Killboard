# Changelog

All notable changes to the **WoW Killboard** project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.49] - 2026-09-28

### Added
- **Addon Intel Tab Overhaul with Top 10 Most Wanted (`UI.lua`)**:
  - Re-architected the in-game Intel tab (`UI:RenderLiveFeed()`) to faithfully match the web platform's Intel feed and execution board.
  - Added the **High Command Execution List — Realm's Most Notorious** header with a "See All Marks →" action button switching directly to the Marks of Spite tab.
  - Integrated a 10-slot 2x5 grid of Most Wanted cards directly above the live combat feed:
    - Active blood contracts display rank `#1`–`#10`, gold reward with coin icon, faction-tinted backdrops, class borders, character names colorized by class, guild/faction affiliation, last seen sector telemetry with elapsed minutes, and one-click `[⚔ Accept]` / `[✓ Tracking]` contract buttons.
    - Unclaimed slots display `#X WANTED - OPEN - Pending Target - <Unclaimed> - No Active Contract` with a one-click `[+ Issue Mark]` button opening the in-game Mark of Spite dialog.
  - Seamlessly anchored the Tactical Telemetry KPI summary bar and live killmail stream below the Most Wanted board with fluid mousewheel scrolling.

### Changed
- **Web War Rallies Restricted to Read-Only Telemetry (`app.js`, `index.html`, `server.py`)**:
  - Removed rally creation / muster forms and modal dialogs from the web interface; rallies are now exclusively mustered in-game via the addon.
  - Added in-game muster badge and directive across the banner and empty states: `📯 Muster In-Game: /kb rally`.
  - Implemented real-time elapsed running duration badges on all active rally cards (`⏱️ Running for Xm` / `Xh Ym`) and clear active timing telemetry.
  - Extended distress beacon API cutoff in `server.py` from 30 minutes to 2 hours (`cutoff = int(time.time()) - 7200`) ensuring active squads remain visible throughout sustained engagements.

## [1.4.48] - 2026-09-28

### Added
- **Full Party Squad Telemetry & Kill/Assist Attribution (`CombatTracker.lua`)**:
  - Implemented `CT:GetPartyMembersList()` querying all active party and raid members (`"player"`, `"party1"`-`"party4"`, `"raid1"`-`"raidN"`) across all 4 WoW client flavors.
  - Automatically incorporates all squad members into the `attackersList` Assault Force breakdown with their real names, classes, levels, and guild tags.
  - Accurately attributes Victorious Combatant to the party teammate who scored the killing blow / top damage when the player acts in support, incrementing `CT.SessionStats.assists` for the assisting player.

### Fixed
- **Gurubashi Arena Subzone Fallback Bug (`watcher.py`, `server.py`, `app.js`)**:
  - Fixed logic in `watcher.py` where empty subzones in open wilderness fell back to `"Gurubashi Arena"` via Python `or`, causing Arathi Highlands kills to display as `Arathi Highlands (Gurubashi Arena)`.
  - Added frontend and ingestion sanitization preventing non-Stranglethorn zones from inheriting Gurubashi Arena subzones.
  - Cleaned all existing bogus subzone records in SQLite.
- **Allied Vanguard Elimination & Bystander Honor Gating (`CombatTracker.lua`, `server.py`)**:
  - Eliminated dummy `"Allied Vanguard"` placeholder records entirely.
  - Implemented Scott Quick's bystander protection: solo players who dealt 0 damage, healed 0 attackers, and were not in a party discard passive bystander honor ticks without creating phantom killmails.
  - Added fallback promotion in `server.py` ensuring incoming or legacy kills with "Allied Vanguard" automatically promote the highest-damage real player attacker.

### Changed
- **Killmail Intelligence Dossier Visual Overhaul (`app.js`, `index.html`, `style.css`)**:
  - Expanded modal container to 820px (`modal-card-lg kill-dossier-card`) completely eliminating awkward text wrapping on combatant names.
  - Added authentic WoW Gold Cinzel header with crossed swords crest.
  - High-contrast glowing Victorious Combatant (Emerald) and Slain Combatant (Crimson) cards with large 52px class crests and role badges.
  - Integrated SVG Combat Role icons: Tank (Shield), Healer (Medical Cross), and DPS (Crossed Swords).
  - Explicit badge differentiation in Assault Force: `★ FINAL BLOW` (Crimson/Gold) vs `🛡️ SQUAD ASSIST` (Sapphire/Emerald).
  - Refined two-box tactical readout at bottom with radar map pins and clean coordinates.

## [1.4.47] - 2026-09-27

### Added
- **Website-Parity In-Game Champions Dashboard (`UI.lua`)**:
  - Re-architected the in-game Leaderboard tab to faithfully mimic the web platform's Champions layout.
  - **Operative Benchmark Comparison Banner**: Features dedicated benchmark card at the top displaying the player's callsign, class crest, live Rank, Kills, Solo Kills, Delta vs #1 (`★ #1 Apex Leader` or `-X Kills`), and Percentile (`Top 0.1% (99.9th)`).
  - **Full Table Column Structure**: Clean 7-column tabular layout matching the website: `RANK`, `COMBATANT`, `GUILD`, `FACTION`, `KILLS`, `SOLO KILLS`, `PERCENTILE`.
  - **In-Game Save & Sync Button**: Added `[⚡ Sync Kills]` header action button adjacent to Combat Alerts, allowing players to flush memory to `SavedVariables` on disk and instantly trigger `WoWKillboardSync.exe`.

### Changed
- **Hall of Legends Renamed to Champions (Web & Addon)**:
  - Updated web navigation rail button and mobile drawer from "Hall of Legends" to "Champions".
  - Updated section title header and error states in `app.js` to "Champions".
  - Renamed in-game addon tab from "Hall of Legends" to "Champions".
- **4-Way Mode Filter Toggle on Web Champions View (`app.js`)**:
  - Replaced static `Open World PvP` pill with reactive 4-way filter pills: `World`, `BGs`, `Duels`, and `Arenas` (disabled/greyed out for Classic flavors).
  - Seamlessly reloads rankings and benchmark statistics via `/api/leaderboard?mode=...` and `/api/guilds?mode=...`.
- **Lexer Precision in Test Validation (`validate_lua.py`)**:
  - Upgraded Lua comment lexing to tokenize strings and comments simultaneously, preventing false-positive paren mismatches on format strings containing hyphens.

## [1.4.46] - 2026-09-27

### Fixed
- **Character Claim Verification Logic & Multi-Character Bug (`server.py`, `app.js`)**:
  - Fixed issue where selecting or claiming another character would incorrectly show them as `🛡️ Verified Owner` even when unverified.
  - Enforced strict verification check `is_verified: bool(r["verified"] and r["verified"] == 1)` in `/api/characters`.
  - Characters awaiting in-game `/kb claim <CODE>` now correctly display `⏳ Verification Pending` with `[Verify Code]` and `[Cancel Claim]` controls.
  - Added `@app.route("/api/auth/release-claim", methods=["POST"])` allowing players to release unverified or verified claims and unlink characters cleanly.
- **Accurate Character Telemetry Sync (`app.js`, `UI.lua`, `Core.lua`)**:
  - Fixed bug where logged-in characters defaulted to Warrior instead of Paladin due to unpopulated class/level/faction attributes.
  - Updated Addon `UI:ShowCharacterWebLink` to pass `class`, `level`, and `faction` in the URL query parameters (`/?character=Name&class=PALADIN&level=60&faction=Alliance`).
  - Implemented `syncActiveCharacterTelemetry(charName)` in `app.js` to automatically fetch true operative class/level/faction from the server and synchronize `localStorage` and the header identity badge.
  - Added `/kb profile [Name]` and `/kb web` slash command in `Core.lua`.

### Removed
- **External Armory Links Purged (`app.js`)**:
  - Removed third-party external redirect buttons to Blizzard Armory, Classic Armory, and Warcraft Logs from character profile dossiers.
  - Retained clean, zero-external-dependency `[📋 Copy Link]` clipboard utility for sharing operative dossier URLs.

### Changed
- **Dynamic Rally Target Location Selection (`app.js`, `index.html`)**:
  - Replaced static text/dropdown with dynamic theatre-aware target dropdown:
    - **Open World**: 31 classic frontline zones (Stranglethorn Vale, Hillsbrad Foothills, Arathi Highlands, Ashenvale, Blackrock Mountain, Silithus, etc.).
    - **Battlegrounds**: Warsong Gulch, Arathi Basin, and Alterac Valley.
    - **Custom**: Reveals free-form location text input field for specialized battle coordinates.
- **Modern Tactical Role SVGs & Glyph Rectangle Elimination (`index.html`, `app.js`)**:
  - Replaced unsupported Unicode emoji glyphs with crisp inline vector SVGs (Shield, Cross, Crossed Swords) for Tank, Healer, and DPS role buttons.
  - Eliminated font-fallback missing glyph rectangles (`▯`) across headers, rally cards, and buttons.
- **Multi-Client Addon Parity & Test Coverage (`deploy.py`, `test_pipeline.py`)**:
  - Deployed updated addon files across all 4 local WoW clients (`_classic_beta_`, `_classic_era_`, `_anniversary_`, `_retail_`).
  - Added unit test coverage for the `/api/auth/release-claim` endpoint and verified 100% pass across all 15 automated test suites.

## [1.4.45] - 2026-09-27

### Changed
- **Complete Elimination of SaaS Account Gates & "Sign up with Google" (`app.js`, `index.html`)**:
  - **Direct Live Feed Default Landing**: `DOMContentLoaded` now routes all visitors directly to `switchTab("INTEL")`. First-time visitors, incognito windows, and returning players land immediately on the live frontline killboard feed with zero clicks, zero popups, and zero account creation prompts.
  - **Zero-Gate War Room Operational Briefing Hub (`loadPortalView`)**: Replaced SaaS-style "Create Free Account" and "Sign In to War Room" email/password/Google form cards with direct tactical action modules:
    1. *Frontline Killboard Feed*: Immediate direct entry (`[⚔️ Enter Live Frontline Feed &rarr;]`).
    2. *Character Dossier & Claim*: Direct character lookup and cryptographic token claim (`[⚔️ Select / Claim Character &rarr;]`).
    3. *Active Operative Status*: When an operative is linked, displays combatant rank, class color, and one-click dossier inspection or character unlinking.
  - **Clean Operative Session Lifecycle**: Updated `portalSignOut()` and `handleHeaderSignOut()` to cleanly flush character credentials and owner tokens while keeping the player on the live intelligence feed rather than redirecting to a login wall.
  - **Dossier Tier Modal Modernization (`index.html`)**: Updated `#supporter-tier-modal` Tier 1 button to `Enter Live Combat Feed` and Tier 2 button to `Select / Claim Operative`, removing legacy "Create Free Account" and "Continue as Guest" labels.

## [1.4.44] - 2026-09-27

### Added
- **Cryptographic Character Ownership Protection (`server.py`, `app.js`, `index.html`)**:
  - **Single-Owner Locking**: Integrated `character_claims` table and `X-Owner-Token` headers. Once a character callsign is claimed by an operative, subsequent attempts by other users to select or claim the character are rejected with HTTP 403 Forbidden.
  - **Ownership Status Badging**: The character selection modal displays `🛡️ Verified Owner` for the authenticated owner and `🔒 Claimed (Protected)` with disabled actions for other users.
  - **In-Game Claim Verification Modal**: Users claiming an operative receive a deterministic 6-character code (e.g., `KB-XXXX`) along with exact instructions to run `/kb claim <CODE>` inside World of Warcraft.
  - **Automated Desktop Token Verification (`sync/watcher.py`)**: `WoWKillboardSync` now auto-ingests `WoWKillboardDB.claimTokens` written by the `/kb claim` in-game slash command and synchronizes verified claims with the web API `/api/auth/verify-claim`.

- **Web War Rally Muster Modal & Rich Telemetry (`app.js`, `index.html`, `server.py`)**:
  - **Web Squad Creation Panel**: Added an interactive "+ Muster War Rally / Sound War Horn" button and modal on the Web Rallies view supporting:
    1. **Squad Capacity**: 5-Man Squad (Party) vs 40-Man Strike Team (Raid).
    2. **Combat Theatre**: Open World PvP vs Battleground Operations.
    3. **Target Location**: Common frontline zone dropdown (Stranglethorn Vale, Hillsbrad Foothills, Warsong Gulch, Arathi Basin, Alterac Valley, etc.) and custom location text box.
    4. **Preferred Level Bracket**: Min and Max level inputs with quick-select presets (`[All (1-60)]`, `[Twink 19]`, `[Twink 29]`, `[Endgame (50-60)]`).
    5. **Requested Roles**: Toggleable combat role badges (`[🛡️ Tanks]`, `[💚 Healers]`, `[⚔️ DPS]`).
    6. **Battle Cry / Directive**: Custom mission message dispatched to realm telemetry and Discord webhooks.
  - **Enhanced Rally Cards**: Rendered rally listings display squad size badges (`[5-MAN SQUAD]` / `[40-MAN RAID]`), theatre badges (`[OPEN WORLD PVP]` / `[BATTLEGROUND]`), level brackets, requested roles, commander battle cry, and `/w CommanderName rally` auto-invite hint.

### Removed
- **Battle.net OAuth Deprecation (`index.html`, `app.js`, `server.py`)**:
  - Completely purged third-party Battle.net OAuth buttons, modal tabs, and URL callback dependencies in favor of lightweight in-game character links and token-based claims.
  - Replaced portal button with `⚔️ Select / Claim Operative Identity`.

### Changed
- **Zero-Friction In-Game Web Link Auto-Authentication (`app.js`)**:
  - Clicking any in-game character web profile link (`http://13.216.102.148/?character=Name`) automatically authenticates the player session as that operative, updates the header identity badge, switches to the live feed, and opens their character profile dossier instantly without requiring logins or popups.

## [1.4.43] - 2026-09-27

### Fixed
- **Forensic Elimination of In-Combat Action Blocked Taint (Guardrail 1: Zero Blizzard UI Taint)**:
  - **Combat Wire CircularBuffer Deferral (`UI.lua:5120-5145`)**: Discovered that calling `combatWireHUD.msgFrame:AddMessage(line)` on a `ScrollingMessageFrame` during combat executed Blizzard's `CircularBuffer.lua:49 PushFront` -> `SecureTypes.lua:279 GetValue()`, triggering execution taint. Implemented `UI.PendingWireEntries` queue to buffer all combat wire logs during `InCombatLockdown()` and flush cleanly upon `PLAYER_REGEN_ENABLED`.
  - **Complete Secure Nameplate Hook Purge (`UnitScanner.lua:430-452`)**: Purged `NAME_PLATE_UNIT_ADDED` event registration and handler, completely uncoupling WoWKillboard from Blizzard's secure `NamePlateDriverFrame` pipeline.
  - **Combat Unit Token Inspection Lockdown (`UnitScanner.lua:18`, `CombatTracker.lua:67-70`, `1775-1785`)**:
    - Gated `US:ScanUnit(unit)` with `if InCombatLockdown() and unit ~= "player" then return end`, preventing inspecting secure unit frames or writing to DB during combat.
    - Gated `UnitScanner` event listeners (`UPDATE_MOUSEOVER_UNIT`, `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED`) behind `if InCombatLockdown() then return end`.
    - Gated `UnitExists("mouseover")` and `UnitExists("target")` in `CT:IsPlayerUnit` behind `not InCombatLockdown()`.
    - Gated `GetGuildInfo("target")` and `US:ScanUnit("target")` in `PLAYER_TARGET_CHANGED` behind `not InCombatLockdown()`.
  - **Global Frame Anonymization (`UI.lua:4403, 4642, 4999`)**: Replaced named frame declarations (`WoWKillboardRadarHUD`, `WoWKillboardRallyDialog`, `WoWKillboardCombatWire`) with pure anonymous Lua widgets (`CreateFrame("Frame", nil, UIParent, "BackdropTemplate")`), preventing `_G` global table pollution.
  - **Dynamic Banner Drag Unregistration (`UI.lua:3578, 3834-3860`)**: Removed eager `RegisterForDrag("LeftButton")` from `killBanner` initialization. Drag listeners and mouse interaction are now registered ONLY when explicitly unlocked via `/wowkb move`, guaranteeing the banner remains 100% click-through in combat.
  - **Raid Conversion & Sync Chat Lockdown (`Reinforcements.lua:62`, `Sync.lua:300`)**: Added strict `InCombatLockdown()` gating to `EnsureRaidConversion` and fallback `DEFAULT_CHAT_FRAME` outputs.
  - **Complete `pcall()` Purge Across All C-APIs & Frame Methods (`CombatTracker.lua:1884`, `UI.lua:408, 501, 676, 3706`)**: Forensic analysis of `taint.log` proved that the exact line triggering Blizzard's `ADDON_ACTION_BLOCKED` was `pcall(frame.RegisterEvent, frame, "COMBAT_LOG_EVENT_UNFILTERED")` at `CombatTracker.lua:1884`. In the War Within / Classic 1.15+ engine, invoking protected C-APIs or frame userdata methods through Lua's `pcall` strips execution context credentials, marking the frame tainted and triggering an action block. Replaced with direct, native `frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")` and completely eliminated all 12 `pcall` calls across the entire codebase.
  - **CLEU Engine Restriction Gating (`CombatTracker.lua:1880-1895`)**: Discovered that in modern engine builds (WoW Forever Beta 16001+ and Modern Retail 12.0+), Blizzard has officially restricted `COMBAT_LOG_EVENT_UNFILTERED` to the Blizzard internal UI only. Attempting to call `frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")` triggers an immediate `ADDON_ACTION_BLOCKED` ("blocked from an action only available to the Blizzard UI") popup on addon load. Implemented build inspection (`tocversion < 16000 and type(CombatLogGetCurrentEventInfo) == "function"`) so that Classic Era and Anniversary clients retain CLEU while Forever Beta and Retail rely cleanly on public events (`CHAT_MSG_COMBAT_HONOR_GAIN`, `PLAYER_PVP_KILLS_CHANGED`, `UPDATE_BATTLEFIELD_SCORE`, `CHAT_MSG_SYSTEM`), completely eliminating the popup on login.
  - **Live In-Game Diagnostic Interceptor (`Core.lua:710-728`)**: Registered listeners for `ADDON_ACTION_BLOCKED` and `ADDON_ACTION_FORBIDDEN` using `SafePrint` buffering to ensure diagnostic alerts are preserved across early load screens.
  - **Diagnostic Taint Logging (`WTF/Config.wtf`)**: Injected `SET taintLog "2"` and `SET scriptErrors "1"` across all local client environments (`_classic_beta_`, `_classic_era_`, `_anniversary_`, `_retail_`).

## [1.4.42] - 2026-09-27

### Added
- **Tactical Combat Wire Pop-Out Window (`UI.lua`, `Core.lua`, `Config.lua`)**:
  - **Zero Chat Spam Pop-Out Feed**: Added a dedicated, moveable, draggable floating Combat Wire window (`WoWKillboardCombatWire`) built from pure Lua with `"BackdropTemplate"`. All live combat events, gang gank warnings, and solo killmails stream directly to the Combat Wire window, keeping the player's General chat frame 100% clean.
  - **Scrollable Live Stream**: Integrated native `ScrollingMessageFrame` with mousewheel scrolling support (`OnMouseWheel`), allowing players to review up to 100 recent combat engagements with timestamped entries (`[HH:MM:SS]`).
  - **Quick Controls & Position Persistence**: Includes `[Clear]` button, `[X]` close button, and automatic position saving to `WoWKillboardSettings.combatWirePos`.
  - **Header Toggle Button**: Added template-free `[Wire]` button in the main War Room dashboard header next to `[Export]`.
  - **Slash Command Integration**: Added `/kb wire` and `/kb feed` commands to toggle Combat Wire visibility instantly.
  - **Section 6 in Alerts Configuration (`/kb alerts`)**: Added `6. COMBAT FEED DESTINATION` segmented controls: `[Pop-Out Wire (Default)]`, `[Main Chat Frame]`, and `[Muted / Off]`.
  - **Strict Combat Lockdown Click-Through**: In accordance with Guardrail 1, `UI.CombatWireHUD` automatically sets `EnableMouse(false)` during `PLAYER_REGEN_DISABLED` to ensure 100% click-through targeting during combat with zero Blizzard UI taint.

- **War Council Rally Muster Dialog (`UI.lua`, `Reinforcements.lua`)**:
  - **Interactive Squad Creation Panel**: Sounding the War Horn now opens `UI:ShowRallyDialog()`, a pure Lua modal dialog allowing commanders to configure comprehensive squad parameters:
    1. **Group Size**: Segmented `[ 5-Man Squad (Party) ]` vs `[ 40-Man Strike Team (Raid) ]` with automatic raid conversion.
    2. **Theatre / Content Type**: Segmented `[ Open World PvP ]` vs `[ Battleground ]`.
    3. **Target Location**: Pre-filled with current zone (`GetZoneText()`) or custom battleground selector.
    4. **Level Bracket**: Numeric Min and Max level inputs with smart twink bracket defaults.
    5. **Role / Spec Requests**: Toggleable combat role chips (`[ 🛡️ Tank ]`, `[ 💚 Healer ]`, `[ ⚔️ DPS ]`).
    6. **Battle Cry / Mission Directive**: Custom battle cry message dispatched to guild and P2P addon network.
  - **Two-Line Rich Rally Cards**: Redesigned the open rallies list with 46px tactical cards displaying group type badges (`[5-PARTY]` / `[40-RAID]`), content badges (`[WORLD]` / `[BG]`), commander name colorized by class, guild tags, zone coordinates, level brackets, requested roles, commander battle cry, and age telemetry.

### Fixed
- **Web Profile URL Parity (`UI.lua:2630`)**: Repointed character web dossier links from legacy Render URL to the active AWS Lightsail production platform (`http://13.216.102.148/?character=%s`).
- **Sync Desktop Client Binary Rebuild (`WoWKillboardSync.exe`)**: Recompiled the standalone zero-Python executable via PyInstaller to include server-verified solo purity logic and multi-drive discovery.

## [1.4.41] - 2026-09-27

### Fixed
- **Eradication of In-Combat Action Blocked Execution Taint (Guardrail 1: Zero Blizzard UI Taint)**:
  - **100% Global `print()` Purge**: Completely eliminated all calls to global `print()` across all 12 addon files. In WoW 10.x / Classic Beta (TOC 16001), calling `print()` routes through `Blizzard_PrintHandler` -> `ScrollingMessageFrame:AddMessage` -> `CircularBuffer.lua` -> `SecureTypes.lua:279`, contaminating the secure execution buffer and triggering `ADDON_ACTION_BLOCKED` when action buttons or unit frames are clicked.
  - **Taint-Safe Print Queue (`KB.Utils.SafePrint`)**: Replaced all outputs with `SafePrint(...)`, buffering all combat notifications in `KB.PrintQueue` and flushing cleanly via `DEFAULT_CHAT_FRAME:AddMessage` upon `PLAYER_REGEN_ENABLED`.
  - **Recursive In-Combat Timer Purge**: Removed polling `C_Timer.After` calls during combat from `CombatTracker:CheckPendingDeathBounty()` and `UI:ShowDeathBountyPrompt()`, deferring pending Mark of Spite prompt dispatch cleanly to `PLAYER_REGEN_ENABLED`.
  - **Unit Event Deregistration**: Removed `UNIT_HEALTH` and `UNIT_FLAGS` unit event registrations on secure unit tokens (`target`, `focus`, `targettarget`) that fired during combat.
  - **AddonCompartment Table Isolation**: Purged `AddonCompartmentFrame` table mutation logic in `Config.lua` to avoid touching Blizzard internal frame structures.
  - **Anonymous Private Tooltip**: Replaced all usages of Blizzard's global `GameTooltip` with a dedicated, isolated anonymous frame tooltip (`UI:GetOrCreatePrivateTooltip()`).

- **Strict Solo Purity & Ingestion Sanitization (`watcher.py`, `server.py`, `CombatTracker.lua`)**:
  - **Zero-Damage Solo Disqualification**: A kill is strictly never certified as solo if `killer.damageDone <= 0` or if the player was an assist/buff proxy (`killer.name == "Allied Vanguard"`).
  - **Sync Watcher Fallback Fix (`sync/watcher.py`)**: Fixed `isSolo` extraction logic to default to `False` unless explicitly flagged with `attackersCount <= 1`.
  - **Server Ingestion Gatekeeper (`web/server.py`)**: Enforced server-side validation rejecting solo flags on any kill with `attackers_count > 1`, `len(attackers) > 1`, or zero killer damage.
  - **Database Retroactive Sanitization**: Cleaned existing SQLite records in `web/killboard.db` to remove erroneous solo designations from zero-damage encounters.

### Added
- **In-Game Combat Data Export (`/kb export`, `UI.lua`, `Core.lua`)**:
  - Added `/kb export` slash command and header `[Export]` button next to `[Web Profile]`.
  - Opens a pure Lua modal with `BackdropTemplate` containing serialized `WoWKillboardDB` records ready for one-click copy (`Ctrl+A` / `Ctrl+C`) and browser drag/paste into `/upload`.
- **Hall of Legends Open World PvP Consolidation (`web/static/app.js`)**:
  - Removed mode toggles from the Hall of Legends view, replacing them with a fixed `Open World PvP` badge to strictly isolate open world combat telemetry.

## [1.4.40] - 2026-09-27

### Fixed
- **Proximity HK & Ally Buffing Attribution Engine Fix (`CombatTracker.lua`)**:
  - **Player Ally Buff & Heal Telemetry (`CT.PlayerAssistedAllies`)**: Implemented explicit tracking when the local player casts buffs, auras, or heals on friendly allies (`sourceGUID == playerGUID` and `destGUID ~= playerGUID`). Automatically indexes assisted allies into `CT.FriendlyCluster` and `CT.PlayerAssistedAllies`.
  - **Strict Positive Damage Requirement for Solo Certification**: A kill can NEVER be certified as solo if `playerDamage <= 0`. Zero-damage engagements resulting from proximity honor gain or buffing a teammate are strictly marked as assists (`Support Assist`), `isSolo = false`, and `attackersCount = math.max(attackersCount, 2)`.
  - **Dynamic Killer Resolution in Proximity HKs**: In `OnPlayerHonorableKill`, when the local player dealt 0 damage and an ally dealt damage, the killmail attributes the kill to the highest-damage ally, listing the local player as an assisting support combatant rather than erroneously granting them personal solo kill credit.
  - **Mark of Spite Prompt Gating**: Integrated `promptMarkOnDeath` checks directly into `CombatTracker.lua` (`CheckPendingDeathBounty`, `ProcessDeath`) and `UI.lua` (`ShowDeathBountyPrompt`), completely preventing unwanted popups when muted.

### Added
- **Mark of Spite Death Popup Configuration & Toggle (`Config.lua`, `UI.lua`, `Core.lua`)**:
  - Added `promptMarkOnDeath = true` to default settings.
  - Added Section 5 to the Combat Alerts & Radar Configuration dialog (`/kb alerts`): `5. MARK OF SPITE DEATH POPUP` with segmented `[Prompt on Death (Default)]` and `[Never Prompt / Muted]` controls.
  - Added `/kb markprompt [on|off]` slash command to toggle popup behavior instantly.
  - Added `/kb claim <code>` slash command to record in-game character verification tokens into `WoWKillboardDB.claimTokens`.
- **Standardized Client Header Subtitle Across Themes (`Utils.lua`, `UI.lua`)**:
  - Implemented `KB.Utils.GetClientFlavorSubtitle()` generating the unified format:
    `WoW / Game Version (Forever) / Realm (PVP) / Status (Live / Beta) / Version`.
  - Applied uniformly across both Classic and ElvUI themes in `UI:ApplyTheme()`, resolving missing `WoW Forever` in ElvUI.
- **Master War Archivist Public Protection (`web/static/app.js`)**:
  - Gated the red "Master War Archivist • Database Administration" reset panel in `loadUploadView()`.
  - Completely hidden from regular public view by default; revealed only via secret key unlock or administrative URL parameter (`?admin=valor2026`).

## [1.4.39] - 2026-09-27

### Fixed
- **Root Cause Resolution for Erroneous Solo Attribution (`CombatTracker.lua`, `Utils.lua`)**:
  - **Unblocked Combat Log Registration for WoW Forever Beta**: Discovered and removed `if tocversion >= 16000` condition in `CombatTracker.lua` that erroneously flagged CLEU as forbidden in WoW Forever Beta (TOC 16001). CLEU is now unconditionally registered across all flavors using safe `pcall`, restoring damage, healing, swing, and spell log stream ingestion.
  - **Dual-Lookup Attribution Engine (`CT.RecentDamageByName`, `CT.RecentVictimAssistsByName`)**: Implemented secondary dictionary indexing by normalized lowercase combatant name (stripping realms, PvP rank prefixes, and punctuation via `KB.Utils.CleanCombatantName` and `KB.Utils.NormalizeCombatantName`). Guarantees 100% resolution even when chat HK events arrive without unit tokens or GUIDs.
  - **Strict 100% Solo Purity Enforcement**:
    - If ANY other player (or pet/guardian) hits the victim within the 30-second window, the kill is certified as group/gang combat (`attackersCount = math.max(#attackersList, friendlyPartySize) >= 2`) and stamped `[GANG xN]`, NEVER `[SOLO]`.
    - Revoked solo status if any external friendly debuff/stun/slow was applied to the victim (`RecentVictimAssists`), if the player received external heals or buffs (`ExternalAssistsOnPlayer`), if party size > 1, or if friendly cluster members were actively engaged nearby (`friendlyAssists > 0`).
  - **Race Condition & Damage Wiping Fix (`ProcessDeath`, `OnPlayerHonorableKill`)**:
    - Added `CT.LastKillGUID` to deduplicate between CLEU `UNIT_DIED` / `PARTY_KILL` and `CHAT_MSG_COMBAT_HONOR_GAIN`, preventing a second corrupted solo killmail from overwriting a multi-attacker kill.
    - Preserved damage and assist tables for the duration of the combat pruning window instead of immediately setting `RecentDamage[victimGUID] = nil`.
  - **Additional Damage & Aura Subevents**: Added explicit handlers for `DAMAGE_SHIELD` (Thorns, Retribution Aura, Lightning Shield) and `SPELL_AURA_APPLIED_DOSE` in CLEU.

## [1.4.38] - 2026-09-27

### Added
- **Mark of Spite Gold / Silver / Copper Currency Overhaul (`BountyEngine.lua`, `UI.lua`)**:
  - Overhauled Mark of Spite declaration dialogs with discrete numeric editboxes for Gold, Silver, and Copper, paired with authentic coin icon textures.
  - Implemented standalone Target Name input and Mark Amount inputs with explicit `[Declare Mark]` and `[Cancel]` buttons.
  - Updated `PlaceBounty` in `BountyEngine.lua` to accept exact copper calculations (`totalCopper = (gold * 10000) + (silver * 100) + copper`).
  - Systematically renamed all references from "Blood Bounty" / "Bounty" to "Mark of Spite" / "Mark" across the addon and dialogs.

### Fixed
- **Classic Theme Title Header Plate Alignment (`UI.lua`)**:
  - Resolved title text overflow in `UI.lua` where `ApplyTheme()` injected the 45-character `GetClientFlavorTitle()` into `UI.TitleText`, causing it to spill outside the 320px arched header plate.
  - Set `UI.TitleText` strictly to centered `WoW Killboard` and placed client flavor and realm info cleanly in `UI.SubtitleText`.
- **Alert Anchor Transparency & Border Removal (`UI.lua`)**:
  - Made the alert anchor draggable banner semi-transparent (`alpha 0.60`) instead of solid black.
  - Removed the thick yellow border (`SetBackdropBorderColor(0, 0, 0, 0)`) for a sleek, unobtrusive repositioning interface.
- **Hall of Legends Terminology Cleansing (`UI.lua`, `web/static/app.js`)**:
  - Removed awkward "cohorts percentile" wording in both the addon and web interface.
  - Replaced with clean "rank efficiency", "Class Standing", and "active combatants".
- **Website PvP Mode Filter Consolidation (`web/static/app.js`, `web/server.py`)**:
  - Removed "All PvP" filter button from web feed and leaderboards so only `World`, `BGs`, `Duels`, and greyed-out `Arenas` are presented.
  - Set default active combat filter strictly to `World PvP`.

## [1.4.37] - 2026-09-27

### Added
- **Dedicated Linux VPS Deployment Provisioning Kit (`deploy/setup_vps.sh`, `deploy/Caddyfile`, `deploy/wowkillboard.service`, `docs/DEPLOYMENT_VPS.md`)**:
  - Created automated 1-command installer script for Ubuntu 22.04 / 24.04 and Debian 12 running on $3.50–$4.00/mo VPS instances (AWS Lightsail, DigitalOcean Droplet, Hetzner Cloud).
  - Configured modern Caddy web server with native HTTP/2 and HTTP/3, automatic Let's Encrypt / ZeroSSL TLS certificates, security headers, and static caching.
  - Packaged systemd daemon `wowkillboard.service` running the FastAPI application with auto-restart, sandboxing, and persistent SSD storage in `/opt/wowkillboard/data/killboard.db`.
  - Added automated daily SQLite backup cron job (`/usr/local/bin/wowkillboard-backup.sh`) with 14-day retention.
  - Authored comprehensive operations runbook (`docs/DEPLOYMENT_VPS.md`) for zero-downtime deployment, DNS mapping, and sync configuration.
- **Tactical Radar HUD Floating Window (`UnitScanner.lua`, `UI.lua`, `Core.lua`, `Config.lua`)**:
  - Replaced chat console radar announcements with a sleek, moveable, and togglable floating HUD widget (`WoWKillboardRadarHUD`).
  - Displays up to 3 hostiles spotted in immediate proximity with circular class crests, class-colored names, levels, guilds, zones, and elapsed time.
  - Frame is 100% pure Lua with `BackdropTemplate` (zero Blizzard XML taint), draggable with left-click, clamped to screen, and auto-dismisses after 15 seconds of inactivity.
  - Position saved persistently in `WoWKillboardSettings.radarPos`.
  - Added `/kb radar` and `/kbradar` slash commands to toggle visibility on and off at will.

### Fixed
- **Strict 100% Solo Purity Enforcement (`CombatTracker.lua`, `Config.lua`)**:
  - Implemented 100% zero external contribution requirement for a kill to receive the `[SOLO]` badge: verified zero external player damage, zero external friendly buffs, zero external friendly heals received, zero external CC/debuffs on the victim, and party size strictly 1.
  - Added reverse lookup caches `RecentVictimNames` and `RecentVictimGUIDs` so honorable kill events map directly to all attacker contributions in `RecentDamage`.
  - Added 30-second tracking for `ExternalAssistsOnPlayer` and `RecentVictimAssists`.
- **Player Death Attribution & Revenge Blood Bounty Trigger (`CombatTracker.lua`, `UI.lua`)**:
  - Resolved bug where player death failed to record in the Intel feed and stats. When the player is slain, `ProcessDeath` now falls back to `activeEnemyTarget`, `CT.RecentEngagedEnemies`, and `CT.HostileCluster` to attribute the enemy killer, records the death killmail to `WoWKillboardDB.kills`, and debounces death increments.
  - Resolved timing bug where `ShowDeathBountyPrompt` failed when dying during combat lockdown: implemented `CheckPendingDeathBounty()` with `C_Timer.After` retry on `PLAYER_DEAD`, `PLAYER_ALIVE`, `PLAYER_UNGHOST`, and `PLAYER_REGEN_ENABLED`.
- **Classic Theme Header Geometry & Lifetime Stat Card Fixes (`UI.lua`)**:
  - Repositioned arched `HeaderPlate` to `(0, -2)` with gold title `WoW Killboard` and subtitle `WoW Forever • Classic Beta PvP`, eliminating frame border clipping.
  - Reconciled `SESSION COMBAT K/D (You)` card with `WoWKillboardDB.kills` so lifetime kills and deaths persist across `/reload`.

## [1.4.36] - 2026-09-27

### Added
- **Battle.net OAuth 2.0 Account Linking (`web/server.py`, `web/static/app.js`, `web/static/index.html`)**:
  - Implemented `/api/auth/bnet` and `/api/auth/bnet/callback` endpoints supporting Blizzard's official OAuth 2.0 flow with `wow.profile` scope.
  - Automatically fetches BattleTag, user profile characters across WoW accounts, and ingests them into the persistent `characters` table.
  - Added graceful fallback and instructional configuration guide when `BLIZZARD_CLIENT_ID` / `BLIZZARD_CLIENT_SECRET` are not yet set in the server environment.
- **Interactive Character Selector & Claim Modal (`web/static/app.js`, `web/static/index.html`, `web/server.py`)**:
  - Replaced the random `Champion_XXXX` placeholder on sign-in with an interactive character selector modal (`openCharacterLinkModal()`).
  - Added `/api/characters` directory endpoint providing all indexed combatants sorted by last seen and level (including `Dagariane` and all discovered players).
  - Provided 3 tab options: Active Combatants list (1-click claim), Battle.net Account Link, and Custom Character Claim (`/api/auth/claim-character`).
  - Upgraded header auth badge to display the claimed character's faction crest, class badge, class-colored name, level, and a `[Switch]` button for easy switching.
- **In-Game Combat Sync Commands & Tips (`CombatTracker.lua`, `Core.lua`, `Killmail.lua`)**:
  - Added `/kb sync` and `/kb reload` commands in-game that flush in-memory combat SavedVariables to disk via `ReloadUI()` for instant desktop watcher syncing.
  - Added subtle in-game chat tip after honorable kills reminding players that `/reload` or `/kb sync` pushes combat data to the live website immediately.
  - Added manual `🔄 Refresh` button in the web feed header and informative sync tooltip (`Auto-syncs on /reload in WoW`).

### Fixed
- **False 1v1 Solo Attribution on World Group Kills (`CombatTracker.lua`)**:
  - Resolved bug in `CT:OnPlayerHonorableKill` where honorable kills (`CHAT_MSG_COMBAT_HONOR_GAIN`, unit death, and target change events) hardcoded `isSolo = (partySize <= 1)` and single-attacker attribution, ignoring other friendly combatants when fighting outside a formal party.
  - Enforced full `RecentDamage[victimGUID]` lookup to extract all participating attackers who dealt damage.
  - Added 15-second sliding window assist verification with `CT.FriendlyCluster`, ensuring that any nearby friendly combatants who dealt damage or cast spells are credited as assists.
  - Enforced strict certified 1v1 solo criteria: `isSolo = (#attackersList <= 1) and (partySize <= 1) and (friendlyAssists == 0)`.
  - Expanded deduplication window between CLEU `ProcessDeath` and Chat Honor Gain from 2 to 5 seconds to prevent double-counting or overwriting.
- **Persistent Characters Directory Auto-Backfill (`web/server.py`)**:
  - Backfilled `characters` table directly from all historical `kills` records in `web/killboard.db` upon database initialization.
  - Added automatic upsert of killer and victim into `characters` table during live kill ingestion.

## [1.4.35] - 2026-09-27

### Fixed
- **Classic Theme Container & Button Geometry Overhaul (`Config.lua`, `UI.lua`)**:
  - Eliminated distorted `UI-Panel-Button-Up` Blizzard button textures and `SetButtonState("PUSHED", true)` calls in favor of pure Lua `BackdropTemplate` widgets, matching the clean container geometry of the ElvUI theme that user praised.
  - Implemented rich Classic Warcraft aesthetics: dark bronze/slate background (`{0.14, 0.10, 0.07, 0.95}`), antique gold borders (`{0.55, 0.44, 0.22, 0.95}`), glowing gold active states (`{1.0, 0.84, 0.0, 1.0}`), and drop-shadowed gold text (`#ffd100`).
  - Widened header buttons (`ThemeButton` to 105px, `AlertsButton` to 76px) and standardized `CloseButton` to a sleek 22x22px frame, completely eliminating text squishing and clipping.
  - Anchored `TitleText` and `SubtitleText` directly into the center of the arched `HeaderPlate` at `(0, 11)` and `(0, -5)`, eliminating overlap with the top dialog border.
  - Switched Classic theme inset backdrop from bright yellow `QuestBG` parchment to `dark_war_bg.tga` with a warm dark wash (`alpha 0.40`), ensuring crystal-clear text readability across all rows.
- **Website Duel Isolation & Deadliest Zones Cleansing (`server.py`, `app.js`, `index.html`)**:
  - Excluded duels from `Deadliest Zones (24 Hours)` query, preventing friendly duel hot spots (e.g. Goldshire/Elwynn Forest) from polluting open-world conflict zones.
  - Defaulted website feed and API to `WORLD` mode (`currentMode = "WORLD"`), removing the confusing "All PvP" filter pill and isolating duels strictly to the `[Duels]` filter tab.
  - Added combat mode filter pills (`[World]`, `[BGs]`, `[Duels]`, `[Arenas (Disabled)]`) directly into the Recent Kills / Intel feed header.
- **Level 60 Default Bug Resolution (`watcher.py`, `server.py`, `app.js`, `killboard.db`)**:
  - Resolved Python falsy evaluation bug where unobserved level `0` evaluated as `0 or 60 -> 60` across `watcher.py:297` and `server.py:812`.
  - Added safe level sanitization preserving `0` for unobserved or skull combatants, and formatted level `0` as `??` on website feed, modals, and profile lists.
  - Sanitized historical database records in `web/killboard.db`.

## [1.4.34] - 2026-09-27

### Fixed
- **Duel Gank & Intel Contamination Removal (`CombatTracker.lua`, `Killmail.lua`, `Sync.lua`, `UI.lua`, `web/server.py`)**:
  - Disconnected 1v1 duels from world gank statistics: explicitly marked duels with `isSolo = false` and `attackersCount = 1`, and excluded `is_duel = 1` from "Top Active Gankers (24 Hours)", "Deadliest Zones", and "Top Active Guilds" queries in `web/server.py`.
  - Blocked duels from broadcasting over P2P sync (`Sync.lua:BroadcastKillmail`), preventing private duels from leaking into other players' feeds across the guild or group.
  - Suppressed combat sirens, sound effects, and raid warning kill banners on duels in `Killmail.lua` and `UI.lua`.
  - Eliminated chat spam for bystander duels: console announcements only print for duel combatants themselves.
- **Duelist Level Resolution & Max Level Bounds (`CombatTracker.lua`, `UnitScanner.lua`)**:
  - Eliminated invalid `level = 99` fallback across `UnitScanner.lua` and `CombatTracker.lua`, clamping levels to valid realm bounds (`<= 85`) and leveraging `C_PlayerInfo.GetPlayerLevelByGUID` when available.
  - Added persistent character directory lookup so that duelists who were previously targeted or scanned resolve with their exact level and class.
- **Character Portrait Medallion Polish (`UI.lua`, `build_textures.py`)**:
  - Resolved distorted character headshot by removing double-cropping `SetTexCoord(0.12, 0.88, 0.12, 0.88)` and using natural `(0, 1, 0, 1)` framing provided by `SetPortraitTexture`.
  - Resized medallion to a compact, elegant 46x46 and anchored it cleanly inside the top-left header bar at `("TOPLEFT", 14, -8)` rather than protruding over the window edge.
  - Re-engineered `medallion_border.tga` to replace the 14px thick bronze ring and bulky rivets with a sleek 2.5px-3px antique metallic gold bezel.

### Added
- **Persistent Characters Directory & Active Characters Telemetry (`UnitScanner.lua`, `web/server.py`, `UI.lua`)**:
  - Added `WoWKillboardDB.characters` persistent storage in the addon, automatically caching every scanned character's name, realm, class, race, level, guild, faction, and timestamp.
  - Created `characters` table in SQLite (`web/server.py`), ingesting observed character directories from upload and sync payloads.
  - Updated "Active Characters" in the web's Lifetime Combat Activity box to compute the union of combatants from `kills` and indexed players from `characters`.
  - Added `US:GetKnownCharactersCount()` displaying total tracked characters in the character medallion hover tooltip.

## [1.4.33] - 2026-09-27

### Added
- **In-Game Rallies Vanguard (`Reinforcements.lua`, `UI.lua`)**:
  - Added dedicated `Rallies` navigation tab (`UI.lua`) displaying open vanguard rallies across the realm with War Horn status card.
  - Implemented `RF:GetOpenRallies()` returning active distress beacons for the player's faction within a 30-minute window, sorted newest first with zone, GPS coordinates, hostile counts, and commander identity.
  - Added easy 1-click `[⚔️ Join Rally]` button that auto-whispers `"rally"` to the squad commander to trigger instant raid/party invites and raid conversion, with status badge updating to `|cff00ff00Requested!|r`.
  - Added `[Close Rally]` option allowing commanders to stand down active beacons directly from the UI.
  - Updated `Reinforcements.lua` and `Sync.lua` to mark resolved beacons with status `"RESOLVED"` locally and broadcast resolution over peer-to-peer sync.
- **Frontline Telemetry Web Rallies View (`web/static/index.html`, `web/static/app.js`)**:
  - Added `#nav-rallies` and `#m-nav-rallies` to desktop and mobile navigation rails.
  - Implemented read-only `loadRalliesView()` querying `/api/backup/distress` to display real-time active rallies with zone, GPS coordinates, hostile counts, faction badges, elapsed duration, and commander whisper instructions (`/w CommanderName rally`).
  - Read-only web design ensures complete separation between live web telemetry and in-game command execution with zero security risk.

### Fixed
- **Container Text Boundary Constraints & Header Overlap Fixes (`UI.lua`)**:
  - Centered Title and Flavor Subtitle directly onto the arched crest `Interface\DialogFrame\UI-DialogBox-Header`.
  - Relocated `[Web Profile]` button to the left side adjacent to the character medallion to prevent collision with right-side action buttons (`Alerts`, `Theme`, `Close`).
  - Fixed text overflow in `RenderLiveFeed()` and `RenderLeaderboard()` by enforcing strict double-anchored boundaries (`LEFT` to icon, `RIGHT` to separator/stats) and setting `fontString:SetWordWrap(false)`, preventing long player names and combat text from spilling across adjacent columns.
  - Balanced tab widths (`Intel`, `Hall of Legends`, `Marks of Spite`, `Rallies`, `Zone Intel`) with adequate spacing before right-aligned mode filter pills (`World`, `BGs`, `Duels`, `Arenas`).

## [1.4.32] - 2026-09-27

### Fixed
- **Parchment Typography & Decipherability Overhaul (`Config.lua`, `UI.lua`)**:
  - Resolved low-contrast text washout on Blizzard's `QuestBG` parchment by darkening row background cards to deep dark slate (`{ 0.08, 0.06, 0.05, 0.88 }` / `{ 0.05, 0.04, 0.03, 0.92 }`) with antique gold trim (`{ 0.45, 0.35, 0.18, 0.85 }`).
  - Added subtle warm dark wash overlay (`vignette:SetColorTexture(0.02, 0.015, 0.01, 0.32)`) in `UI.ContentInset` to eliminate blinding parchment paper glare while preserving organic fibers and natural borders.
  - Enforced high-contrast drop shadows (`SetShadowOffset(1, -1)` and `SetShadowColor(0, 0, 0, 1)`) across all font strings in `Intel`, `Hall of Legends`, `Marks of Spite`, and `Zone Intel`.

### Added
- **Hall of Legends Sub-Navigation & Standing Parity (`Leaderboard.lua`, `UI.lua`)**:
  - Implemented sub-navigation toggle buttons: `[Player Ranks]` and `[Guild Ranks]` mimicking the web platform layout.
  - Added Top 10 leaderboards for both Players and Guilds with gold/silver/bronze rank badges and class icons.
  - Added glowing gold highlight (`{0.24, 0.17, 0.06, 0.95}` + gold border) when the local player (or their guild) ranks within the Top 10.
  - Implemented pinned bottom standing card (`— YOUR STANDING —` / `— YOUR GUILD STANDING —`) below a divider rule whenever the player or guild is outside the Top 10 or unranked (`#--`), displaying total kills, 1v1 solo kills, deaths, and K/D ratio.
  - Added `GetPlayerRankAndStats` and `GetGuildRankAndStats` methods to `Leaderboard.lua`.
- **Marks of Spite Web Layout Parity (`BountyEngine.lua`, `UI.lua`)**:
  - Added sub-navigation toggle buttons: `[Active Marks]`, `[Hall of Fame]`, and `[Wall of Shame]`.
  - Added Personal Marks dossier banner card displaying contracts issued by the player and active bounties on their head via `BE:GetPersonalMarks()`.
  - Integrated `[Hall of Fame]` displaying Top Mark Hunters (most executions claimed), Richest Bounty Pursuits (highest stakes placed), and Most Elusive Outlaws (longest time evading pursuit) via `BE:GetBountyRecords()`.
  - Upgraded `[Active Marks]` with class icons, colorized target names, bounty gold, contractor names, last sighted zones/times, and `[Accept Contract]` / `[Tracking]` buttons, plus archived cold cases (>30 days).
  - Maintained `[Wall of Shame]` debt ledger with Traitor's Gibbet and debt settlement buttons.
- **Intel Tactical Live Feed KPI Bar (`Leaderboard.lua`, `UI.lua`)**:
  - Added Realm Telemetry KPI summary bar (`REALM CARNAGE: %d • 1V1 SOLO RATIO: %d%% • FACTION WAR: A %d%% / H %d%% • FILTER: [%s]`) powered by `LB:GetModeSummary`.

## [1.4.31] - 2026-09-27

### Fixed
- **Secret Number Value Lua Error (`CombatTracker.lua`)**:
  - Eliminated `attempt to compare a secret number value (execution tainted by 'WoWKillboard')` occurring when clicking or targeting enemy combatants.
  - Replaced arithmetic comparisons on `UnitHealth(unit) <= 0` and `UnitReaction(player, unit) <= 4` with safe boolean Blizzard APIs: `UnitIsDead(unit) or UnitIsDeadOrGhost(unit)`, `UnitIsEnemy("player", unit)`, and `UnitCanAttack("player", unit)`.
- **Duel Combatant Level Resolution (`CombatTracker.lua`, `Killmail.lua`, `UI.lua`)**:
  - Engineered `ResolveDuelCombatant(name, cleanName, defaultGuid)` scanning 5 cascading data sources: `UnitScanner` cache, active unit tokens (`target`, `mouseover`, `focus`, `targettarget`), 40 visible nameplates (`nameplate1..40`), party/raid tokens, and past historical database records in `WoWKillboardDB.kills`.
  - Replaced unobserved `[0]` level fallback with standard Classic `[??]` notation across console announcements (`Killmail.lua`), feed rows, and detail dossiers (`UI.lua`).

### Changed
- **Filter Mode Refactor & "All PvP" Removal (`UI.lua`, `Config.lua`, `Leaderboard.lua`)**:
  - Removed "All PvP" filter mode to prevent duels from contaminating general PvP telemetry.
  - Replaced filter pills with 4 distinct modes: `World` (default), `BGs`, `Duels`, and `Arenas` (greyed out and disabled with tooltip `Arenas (Coming Soon - Season Telemetry Pending)`).
  - Updated default filter mode in `Config.lua` and `UI.lua` to `WORLD`.
  - Updated `LB:MatchesMode` to default to `WORLD` and explicitly filter out duels from any legacy aggregates.

### Added
- **External Web Profile Integration (`UI.lua`, `web/static/app.js`)**:
  - Added template-free, zero-taint popup dialog `UI:ShowCharacterWebLink(charName)` featuring an auto-focused, Ctrl+C copyable EditBox pre-filled with `https://wow-killboard.onrender.com/?character=PlayerName`.
  - Intercepted `ESCAPE` key via pure Lua `SetPropagateKeyboardInput` with zero `UISpecialFrames` pollution (Guardrail 1).
  - Made the circular character medallion clickable with rich hover tooltip to copy the player's web profile link.
  - Added dedicated `[Web Profile]` button in the main window header bar.
  - Added `[Web Profile]` buttons to both Killer and Victim cards in the Killmail Intelligence Dossier modal (`UI.DetailModal`).
  - Added URL parameter detection in `web/static/app.js` (`?character=Name`, `?char=Name`, `?player=Name`) to automatically activate `FEED` and open the character's detailed web dossier upon page load.
  - Added a `📋 Copy Link` button in the web character dossier modal header for direct link sharing.

## [1.4.30] - 2026-09-26

### Fixed
- **Authentic Blizzard QuestBG Parchment & Frame Visibility Overhaul (`UI.lua`, `Config.lua`)**:
  - Eliminated the solid pitch-black `UI.SolidBg` overlay in Classic theme (`UI.SolidBg:Hide()`), exposing Blizzard's canonical tiled granite/stone dialog backdrop (`Interface\DialogFrame\UI-DialogBox-Background`) and beveled ornamental border (`Interface\DialogFrame\UI-DialogBox-Border`).
  - Switched the main content parchment texture from un-indexed local assets to Blizzard's native in-RAM quest parchment: `Interface\QuestFrame\QuestBG`.
  - Mapped canonical parchment texCoords `(0, 0.586, 0.02, 0.655)` at 100% alpha and removed the dark vignette in Classic theme, rendering the authentic warm aged paper with organic fibers and natural borders.
  - Set `UI.ContentInset` backdrop background color to transparent (`alpha = 0.0`) so the parchment is crisp and unobstructed.
  - Re-architected 3 KPI Stat Cards to authentic sunken dark slate backing (`0.10, 0.08, 0.06, 0.85`) with gold beveled border (`0.72, 0.58, 0.28, 0.95`) and antique brass header strip.
  - Calibrated typography across live feed rows, empty state text, and bounty dossiers with high-contrast warm sepia and gold inks (`|cff5a3205`, `|cff3d2817`, `|cff4a3520`) for authentic quest log readability.
  - Upgraded close button to the iconic Blizzard red-gem minimize button (`Interface\Buttons\UI-Panel-MinimizeButton-Up`) and panel buttons to height 22.

## [1.4.29] - 2026-09-26

### Added
- **Web Drag-and-Drop Log Ingestion & Idempotent Upsert (`/api/upload`, `web/static/app.js`, `web/static/index.html`)**:
  - Implemented zero-download browser ingestion pipeline allowing players to synchronize `WoWKillboard.lua` SavedVariables or raw JSON logs directly via drag-and-drop.
  - Powered by deterministic 32-bit FNV-1a Kill IDs (`Hash(timestamp + killerGUID + victimGUID + mapId)`) guaranteeing that asynchronous, multi-player uploads across different timeframes merge idempotently into SQLite via `INSERT OR REPLACE` with zero duplicate kills.
  - Added `#nav-upload` to the desktop navigation rail and `#m-nav-upload` to the mobile slide-in drawer.
  - Includes interactive visual dropzone, local SavedVariables file path instructions, copy-paste text fallback, and live telemetry banners.
- **Master Archivist Administrative Reset Protocol (`POST /api/admin/reset`, `--reset-db`)**:
  - Engineered administrative database purge system gated by `ADMIN_SECRET_KEY` (`valor2026`).
  - Added `POST /api/admin/reset` endpoint and `--reset-db` server startup CLI flag to safely drop and re-initialize all 13 SQLite tables for clean state testing.
  - Integrated restricted Master War Archivist reset controls directly into the Web Upload interface with confirmation guards.
- **Authentic Classic WoW Dialog & Quest Parchment UI Overhaul (`UI.lua`, `Config.lua`)**:
  - Upgraded in-game addon UI to authentic Classic Blizzard Dialog frame styling:
    - Main frame backdrop upgraded to canonical Blizzard stone texture: `Interface\DialogFrame\UI-DialogBox-Background` (tile = true, tileSize = 32).
    - Outer border upgraded to canonical diamond gold corner trim: `Interface\DialogFrame\UI-DialogBox-Border` (edgeSize = 32, insets = {11, 12, 12, 11}).
    - Added arched dialogue title crest: `Interface\DialogFrame\UI-DialogBox-Header` (340x68) framing the window title along the top frame edge.
  - Custom Aged Fibrous Parchment Background:
    - Synthesized 1024x512 high-resolution `Addon/WoWKillboard/Textures/classic_parchment_bg.tga` capturing the authentic warm amber tones, organic paper fibers, and burnt vignette of Classic WoW quest logs and dialogue scrolls.
    - Wired `UI.ContentInset.BgArt` to display parchment at 95% opacity in Classic theme and dark tactical war art in ElvUI theme.
  - Red Marble Panel Buttons & Taint-Free State Transitions:
    - Upgraded all interactive addon buttons (`UI:CreateButton`) to use Blizzard's canonical red marble panel textures (`UI-Panel-Button-Up`, `UI-Panel-Button-Down`, `UI-Panel-Button-Highlight`) with antique gold text in Classic theme.
    - Engineered using pure Lua widgets on `"BackdropTemplate"` without inheriting from Blizzard XML templates (`UIPanelButtonTemplate`), preserving 100% Guardrail 1 Zero UI Taint security standard.
    - Integrated visual push-state transitions (`SetButtonState("PUSHED", true)`) for active tabs and filter pills.

## [1.4.28] - 2026-09-26

### Fixed
- **Enemy Player Death Detection & Corpse Attackable Gate (`CombatTracker.lua`)**:
  - Eliminated critical WoW API trap where `UNIT_HEALTH` and `UNIT_FLAGS` evaluated `UnitCanAttack("player", unit)` before checking `UnitIsDead(unit)`. In World of Warcraft, dead corpses return `nil`/`false` for `UnitCanAttack`, causing the death handler to skip execution the exact moment an enemy player died.
  - Replaced with direct hostility checks (`UnitIsEnemy`, reaction index `<= 4`, or `not UnitIsFriend`) decoupled from corpse attackability.
  - Added unit monitoring for `targettarget` and `nameplate` units, capturing deaths of out-of-target enemies engaged in battle.
  - Ensured `CHAT_MSG_COMBAT_HONOR_GAIN` triggers `OnPlayerHonorableKill` even if the server chat message omits the victim's name (e.g. Battleground honor awards), falling back seamlessly to `CT.RecentEngagedEnemies`.
  - Reduced duplicate kill debounce threshold from 5.0s to 2.0s to properly capture rapid multi-kills and burst finishes.
- **Universal `/kb` Slash Command Registration & Subcommand Dispatch (`Core.lua`)**:
  - Registered `SLASH_WOWKILLBOARD3 = "/kb"` alongside `/killboard` and `/wowkb`. Previously, `/kb` was omitted, causing WoW's default chat parser to return `Type '/help' for a listing of a few commands.` whenever `/kb test` or `/kb testkill` was entered.
  - Eliminated duplicate `cmd == "testkill"` handler at line 64 that shadowed the full synthetic killmail generator at line 162.
  - Added instant chat confirmation and sound playback for `/kb test` (Kill Banner preview) and guaranteed banner popups (`isTest = true`) during synthetic combat simulations.
- **Dynamic `/kb testkill` Slash Command Target Inspection (`Core.lua`)**:
  - Enhanced `/kb testkill [name]` to automatically inspect the current active target (`UnitExists("target")`), dynamically extracting the targeted unit's name, class, guild, faction, and level.
- **Web War Room UI Fallback Resilience (`web/static/app.js`)**:
  - Added graceful HTTP error handling with war room retry cards for both the "Hall of Legends" and "Marks of Spite" views when cloud backends are undergoing cold boot or schema initialization.
- **Test Database Isolation (`tests/test_pipeline.py`)**:
  - Redirected unit test database path via `os.environ["DB_PATH"] = "tests/test_killboard.db"`, ensuring automated test teardowns never delete or mutate live combat records in `web/killboard.db`.
- **Render Auto-Deployment Configuration (`render.yaml`)**:
  - Added `autoDeploy: true` to the Render blueprint manifest to ensure future commits trigger continuous builds automatically.

## [1.4.27] - 2026-09-26

### Fixed
- **Render Cloud Gunicorn Database Initialization & Health Endpoint (`web/server.py`)**:
  - Resolved HTTP 500 error on Render cloud deployment (`https://wow-killboard.onrender.com/api/kills`). When deployed via Docker container, Gunicorn imports `server:app` where `__name__ == "server"`. Because `init_db()` was previously enclosed in `if __name__ == "__main__":`, database tables were never created, causing all API endpoints to crash with `sqlite3.OperationalError: no such table: kills`.
  - Moved `init_db()` to execute unconditionally at module import time, ensuring Gunicorn worker threads immediately initialize SQLite tables, columns, and default seed data.
  - Added dedicated `/api/health` endpoint returning `{"status": "ok", "service": "WoW Killboard API", "db": "ready"}` for automated Render container health probing.
- **Tri-Lock Non-CLEU Open-World PvP Kill Detection & Victim Engine (`CombatTracker.lua`, `UnitScanner.lua`)**:
  - Solved issue where open-world PvP kills on Forever Beta (`1.60.1`) were not logging after `COMBAT_LOG_EVENT_UNFILTERED` was disabled.
  - Implemented Tri-Lock Failover Kill Detection:
    1. **Blizzard Engine Signal**: Registered `PLAYER_PVP_KILLS_CHANGED` with `GetPVPLifetimeStats()` / `GetPVPSessionStats()` monitoring to guarantee kill registration from Blizzard's C++ engine even without combat log or chat events.
    2. **Direct Death Dispatch**: Added `UNIT_FLAGS` and `UNIT_HEALTH` listeners for `"target"` and `"focus"` via `RegisterUnitEvent` (or fallback `RegisterEvent`), capturing instant enemy death flags during active combat.
    3. **Honor Chat Parsing**: Upgraded `ExtractVictimFromHonorMsg()` to strip 26 PvP rank prefixes (e.g. `"Corporal Shadowstalker"` -> `"Shadowstalker"`) and added fallback to `CT.RecentEngagedEnemies` if honor gain messages omit the victim's name.
  - Implemented `CT.RecentEngagedEnemies` temporal cache (30-second sliding window) preserving target metadata during tab-targeting and out-of-range combat finishes.
  - Corrected solo kill classification: un-grouped players in open-world combat are properly recognized as `isSolo = true` with `attackersCount = 1` rather than being forced into gang gank status.
  - Removed combat lockdown gates from read-only `UnitScanner:ScanUnit` queries on mouseover and nameplates, ensuring enemy player metadata is continuously populated during combat.
  - Added `/kb testkill [name]` slash subcommand for instant player verification in-game.

### Added
- **Dual-Sync Pipeline & Automated Multi-Endpoint Broadcasting (`sync/watcher.py`)**:
  - Upgraded `KillboardWatcher` to support multiple simultaneous ingestion targets (`api_urls`).
  - By default, `WoWKillboardSync` broadcasts all combat telemetry, kills, bounties, and distress beacons to BOTH the production Render cloud platform (`https://wow-killboard.onrender.com`) and the local development server (`http://127.0.0.1:8080`).
  - Added CLI flags `--cloud` / `--render` and `--local` for explicit routing overrides.
  - Recompiled standalone Windows binary [`WoWKillboardSync.exe`](file:///c:/Users/SQUICK/WoW_Killboard/WoWKillboardSync.exe).

## [1.4.26] - 2026-09-26

### Fixed
- **Root-Cause Eradication of `ADDON_ACTION_FORBIDDEN` on `COMBAT_LOG_EVENT_UNFILTERED` (`CombatTracker.lua`)**:
  - Identified the exact root cause of the Blizzard popup from in-game call stack telemetry: `[Interface/AddOns/WoWKillboard/CombatTracker.lua]:998: in main chunk` calling into `Blizzard_Game/Shared/EventRouting.lua:48`.
  - In WoW Forever Beta (1.60.1 / `tocversion` 16001) and modern Midnight (12.0+) engines, `COMBAT_LOG_EVENT_UNFILTERED` is a restricted, protected internal event. Attempting to call `frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")` (even wrapped in `pcall`) causes Blizzard's secure `EventRouting.lua` to throw `ADDON_ACTION_FORBIDDEN: WoWKillboard, UNKNOWN()`.
  - Implemented dynamic runtime gating: `if not isCLEUForbidden then frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED") end`. On Forever Beta and modern engines, the registration is completely bypassed with zero security violations.
  - Combat and killmail tracking on Forever Beta operates cleanly via public, unrestricted events (`CHAT_MSG_COMBAT_HONOR_GAIN`, `CHAT_MSG_SYSTEM`, `UNIT_HEALTH`, `PLAYER_DEAD`, `PLAYER_TARGET_CHANGED`).
  - Removed `pcall(frame.RegisterEvent, frame, "PVP_MATCH_COMPLETE")` in favor of standard `UPDATE_BATTLEFIELD_STATUS`.
  - Cleaned up all diagnostic stack tracers and temporary hooks from [`Config.lua`](file:///c:/Users/SQUICK/WoW_Killboard/Addon/WoWKillboard/Config.lua).

## [1.4.25] - 2026-09-26

### Fixed
- **Complete Eradication of Blizzard Action Blocked Popup on Login (`WoWKillboard.toc`, `Core.lua`)**:
  - Removed `## AddonCompartmentFunc: WoWKillboard_OnAddonCompartmentClick` from [`WoWKillboard.toc`](file:///c:/Users/SQUICK/WoW_Killboard/Addon/WoWKillboard/WoWKillboard.toc) and deleted the global `WoWKillboard_OnAddonCompartmentClick` handler from [`Core.lua`](file:///c:/Users/SQUICK/WoW_Killboard/Addon/WoWKillboard/Core.lua).
  - In WoW Classic / Forever Beta (1.60.1 / 1.15.x), third-party `AddonCompartmentFunc` tags cause Blizzard's secure Minimap code to block execution and generate the *"WoWKillboard has been blocked from an action only available to the Blizzard UI"* popup dialog upon loading.
- **Secure Unit Event Dispatcher Taint Elimination (`CombatTracker.lua`)**:
  - Replaced `frame:RegisterUnitEvent("UNIT_HEALTH", "target")` with standard `frame:RegisterEvent("UNIT_HEALTH")` in [`CombatTracker.lua`](file:///c:/Users/SQUICK/WoW_Killboard/Addon/WoWKillboard/CombatTracker.lua).
  - Calling `RegisterUnitEvent` at load time in Classic binds the addon frame into Blizzard's internal unit event dispatch tables used by secure unit frames (such as `TargetFrame`), triggering action-blocked taint during target updates. Standard event registration with internal `if unit == "target"` checking completely bypasses the secure dispatcher.
- **Unregistered Action Blocked Diagnostic Listeners (`Core.lua`)**:
  - Removed `ADDON_ACTION_BLOCKED` and `ADDON_ACTION_FORBIDDEN` event registrations from `coreFrame` to eliminate handler loops and secondary taint during engine security notifications.
- **Zero-Allocation Lazy Main Dashboard Initialization (`Core.lua`, `UI.lua`)**:
  - Deferred `UI:CreateMainWindow()` to only instantiate when explicitly toggled by the player via `/wowkb` or the Minimap button, eliminating massive frame allocation during `ADDON_LOADED`.
  - Removed `UNIT_PORTRAIT_UPDATE` and `PLAYER_ENTERING_WORLD` event handlers from `mainFrame`, leaving `UI.lua` with zero registered game events and refreshing portraits safely on `OnShow`.
  - Wrapped `SetPortraitTexture` in `pcall` within `UI:UpdatePortrait()`.

## [1.4.24] - 2026-09-26

### Fixed
- **Open-World PvP Combat Log Crash & Nil Bitmask Error Fix (`CombatTracker.lua`)**:
  - Resolved fatal Lua error `bad argument #2 to 'band' (number expected, got nil)` that occurred in `RecordDamage()` when evaluating `bit.band(sourceFlags, COMBATLOG_OBJECT_REACTION_HOSTILE)` in WoW Forever Beta / Classic client environments where `COMBATLOG_OBJECT_REACTION_HOSTILE` was undefined in FrameXML globals.
  - Implemented local bitmask constants and type-safe `HasFlag(flags, mask)` supporting both `bit` and `bit32` across all WoW client flavors without relying on external FrameXML globals.
  - Upgraded `IsPlayerUnit(guid, flags, name)` with multi-heuristic resolution (Player GUID match, player/control bitmasks, unit cache, active target, and mouseover tokens).
  - Ensured `CT.RecentDamage` is reliably populated on every combat swing or spell hit, preventing missing attacker records.
- **Player Death Kill Dropping & Zero-Attacker Target Fallback (`CombatTracker.lua`)**:
  - Resolved issue where open-world kills were silently dropped by `ProcessDeath()` on `UNIT_DIED` when `RecentDamage` was empty.
  - Added robust target fallback: if `#attackersList == 0` upon enemy death, the engine checks whether the victim was the player's active target or recent enemy target (`UnitGUID("target")`, `UnitName("target")`, or `activeEnemyTarget`), seamlessly attributing the killing blow to the player.
  - Added bidirectional kill deduplication (`CT.LastKillVictim` and `CT.LastKillTime` with a 5-second sliding window) between combat log death events and honor chat announcements.
- **Honor Chat Message Color Stripping & Multi-Word Parsing (`CombatTracker.lua`)**:
  - Overhauled `ExtractVictimFromHonorMsg()` to strip Blizzard UI color codes (`|c...`, `|r`) and hyperlink formatting before matching.
  - Added comprehensive pattern support for `"Victim dies..."`, `"death of Victim..."`, and `"Honorable Kill: Victim..."` with whitespace trimming.
- **Proximity Friendly Temporal Clustering Parity (`CombatTracker.lua`)**:
  - Added proactive friendly combatant tracking in `COMBAT_LOG_EVENT_UNFILTERED`: any friendly player performing a combat action in proximity is added to `FriendlyCluster`.
  - Guarantees certified 1v1 solo kills are strictly awarded when the player is truly alone, marking multi-combatant open-world skirmishes as `[GANG]`.
- **Top Header Duel & Battleground Stat Card Visibility (`UI.lua`)**:
  - Resolved bug where the `1v1 DUELS RECORD` and `BATTLEGROUNDS RECORD` header stat cards showed `"No duels recorded"` even when duels or battleground matches were logged on the board by other players.
  - Cards now display accurate logged counts (`0W - 0L (You) • X Logged`) when spectated or witnessed matches are present.
- **Zero-Taint Keyboard & ESC Event Cycle Overhaul (`UI.lua`)**:
  - Eradicated permanent `EnableKeyboard(true)` allocations from hidden root frames (`mainFrame`, `UI.ReinforcementDialog`, `UI.KOSDialog`, `UI.AlertsDialog`).
  - Previously, `mainFrame` retained keyboard capture even when hidden at login, intercepting the `ESCAPE` key and executing `self:SetPropagateKeyboardInput(false)`. This blocked Blizzard's secure `ToggleGameMenu()` / `ClearTarget()` calls and triggered the *"WoWKillboard has been blocked from an action only available to the Blizzard UI"* popup dialog.
  - Keyboard listening is now initialized to `EnableKeyboard(false)` and activates strictly on `OnShow`, instantly disabling on `OnHide` with unconditional propagation fallback (`not self:IsShown()`). Safe `pcall` guards added for `SetPortraitTexture`.

## [1.4.23] - 2026-09-26

### Fixed
- **Blizzard UI Login Action Blocked Warning Eradication (`Core.lua`)**:
  - Eradicated `pcall(SetCVar, "taintLog", "0")` from the `ADDON_LOADED` event handler in [`Core.lua`](file:///c:/Users/SQUICK/WoW_Killboard/Addon/WoWKillboard/Core.lua).
  - Calling `SetCVar` on Blizzard-protected engine/developer CVars (`taintLog`) from an insecure addon environment triggered the C++ engine's `ADDON_ACTION_BLOCKED` / `ADDON_ACTION_FORBIDDEN` popup dialog (*"WoWKillboard has been blocked from an action only available to the Blizzard UI"*).
  - Zero Blizzard engine CVars are touched, ensuring 100% silent, error-free client load on login.

### Removed
- **Warfronts Navigation Tab (`UI.lua`)**:
  - Removed the `Warfronts` (`BG_METRICS`) tab from the primary navigation bar in [`UI.lua`](file:///c:/Users/SQUICK/WoW_Killboard/Addon/WoWKillboard/UI.lua).
  - Consolidated the header navigation bar to the 4 essential tabs: **Intel** (`FEED`), **Hall of Legends** (`LEADERBOARD`), **Marks of Spite** (`BOUNTIES`), and **Zone Intel** (`ZONES`).
  - Added self-healing fallback in `UI:Refresh()` to redirect any active `BG_METRICS` state to `FEED`.

## [1.4.22] - 2026-09-26

### Fixed
- **Grand Character Portrait Medallion Overhaul (`UI.lua`)**:
  - Resized the header medallion to a bold, authentic Blizzard unit-frame scale: expanded outer medallion from 46x46 to 60x60 and inner character portrait from 36x36 to 48x48.
  - Adjusted concentric texture coordinates (`SetTexCoord(0.12, 0.88, 0.12, 0.88)`) to eliminate square corner bleed while showcasing maximum character detail.
  - Added a dedicated 20x20 circular dark gunmetal backing plate (`lvlFrame`) anchored at `BOTTOMRIGHT, 2, -2` with crisp gold level typography.
  - Realignment of title (`LEFT, medallion, RIGHT, 14, 6`), stat cards (`TOPLEFT, 14, -70`), dividing rule (`-118`), navigation tabs (`-124`), filter pills (`-125`), and content inset (`-154`), expanding main frame height to 580px for zero overlap.
- **Strict Solo Kill Certification & Friendly Proximity Guard (`CombatTracker.lua`)**:
  - Resolved false positive solo kill awards (e.g. against `Shadowstalker` in Refuge Pointe) when nearby guards or friendly players were engaged in combat.
  - Implemented `CT.FriendlyCluster` tracking all friendly players dealing damage or healing within the 15-second combat window.
  - Hardened `ProcessDeath()`: an engagement is certified `isSolo = true` if and only if `#attackersList == 1`, `friendlyPartySize == 1`, and `friendlyAssists == 0`. Open-world skirmishes with nearby allies are strictly tagged as `[GANG]`.
  - Chat honorable kill broadcasts now default to `isSolo = false` to prevent gang kills from masquerading as solo duels.
- **Proactive Class Sniffing & Warrior Class Color Parity (`UnitScanner.lua`, `Utils.lua`, `CombatTracker.lua`)**:
  - Resolved issue where warrior combatants (such as `Commando Joe`) appeared in plain white/grey text due to unknown class status prior to targeting.
  - Implemented `CLASS_SPELL_SIGNATURES` across all 9 classic classes (e.g., Warrior `Heroic Strike`, `Charge`, `Mortal Strike`, `Rend`, `Overpower`, `Thunder Clap`, `Execute`).
  - Added `US:InferClassFromSpell(guid, name, spellName)` hooked into `SPELL_DAMAGE`, `SPELL_HEAL`, and `SPELL_CAST_SUCCESS` to dynamically identify player classes from combat log casts without requiring mouseover.
  - Added `NAME_PLATE_UNIT_ADDED` event scanner to proactively index visible nearby players into the unit cache.
  - Overhauled `U.ColorizeByClass` to safely read `RAID_CLASS_COLORS`, strip extraneous `ff` alpha prefixes, and guarantee authentic Blizzard tan/brown (`#C79C6E`) formatting for Warriors.
- **1v1 Duel Telemetry Surnames & Self-Healing Reconciliation (`CombatTracker.lua`, `UI.lua`)**:
  - Upgraded player name matching in `OnDuelCompleted` with multi-word surname tolerance (`MatchesPlayer`), ensuring duel records with server surnames (e.g. `Wrastarim Moonshadow`) accurately attribute personal wins and losses.
  - Added automatic stat reconciliation in `UI:Refresh()`: parses stored killmails in `WoWKillboardDB.kills` to restore historical duel wins, losses, and total board counts even if counters were desynchronized.
- **Theme Deprecation & Subtitle Streamlining (`Config.lua`, `Core.lua`, `UI.lua`)**:
  - Permanently deprecated and eradicated the redundant `"tactical"` theme. Retained strictly 2 high-contrast themes: **Classic Blizzard** (`classic`) and **ElvUI Minimalist** (`elvui`).
  - Updated theme switcher button in header, `/wowkb theme`, and minimap right-click to toggle directly between Classic and ElvUI.
  - Eradicated redundant theme description text ("Classic Blizzard Stone & Gold") from the main window header, setting subtitle strictly to `v1.0.0`.

## [1.4.21] - 2026-09-26

### Fixed
- **P0 Blizzard UI Taint Elimination & Action Blocked Fix (`UI.lua`, `Config.lua`)**:
  - Eradicated all calls to Blizzard's protected `RaidNotice_AddMessage(RaidWarningFrame, ...)` which caused the red-bordered *"WoWKillboard has been blocked from an action only available to the Blizzard UI"* popup during combat.
  - Built an anonymous, 100% taint-free Raid Warning Notice frame (`UI.RaidNoticeFrame`) running on pure Lua widgets with zero Blizzard FrameXML dependencies.
  - Fixed combat click interception: `UI.KillBanner` now defaults strictly to `EnableMouse(false)` (click-through in combat) and enables mouse interaction *only* while repositioning is active.
  - Eradicated in-combat anchor mutations: removed `ClearAllPoints()` and `SetPoint()` calls from the combat execution path in `ShowKillBanner()`.

### Added
- **Frontline Combat Alerts & Radar Configuration Panel Overhaul (`UI.lua`)**:
  - Redesigned the in-game Alerts modal (`UI:ShowAlertsConfig()`) into a streamlined 4-section calibration hub:
    1. **Display & Audio Feedback**: 3 dedicated toggle selectors (`Sound + Alert`, `Alert Only (Muted)`, `Turn Off`) with real-time active highlights.
    2. **Radar & Proximity Scope**: 3 dedicated proximity selectors (`Same Zone Only`, `Entire Realm`, `Personal Only`).
    3. **Visual Alert Style**: Choose between `Both Displays`, `Raid Warning` (cinematic center-screen text), or `Tactical Banner` (compact bar with class icons).
    4. **Screen Positioning & Calibration**: 1-click `Move / Unlock Alert Anchor` with live coordinate feedback (`TOP: X: 0, Y: -135`) and `Reset to Center`.
  - Added live preview testing via `[Test Alert Preview]` and slash command `/wowkb test`.
  - Added quick slash command `/wowkb move` (or `/wowkb unlock`) to toggle alert repositioning anywhere on screen with automatic persistence.

## [1.4.20] - 2026-09-26

### Fixed
- **Duel Telemetry & KPI Stat Cards Synchronization (`CombatTracker.lua`, `UI.lua`)**:
  - Resolved stat card discrepancy where witnessed realm duels (e.g. duels between other players in the Wetlands) appeared in the live feed but left the top `1v1 DUELS RECORD` card at `0W - 0L (0%)`.
  - Added realm-wide total duel tracking in `WoWKillboardDB.stats.duels.total` and dynamic fallback aggregation from `WoWKillboardDB.kills`.
  - Updated all 3 top KPI Stat Cards to display **both** the player's personal performance (`You`) and the total activity tracked on the board (`Logged`), formatted cleanly as:
    - `SESSION COMBAT K/D`: `0K / 0D (You) • X Logged`
    - `1v1 DUELS RECORD`: `0W - 0L (You) • X Logged` (e.g., `0W - 0L (You) • 1 Logged` for the Wetlands duel)
    - `BATTLEGROUNDS RECORD`: `0W - 0L (You) • X Logged`
  - Added interactive mouse hover tooltips to all 3 attribute stat cards explaining personal records vs total board telemetry.
  - Hardened duel combatant name matching against cross-realm hyphenated suffixes (`cleanWinner`, `cleanLoser`) to ensure reliable personal win/loss attribution.
  - Implemented proximity targeting/mouseover unit scanning fallback in `OnDuelCompleted` to capture levels and classes for active duelists.
  - Cleaned up feed row level rendering: unscanned combatants now display as `??` instead of `0`.

## [1.4.19] - 2026-09-26

### Fixed
- **P0 Combat Engine Restoration on WoW Forever Beta (`CombatTracker.lua`)**:
  - Eradicated hardcoded TOC version check `(tocVersion >= 16000 and tocVersion <= 16999)` that mistakenly flagged WoW Forever Beta (TOC `16001`) as an unsupported modern client and suppressed `COMBAT_LOG_EVENT_UNFILTERED` registration.
  - Implemented dynamic runtime feature detection `type(CombatLogGetCurrentEventInfo) == "function"` adhering strictly to Guardrail 2 (Cross-Client Parity).
  - Normalised payload extraction via `GetCombatLogPayload(...)`, ensuring swing damage, spell damage, heals, party kills, and unit deaths are 100% captured across Forever Beta, Classic Era, Anniversary, and Retail.
  - Made player GUID and unit death detection resilient against missing bit flags by inspecting `Player-` GUID prefixes in `RecordDamage` and `ProcessDeath`.
  - Upgraded target death detection in `UNIT_HEALTH` to trigger on `UnitIsDeadOrGhost("target")` without requiring the transient player combat flag.

### Added
- **Tactical Open-World Hostile Radar Announcements (`UnitScanner.lua`)**:
  - Implemented proximity targeting radar (`US:CheckHostileRadar`) that broadcasts an informative tactical notice in chat when an enemy hostile player is targeted in the open world: `[WoWKB Radar] Detected Hostile: Name (Lvl X Class) in Zone!`.
  - Throttled to once per 30 seconds per unique target to prevent chat spam during combat.
- **Rich Frontline Combat Radar Empty Feed State (`UI.lua`)**:
  - Replaced the ambiguous one-line empty feed message with an informative status card: displays active Sector Surveillance (current zone), filter mode, "ARMED & LISTENING" combat engine status, and a direct hint to run `/wowkb testkill`.
- **Synthetic PvP Verification Commands (`Core.lua`)**:
  - Added `/wowkb testkill` (or `/wowkb demo`): instantly simulates an authentic open-world PvP kill in the player's current zone, popping the Kill Banner alert, playing the audio cue, incrementing K/D stat cards, and populating the live feed with a clickable Killmail Intelligence Dossier.
  - Added `/wowkb testdeath`: simulates a PvP death to test the revenge blood bounty prompt and death counters.

## [1.4.18] - 2026-09-26

### Added
- **Website Atmospheric Dark Battlefield Inset Backdrop**:
  - Converted the website's flagship dark war room image (`web/static/images/dark_war_bg.jpg`) into a high-performance 1024x512 TGA texture (`Addon/WoWKillboard/Textures/dark_war_bg.tga`).
  - Integrated `inset.BgArt` directly into the content inset panel with a subtle dark obsidian vignette, replacing flat pitch-black empty space with the gritty war battlefield atmosphere from the web platform.
- **Concentric Circular Gold Medallion Ring (`Textures/medallion_border.tga`)**:
  - Engineered a custom 128x128 32-bit RGBA beveled gold medallion texture mathematically centered at `(64, 64)`, eliminating the previous Blizzard minimap tracking texture's top-left offset.
  - Positioned the medallion neatly within the top header tier (`TOPLEFT, 12, -8`, size 46x46) with concentric portrait crop (`SetTexCoord(0.15, 0.85, 0.15, 0.85)`), ensuring zero overlap with the top stat cards.
- **Dynamic Flavor & Realm Title Detection (`U.GetClientFlavorTitle`)**:
  - Implemented runtime flavor and realm detection in `Utils.lua` dynamically rendering `WoW Killboard [WoW Forever • <RealmName>]` in vibrant tactical cyan (`|cff00e5ff`) instead of hardcoding `[Classic WoW]`.

### Fixed
- **Clean Vertical Tier Layout & Stat Card Isolation**:
  - Re-anchored the 3 KPI stat cards to `TOPLEFT, 14, -58` (height 42 px), creating a distinct 6-pixel buffer below the header and 6-pixel buffer above the navigation tabs.
  - Fixed portrait square corners and misaligned circular ring overlays.
  - Upgraded `scripts/deploy.py` to recursively synchronize subdirectories (`Textures/`) across all 4 WoW client flavors and package builds.

## [1.4.17] - 2026-09-26

### Added
- **Frontline Combat Alerts & Radar Configuration System**:
  - Implemented 1-click in-game Alerts Configuration modal (`UI:ShowAlertsConfig`) accessible via `⚙️ Alerts` button in the dashboard header or `/wowkb alerts`.
  - Added 3-way **Alert Mode** audio/visual toggling: `🔊 Sound + Banner`, `🔕 Banner Only (No Sound)`, or `⛔ Alerts Disabled (Off)`.
  - Added 3-way **Radar & Proximity Scope** filtering: `📍 Same Zone Only` (Zone Radar: alerts only for combat in current zone), `🌐 All Realm Kills` (broadcasts across realm), or `⚔️ My Kills Only` (personal engagements).
  - Implemented secondary **Raid Warning Screen Notice** (`alertRaidWarning`): flashes large raid warning text across screen center on confirmed kills via `RaidNotice_AddMessage(RaidWarningFrame, ...)`.
  - Added **Draggable Kill Banner Calibration**: `/wowkb move` or `📐 Move / Unlock Banner` unlocks banner for left-click repositioning with auto-saving to `WoWKillboardSettings.bannerPosition`.
  - Added `↺ Reset Position` button to restore default center-top coordinates (`TOP, 0, -135`).
  - Added `▶️ Test Alert Preview` (`/wowkb test`) for instant live preview of banner placement, sound, and raid warning text.
  - Linked P2P synchronized kill reception (`Sync.lua`) to `UI:ShowKillBanner(syncedKM)`, enabling real-time cross-player frontline radar alerts filtered by zone and scope.

### Fixed
- **Minimap Button Hover Lua Error (`TableLength` nil value)**:
  - Resolved `Core.lua:422: attempt to call a nil value` by implementing `U.TableLength(t)` in `Utils.lua` for safe dictionary and sparse array length calculation.
- **Unified Audio Alert Dispatch**:
  - Centralized sound dispatch and audio gating inside `UI:ShowKillBanner`, eliminating duplicate audio triggers and ensuring strict adherence to the player's `alertMode` preference across `Killmail.lua` and `BountyEngine.lua`.

## [1.4.16] - 2026-09-26

### Added
- **Aegis Tactical / Obsidian Gold In-Game Addon Theme**:
  - Engineered the flagship **Aegis Tactical** visual theme for the in-game addon (`Addon/WoWKillboard/Config.lua` and `UI.lua`), perfectly matching the dark iron, brushed brass, and tactical gold aesthetic of the web platform.
  - Deep obsidian velvet backdrop (`#090c12`), brushed aged brass framing, dark iron card plates, and radiant golden active buttons.
  - Added seamless 3-way theme cycling (`Aegis Tactical` &rarr; `ElvUI Minimalist` &rarr; `Classic WoW`) via `/wowkb theme` or 1-click header switcher.
- **Frontline Kill Banner & Combat Toast System**:
  - Implemented an anonymous, taint-free on-screen combat banner (`UI:ShowKillBanner`) triggered whenever the player secures a PvP execution.
  - Pre-allocated at addon load to guarantee zero memory allocation and 100% `InCombatLockdown()` safety.
  - Displays high-resolution Blizzard class icons, colorized combatant callsigns, dynamic engagement badges (`[SOLO 1v1]`, `[DUEL]`, `[BG]`, `[GANG xN]`), location telemetry (Zone & GPS coordinates), and auto-dismisses after 4.5 seconds with sound feedback.
- **Enhanced Interactive Minimap Launcher**:
  - Upgraded floating minimap button to support Left-Click (Toggle Dashboard) and Right-Click (Quick Theme Cycle).
  - Enriched private hover tooltip with active theme identifier and real-time combat session kill counter.
- **Cloud Persistent Storage & Infrastructure as Code**:
  - Engineered `render.yaml` blueprint defining the web service, persistent disk mount (`/data/killboard.db`), and cloud environment variables for 1-click deployment on Render.com.
  - Updated `Dockerfile` CMD to dynamically bind to `$PORT` via shell expansion, ensuring compliance with container orchestrators.
  - Enhanced `get_db()` in `web/server.py` to auto-create parent directories when mounting cloud volumes.
- **Production-Ready Desktop Sync Agent (`WoWKillboardSync.exe`)**:
  - Upgraded `sync/watcher.py` with dual-endpoint resolution: defaults to the public cloud URL (`https://wow-killboard.onrender.com`), auto-detects active local development servers (`http://127.0.0.1:8080`), and supports `wowkb_sync_config.json` overrides.
  - Configured UTF-8 console output with cp1252-safe ASCII terminal formatting.
  - Recompiled standalone binary `dist/WoWKillboardSync.exe` (8.8 MB).

### Changed
- **In-Game Marks of Spite Terminology Synchronization**:
  - Synchronized in-game tab labels, headers, and dialogue prompts from legacy "Blood Bounties" to **Marks of Spite**.
  - Updated in-game contract creation modal to **Issue Mark of Spite** with reward bounty gold formatting.

## [1.4.15] - 2026-09-26

### Fixed
- **Hall of Legends Mobile Table Sizing & Horizontal Touch Scrolling**:
  - Encapsulated Player Ranks and Guild Ranks tables inside `.legends-table-wrapper` with `overflow-x: auto; -webkit-overflow-scrolling: touch; width: 100%;` to enable frictionless native touch swipe side-scrolling on screens $< 768px$.
  - Fixed table geometry to prevent column crushing: Player Ranks (`min-width: 710px; table-layout: fixed;`) and Guild Ranks (`min-width: 740px; table-layout: fixed;`) with strict `<colgroup>` pixel allocations and `white-space: nowrap` cells.
  - Added visual `.mobile-table-scroll-hint` swipe guides (`⟵ Drag table to view all combat stats | N Columns ⟶`) displayed exclusively on mobile viewports.
  - Reformatted Operative Benchmark Comparison Banner for mobile: responsive 3-column stats grid (`.benchmark-stats-row`) with full-width input container (`.benchmark-input-wrap`).
  - Restructured `.legends-header-controls` for mobile: full-width stacked filter pills (`#legends-type-pills` with flexed buttons, `#legends-mode-pills` with horizontal touch scroll and hidden scrollbars).
  - Responsive single-column wrap for Marks of Spite Hall of Fame cards (`.bounty-hall-of-fame-grid`).

## [1.4.14] - 2026-09-26

### Fixed
- **Mobile Navigation Rail & Menu Options Availability**:
  - Restored primary navigation rail (`.nav-links-rail`) on all mobile and tablet viewports ($\le 1024px$, $\le 768px$, and $\le 480px$), eliminating the `display: none !important` rule that hid menu options on mobile.
  - Implemented dual-tier responsive header: row 1 houses the crests, title, and tools; row 2 houses a smooth, horizontally scrollable navigation rail granting instant 1-tap access to **Theater**, **Intel**, **Hall of Legends**, and **Marks**.
  - Re-anchored `.header-main-row` with `flex-wrap: wrap` and scaled tool padding to prevent the hamburger menu button from clipping off-screen on compact phones ($< 390px$).
  - Elevated mobile drawer z-index to `3001` and backdrop to `3000` to guarantee smooth, unobstructed slide-out menu operation.

## [1.4.13] - 2026-09-26

### Added
- **"In Development" Lifecycle Gating for War Room, Armory, and World Hazards**:
  - Gated navigation tabs for **World Hazards**, **Armory**, and **War Room** on both desktop and mobile drawer with `.in-development` styling, `[In Dev]` amber pills, `disabled` attributes, and click suppression.
  - Added programmatic guards in `switchTab()` and `handleArmoryNavClick()` preventing route activation.
- **Cross-Mode Guild Leaderboard Filtering**:
  - Added `mode` query parameter support (`WORLD`, `BG`, `ARENA`, `DUEL`, `ALL`) to `/api/guilds`, mirroring Player Ranks.
  - Persisted combat mode filter pills (`All PvP`, `World`, `BGs`, `Arenas`, `Duels`) when switching between Player Ranks and Guild Ranks in Hall of Legends.

### Changed
- **Alphabetical Realm Talent Specializations**:
  - Re-sorted Top Specs strictly from A to Z across all 27 canonical talent archetypes (Affliction through Survival) on both backend (`server.py`) and frontend (`app.js`).
- **Standardized Class Name Typography in Intel Sidebar**:
  - Converted realm class labels from all-caps (`DRUID`, `HUNTER`) to standard title-case layout (`Druid`, `Hunter`, `Mage`, `Paladin`, `Priest`, `Rogue`, `Shaman`, `Warlock`, `Warrior`).
- **Hall of Legends Table Cell Stabilization**:
  - Enforced `table-layout: fixed;` with explicit `<colgroup>` column widths and uniform `6px 10px` padding on all table headers and cells across both Player Ranks and Guild Ranks, eliminating layout shifting when cycling combat modes.
  - Purged rectangular background and border backdrops from percentile numbers, rendering clean tactical cohort text.

### Removed
- **Guest Reconnaissance Sign-In Prompt**:
  - Purged the *"Browsing as Guest Recon. Sign in to display your personalized combat kills..."* prompt strip from the homepage stats hub.

## [1.4.12] - 2026-09-26

### Added
- **Complete 27-Archetype Classic Specialization Indexing**:
  - Indexed all 27 canonical Classic talent specializations in `/api/stats/activity-7d` across all 9 classes (Affliction, Arcane, Arms, Assassination, Balance, Beast Mastery, Combat, Demonology, Destruction, Discipline, Elemental, Enhancement, Feral Combat, Fire, Frost, Fury, Holy [Paladin], Holy [Priest], Marksmanship, Protection [Paladin], Protection [Warrior], Restoration [Druid], Restoration [Shaman], Retribution, Shadow, Subtlety, Survival).
  - Actively logged kills bubble to the top sorted by `(-kills, spec_name)`, while unused specs remain indexed alphabetically.
  - Active kills rendered in bright cyan (`var(--accent-cyan)`), while unlogged specs are rendered in muted slate (`#64748b`).

### Changed
- **Right Sidebar Tactical Card Reordering**:
  - Repositioned **All Classes** directly above **Top Active Specs** in `index.html`.
- **Hall of Legends & Marks of Spite Visual Realignment**:
  - Aligned main view headers directly against the dark stone backdrop with brass bottom borders (`border-bottom: 1px solid var(--wow-brass-border)`) and `#856a36` tactical subtitles, matching the Intel combat feed.
  - Purged bulky outer card wrapper containers from the Personal Marks and High Command Marks sections.
  - Replaced generic card styling with dark iron plate styling (`linear-gradient(180deg, #0a0d14 0%, #030407 100%)`, heavy inset shadows, and subtle brass borders) across Hall of Legends leaderboards and Marks of Spite Hall of Fame cards.

## [1.4.11] - 2026-09-26

### Added
- **WoW Forever 4-Server Realm Selector (PvP, PvE, RP, Hardcore)**:
  - Added dedicated realm server selector modal (`#server-modal`) and interactive theater card quick-switch pills for all 4 WoW Forever servers (PvP, PvE, RP, Hardcore).
  - Selecting WoW Forever in Campaign Selector now triggers the additional server ruleset picker.
  - Top navigation rail displays the active server pill badge (`Theater: WoW Forever [PvP] ▾`), allowing instant 1-click server switching anywhere on the platform.
  - Backend `/api/system/flavor` updated to persist and return active realm server (`server` & `supportedServers`).

### Removed
- **High Command Execution List Outer Rectangle Container**:
  - Purged background, border, shadow, and inset padding from `.most-wanted-section`.
  - The High Command header and subtitle now sit directly on the dark textured stone backdrop, achieving visual parity with the `Recent Kills` feed.
- **Guild Names from Top Active Gankers**:
  - Removed `<guild>` tags from the Top Active Gankers sidebar widget, delivering clean single-line player rank rows.

## [1.4.10] - 2026-09-26

### Added
- **Topographic Azeroth Battle Terrain Backdrop for Deadliest Zones**:
  - Generated and installed custom grimdark topographic battle terrain backdrop (`zone_map_backdrop.jpg`) for the Deadliest Zones widget.
  - Applied subtle brass borders and dark gradient overlays to guarantee pristine contrast and readability.
- **Dedicated "See All Marks →" High Command Action**:
  - Replaced the static "LIVE CONTRACTS" status badge with a direct routing button navigating to the Marks of Spite board.

### Changed
- **Transitioned to "Mark of Spite" Terminology**:
  - Rebranded the realm contract ecosystem to **Marks of Spite** across the web platform, High Command Execution List, navigation tabs, personal mark tracking, and Hall of Fame leaderboards.
  - High Command Execution List subtitle updated to: *"Certified Marks of Spite across Azeroth • Deliver the final blow in open combat to claim the reward"*.
  - Renamed primary navigation buttons from "Bounties" to "Marks" across desktop header and mobile navigation drawer.
- **Separated Top Active Specs & Alphabetical Realm Classes**:
  - Split "Top Classes & Specs" into two dedicated cards: **Top Active Specs** (indexing top 10 talent archetypes colored by class) and **All Classes**.
  - All realm classes are sorted server-side strictly in alphabetical order (A–Z: Druid, Hunter, Mage, Paladin, Priest, Rogue, Shaman, Warlock, Warrior).
- **Uniform 1px Sidebar Rank Borders**:
  - Removed solid 3px left edge accent borders (`border-left`) from `.sidebar-rank-item.alliance` and `.sidebar-rank-item.horde` for a clean, consistent border design across all sidebar blocks.

## [1.4.9] - 2026-09-25

### Added
- **Automated Full Project Snapshot & Backup Tool (`scripts/backup.py`)**:
  - Engineered zero-dependency backup engine packaging complete codebase, addon files, web app, databases, documentation, and tests into high-compression zip archives under `backups/`.
  - Automatically filters ephemeral files (`.git`, `build`, `dist`, `__pycache__`, `cloudflared.exe`) and prints compression statistics.

### Removed
- **Purged Frontline Vanguard Supporter Card**:
  - Completely removed the supporter/patron widget from the tactical sidebar to maintain a 100% focused, battle-ready intelligence feed with zero non-combat distractions.

### Changed
- **Tactical Sidebar Block Standardization (Lifetime Combat Activity Standard)**:
  - Standardized all right-sidebar widget items to a clean, compact dark iron plate design matching the Lifetime Combat Activity and Top Classes layout (`0.76rem`, `#030407` plate with subtle brass border).
  - Purged feed-style banner image backgrounds from sidebar items, replacing them with crisp 3px faction left borders to keep the sidebar visually distinct and non-redundant with the center combat feed.
  - **All Classes Displayed**: Removed the 5-class restriction so all realm classes are dynamically indexed and tracked in real-time.
  - **Specialization Class Coloration**: Individual talent specializations now directly display in their signature class color (e.g. Marksmanship in hunter green `#abd473`) with the redundant class name text removed.
  - **Deadliest Zones Streamlined**: Removed the redundant secondary "High Conflict Zone" sub-line, aligning zone names and rank badges into single-row entries.
- **Comprehensive Grimdark Tactical War Room Design System**:
  - Pushed the entire visual system deeply into a dark, grim, gritty Blizzard fantasy aesthetic: obsidian black base canvas (`#020305`), blackened slate surfaces (`#040609`), and cast iron plate cards (`#0c0f16` to `#030407`).
  - Intensified body vignette falloff with deep charred stone background overlay, ensuring zero visual wash or low-contrast gray blocks.
  - Weathered dark brass borders (`#241c10`) and heavy 18px-24px inset plate shadows across killmail rows, most wanted cards, sidebar rankings, bounty target warrants, and modal cards.
  - Deepened faction tints to battle-worn midnight cobalt (`rgba(6, 12, 24, 0.92)`) for Alliance and dried blood-iron (`rgba(22, 6, 8, 0.92)`) for Horde.
- **Dark & Gritty Atmospheric Faction Color Tuning**:
  - Replaced high-saturation neon washes with subtle, battle-worn dark tints across all player areas: a deep moody navy tint (`rgba(12, 22, 44, 0.86)`) for Alliance and an equally subtle dark blood-iron tint (`rgba(44, 12, 16, 0.86)`) for Horde.
  - Symmetrized dark borders and removed excessive neon box-shadows across killmail feed rows, Most Wanted cards, bounty execution target cards, and tactical sidebar items.
- **Unified Heading Typography (Cinzel Metallic Gold Standard)**:
  - Standardized all major section and card headings across the center main column and right sidebar column to match the "Recent Kills" heading style (`font-family: var(--font-display)` Cinzel, 3D metallic gold gradient, and drop shadow).
  - Aligned `.section-title`, `.sidebar-sub-title`, `.most-wanted-title`, `Hall of Legends`, `Bounty Board`, and `Wall of Shame` headings to this uniform Blizzard aesthetic.
- **Purged Unmarked Recon (Guest) Badge**:
  - Removed the `UNMARKED RECON (GUEST)` badge from the homepage realm telemetry header.
- **Live Recon Wire Retired from Web (In-Game Dispatch Only)**:
  - Retired `#intel-sighting-wire` from the web platform; tactical reconnaissance sightings are dispatched strictly in-game via addon communication channels and combat tracker alerts.
- **Faction Backdrops for Most Wanted Outlaws**:
  - Dynamically bound authentic Alliance (`card_alliance_square.png`) and Horde (`card_horde_square.png`) stone crest backdrops to active outlaws in the Most Wanted grid.
  - Automatically infers faction from `target_faction` and class identity (e.g. Paladin/Shaman fallback), while keeping unclaimed slots cleanly neutral.
- **Tactical Sidebar Faction Backdrops & Redundant Text Purge**:
  - Created distinct Alliance and Horde tactical map backdrops, glowing 3.5px faction accent borders, and hover slide animations for "Top Active Gankers" and "Top Active Guilds" sidebar items.
  - Completely purged redundant literal text labels ("Alliance" / "Horde") from guild blocks, letting the visual faction heraldry and border styling communicate allegiance directly.
- **Canonical World of Warcraft Faction Artwork & Comprehensive Player Area Backdrops**:
  - Replaced non-canonical web reference images with custom-generated, authentic World of Warcraft canonical heraldry:
    - **Grand Alliance Canonical Crest**: Golden stylized roaring lion on cracked dark blue runic stone (`card_alliance_square.png`) and the vintage War of Lordaeron operational battlefront map (`banner_alliance_tactical.jpg`).
    - **Orcish Horde Canonical Sigil**: Curved-horn battle-worn blood iron tribal sigil on dark charcoal stone with Orcish runes (`card_horde_square.png`) and the Kalimdor/Barrens military tactical war map (`banner_horde_tactical.png`).
  - Extended authentic faction backdrops to all player-related areas across the web platform:
    - **High Command Execution List / Bounty Board**: Target cards styled with authentic Alliance or Horde military execution warrant backdrops, target class badges, and gold escrow telemetry.
    - **Hall of Legends Operative Benchmark**: Dynamically binds the benchmark comparison banner to the operative's faction war map.
    - **Character Profile Dossier Modal**: Injects the authentic faction tactical map hero header when inspecting any player character.
- **Authentic Textured Faction Banners & Square Card Blocks**:
  - Upgraded Intel Feed killmail rows with authentic World of Warcraft tactical war map banner backdrops (`banner_horde_tactical.png` and `banner_alliance_tactical.jpg`) for Horde and Alliance victories, featuring dark topographic battle lines, terrain contours, and subtle faction crest watermarks.
  - Applied authentic textured stone/grunge faction card blocks (`card_horde_square.png` and `card_alliance_square.png`) to landing entry gate cards with faction-tinted linear gradients, elevating visual parity to official Blizzard cinematic standards.
- **Dark Alliance & Horde Full-Row Banner Backdrops**:
  - Implemented full-width atmospheric banner backdrops across the entire killmail row for both factions: dark royal blue gradient (`rgba(29, 78, 216, 0.24)` to `rgba(9, 13, 22, 0.98)`) for Alliance victories and dark crimson gradient (`rgba(185, 28, 28, 0.24)` to `rgba(14, 10, 12, 0.98)`) for Horde victories.
  - Added high-contrast borders and interactive hover glows while preserving clear text readability, guild tags, and class color hierarchy.
- **Hall of Legends Operative Benchmark Comparison**:
  - Added live Operative Benchmark Comparison banner above the Player Ranks table.
  - Automatically benchmarks the signed-in player's standing (or guest user via quick callsign benchmark input) directly against the realm's top killers: current rank, total kills, solo kills, kill delta relative to #1 apex leader, and Warcraft Logs percentile standing.
  - Highlights the operative's row with an illuminated gold border and `[YOU]` badge in the rankings table, or appends a pinned benchmark standing row if outside the top 15.
- **Intel Tactical Sidebar 24-Hour Telemetry Overhaul**:
  - Transitioned combat telemetry cards to high-urgency 24-hour windows:
    - **Deadliest Zones (Last 24 Hours)**: Ranks top 5 active conflict zones by 24h kill count.
    - **Top Active Gankers (Last 24 Hours)**: Displays top 5 assassins with class badge, specialization, guild, and kill count.
    - **Top Active Guilds (Last 24 Hours)**: Displays top 5 guilds with faction coloring and kill volume.
    - **Top Classes & Specializations (Lifetime)**: Real-time class breakdown and talent specialization distributions (Arms Warrior, Subtlety Rogue, Marksmanship Hunter, Frost Mage, etc.).
- **Lifetime Combat Activity Card**:
  - Renamed 7-day activity card to **Lifetime Combat Activity**, reporting all-time realm kills, Alliance kills, Horde kills, active characters, and active guilds.
  - Removed deprecated active conflict zones row from the activity card.
- **Redundant Sidebar Player Armory Card Purge**:
  - Completely purged the sidebar Player Armory card to eliminate redundancy with the primary Armory navigation tab and character dossier modals, streamlining the tactical sidebar column.
- **Landing Portal Card Rebalancing & Side Alignment**:
  - Aligned `.dramatic-gate-grid` max-width (`1060px`) to match `.portal-hero.dramatic-hero`, ensuring left and right containers are inline with each other on the sides.
  - Rebalanced landing page cards: moved Create Free Account registration form into the left card alongside a clean Guest Pass entry button, eliminating vertical emptiness and balancing height with the Sign In card.
  - Aligned both cards to the top with responsive, matched flex layout.
- **Operational Specification Modal Header & Section Alignment**:
  - Replaced buzzword header with tactical title: `WAR ROOM OPERATIONAL SPECIFICATION` / `REAL-TIME COMBAT TRACKING • ZERO TAINT • AUTOMATED DESKTOP COURIER • OPEN-WORLD BOUNTIES`.
  - Enforced top-alignment across all 3 tier cards (`.dossier-tier-card`), with standardized header height (`min-height: 72px`) so feature lists start at the exact same horizontal baseline, and pinned action buttons to the bottom (`margin-top: auto`).
  - Centered download box info and action buttons (`.dossier-download-box`, `.dossier-dl-actions`).
- **Intel Combat Feed Victor Faction Accent & 15-Row View More Pagination**:
  - Replaced kill mode left-border accent with dynamic Victor Faction colors: Alliance Blue (`#3b82f6`) vs. Horde Red (`#dc2626`).
  - Preserved unique mode badge tag colors (`1V1 SOLO`, `GANG X...`, `ARENA`, `1V1 DUEL`, `BG`, `WORLD`).
  - Implemented 15-row display limit with dynamic "View More Combat Records" button to keep feed responsive and prevent vertical overload.
  - Streamlined right-meta column width (`130px`) and harmonized right sidebar text sizes.
- **Hall of Legends: Player vs. Guild Toggle, WoWLogs Parse Colors, & BG Gladiators Removal**:
  - Added direct toggle: `[ Player Ranks | Guild Ranks ]` next to combat mode filter pills.
  - Cleaned subtitle by removing raw mode string concatenation (`[${currentMode}]`).
  - Completely purged unwanted Battleground Gladiators (damage & healing telemetry) section from Hall of Legends.
  - Moved Percentile column to the last position in the Player table.
  - Implemented authentic Warcraft Logs parse color tiers: Gold (`100`), Pink (`99`), Legendary Orange (`95-98`), Epic Purple (`75-94`), Rare Blue (`50-74`), Uncommon Green (`25-49`), and Common Grey (`<25`).
- **Clean Text-Only Navigation & Authentic WoW Version Accent System**:
  - Completely stripped all box backdrops, borders, and box shadows from `.nav-btn` and `.theater-btn` across the primary navigation rail.
  - Replaced box styling with clean, readable muted slate typography (`#94a3b8`), hover highlights, and an authentic bottom underline (`border-bottom: 2px solid var(--active-flavor-color)`) for the active tab.
  - Dynamically styled the active theater version label (`#theater-nav-version` and `.theater-caret`) with the authentic client color: Cyan (`#00e5ff`) for WoW Forever Beta, Gold (`#eab308`) for Classic Era, Amber (`#d97706`) for Anniversary, and Purple (`#a855f7`) for Retail.
- **Theater Campaign Card Button Overflow Fix**:
  - Resolved text spillover on the WoW Forever version card by removing inherited `white-space: nowrap` from `.nav-btn` and applying responsive flex wrapping with clean inline button constraints.
- **Intel Live Feed Routing & Stale Portal DOM Resolution**:
  - Fixed issue where clicking Intel displayed the War Room sign-in portal instead of live combat feeds by updating `loadKills()` to evaluate `currentTab === "FEED" || currentTab === "INTEL"`.
  - Added immediate feed rendering and loading state initialization upon entering `INTEL` tab, completely purging stale portal cards.
- **Live Recon Wire Tab Gating & Empty State Handling**:
  - Strictly gated `#intel-sighting-wire` to display only on the `INTEL` tab when live sightings are active.
  - Automatically hides the recon wire when no live sighting data is reported or when switching to non-Intel tabs (`THEATER`, `LEGENDS`, `ARMORY`, `BOUNTIES`, `WARROOM`).
- **Distraction-Free Landing Page (Pure Sign-In / Entry Portal)**:
  - Ensured initial site load (`DOMContentLoaded`) unconditionally defaults to the War Room Sign-In & Entry Portal (`PORTAL`).
  - Enforced strict suppression of the header top menu, search bar, footer, and floating controls via `body.portal-active` so visitors encounter a focused, dramatic entry portal with zero header distractions.
  - Visitors choose between "Continue as Guest" or "Sign In / Create Account", with direct routing to active combat intelligence (`INTEL`).
- **Dedicated Theater of War Campaign Selector (`THEATER`)**:
  - Decoupled `PORTAL` (landing sign-in gateway) and `THEATER` (in-app version selection page) into distinct architectural routes.
  - Clicking `Theater: WoW Forever ▾` in the top navigation keeps the header intact and renders the 4-card campaign selector grid:
    1. **WoW Forever**: Active & selectable (`[ ACTIVE THEATER ]`, Level 60 Cap) with immediate entrance button.
    2. **Classic Era**: Offline (`[ TBD • IN DEVELOPMENT ]`, Level 60 Cap).
    3. **Anniversary Edition**: Offline (`[ TBD • IN DEVELOPMENT ]`, Level 60 Cap).
    4. **Modern Retail**: Offline (`[ TBD • IN DEVELOPMENT ]`, Level 80 Cap).
  - Selecting WoW Forever automatically updates the primary navigation button to `Theater: WoW Forever ▾` and transitions to the live combat feed.
- **Complete Cheesy Emoji & Icon Purge**:
  - Systematically stripped all emoji icons (`🌐`, `📡`, `🏆`, `☠️`, `🛡️`, `🩸`, `⚔️`, `🚨`, `🏰`, `⚡`, `👤`, `🎯`, `💰`, `⏳`, `📈`, `🚩`) across the navigation rail, mobile drawer, section headers, badges, alerts, and tables in `index.html` and `app.js`.
  - Replaced decorative emblems with precision SVG vector assets (crossed swords, search glass, and tactical shields) and clean military typography.
- **Percentile Standing Column in Hall of Legends**:
  - Integrated `Percentile Standing` cohort ranking column into the **Hall of Legends** table.
  - Enriched `get_leaderboard()` in `web/server.py` to query class, spec, and level for all top killers and compute cohort percentiles (`compute_character_percentile`).
  - Rendered `Top X% (Yth Pct)` badges on all ranked combatants with full tooltip telemetry (`Level 60 Marksmanship Hunter (X in cohort)`).
- **Warroom Loading Resolution & Zero-Taint Hardening**:
  - Eliminated `ReferenceError: escapeHtml is not defined` causing "Failed to load Warroom" by defining a global `escapeHtml()` utility in `app.js`.
  - Validated `/api/feuds` and `/api/kos/blacklist` endpoints with robust defensive JSON parsing.
- **Top Header Search Removal**:
  - Completely purged the redundant `<div class="search-wrap">` from the top header navigation, centering search on the specialized Player Armory directory and mobile search drawer.
- **Zero Creator PII in Web Application**:
  - Completely purged all author real names from web interface scripts, templates, and comments.

## [1.4.8] - 2026-09-25

### Added
- **Class, Spec & Level Cohort Percentile Engine**:
  - Implemented mathematical cohort percentile ranking evaluating player combat effectiveness against all combatants sharing the exact same `(class, spec, level)` combination on the realm.
  - Calculated exact percentile rankings (`percentile`, `topPct`, `rank`, `totalInCohort`, and `cohortLabel`) with dual-factor scoring (Total Kills primary, K/D ratio tie-breaker).
  - Enriched `GET /api/character/<name>` and `GET /api/armory` to return cohort standing and percentile metrics on all character records.
- **Cross-Client Addon Specialization Detection (`U.GetPlayerSpec`)**:
  - Implemented dynamic runtime feature detection in `Addon/WoWKillboard/Utils.lua` supporting talent-point inspection (`GetTalentTabInfo`) on Classic Era / WoW Forever Beta and modern API (`GetSpecializationInfo`) on Retail.
  - Updated `Killmail.lua` to persist `killer.spec` and `victim.spec` within in-game SavedVariables.
- **Database Schema Expansion**:
  - Added `killer_spec` and `victim_spec` columns to `kills` table with automatic database migration.
  - Added default and valid talent spec resolution mapping across all 13 World of Warcraft classes.
- **Percentile Badges & UI Integration**:
  - **Personalized Operative Banner**: Displays green tactical badge `⭐ Top X% (Yth Pct) • Level 60 [Spec] [Class]` alongside Classic Military Rank and Standing (`Rank #X of Y`).
  - **Character Dossier Modal**: Header features prominent percentile banner showing exact standing within cohort.
  - **Armory Directory Cards**: Inlines class specialization and percentile badges across all character cards.
  - Added `.operative-percentile-pill` and `.armory-percentile-pill` styles to `style.css`.

## [1.4.7] - 2026-09-25

### Changed
- **Full Field Manual & Codex Persona Alignment (Classic Azeroth Scribe)**:
  - Completely overhauled the public `INFO` tab (`loadInfoView`) to embody the **Classic Azeroth Scribe** voice—dark, rugged, utilitarian, and grounded in the post-Third War Vanilla WoW (2004–2006) aesthetic.
  - Purged internal developer guardrails (*"The 5 Non-Negotiable Engineering Guardrails"* and *"Technology Stack"*) from the public web interface.
  - Inscribed **The Four Pillars of the Field Ledger**:
    1. *Silent Fieldcraft (Zero Interface Hesitation)*: Passive combat observation with zero gameplay obstruction.
    2. *The Camp Courier (Automated Dispatch)*: Hands-off dispatch runner (`WoWKillboardSync.exe`) carrying combat logs to High Command.
    3. *The Seal of Indelible Truth (Duplicate Resolution)*: Cross-referencing conflicting battlefield accounts into one certified record.
    4. *Blood Retribution & Iron Escrow*: Grim retaliation against open-world ambushers and the Traitor's Gibbet.
- **Synchronized Subpage Architecture & Navigation**:
  - Re-anchored the initial tab directly as **📜 Field Manual & Codex** (eliminating the disconnected *"Codex & Chronicles"* label).
  - Aligned all seven subpages with authentic Azerothian naming: *Field Manual & Codex*, *Rules of Engagement*, *Soldier's Handbook (FAQ)*, *Fog of War & OpSec*, *War Room Patronage*, *The Chronicler's Looking Glass (OBS)*, and *The Accord of Azeroth*.
  - Synchronized the site footer navigation links in `index.html` to mirror the revised subpages 1-to-1.
- **Doctrine Card Layout (`style.css`)**:
  - Added `.doctrine-grid` and `.doctrine-card` tactical styling with gold leaf borders (`border-left: 3px solid var(--wow-gold)`) and dark parchment backgrounds (`rgba(10, 14, 22, 0.7)`).

## [1.4.6] - 2026-09-25

### Changed
- **Plain-Language User Experience & Persona Alignment**:
  - Purged all internal engineering jargon and developer guardrail technobabble ("Zero Blizzard UI Taint", "32-Bit FNV-1a Determinism", "Pure Lua Discipline", "Automated Courier") from the user-facing Addon Guide modal (`#addon-dossier-modal`).
  - Replaced technical specs with straightforward, player-friendly descriptions: *Lightweight Combat Tracker*, *Automated Windows Sync App*, *Accurate Battle Merging*, and *Bounties on Gankers & Gibbet Board*.
- **Explicit `[ In Development ]` Badging for Roadmap Perks**:
  - Styled a prominent amber pill badge (`.in-dev-pill`) and tagged all upcoming roadmap features: *Beta Tester Access*, *Priority Feature Voting*, *StreamBox Broadcaster HUD*, *Live Subzone GPS*, *Discord SOS Defense*, *Gilded Benefactor Insignia*, *Extended Cold Case Vault*, and *Cross-Client Support* (expanding beyond Forever Beta to Classic Era, Anniversary, and Modern Retail).
- **Blizzard Add-on Policy & Community Supporter (Optional Donations)**:
  - Completely eliminated the word "Paid" across all user interface cards and modal tiers, replacing it with **Community Supporter (Optional Donations // Funds Server Hosting)**.
  - Clarified that in-game gold bounties are a 100% free in-game feature for all players with the addon, not a locked web perk.
  - Added formal Fair Play & Blizzard Add-on Policy notice emphasizing that the addon and all in-game mechanics are free with zero gameplay advantages, and donations strictly support web hosting and companion tools.
- **Typography & Flexbox Layout Refinement**:
  - Refined `.tier-text`, `.tier-bullet`, and `.in-dev-pill` CSS properties (`font-size: 0.74rem`, `line-height: 1.45`, `text-align: left`) to guarantee natural inline flow and eliminate awkward word breaks or column splits.
  - Wired interactive handler `handleSupporterClick()` providing polite, direct confirmation and local testing preview.

## [1.4.5] - 2026-09-25

### Added
- **Dual-State Personalized vs Cumulative Homepage Stats**:
  - **Signed In Operative Banner**: Top of homepage renders a personalized operative combat strip featuring character name, military rank tag (`calculate_pvp_rank_title`), faction allegiance, class, active combatant status, and 4 personalized metrics: *Your Confirmed Kills*, *Your Casualties (Deaths)*, *Your K/D Ratio*, and *Your Solo Kills (1v1)*, accompanied by a direct 1-click link to their full Armory profile.
  - **Frontier Cumulative War Telemetry**: Displayed beneath the personalized operative strip for signed-in members, and prominently as the primary header for guests, reporting *Realm Total Carnage*, *1v1 Solo Kill Ratio*, *Faction War Split*, and *Active Combat Filter*.
  - **Guest Recon Mode Strip**: Unmarked guests receive full cumulative realm telemetry alongside a subtle call-to-action strip inviting them to authenticate for personal kill/death tracking.
- **Enriched Cumulative Stats & Character Profile Fallbacks**:
  - Updated `GET /api/stats` to aggregate and return `total`, `world`, `bg`, `arena`, `duel`, `solo`, `alliance`, `horde`, `active_bounties`, `bounty_gold`, and `top_zone` from SQLite (`bounties.amount_gold`).
  - Updated `GET /api/character/<name>` with a graceful fallback returning a valid 200 OK profile (`WARRIOR`, level 60, 0 kills, 0 deaths, 0.0 K/D) for newly registered accounts, ensuring zero blank states or 404 errors.

### Changed
- **Direct WoW Forever Portal Routing (Zero Version Distractions)**:
  - Eliminated the Screen 2 version picker per user directive to focus exclusively on WoW Forever (`FOREVER`).
  - Selecting either "Continue as Guest" or authenticating via username/password or Google SSO immediately routes the operative straight to the WoW Forever homepage with their stats loaded at the top.
  - Locked top header flavor tabs and mobile drawer exclusively to **WoW Forever** (`LIVE FRONTIER`, Level 60 Max).
- **3-Tier Access Matrix (Guest, Free Member, Paid Supporter) & ToS Guarantee**:
  - Implemented 3-column comparative matrix contrasting **Tier 1 (Guest Recon)**, **Tier 2 (Free Registered Member)**, and **Tier 3 (Paid High Command Supporter)**.
  - Added formal **Blizzard Addon Policy & ToS Compliance Guarantee** certifying that the addon and all in-game combat mechanisms remain 100% free and open, with supporter perks strictly confined to off-game web platform hosting, StreamBox OBS overlays, beta tester access, and cosmetic badges.
  - Added **Beta Tester Access (Early Addon & Web Builds)** and **War Council Priority Feature Voting** to the supporter tier.
  - Fixed flexbox typography wrapping bug on tier list items by nesting bullet icons and inline text in `.tier-item`, eliminating artificial whitespace gaps and awkward column splitting.
  - Redesigned download action buttons with matching 40px height, tactical borders, SVG vector icons, and unified typography.

## [1.4.4] - 2026-09-25

### Changed
- **Standard Account Authentication & Google SSO**:
  - Replaced the roleplay "Character Call-Sign" and "Faction Allegiance" fields on the portal muster gate with standard modern account authentication.
  - Implemented tabbed Sign-In / Create Account form with Username, Email, Password, "Remember me" checkbox, and "Forgot password" recovery link.
  - Added clean "Sign in with Google" SSO button featuring the official 4-color SVG "G" logo.
  - Authenticated operatives now see a verified account profile card with 1-click homepage entry and an explicit "Sign Out / Switch Account" control.
- **Unified Direct Naming — The War Archivist & Addon Guide**:
  - Christened the AI combat oracle **The War Archivist** (*Live Azeroth Combat Telemetry & Historical Codex*) across all interface buttons, header tools, mobile drawers, modal consoles, and the backend Python system prompt (`SCRIBE_SYSTEM_PROMPT`).
  - Replaced ambiguous "Field Kit & Addon Blueprints" terminology with direct, player-friendly naming: **"How the Addon Works & Download"** (hero masthead and modal) and **"Addon Guide"** (floating action trigger and header).
  - Streamlined the hero masthead actions by removing the redundant "Inquire with War Scribe" button, focusing attention on a single primary action: `[ How the Addon Works & Download ]`.
- **Responsive Mobile Popouts & Tactical Bottom Sheet**:
  - Resolved the modal container hierarchy issue caused by an unclosed `<footer>` tag in `index.html`.
  - Configured `#addon-dossier-modal` (Addon Guide) to render as a responsive, centered dialog on mobile with stacked 1-column pillars and touch-friendly download targets (`95vw`, `92dvh`).
  - Configured `#oracle-chat-modal` (The War Archivist) to deploy as a dedicated, full-screen tactical intelligence sheet on mobile viewports (`100vw`, `100dvh`, `z-index: 2800`), featuring safe-area inset padding and a sticky top navigation bar for immediate one-tap dismissal.
- **Balanced Tactical Typography & Form Proportions**:
  - Added explicit typography definitions for `.portal-title` (`1.85rem` desktop / `1.45rem` mobile), `.portal-tagline`, and `.portal-lead` to eliminate awkward browser defaults.
  - Standardized all form inputs to uniform `42px` height, `0.88rem` font size, crisp `#26334d` borders, and burnished gold focus states.

## [1.4.3] - 2026-09-25

### Changed
- **Direct Sign-In Flow to War Room Homepage**:
  - Eliminated the mandatory "Garrison / Realm" input field across the portal gate and authentication state, natively accommodating WoW Forever Beta and modern clients that operate without traditional realm sharding.
  - Linked the Sign-In button and quick sign-in actions directly to the War Room homepage (`portalLaunchFront(currentFlavor)` / `FEED`), immediately authenticating and routing inscribed operatives to the live combat feed.
  - Provided direct 1-click fallback links on both Guest and Officer cards for instantaneous homepage deployment.
- **Horizontal Faction Crest Hero Alignment**:
  - Enforced strict CSS `flex-direction: row !important;` and `display: flex !important;` on `.portal-crest-row` across mobile, tablet, and desktop viewports, ensuring the Alliance shield, crossed war swords, and Horde shield render in an unbroken horizontal row.
- **Elimination of Purple Buttons & Cartoon Emojis**:
  - Purged all purple buttons, glow effects, and accents (`#a855f7`, `#c084fc`, `#7e22ce`) across the portal triggers, header pills, and War Scribe / Oracle AI chat modals, re-skinning all controls in dark iron (`#090c14`), burnished gold (`#d4a329`), and weathered brass (`#735934`).
  - Replaced cartoon emojis (`📜`, `🔮`, `👑`, `👁️`, `🦁`, `🐺`, `📦`) with clean, diegetic SVG vector symbols and austere military typography badges, strictly aligning with the **Classic Azeroth Scribe** aesthetic.

## [1.4.2] - 2026-09-25

### Added
- **Dramatic 2-Screen Portal Gateway Flow**:
  - **Screen 1 — The Muster Gate (`GATE`)**: Simplified into two solemn, weathered iron choices: **Unmarked Reconnaissance (Continue as Guest)** and **Inscribe the Muster Roll (Officer Sign-In)**. Selecting either path commits the soldier's clearance and transitions immediately to Screen 2.
  - **Screen 2 — The Theaters of Conflict (`VERSIONS`)**: Presents the 6 war fronts (Classic Era, 20th Anniversary, Forever Beta, TBC, WotLK, Modern Retail). Clicking any war front immediately deploys the soldier's console directly into the live frontline combat feed for that campaign. Includes a `[ ← Retreat to Muster Gate ]` navigation button to alter clearance at will.
- **Universal Pop-Out Addon Field Kit Dossier Modal (`#addon-dossier-modal`)**:
  - Added an omnipresent **"📜 Field Kit"** trigger button accessible across all pages (desktop header tools, mobile navigation drawer, portal masthead, and persistent floating bottom-left badge).
  - Opens a dark scorched-iron and brass modal laying out the 4 martial pillars (Pure Lua zero-taint logging, background sync courier, 32-bit FNV-1a cryptographic certification, and blood bounties) with direct package downloads.
- **AI War Scribe & Combat Oracle Module (`/api/oracle/chat` & `#oracle-chat-modal`)**:
  - Deployed an in-character AI combat intelligence console accessible via a floating bottom-right trigger (`[ 🔮 Ask the War Scribe ]`), desktop header tools, and mobile drawer.
  - Connects to SQLite database (`combat.db`) to provide real-time intelligence on active bounties, dangerous zones, player dossiers, deadly NPC casualties, and addon mechanics.
  - Supports Google Gemini API generative synthesis (`gemini-2.5-flash`) when provided with an API key, while maintaining a robust diegetic heuristic engine for 100% offline accuracy.
  - Adheres strictly to the **Classic Azeroth Scribe** voice: grounded, utilitarian, diegetic, and austere with zero modern SaaS or tech jargon.

## [1.4.1] - 2026-09-25

### Changed
- **Portal First-Page Header Stack Suppression**:
  - Hides the entire 3-row desktop and mobile header stack (`.site-header`, `#wowhead-top-bar`, `.header-top-row`, `.header-sub-row`, `#mobile-menu-btn`, `#mobile-flavor-badge`) whenever `body.portal-active` is set (`display: none !important;`).
  - Converts the main landing page into a clean, cinematic, distraction-free Warcraft portal gateway where visitors are not overwhelmed by navigation tabs, filters, or expansion bars before selecting how to enter.
  - The complete 3-row header stack seamlessly re-engages the moment the user launches into the War Room, calibrated to their selected client version and authorization level.
  - Added a prominent **"🏰 War Room Portal"** tab to the navigation rail, mobile drawer, and header logo for 1-click return to the gateway anytime.

### Added
- **Streamlined 4-Step Portal Gateway Flow**:
  - **Step 1 — War Room Clearance Level**: Interactive toggle cards allowing visitors to choose between **Option A (Continue as Guest / Public Recon)** and **Option B (Officer / Vanguard Sign-In)**.
    - Guest Mode displays instantaneous read-only clearance confirmation.
    - Officer Mode displays character call-sign, realm server, and allegiance faction inputs (or active authenticated operative profile with 1-click sign out/switch).
  - **Step 2 — World of Warcraft Version Selection**: Interactive 6-card grid with live selection state for **Classic Era (60)**, **20th Anniversary Edition (60)**, **WoW Forever Beta (60)**, **The Burning Crusade (70)**, **Wrath of the Lich King (80)**, and **Modern Retail (80)**.
  - **Step 3 — Dynamic Tactical Launch Bar**: High-prominence, glowing CTA bar that continuously mirrors the user's Step 1 and Step 2 selections (e.g. `[ ⚔️ Launch War Room — Classic Era (Guest Recon) → ]` or `[ 👑 Sign In & Launch War Room — 20th Anniversary Edition → ]`), validating credentials and launching into the War Room with smooth scroll-to-top.
  - **Step 4 — Addon Architecture & Downloads**: The 4 architectural pillars (Passive Combat Logging, Zero-Python Sync, 32-Bit FNV-1a Deduplication, Blood Bounties & KOS Tracking) and direct package downloads.
  - **Hero Return Gateway**: Added `[ ⚔️ Return to Active Frontline Feed → ]` quick button in the hero masthead for returning users who already have an active session.

## [1.4.0] - 2026-09-25

### Added
- **Azeroth War Room Entry Portal (First Page Gateway)**:
  - **First-Visit Gateway Experience**: Configured the platform so all new visits and fresh sessions land immediately on the immersive **War Room Portal**, providing full context before entering the frontline combat feed.
  - **Interactive 6-Flavor WoW Version Selector**:
    - Featured rich selection cards for **Classic Era (60)**, **20th Anniversary Edition (60)**, **WoW Forever Beta (60)**, **The Burning Crusade (70)**, **Wrath of the Lich King (80)**, and **Modern Retail (80)**.
    - Displays active level caps, expansion summary descriptions, and instant engine calibration with glowing gold/cyan selection indicators.
  - **Dual-Path Access Level (Guest vs. Officer Login)**:
    - **Continue as Guest (Field Operative)**: Instant one-click entry to live frontline combat telemetry, death feeds, Most Wanted execution contracts, and player armory with zero sign-up.
    - **Officer / Vanguard Sign-In**: Enables combatants to register their character call-sign, server realm, and allegiance faction (Alliance / Horde), automatically unlocking Vanguard Supporter status, personal combat synchronization, and bounty placement authority.
  - **Comprehensive Addon Architecture & Explanation**:
    - **Pillar 1 — Passive Combat Log Capture**: Pure Lua (`BackdropTemplate`, anonymous widgets), listening to `COMBAT_LOG_EVENT_UNFILTERED` with spatial GPS coordinates (`C_Map`) and 15-second sliding gang clustering. Zero Blizzard UI taint.
    - **Pillar 2 — Zero-Python Desktop Auto-Sync**: Standalone `WoWKillboardSync.exe` with automated multi-drive auto-discovery across `C:`, `D:`, and `E:` drives.
    - **Pillar 3 — 32-Bit FNV-1a Cryptographic Deduplication**: Guarantees distributed deduplication when 40 raid members log the same battle.
    - **Pillar 4 — Blood Bounties & KOS Tracking**: In-game gold contracts with server-wide KOS branding for defaulted debtors across name changes and guild transfers.
    - **One-Click Download Center**: Direct download links for `WoWKillboard-v1.0.0.zip` and `WoWKillboardSync.exe`.
  - **Sleek Portal Navigation & Full-Width Layout**:
    - Added dedicated **"🏰 War Room Portal"** buttons to the desktop navigation rail, the mobile drawer directory, and the site header crest logo.
    - Introduced `.container.portal-mode` full-width layout, cleanly hiding sidebar widgets, stats grid, and feed cards during portal viewing.

## [1.3.2] - 2026-09-25

### Fixed
- **Mobile Flex-Basis Vertical Void Root Cause**:
  - Diagnosed and resolved the root cause of the 400px+ tall empty killmail cards on mobile screens ($\le 768\text{px}$). When `.killmail-row` switched to `flex-direction: column`, the desktop rules `flex: 0 0 200px` on `.km-left-meta` and `.km-right-meta` caused the browser to assign 200px of vertical height to both metadata bars, leaving two ~180px empty black voids inside each card.
  - Enforced `flex: 0 0 auto !important; height: auto !important; width: 100% !important;` on both meta containers within mobile media queries, shrinking mobile killmail cards from 460px down to ~88px (an 81% reduction in card height).
- **CSS Cascade Specificity Override Bug**:
  - Re-ordered stylesheet architecture so the desktop `.wowhead-top-bar` declarations precede all responsive media queries, ensuring `@media (max-width: 768px)` rules reliably override desktop properties without cascade collision.

### Changed
- **Mobile Header Optimization & Height Reduction**:
  - Eliminated the awkward side-scrolling Wowhead expansion bar on mobile phones (`display: none !important;`), delegating expansion selection entirely to the native slide-in mobile navigation drawer.
  - Removed desktop-only visual noise on mobile: hidden the 4-line subtitle, the redundant desktop nav links rail, the live recon pill, and the desktop supporter button from the mobile header bar.
  - Added a compact, tactile active expansion indicator badge (`#mobile-flavor-badge`, e.g. `ERA 60` or `WOTLK 80`) next to the hamburger button, opening the drawer upon tap.
  - Reduced total mobile header height from ~151px down to 44px, reclaiming 107px of immediate viewport space.
- **Most Wanted Horizontal Touch-Snap Carousel on Mobile**:
  - Converted the vertical 5-row Most Wanted grid on mobile into a sleek, horizontal touch-snap carousel (`scroll-snap-type: x mandatory`).
  - Reduced Most Wanted vertical consumption from 825px down to 155px, allowing users to swipe through all 10 bounties without obscuring the frontline kill feed.
- **Compact Mobile Realm Stats Grid**:
  - Tightened the 2&times;2 Realm Stats grid with refined padding (6px 10px) and proportional typography, conserving an additional 60px of vertical space.

## [1.3.1] - 2026-09-25

### Added
- **10-Slot Most Wanted Execution Grid (5 Per Row &times; 2 Rows)**:
  - Engineered compact bounty cards with real class icon emblems, character names in class colors, guild/faction labels, gold rewards, and quick-accept tracking buttons.
  - Implemented 10-slot layout guaranteeing 2 rows of 5 cards across desktop and tablet viewports.
  - Added styled placeholder cards (`.wanted-card.blank`) for unfilled bounty slots with interactive click-to-bounty routing (`+ Issue Bounty`).
- **Mathematical Symmetrical Centering for PvP Killmail Feed Rows**:
  - Bound `.km-left-meta` and `.km-right-meta` to identical fixed widths (`175px`), positioning the midpoint of `.km-combatants-center` at the 50.0% centerline of each card row.
  - Configured symmetrical combatant clashing: Killer (Name, Level, Class Icon) aligned right towards `⚔️`, and Victim (Class Icon, Name, Level) aligned left away from `⚔️`.
  - Positioned guild affiliations centered directly underneath player names.
- **Realm War Recon KPI Telemetry Clarification**:
  - Replaced misleading server-wide duel win/loss text (`0W-0L`) with authentic **Faction War Carnage Split** (e.g., `A: 54% | H: 46%`) color-coded in Alliance Blue and Horde Red.
  - Clarified KPI card headers as server-wide combat reconnaissance (`Realm Total Carnage`, `1v1 Solo Kill Ratio`, `Faction War Split`, `Active Combat Filter`).
- **Compact Layout & Sleek Scrollbar Refinements**:
  - Tightened card padding across stats grid, Most Wanted container, and sidebar widgets to eliminate vertical bloat and prevent excessive page scroll.
  - Refined custom scrollbar track and thumb to modern 6px transparent/amber styling.

## [1.3.0] - 2026-09-25

### Added
- **Wowhead-Style Global Expansion Top Header Navigation Bar**:
  - Full-Width Global Strip: Positioned `.wowhead-top-bar` as the top-most header element above the War Room title row, creating an authentic Warcraft database feel mirroring Wowhead.
  - Expansion Circular Badges (`.wh-w-badge`):
    - `RETAIL`: Dragon Gold (`#f59e0b`)
    - `FOREVER`: WoW Forever Beta Cyan (`#00e5ff`)
    - `CLASSIC`: Classic Era & 20th Anniversary Bronze/Yellow (`#eab308`)
    - `TBC`: The Burning Crusade Fel Green (`#22c55e`)
    - `WOTLK`: Wrath of the Lich King Frost Blue (`#38bdf8`)
  - Dynamic Tab Active States & Glow Effects: Active button highlights with lower glowing border accent (`--active-tab-color`), home icon shortcut (`🏠`), and `WOW` brand label.
  - Live Active Engine Status: Real-time telemetry badge (`ACTIVE ENGINE: CLASSIC (60 MAX)`) with pulsing green heartbeat indicator.
  - Full Mobile & Touch Parity: Horizontal scroll navigation rail on mobile screens (`overflow-x: auto`) and synchronized dual-column flavor pills in the slide-in mobile drawer (`#mobile-drawer`).
  - Strict Rule Enforcement: Zero Blizzard UI taint, zero documentation drift, and complete cross-client parity across all 4 WoW client flavors.

## [1.2.0] - 2026-09-25

### Added
- **Most Deadly NPC Leaderboard & PvE Casualty Isolation**:
  - Addon Engine PvE Death Tracking: Initialized dedicated `WoWKillboardDB.pveDeaths` storage, completely separated from `WoWKillboardDB.kills` to guarantee zero PvP stat skew.
  - Slew-by-NPC Combat Logic: In [`CombatTracker.lua`](file:///c:/Users/SQUICK/WoW_Killboard/Addon/WoWKillboard/CombatTracker.lua), mapped incoming damage to track `isSourcePlayer` boolean. If a player dies with zero player attackers, the event is routed exclusively to `KM:RecordPveDeath` with `UNIT_DIED` and `PLAYER_DEAD` fallback protection.
  - Telemetry Capture: Parses NPC creature ID from GUID (`Creature-0-...-(id)-...`), monster name, signature ability, total damage, victim identity, and map GPS coordinates.
  - Dedicated Web UI Tab **"☠️ Deadly NPCs"**:
    - Hero Metrics Header: Displays total fallen mortals, unique monster slayers, and deadliest realm conflict zone.
    - Top Executioner Monsters & Elites Leaderboard: Ranked by confirmed player kills (featuring iconic executioners such as Hogger, Son of Arugal, Stitches, Mor'Ladim, and Devilsaur).
    - Top Fallen Mortals Graveyard: Displays players with the highest casualty counts against realm creatures.
    - Live Fallen Mortals Stream: Real-time feed of player PvE executions.
  - Strict PvP Isolation Guarantee: PvE casualties never enter `kills` database, never affect player K/D ratios, never award PvP honor ranks, and never trigger death bounty prompts.
- **Client Flavor Identification & Dynamic Feature Gating**:
  - Multi-Expansion Client Flavor System: Engineered runtime flavor detection in [`Utils.lua`](file:///c:/Users/SQUICK/WoW_Killboard/Addon/WoWKillboard/Utils.lua) (`GetClientFlavor`) and backend endpoints (`GET /api/system/flavor`, `POST /api/system/flavor`) supporting:
    1. `CLASSIC_ERA` (Vanilla 1.15 / Anniversary / Forever Beta)
    2. `TBC` (The Burning Crusade 2.4.3)
    3. `WOTLK` (Wrath of the Lich King 3.3.5)
    4. `RETAIL` (Dragonflight / War Within 11.x)
  - Interactive Command Bar Switcher: Embedded styled dropdown in header tools group allowing instant flavor switching with persistent local storage.
  - Dynamic Player Armory Class Gating: Classes not present in the active flavor (e.g. Death Knight in Classic/TBC, Monk/Demon Hunter/Evoker in Classic/TBC/WotLK) remain visible in the dropdown but are disabled, styled grey, and tagged with expansion lock markers (e.g. `[🔒 Death Knight (WotLK 3.0+)]`).
  - Dynamic Combat Mode Gating: Unavailable modes (e.g. Arenas in Classic Era) are greyed out with tooltip guidance.
  - Desktop Ingestion Watcher (`sync/watcher.py`): Updated to parse `pveDeaths` and recompiled to standalone `WoWKillboardSync.exe`.

## [1.1.0] - 2026-09-25

### Added
- **Recent Kills Centered Player vs. Player Layout**:
  - Reverted feed display mode toggle to prioritize pure player-vs-player combat engagements across all realms.
  - Centered combatant pairing horizontally on the feed line: Killer column on the left, central `⚔️` clash divider, and Victim column on the right.
  - Positioned guild affiliations (`<Guild Name>`) centered directly beneath each player's character name in subtle gold/brass font with direct links to guild war dossiers.
  - Positioned encounter theater telemetry (`Zone` and `Subzone / GPS Coordinates`) on the left meta column, and relative combat timestamp and mode tags (`1v1 SOLO`, `1v1 DUEL`, `GANG xN`, `BG`, `ARENA`) on the right meta column.
  - Fully responsive on mobile devices with automated stacked cards and zero horizontal scroll overflow.
- **Battle Report Dossier with Specialization Icons & Assault Force Telemetry**:
  - Downloaded and locally hosted official Blizzard specialization icon assets for all 36 specs (`web/static/icons/specs/*.jpg`).
  - Engineered combat log specialization inference engine (`inferSpec`) mapping signature spells (e.g. Mortal Strike, Pyroblast, Bloodthirst, Penance) to deterministic specs across Classic Era, Anniversary, Forever Beta, and Retail.
  - Upgraded Battle Report modal (`openKillModal`) to display complete Assault Force telemetry:
    - Killer & Victim encounter showcase with large class emblems and specialization badges.
    - Certified 1v1 Solo Triumph banner (`⭐ CERTIFIED 1v1 SOLO TRIUMPH`) for unassisted victories.
    - Participating party members / attackers list with class icon, spec badge, signature abilities, damage done, percentage contribution bar, and killing blow tag (`★ FINAL BLOW`).
- **Blood Debtor (Debt Welcher) Automated KOS Blacklist System**:
  - Rebranded Oathbreaker debt ledger to **"Blood Debtor Ledger"** (with **"Debt Welcher"** stigma).
  - Engineered automatic consignment to the **Realm KOS Blacklist** (`kos_blacklist`) for any player in default on a bounty debt (`POST /api/bounties/debt-ledger`).
  - Added automatic KOS cleansing upon debt redemption (`POST /api/debt/pay`), restoring reputation to `HONORABLE COMBATANT`.
  - Implemented permanent anti-evasion tracking across character name changes and guild hopping using immutable `Player-GUID`.
  - Displayed prominent reputation badges in Character Profiles (`BLOOD DEBTOR — KILL ON SIGHT` vs `HONORABLE COMBATANT — DEBTS SETTLED`).

## [1.0.0] - 2026-09-24

### Added
- **Recent Kills Player vs. Guild Display Toggle & Gritty Dark War Aesthetic**:
  - Engineered 1-click **`[ 👤 Players | 🛡️ Guilds ]`** toggle on the Recent Kills feed header with local persistence (`localStorage: wow_killboard_feed_display_mode`).
  - In **Guilds Mode**, hides individual player names completely to focus purely on Guild War clashes (`<Killer Guild> ⚔️ <Victim Guild>`) with faction crests and colors, with unguilded combatants displayed cleanly in muted text.
  - In **Players Mode**, preserves streamlined combatant focus (`[Class Icon] Killer (60) ⚔️ [Class Icon] Victim (60)`) with guild affiliation.
  - Pulled in official World of Warcraft raster assets locally (`web/static/icons/classes/` and `web/static/icons/factions/`) covering all 13 playable classes and Alliance/Horde PvP crests, with automatic fallback to vector SVGs.
  - Crafted an immersive, dark, gritty Warcraft War Room background (`web/static/images/dark_war_bg.jpg`) capturing torchlit iron-bolted dungeon walls, chains, battle-worn Alliance & Horde banners, and a war planning table under atmospheric radial vignette shading.
- **Streamlined Minimal Combat Feed & Authentic Warcraft UI Styling**:
  - Implemented a clean "less is more" recent kills feed: hid noisy text badges (`[SOLO]`, `[GANG]`, `[WORLD]`, `[DUEL]`) from the default row, eliminating visual clutter.
  - Added sleek 3.5px left-edge indicator bars color-coded by combat mode (Emerald for Solo, Amber for Gang, Gold for Duel, Cyan for BG, Purple for Arena).
  - Integrated authentic World of Warcraft class icon badges (20x20px bordered tiles with crisp class emblem vectors) for all 13 classes beside killer and victim names.
  - Added Blizzard metallic gold typography (`.wow-gold-header`) with subtle text gradients and chiselled shadows for branding, titles, and combat log headers.
  - Upgraded cards with Blizzard antique brass borders (`--wow-brass-border: #423522`), dark iron plate backgrounds, and deep inner bevel shadows.
  - Replaced generic emoji with authentic circular metallic World of Warcraft coins (Gold, Silver, Copper) for blood bounties and debt ledgers.
- **Dark Warcraft Tactical War Room & Mobile/Tablet Responsive Overhaul**:
  - Implemented high-fidelity Dark Warcraft Tactical War Room aesthetic inspired by zKillboard and dark military fantasy, featuring atmospheric radial illumination (Alliance Blue & Horde Crimson), ambient tactical grid, and glassmorphic card elements (`backdrop-filter: blur(16px)`).
  - Integrated Google Fonts: `'Cinzel'` for regal war room titles, `'Rajdhani'` for combat meters and tactical telemetry, and `'Inter'` for high-legibility feed logs.
  - Re-engineered header into a clean dual-row command bridge: top row with 3D crest glow, live recon radar indicator, search, and supporter button; sub-row with smooth-swiping horizontal navigation rail (`#nav-rail`) and 5-state filter pills (`#mode-filter-pills`).
  - Added slide-out Mobile Navigation Drawer (`#mobile-drawer`) with backdrop blur, accessible hamburger trigger (`#mobile-menu-btn`), mobile search input, full view switcher, and $\ge 44\text{px}$ touch targets.
  - Implemented comprehensive media queries supporting Desktop Ultra-Wide (>1400px), Standard Desktop (1024px-1280px), Tablet Portrait/Landscape (768px-1024px), and Mobile Phones (320px-768px) with zero horizontal overflow, fluid clamp typography, and stacked combatant layouts.

- **Eradicated Taint Log Warning Popup**: Removed developer diagnostic `SetCVar("taintLog", "2")` from `Core.lua` and added automatic cleanup resetting `taintLog` back to `"0"`, eliminating Blizzard's *"You have the Taint Log enabled. This causes significant increase in loading times"* warning prompt on login and UI reload.

### Added
- **Native Realm Player Armory & Classic Military Honor Rank Titles**:
  - Implemented authoritative realm-wide combat directory API (`GET /api/armory`) supporting dynamic search, faction filtering (All, Alliance, Horde), class filtering (all 13 classes), and sorting (Most Lethal, Highest K/D, Solo Specialists, Level, Recently Active).
  - Engineered `calculate_pvp_rank_title` calculating authentic World of Warcraft Classic PvP Military Honor Ranks (Scout through High Warlord for the Horde; Private through Grand Marshal for the Alliance) dynamically from combat kills and K/D performance.
  - Added dedicated top navigation tab **"🏰 Player Armory"** (`#nav-armory` -> `switchTab('ARMORY')`).
  - Built responsive Player Armory Directory frontend view in `web/static/app.js` and `web/static/style.css` featuring glassmorphic character cards, class color accents, honor rank badges, KOS/Deserter/Bounty status tags, and instant dossier inspection.
  - Upgraded sidebar intelligence module into native **"🏰 Player Armory"** quick search and character lookup with fallback external mirrors (Official Blizzard Armory, Ironforge.pro, Warcraft Logs).
  - Added in-game slash commands `/armory [Name]` and `/killboard armory [Name]` in `Addon/WoWKillboard/Core.lua` reporting character class, level, honor rank, K/D, solo triumphs, KOS blacklist status, and active blood bounties directly to in-game chat.
  - Added comprehensive automated unit test `test_11_player_armory_directory` in `tests/test_pipeline.py`.
- **Head-to-Head Blood Feuds & Custom Rules of Engagement (ROE)**:
  - Added `blood_feuds` database schema and real-time kill scoring engine in `web/server.py`.
  - Supports both Guild Wars and 1v1 Grudge Matches with custom kill goals (e.g. first to 100 kills) and 30-day contest windows.
  - Strict Rules of Engagement (ROE) logic built directly into combat ingestion:
    - **Anti-Lowbie Filter**: Kills against victims below minimum level (e.g. Level 55+) award 0 points.
    - **Underdog Multiplier**: Solo combatants triumphing over outnumbered enemy squads (1v2, 1v3) earn 2x points.
    - **Anti-Zerg Filter**: Cheap zerg ganks (3+ attackers on a solo victim) award 0 points.
    - **Zone Restrictions**: Contests can be confined to specific combat theaters (e.g. Stranglethorn Vale).
  - Web UI tab **"⚔️ Blood Feuds & Blacklist"** (`#nav-feuds`) renders interactive progress bars, active ROE badges, victor announcements, and feud challenge modal (`/api/feuds/challenge`, `/api/feuds`).
- **Zero-Gold Wagers & Realm KOS Blacklist**:
  - High-stakes honor consequences with zero gold custody: Defeated guilds and rogue gankers are permanently branded onto the **Realm KOS Blacklist** (`kos_blacklist`, `/api/kos/blacklist`).
  - Manual KOS branding and war council pardons supported via `/api/kos/blacklist` and `/api/kos/pardon`.
- **30-Day Anti-Guild-Hop Deserter Stain**:
  - Implemented `kos_deserters` database engine stamping all roster members of a blacklisted/defeated guild with a 30-day penance stain bound to immutable character `Player-GUID`.
  - Leaving or `/gquit`ing a blacklisted guild preserves the stain for the full 30 days (`expires_at = now + 30*86400`).
  - In-game air-raid sirens (`PlaySound(8959)`) and dedicated alert dialog (`UI:ShowKOSAlert`) trigger whenever a marked deserter or blacklisted guild member enters targeting or mouseover range.
  - Web UI displays active deserter countdown cards with remaining days (`⏳ X Days Remaining`).
- **Tactical Intel & Gank Sighting Wire**:
  - Implemented `Addon/WoWKillboard/IntelScanner.lua` providing in-game recon commands (`/spot [notes]`, `/scout [notes]`, `/kb spot`, `/kb scout`).
  - Instantly captures enemy name, class, level, guild, faction, and spatial GPS coordinates (`C_Map`).
  - Broadcasts sightings across Guild chat (`/g`), Party/Raid (`/p`, `/ra`), and P2P addon message wire (`SPT:` protocol via `Sync.lua`).
  - Backend ingestion (`POST /api/intel/sighting`, `GET /api/intel/sightings`) with strict Open-World PvP gating and automated Discord Webhook rich embed broadcast.
  - Live Tactical Intel Sighting Wire (`#intel-sighting-wire`) displayed above the frontline feed with 6-second polling updates.
- **Complete Decoupling from Forged By Valor**:
  - 100% eradication of all references to *Forged By Valor*, *FBV*, and *501(c)(3)* across all codebase files, TOC files, manifests, documentation, tests, and web UI.
  - Updated client-side localStorage keys from `fbv_supporter` to `wowkb_supporter`.

- **Dark Warcraft War Room Lore & Open-World PvP Gating**:
  - **Frontline War Room Theming**: Eradicated generic modern terms in favor of gritty, war-torn Alliance vs. Horde Warcraft lore across Addon, Web, and Discord notifications.
  - **War Horn: Call to Arms**: Rebranded backup calls into sounding the War Horn (`/warhorn`, `/kbwarhorn`, `/kbrally`, `[ 📯 WAR HORN ]`). Auto-invite keyword `"rally"` drafts reinforcements into the vanguard.
  - **High Command Execution List**: Rebranded outlaw board into High Command kill contracts with open-world final-blow execution requirements.
  - **The Traitor's Gibbet**: Condemned debtors to the public gibbet as branded traitors with proximity alerts.
  - **Scout's Spyglass / War Correspondent HUD**: Introduced `/war-hud/<character_name>` streaming HUD while maintaining `/streambox/<character_name>` backwards-compatible alias.
  - **Strict Open-World PvP Gating**: Enforced `IsInInstance()` checks across `BountyEngine.lua`, `CombatTracker.lua`, `Reinforcements.lua`, and `UI.lua`. Bounties and War Horn calls can strictly only occur in the open world, never inside instances, raids, battlegrounds, or arenas. Backend APIs reject instance submissions with HTTP 400.
- **Call for Backup (SOS Distress Beacon) & Open Auto-Invite Party Engine**:
  - Implemented `Reinforcements.lua` providing 1-click tactical distress beacons via header button (`[ 🚨 CALL BACKUP ]`) and slash commands (`/killboard backup`, `/kbsos`, `/kbbackup`).
  - Gathers real-time spatial GPS coordinates, active hostile attackers, class, and threat count from `CombatTracker.lua`.
  - Broadcasts emergency signals across Guild Chat (`/g`), Party/Raid (`/p`, `/ra`), local Defense/Yell, and peer-to-peer Addon messages (`Sync.lua`).
  - Activates a 10-minute Open Auto-Invite listener: players whispering `"backup"`, `"invite"`, `"inv"`, or `"sos"` are immediately invited to the party/raid (`EnsureRaidConversion`).
  - Implemented 100% taint-free Reinforcement Alert dialog (`UI:ShowReinforcementAlert`) for nearby guildmates and allies with 1-click `"⚔️ Join Squad & Assist"` and ESC key handling.
- **Discord Defense Gateway & Guild Event Announcement Engine**:
  - Built zero-dependency Discord Webhook dispatcher in `web/server.py` supporting rich embeds for emergency Call for Backup beacons and Guild Operations.
  - Added Guild Events & Tactical Rallies subsystem (`/api/events`, `/kb event <Title> | <Zone> | <Time>`) allowing guild leaders to coordinate defense operations and publish announcements straight to Discord.
  - Added dedicated Web **"🛡️ Guild Defense & Events"** tab (`#nav-defense`) with live SOS beacon monitoring, interactive event scheduling, and Discord Webhook setup.
  - Added high-priority pulsing emergency banner (`#global-sos-banner`) pinned to the top of the live kill feed when a guildmate is under fire.
- **In-Game Death Bounty Prompt & Combat Lockdown Gating**:
  - Implemented automated death prompt frame in `UI.lua` triggered on PvP demise (`PLAYER_DEAD`) asking `"[Killer] has killed you. Would you like to place a bounty?"` with gold amount input and 1-click submission.
  - Strict Guardrail 1 compliance via `InCombatLockdown()` gating with deferred delivery via `PLAYER_REGEN_ENABLED` buffer.
- **Anti-Name Change Evasion Engine via Character GUID**:
  - Bound all bounty contracts and debt ledger entries to permanent, immutable character `targetGUID` (`Player-XXXX-XXXXXXXX`).
  - Added automated reconciliation in ingestion pipeline: renaming a character via the Blizzard shop preserves active contracts and debt history under the new name.
- **Contract Acceptance & Killing Blow Exclusivity**:
  - Added contract tracking workflow (`BE:AcceptBounty`, `/api/bounties/accept`) requiring hunters to accept bounties before hunting.
  - Enforced killing blow exclusivity: only the certified killing blow hunter who accepted the contract collects the reward; non-addon players cannot claim.
- **Cold Cases Archival (>30 Days)**:
  - Added automated cold case transition for bounties unclaimed after 30 days (`COLD_CASE` status) in both addon ledger and web backend (`GET /api/bounties/archive`).
- **Static FBI Most Wanted Web Showcase & Outlaw Gallery**:
  - Implemented horizontal Top 10 Most Wanted outlaw gallery with class avatars, gold reward badges, faction crests, and last seen zone telemetry.
  - Made showcase permanently static on the main feed view, completely removing collapse toggle traps and client-side localStorage state traps.
  - Added 1-click contract acceptance (`🎯 Accept Contract` / `✓ Tracking Contract`).
- **StreamBox Native OBS Overlay (`/streambox/<character_name>`)**:
  - Added dedicated transparent streamer HUD endpoint formatted for Open Broadcaster Software (OBS Studio) and Twitch/YouTube livestreams.
  - Supports horizontal ticker and vertical tower layouts (`?vertical=1`) with live combat event polling every 5 seconds.
  - Class-color coded combatants, faction crests, and live-updating kill/death feeds.
- **zKillboard-Style Information Hub & Footer Integration**:
  - Implemented comprehensive docs and intelligence hub (`openInfoPage()`) accessible via top navigation (`Docs & Intel`) and the new global footer.
  - 7 standard informational sections mirroring zKillboard: Features, FAQ, About, Delayed Intel, Supporter/Payments, StreamBox Generator, and Legal/Fair Play policies.
  - Interactive StreamBox URL generator with copy-to-clipboard functionality.
- **zKillboard Sidebar Intelligence Overhaul**:
  - Added 7-day rolling activity box (`/api/stats/activity-7d`) tracking active characters, active guilds, total kills, Alliance vs Horde breakdown, and active zones.
  - Added Top Characters (7D), Top Guilds (7D), Top Classes (7D), and Hotspot Zones (7D) ranking cards alongside direct Armory and intelligence links.
- **Bounty Hall of Fame Records & Ingestion Auto-Claim Engine**:
  - Built 4-category Hall of Fame grid (`GET /api/bounties/leaderboards`): Top Bounty Hunters (by claims and gold earned), Highest Bounty Contracts, Most Elusive Outlaws (longest outstanding), and Fastest Collected Manhunts.
  - Automated auto-claim pipeline inside `/api/kills`: Slain targets with active bounties automatically transition contract status to `CLAIMED` and attribute rewards to the executing hunter.
- **Supporter Subzone Recon Gating & 100% Ad-Free Experience**:
  - Eliminated all commercial third-party ad containers and placeholders, guaranteeing a 100% ad-free, player-supported web experience.
  - Introduced Frontline Vanguard Community Supporter card to fund realm infrastructure and cloud compute.
  - Tiered vicinity telemetry: Public view displays confirmed combat Zone (`Last Sighted: Stranglethorn Vale ~14m ago`), with exact Subzone landmark (`Booty Bay`) unlocked for community supporters.
  - In-game `/kb` bounty contract rows updated to show `Last Sighted: <Zone> (~<mins>m ago)`.
- **Guild War Tracking & Historical Guild Ledger**:
  - In-game guild affiliation tracking via `GetGuildInfo(unit)` indexed into leaderboards with `Leaderboard:GetTopGuilds(mode, limit)` and rendered in the in-game dashboard.
  - Dedicated `character_guild_history` database ledger tracking character guild transfers, memberships, and tenure timestamps (`first_seen`, `last_seen`).
  - Web Guild War Leaderboards (`/api/guilds`) ranking guilds by total kills, deaths, K/D ratio, active combatant count, and top killer.
  - Guild Intelligence Dossier modal (`GET /api/guild/<guild_name>`) displaying active guild roster, aggregate stats, and recent guild kills.
- **Interactive Character Combat Profile & Armory Integration**:
  - Full player dossier modal (`GET /api/character/<character_name>`) featuring lifetime kills, deaths, K/D, solo kills, duel records, damage/healing telemetry, and guild history timeline.
  - Direct 1-click external Armory link integration:
    - ⚔️ Official Blizzard Armory (`worldofwarcraft.blizzard.com`)
    - 🛡️ Classic Vanilla Armory (`ironforge.pro`)
    - 📜 Warcraft Logs (`classic.warcraftlogs.com`)
  - Everywhere-clickable player and guild entities across live kill feed, sidebar rankings, leaderboard tables, and killmail modals.
- **Automated Multi-Client Deployment Engine (`scripts/deploy.py`)**:
  - Automated deployment script synchronizing the addon to all 4 target client flavors (`_classic_beta_`, `_classic_era_`, `_anniversary_`, `_retail_`) and rebuilding the distribution zip package (`WoWKillboard-v1.0.0.zip`).
- **1v1 Duel Match Engine**:
  - Full detection for duel challenges, forfeits ("fled"), and knockouts via `CHAT_MSG_SYSTEM` hooks.
  - Dedicated Duel Record tracking (`wins`, `losses`, `win %`) stored in `WoWKillboardDB.stats.duels`.
  - Independent `DUEL` filter context across in-game UI, sync engine, and web platform.
  - Certified 1v1 duel killmail classification (`isDuel = true`) distinct from world PvP.
- **Battleground Scoreboard & Match Telemetry**:
  - Event listeners for `UPDATE_BATTLEFIELD_SCORE`, `PVP_MATCH_COMPLETE`, and `UPDATE_BATTLEFIELD_STATUS`.
  - Automated tracking of Battleground Wins, Losses, and Win % stored in `WoWKillboardDB.stats.bgs`.
  - Real-time aggregation of player and lobby damage done, healing done, and objective score metrics.
- **Tactical 3-Card KPI Header**:
  - Redesigned in-game stat header into three wide, balanced telemetry cards (268px width each):
    1. `SESSION COMBAT K/D` (Cyan `#00e5ff`) — Active session kills, deaths, and K/D ratio.
    2. `1v1 DUELS RECORD` (Gold `#ffd700`) — Duel wins, losses, and win percentage.
    3. `BATTLEGROUNDS RECORD` (Blue `#00ccff`) — Battleground wins, losses, and win percentage.
- **Standalone Desktop Sync Binary (`WoWKillboardSync.exe`)**:
  - PyInstaller-compiled standalone 8.8 MB Windows executable.
  - Zero Python installation requirement for end users.
  - Multi-Drive Auto-Discovery scanning `C:`, `D:`, and `E:` drives for WoW installations across Retail, Classic, Classic Era, and Forever Beta.
- **Hotspot Conflict Zones & Bloodshed Rankings**:
  - Dedicated `Zone Intel` tab analyzing top casualty zones, localized choke points, and dangerous regions.
  - Added `Leaderboard:GetDeadliestZones(limit)` and `Leaderboard:GetTopZones(mode, limit)`.
- **Bounty Escrow & Oathbreaker Debt Ledger**:
  - Full player bounty placement system with anti-win-trade verification (level deltas, guild collusion protection, duplicate kill cooldowns).
  - "Wall of Shame" Debt Ledger branding players who default on bounty promises as **Oathbreakers**.
  - Proximity Wanted Debtor Radar triggering audio sirens and screen notifications when a debtor is nearby.
  - 1-click in-game redemption workflow via C.O.D. mail with a 10% administrative surcharge.
- **Legal, Safety & Compliance Framework**:
  - Formal declaration of sole authorship and copyright: Scott Quick.
  - Published comprehensive compliance audit in `docs/LEGAL_AND_COMPLIANCE.md`.
  - Formally certified 100% compliance with Blizzard Entertainment's UI Customization Policy (zero in-game ads, free distribution, open source, no RMT).
  - Enforced zero-PII privacy standards (no collection of Real IDs, IPs, emails, or credentials) and zero-Warden-risk filesystem architecture.
- **Dual Theme Architecture (Classic WoW UI & ElvUI Minimalist)**:
  - **Classic WoW Theme**: Replicates the iconic Blizzard stone dialog frames, gold/brass trim (`Interface\DialogFrame\UI-DialogBox-Border`), warm parchment cards, and golden typography while maintaining 100% template-free Lua taint isolation.
  - **ElvUI Minimalist Theme**: Ultra-clean 1px razor borders (`Interface\Buttons\WHITE8X8`), pitch dark obsidian backdrop (`0.06, 0.07, 0.10`), and high-contrast cyan/white typography.
  - **Instant In-UI Theme Switcher**: Dedicated `[Theme: Classic]` / `[Theme: ElvUI]` header button allows seamless 1-click theme toggling in real time without reloading the game.
  - **Slash Command Support**: Added `/killboard theme [classic|elvui]` for instant CLI theme switching.
  - **Persistent Settings**: Theme selection automatically saved to `WoWKillboardSettings.theme`.

### Changed
- **In-Game Navigation & Filter Bar Overlap Elimination**:
  - Calibrated explicit widths for the 5 left navigation tabs: `Live Feed` (95px), `Leaderboards` (105px), `Bounties & Debt` (110px), `BG Gladiators` (100px), `Zone Intel` (88px) — Total 510px.
  - Re-proportioned the 4 right filter pills: `Duels` (54px), `BGs` (50px), `World` (56px), `All PvP` (62px) — Total 234px.
  - Created an **88px guaranteed clear margin** between `Zone Intel` and `Duels`, permanently eliminating button and text collisions across all screen resolutions and UI scales.
- **Excised Arena Context for Vanilla / Forever Parity**:
  - Removed rated Arena stat card and filter pill from the in-game dashboard to conform strictly with WoW Forever / Classic Vanilla design boundaries.
  - Updated killmail detail modal and feed formatters to focus on Duels, Battlegrounds, and Open World PvP.
- **Modern Dark Gunmetal Aesthetic**:
  - Standardized all frames on 1px razor borders (`Interface\Buttons\WHITE8X8`), dark slate backgrounds (`0.06, 0.07, 0.10, 0.97`), and custom class color hex palettes.

### Fixed
- **Bounty Hall of Fame & Tab Switch Rendering Failure**:
  - Implemented missing `formatDuration` telemetry helper in `web/static/app.js` which caused an unhandled `ReferenceError` preventing the Bounty Hall of Fame and Debt Ledger view from rendering when switching tabs.
  - Added visual loading state and error rendering directly within `#main-content-area` during tab navigation.
- **Top Ad Banner Removal for True 100% Ad-Free Experience**:
  - Excised the remaining programmatic 728x90 ad container from `web/static/index.html` and `web/static/style.css` in strict adherence to the executive zero-ad mandate.
- **Blizzard UI Taint & Action Blocked Eradication**:
  - Completely eradicated Blizzard XML template dependencies (`UIPanelCloseButton`, `UIPanelButtonTemplate`, `BasicFrameTemplateWithInset`) across all frames.
  - Replaced Blizzard `UISpecialFrames` registration with custom ESC key down handlers (`SetPropagateKeyboardInput(false)` on modal hide), preventing secure button taint during combat lockdown.
  - Added strict `InCombatLockdown()` gating to frame dragging, sizing, and dialog creation.
- **Runtime Nil Method Error (`GetDeadliestZones`)**:
  - Fixed `UI.lua:747: attempt to call a nil value` by defining `LB:GetDeadliestZones(limit)` in `Leaderboard.lua` with multi-tier fallback checks in `UI.lua`.
- **Button Texture Clearing C++ Engine Binding Exception (`SetNormalTexture`)**:
  - Fixed `UI.lua:114: bad argument #1 to 'SetNormalTexture' (Usage: self:SetNormalTexture(asset))` caused by passing `nil` to WoW's C++ texture setter when switching to or loading the ElvUI theme.
  - Replaced illegal `SetNormalTexture(nil)` calls with safe texture clearing and hiding via `GetNormalTexture():SetTexture(nil)` and `GetNormalTexture():Hide()`.
- **Killmail Detail Modal Click Interception & Dismiss Button Fix**:
  - Elevated modal frame strata to `DIALOG` and frame level to `mainFrame:GetFrameLevel() + 50`, with explicit `EnableMouse(true)` and `SetClampedToScreen(true)`.
  - Assigned `DIALOG` strata and `modal:GetFrameLevel() + 10` to the bottom `Dismiss` button and top-right `[X]` button, completely preventing background scroll rows from intercepting or swallowing clicks.
  - Expanded modal dimensions from 480x320 to 520x360 with dedicated header spacing, eliminating visual overlap between the title and combatant dossier cards.
  - Intercepted `ESCAPE` key listeners so pressing ESC dismisses the active detail modal before closing the main dashboard.
- **Authentic Neutral ElvUI Palette Calibration**:
  - Overhauled ElvUI theme colors from navy blue/cyan (`0.06, 0.07, 0.10`) to true ElvUI matte charcoal/jet black (`0.05, 0.05, 0.05, 0.98`), 1px solid black razor outlines (`0.0, 0.0, 0.0, 1.0`), and signature ElvUI gold accents (`#ffd100`).
  - Eradicated out-of-place neon cyan elements across feed tags, leaderboard rankings, and filter pills.
- **Classic WoW Theme Polish & Texture Assets**:
  - Replaced missing Unicode glyph `✕` (which rendered as a broken empty box `[]` in WoW font tables) with authentic Blizzard round red jewel minimize buttons (`Interface\Buttons\UI-Panel-MinimizeButton-Up`) in Classic and crisp ASCII `|cffff3333X|r` in ElvUI.
  - Calibrated Battleground badges (`[BG x%d]`) and metrics to Blizzard soft blue (`#69ccf0`) and warm gold (`#ffd100`) across all modes.
- **Scoreboard Type Comparison Exception**:
  - Fixed `CombatTracker.lua: attempt to compare number with string` by wrapping `GetBattlefieldWinner()` comparisons in type-safe casts `(tonumber(winner) == pFactionIndex) or (tostring(winner) == tostring(pFaction))`.
- **Cross-Client Combat Log Unification**:
  - Resolved `COMBAT_LOG_EVENT_UNFILTERED` payload incompatibility between modern 11.x client engines (payload-based arguments) and Classic 1.15.x engines (`CombatLogGetCurrentEventInfo()`).

---

## [0.9.0] - 2026-09-23

### Added
- **Temporal Hostile Gang Clustering Algorithm**:
  - Sliding 15-second combat log clustering to accurately reconstruct gang engagements vs certified solo kills.
- **Unit & Nameplate Scraping Engine (`UnitScanner.lua`)**:
  - Non-invasive caching of target, mouseover, and nameplate data (level, class, race, faction, guild name).
- **Cryptographic Killmail Hashing (`Utils.lua`)**:
  - 32-bit FNV-1a hashing producing deterministic, tamper-resistant Kill IDs based on timestamp, killer GUID, victim GUID, and location.
- **P2P Addon Synchronization (`Sync.lua`)**:
  - P2P gossip protocol distributing killmails and bounties across `PARTY`, `RAID`, and `GUILD` addon communication channels via `C_ChatInfo`.

### Changed
- Refactored `CombatTracker.lua` to record damage and healing meters independently for all participants in a combat engagement.

---

## [0.5.0] - 2026-09-22

### Added
- **zKillboard-Style Web Platform (`web/server.py`)**:
  - Lightweight Flask REST API with SQLite database persistence.
  - Endpoints for live kills, killmail dossiers, leaderboard rankings, battleground metrics, and bounty queries.
- **Tactical Dark Web Dashboard (`web/static/`)**:
  - Live kill ticker, faction badges, class colors, interactive killmail modal, and filter switches.
  - Integrated high-CPM gaming ad placement containers (NitroPay / Playwire responsive units).
- **SavedVariables Tokenizer & Parser (`sync/watcher.py`)**:
  - Recursive-descent parser capable of streaming parsing WoW `SavedVariables/WoWKillboard.lua` files.

---

## [0.1.0] - 2026-09-20

### Added
- Initial proof-of-concept addon hooking combat log events.
- Basic kill tracking and saved variables persistence.
