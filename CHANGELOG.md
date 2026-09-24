# Changelog

All notable changes to the **WoW Killboard** project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2026-09-24

### Added
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
  - Introduced non-profit **Forged By Valor (501(c)(3))** Community Supporter card to fund realm infrastructure and veteran mental health gaming programs.
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
  - Formal declaration of sole authorship and copyright: Scott Quick / Forged By Valor, 501(c)(3).
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
