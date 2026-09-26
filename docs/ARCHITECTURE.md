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
| **`Sync.lua`** | Peer-to-peer gossip protocol over party, raid, and guild channels | `C_ChatInfo.SendAddonMessage`, `CHAT_MSG_ADDON` |
| **`Reinforcements.lua`** | War Horn: Call to Arms (open-world emergency distress), open auto-invite engine (`rally`/`war`/`backup`), guild alerts | `C_PartyInfo.InviteUnit`, `InviteUnit`, `ConvertToRaid`, `SendChatMessage` |
| **`UI.lua`** | Dual-theme dashboard (Classic Stone & Gold vs ElvUI Charcoal/Black) with 3 KPI cards, 5 tabs, 4 filter pills, and strata-isolated Detail Modal | `CreateFrame("Frame", nil, UIParent, "BackdropTemplate")` |

#### Data Integrity & Cryptographic Hashing
To prevent duplicate records from inflating rankings when multiple group members record the same engagement, each kill is assigned a deterministic 32-bit FNV-1a hash:

$$\text{KillID} = \text{FNV-1a}\left( \text{Timestamp} \parallel \text{KillerGUID} \parallel \text{VictimGUID} \parallel \text{MapID} \parallel \text{CoordX} \parallel \text{CoordY} \right)$$

This hash acts as the primary key across the addon's internal database, the P2P network, and the remote web database.

---

### Tier 2: Desktop Ingestion Agent (`sync/`)

WoW flushes its Lua `SavedVariables` cache to disk when the player reloads the UI (`/reload`), logs out, or exits the game. The Desktop Ingestion Agent bridges the file system to the web tier.

1. **Auto-Discovery Engine**:
   - Automatically iterates common root paths on `C:\`, `D:\`, and `E:\`:
     - `World of Warcraft\_classic_beta_\WTF\Account\`
     - `World of Warcraft\_classic_era_\WTF\Account\`
     - `World of Warcraft\_anniversary_\WTF\Account\`
     - `World of Warcraft\_retail_\WTF\Account\`
   - Locates all `SavedVariables/WoWKillboard.lua` files dynamically.
2. **Streaming Lua Tokenizer**:
   - Custom lexer/parser parses multi-megabyte Lua table dumps without requiring a native Lua runtime.
   - Evaluates nested dictionaries, string escapes, arrays, booleans, and timestamps.
3. **Standalone Distribution**:
   - Compiled with PyInstaller into a self-contained executable (`WoWKillboardSync.exe`).
   - Requires zero Python environment on the player's gaming rig.

---

### Tier 3: Intelligence Platform (`web/`)

A high-performance Flask REST API and responsive dark-mode frontend built with standard web technologies.

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
6. **Streamlined 7-Item Text-Only Navigation & Authentic WoW Version Accents**:
   - Replaced clunky button-box navigation with a clean, minimalist text navigation rail:
     - All navigation links use muted slate typography (`#94a3b8`) on transparent backgrounds with zero box backdrops or borders.
     - The active tab is elegantly highlighted with a bottom underline (`border-bottom: 2px solid var(--active-flavor-color)`) matching the active WoW version's authentic color accent.
     - **Theater of War**: Displays the active WoW flavor (`Theater: WoW Forever ▾`) with the version name dynamically rendered in that client's signature hue: Cyan (`#00e5ff`) for WoW Forever Beta, Gold (`#eab308`) for Classic Era, Amber (`#d97706`) for Anniversary, and Purple (`#a855f7`) for Retail.
     - **Intel**: Live combat killmail feed, Top 10 High Command Execution List outlaw gallery, and real-time recon wire (strictly gated to Intel tab).
     - **Hall of Legends**: Competitive leaderboard embedding the 5-state combat mode filter pills (`All PvP`, `World`, `BGs`, `Arenas`, `Duels`) and cohort percentile standings.
     - **World Hazards**: Wilderness environmental deaths and deadly PvE NPC casualty telemetry.
     - **Armory**: Context-aware routing—authenticated users immediately access their personalized combat dossier; guest users access the full realm combatant directory.
     - **Bounties**: High Command execution list and contract ledger with personal bounties pinned in a dedicated gold card at the top.
     - **Warroom**: Head-to-head guild wars, blood feuds, and realm KOS blacklist with personal wars pinned at the top.
   - **Header Auth Badge (`#header-auth-badge`)**: Displays real-time authentication session state (`👤 Username [Sign Out]` or `[Sign In]`).

7. **Class, Spec & Level Cohort Percentile Engine (`GET /api/character/<name>`, `GET /api/armory`)**:
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
