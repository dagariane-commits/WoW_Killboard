# System Architecture Specification

## 1. Architectural Overview

Because World of Warcraft addons operate in a strictly isolated Lua 5.1 sandbox without raw socket access or outbound HTTP capabilities, the **WoW Killboard** system implements an asynchronous three-tier decoupled pipeline:

```mermaid
flowchart TD
    subgraph Tier1 ["Tier 1: In-Game Addon (Lua 5.1 Sandbox)"]
        CL["Combat Log Events\n(COMBAT_LOG_EVENT_UNFILTERED, CHAT_MSG)"] --> CT["Combat Tracker Engine\n(Gang Clustering, Metering)"]
        US["Proximity Unit Scanner\n(Target / Mouseover / Nameplate)"] --> CT
        GPS["C_Map Telemetry\n(Normalized X, Y, MapID)"] --> CT
        CT --> KM["Killmail Engine\n(FNV-1a Hash Generator)"]
        KM --> DB[("SavedVariables\nWoWKillboardDB.lua")]
        KM --> P2P["P2P Gossip Network\n(C_ChatInfo Addon Channels)"]
        KM --> UI["Tactical Dashboard\n(Pure Lua, 100% Taint-Free)"]
    end

    subgraph Tier2 ["Tier 2: Desktop Ingestion Agent (Python / PyInstaller EXE)"]
        DB --> FW["Multi-Drive File Watcher\n(C:, D:, E: Auto-Scan)"]
        FW --> LP["Streaming Lua Tokenizer\n& Recursive Descent Parser"]
        LP --> HTTP["HTTPS REST Client\n(Batched Ingestion)"]
    end

    subgraph Tier3 ["Tier 3: Intelligence Platform (Flask REST API + SQLite)"]
        HTTP --> EP["Ingestion Endpoint\n(/api/sync/push)"]
        EP --> SQL[("Relational Database\nSQLite (killboard.db)")]
        SQL --> REST["Public REST API\n(/api/kills, /api/leaderboard)"]
        REST --> WEB["Tactical Dark Web Interface\n(Live Ticker, Dossiers, Supporter Perks)"]
    end
```

---

## 2. Tier Breakdown & Component Specifications

### Tier 1: In-Game Addon (`Addon/WoWKillboard/`)

The in-game addon is a modular Lua package designed to run without third-party libraries (e.g., Ace3) to minimize memory overhead and eliminate vulnerability vectors.

| Module | Purpose | Key Blizzard APIs Utilized |
| :--- | :--- | :--- |
| **`Core.lua`** | Initialization, slash commands (`/kb`), event orchestrator | `ADDON_LOADED`, `PLAYER_LOGIN`, `SLASH_*` |
| **`Config.lua`** | Addon defaults, faction color constants, sound alert IDs | N/A (Static Configuration Table) |
| **`Utils.lua`** | FNV-1a hashing, number/gold formatters, GPS coordinate resolution | `C_Map.GetBestMapForUnit`, `C_Map.GetPlayerMapPosition` |
| **`UnitScanner.lua`** | Proximity level, class, race, and guild cache | `UnitLevel`, `UnitClass`, `UnitRace`, `UnitFactionGroup`, `GetGuildInfo` |
| **`CombatTracker.lua`**| Real-time combat logging, hostile gang clustering, meter aggregation | `COMBAT_LOG_EVENT_UNFILTERED`, `CHAT_MSG_SYSTEM`, `UPDATE_BATTLEFIELD_SCORE` |
| **`Killmail.lua`** | Standardized telemetry generation, chat broadcast, sound triggers | `PlaySound`, `SendChatMessage`, SavedVariables persistence |
| **`BountyEngine.lua`** | Blood bounties, execution contracts, open-world gating (`IsInInstance()`), anti-win-trade, debtor sirens | `GetMoney`, `SendMail`, proximity nameplate hooks |
| **`Leaderboard.lua`** | In-memory aggregation engine supporting `ALL`, `WORLD`, `BG`, and `DUEL` | Internal Aggregation Tables |
| **`Sync.lua`** | Open-world and cross-player peer-to-peer gossip protocol over realm channel (hidden `WoWKillboard`), party, raid, and guild | `C_ChatInfo.SendAddonMessage`, `SendChatMessage`, `CHAT_MSG_ADDON`, `CHAT_MSG_ADDON_LOGGED`, `CHAT_MSG_CHANNEL` |
| **`Reinforcements.lua`** | War Horn: Call to Arms (open-world emergency distress), Vanguard Rallies coordination, open auto-invite engine (`rally`/`war`/`backup`), guild alerts | `C_PartyInfo.InviteUnit`, `InviteUnit`, `ConvertToRaid`, `SendChatMessage` |
| **`UI.lua`** | Dual-theme dashboard (Classic Stone & Gold vs ElvUI Charcoal/Black) with 5 tabs (`Intel`/`Casualties`, `Defender of Azeroth`/`Deadly Hazards`, `The Marked`/`Notorious Elites`, `Manhunt`/`Rescue Beacons`, `Zone Intel`/`Zone Mortality`), 4 filter pills, campaign ruleset toggle (`PvE` vs `PvP`), strata-isolated Detail Modal, and Section 5 Database Management (`[Reset Local Database]`) | `CreateFrame("Frame", nil, UIParent, "BackdropTemplate")` |

#### Data Integrity & Cryptographic Hashing
To prevent duplicate records from inflating rankings when multiple group members record the same engagement, each kill is assigned a deterministic 32-bit FNV-1a hash:

$$\text{KillID} = \text{FNV-1a}\left( \text{Timestamp} \parallel \text{KillerGUID} \parallel \text{VictimGUID} \parallel \text{MapID} \parallel \text{CoordX} \parallel \text{CoordY} \right)$$

This hash acts as the primary key across the addon's internal database, the P2P network, and the remote web database.

#### In-Memory History Self-Healing & Stress Profiling
- **`KB:SanitizeKillHistory()`**: Runs during `KB:Initialize()` on UI load/reload to sanitize in-memory records, auto-pruning victim self-insertion from historical kills and restoring healer assists.
- **`/kb stress [N]`**: Injects up to 250 validated synthetic kills into memory in 1 frame, measuring execution duration (`debugprofilestop`) and heap memory delta (`collectgarbage`).

---

### Tier 2: Ingestion & Telemetry Pipeline (`sync/` & Web Uploader)

WoW flushes its Lua `SavedVariables` cache to disk when the player reloads the UI (`/reload`), logs out, or exits the game. WoW Killboard supports two parallel, idempotent ingestion pathways:

1. **Option A: Desktop Ingestion Agent (`WoWKillboardSync.exe`)**:
   - Automated Multi-Drive Discovery: Scans `C:`, `D:`, and `E:` for active WoW client roots (`_classic_beta_`, `_classic_era_`, `_anniversary_`, `_retail_`).
   - Two-Way Realm Intel Synchronization: In addition to streaming local combat records to cloud endpoints (`https://wowkillboard.com`), automatically pulls the latest 60 confirmed realm kills and active bounties down into `WoWKillboard_RealmData.lua` across all client directories.
   - Cross-Account Parity: Automatically monitors all local account directories (`WTF/Account/*`), aggregating combat telemetry so that secondary accounts and alts instantly share confirmed kills and intel on the same machine.
   - Real-time file system watcher streams updates automatically to both local and cloud endpoints (`https://wowkillboard.com`).
   - Self-contained, zero-Python binary distributed in `dist/WoWKillboardSync.exe` and `WoWKillboardSync.exe`.
2. **Option B: Web Drag-and-Drop Uploader (`/api/upload`)**:
   - Zero-download, browser-native alternative for players who do not want a desktop background process.
   - Accepts raw `WoWKillboard.lua` files or JSON payloads directly via web interface (`/upload`).
   - Pure-Python streaming `LuaTableParser` parses SavedVariables directly on the server.
3. **High-Throughput Lua Tokenizer Benchmarks**:
   - Benchmarked across escalating SavedVariables payloads (100 to 2,500 records), achieving **7,200+ records/second** parsing throughput with zero external dependencies.
4. **Idempotent Out-of-Order Reconciliation**:
   - Because every combat engagement generates an identical 32-bit FNV-1a Kill ID across all combatants, asynchronous uploads at arbitrary times (e.g. Killer at 2 PM, Victim at 11 PM) merge into SQLite via `INSERT OR REPLACE INTO kills` with zero duplication.
5. **Master Administrative Reset**:
   - Provides `POST /api/admin/reset` (secret-gated) and Web Admin Console (`promptAdminAccess()`) to safely wipe all tables (`kills`, `bounties`, `characters`, `character_claims`, etc.) back to zero during administrative maintenance.

---

### Tier 3: Intelligence Platform (`web/`)

A high-performance Flask REST API and responsive dark-mode frontend built with standard web technologies.

1. **SQLite Concurrency & WAL Hardening**:
   - Configured Write-Ahead Logging (`PRAGMA journal_mode=WAL;`), 10-second busy timeout (`PRAGMA busy_timeout=10000;`), and normalized synchronous writes (`PRAGMA synchronous=NORMAL;`).
   - Completely eliminates file write locks under concurrent ingestion bursts, tested up to 168.9 Requests/Second with zero lock contention.
2. **Two-Tier Header Navigation & Dynamic Most Wanted**:
   - Decoupled site header: Tier 1 (Brand, Factions, Theater, Mode Filters, Claim) + Tier 2 (Dedicated Navigation Sub-Rail), eliminating squishing at 150%+ zoom.
   - Dynamic Most Wanted card grid: Displays 1 sleek row of 5 slots when $\le 5$ bounties exist, dynamically expanding to 10 slots.

1. **Relational Schema (`killboard.db`)**:
   - `kills`: Stores raw killmail documents (killer info, victim info, location, timestamps, mode).
   - `attackers`: Normalized relation tracking individual damage contributions and spell names.
   - `bounties`: Active and fulfilled bounty records.
   - `debt_ledger`: The public Oathbreaker registry recording default amounts and days in default.
   - `character_guild_history`: Historical ledger tracking character guild transfers, memberships, factions, and tenure timestamps (`first_seen`, `last_seen`).
2. **Query & Ranking Engine**:
   - Filter modes: `ALL`, `WORLD`, `BG`, `DUEL`.
   - Aggregated telemetry: Top Killers, Top Victims, Deadliest Zones, Battleground Gladiators (Damage vs Healing).
   - Guild War Intelligence (`GET /api/guilds`, `GET /api/guild/<name>`): Guild K/D rankings, member counts, rosters, and recent guild combat records.
   - Character Intelligence & Armory Integration (`GET /api/character/<name>`): Lifetime combat KPI stats, historical guild timeline, recent kills/deaths, and external Armory links (Blizzard Armory, Classic Ironforge.pro, and Warcraft Logs).
3. **Supporter Framework & 100% Ad-Free Architecture**:
   - Zero commercial ad units, banners, or tracking networks.
   - Community-supported infrastructure with voluntary player and guild patron options.
   - Quality-of-life perks: Unlocks exact Subzone Recon Intel on active bounties and supporter visual badges.
4. **Bounty Hall of Fame Engine (`GET /api/bounties/leaderboards`)**:
   - Real-time aggregation of Top Bounty Hunters, Highest Bounty Contracts, Most Elusive Outlaws, and Fastest Collected Manhunts.
   - Ingestion-driven auto-claim pipeline that transitions active bounties on slain targets to claimed status automatically.
5. **War Correspondent HUD OBS Overlay (`GET /war-hud/<name>`)**:
   - Zero-dependency transparent HTML/CSS/JS HUD designed for streaming software (OBS Studio Browser Source, Twitch/YouTube).
   - Dynamic real-time event polling every 5s with class-colored combatants and killer/victim telemetry.
   - Dual layout options: Horizontal bottom-ticker or vertical side-panel (`?vertical=1`).
   - Backwards-compatible alias preserved at `/streambox/<name>`.
6. **Consolidated 56px Sticky Header, Global Omni-Search & Core Combat Views**:
   - Replaced multi-row header deck with a single 56px sticky header (`position: sticky`, `top: 0`, `z-index: 1000`):
     - **Brand & Theater**: Grouped brand crests, title, and active theater badge tightly on the left.
     - **Global Omni-Search (`#global-search-input`)**: Centralized typeahead search bar with `/` keyboard shortcut, instant dropdown (`#search-results-dropdown`), search federation across combatants, guilds, and zones, and keyboard arrow/enter navigation.
     - **Core Combat Views**: Streamlined 5-button nav rail (`Intel`, `Leaderboards`, `Deadly Hazards`, `Bounties & Manhunt`, `Zone Intel`) with dedicated top-level visibility for PvE hazards.
     - **Contextual In-Page Mode Filtering**: Replaced redundant header mode pills with in-page filters (`[ World | BGs | Duels | Arenas ]`) located directly on the combat feed header (`#feed-mode-pills`) and leaderboard (`#champions-mode-pills`).
     - **Action Tools & Gold CTA**: War Archivist AI trigger, Upload utility link, real-time Auth Badge, and primary gold CTA button `[ Download Field Kit ]` linking to `/download`.
     - **32px Telemetry Ribbon**: Replaced heavy stat cards with a compact single-row ribbon, anchoring the live combat feed above the fold with 6–8 rows visible on standard 1080p viewports.
     - **5-Slot Right Sidebar Hierarchy**:
       1. *Lifetime Combat Activity*: Scoped strictly to the active realm tenant.
       2. *The Marked (Active Bounties)*: Condensed vertical ledger with class crests, realm, bounty pot, and `+ Issue Mark` quick trigger.
       3. *Champion Filters*: Faction (All/Alliance/Horde) and Timeframe (24h/7d/All-Time) on Leaderboard view.
       4. *Tabbed 24-Hour Leaderboard Widget*: Instant pill switching between Hot Zones, Top Gankers, and Top Guilds.
       5. *All Classes Combat Matrix*: Compressed 2-column tactical grid.

7. **Global Realm Isolation & Multi-Tenant Boundary (`server.py`, `app.js`)**:
   - Each theater / realm represents an isolated database tenant (e.g., `Classic Beta PvP`, `Classic Beta PvE`, `Classic Beta RP`, `Classic Beta Hardcore`).
   - Every API route and database query enforces strict realm filtering via `normalize_realm_filter` (`LOWER(realm) = LOWER(?)`).
   - Client-side state flushes on switch (`flushAndReloadActiveRealm`): clears combat log cache, known kill IDs, and benchmark cache before reloading, ensuring zero cross-realm data bleed.
   - Blizzard 1-based class ID map (`BLIZZARD_CLASS_IDS`) and `resolveClassName` guarantee accurate class coloring (`#f58cba`) and Paladin crest icon resolution for characters like Dagariane.

8. **Class, Spec & Level Cohort Percentile Engine (`GET /api/character/<name>`, `GET /api/armory`)**:
   - Mathematical cohort ranking computing exact player standing against all combatants sharing the exact same `(class, spec, level)` on the realm.
   - Dual-factor evaluation: Total Kills primary, K/D ratio tie-breaker.
   - Returns `percentile`, `topPct`, `rank`, `totalInCohort`, and `cohortLabel` (e.g., `⭐ Top 5% (95th Pct) • Level 60 Shadow Priest`).
   - Integrated into the Operative Banner, Character Dossier modal, and Armory Directory cards.

8. **Warroom: Head-to-Head Blood Feuds & 30-Day Deserter KOS Blacklist (`/api/feuds`, `/api/kos/blacklist`)**:
   - Guild vs. Guild and 1v1 grudge match challenges with custom target score goals (e.g., First to 100 Kills).
   - Custom Rules of Engagement (ROE): Minimum level filters, 2x Underdog bonuses, anti-zerg scoring, and zone restrictions.
   - 30-day anti-guild-hop penalty tracking by permanent character Player-GUID to prevent evasion.
   - Pinned personal engagements at the top for signed-in operatives.

9. **World Hazards & Deadly PvE NPC Casualty Stream (`/api/pve/deadly-npcs`, `/api/pve/stream`)**:
   - Wilderness environmental deaths, deadly NPC rankings, and complete PvP isolation.
   - Tracks world bosses, elite patrol hazards, and dangerous fauna across Azeroth.

10. **Native Realm Player Armory & Military Honor Rank Titles (`GET /api/armory`, `calculate_pvp_rank_title`)**:
    - High-performance character directory aggregating all realm combatants from `kills`, `character_guild_history`, and `bounties`.
    - Real-time search by character name or guild name with dynamic filters for Faction (Alliance / Horde) and Class (all 13 WoW classes).
    - Multi-mode sorting: Most Lethal (Kills), Highest K/D Ratio, Solo Specialists, Character Level, and Recently Active.
    - Dynamic Classic PvP Military Honor Rank Title calculation: Scout through High Warlord (Horde) and Private through Grand Marshal (Alliance).

11. **War Correspondent HUD OBS Overlay (`GET /war-hud/<name>`)**:
    - Zero-dependency transparent HTML/CSS/JS HUD designed for streaming software (OBS Studio Browser Source, Twitch/YouTube).
    - Dynamic real-time event polling every 5s with class-colored combatants and killer/victim telemetry.
    - Dual layout options: Horizontal bottom-ticker or vertical side-panel (`?vertical=1`).

12. **War Council & Rallies Discord Webhook Gateway (`/api/backup/distress`, `/api/events`, `/api/discord/config`)**:
    - Ingestion of live War Horn distress calls (strictly gated to Open World PvP) and tactical guild event rallies.
    - Zero-dependency Discord embed dispatcher notifying guild channels in real-time with automated party auto-invite instructions.

13. **Grimdark Tactical War Room Design System (`style.css`)**:
    - Deep obsidian base canvas (`#020305`), blackened slate background (`#040609`), and cast iron plate surfaces (`#0c0f16` to `#030407`).
    - Heavy radial vignette overlaying charred battlefield imagery for zero-wash contrast.
    - Symmetrized battle-worn atmospheric faction tints: deep midnight cobalt (`rgba(6, 12, 24, 0.92)`) for Alliance and dried blood-iron (`rgba(22, 6, 8, 0.92)`) for Horde.
    - Weathered dark brass borders (`#241c10`) and heavy 18px-24px inset plate shadows across killmail rows, most wanted cards, sidebar rankings, and modal cards.
