--[[
    WoWKillboard - Config.lua
    Configuration constants, settings defaults, and color palettes.
]]

WoWKillboard = WoWKillboard or {}
local KB = WoWKillboard
WoWKB = WoWKillboard

KB.Version = "1.0.6"
KB.Prefix = "WOWKB"
KB.WebDomain = "wowkillboard.com"

-- Default User Settings
KB.DefaultSettings = {
    enabled = true,
    theme = "wkb",             -- "wkb" (WKB Theme - 1:1 Web Mirror), "elvui" (ElvUI), "classic" (Classic Blizzard Stone)
    isolateRealms = true,        -- Strictly isolate combat telemetry, killfeeds, and leaderboards to active realm
    accentColorMode = "gold",    -- "gold" (#FFD100), "class" (Player Character Class), "custom" (User RGB)
    customAccentColor = { 1.0, 0.82, 0.0, 1.0 }, -- Saved custom RGB
    includeBattlegrounds = true,
    filterMode = "WORLD",        -- "WORLD", "BG", "DUEL", "ARENA"
    combatFilter = "WORLD",      -- Default active sub-toolbar filter pill: "WORLD", "BG", "DUEL", "ARENA"
    trackDamage = true,
    trackHealing = true,
    soundAlerts = true,
    alertMode = "SOUND_AND_BANNER", -- "SOUND_AND_BANNER", "BANNER_ONLY", "OFF"
    alertScope = "ZONE",             -- "ZONE" (Same zone only), "ALL" (All realm kills), "MINE" (Only my kills/deaths)
    alertStyle = "BOTH",             -- "BOTH" (Banner + Raid Warning), "RAID_WARNING" (Raid Warning only), "BANNER" (Banner only)
    alertRaidWarning = true,         -- backward compatibility alias for alertStyle ~= "BANNER"
    bannerPosition = nil,            -- saved position: { point, relPoint, x, y }
    bountyEscrowBanker = "BountyEscrow",
    p2pSyncEnabled = true,
    showMinimapButton = true,
    bountyAlertRadius = 60,       -- alerts when wanted debtor is within proximity
    redemptionTaxPercent = 10,   -- 10% fee when redeeming Oathbreaker status
    combatWindowSeconds = 45,    -- temporal window for grouping/gang inference and solo purity (45s covers extended open-world PvP kiting)
    enableRadarAlerts = true,    -- detect and display hostile players on radar
    showRadarHUD = true,         -- show floating moveable Radar HUD window
    radarChatAlerts = false,     -- mute radar spam in chat (HUD only)
    radarPos = nil,              -- saved position for radar HUD: { point, relPoint, x, y }
    promptMarkOnDeath = true,    -- prompt to declare a Mark of Spite on death in open world PvP
    promptBountyOnDeath = true,  -- backward compatibility alias for promptMarkOnDeath
    ignoreDeathBounties = false, -- ignore and suppress all Mark offers upon death
    combatFeedMode = "POPOUT",   -- "POPOUT" (Dedicated floating Combat Wire window), "CHAT" (Main chat window), "OFF"
    showCombatWire = true,       -- show floating moveable Combat Wire pop-out window
    combatWirePos = nil,         -- saved position for Combat Wire window: { point, relPoint, x, y }
    hasSeenBetaWelcome = false,  -- shows early beta preview & feedback dialog on first login
    enableChatBroadcasts = false,   -- Enable Chat Broadcasts (Yell / Say) [Default: Off / Opt-in]
    enableGuildBroadcasts = true,   -- Enable Guild Broadcasts [Default: On]
    includeCoordinates = true,      -- Include Coordinates [Default: On]
    enableWhisperAutoInvite = true,  -- Enable Whisper Auto-Invite [Default: On]
    showChannelInChat = false,      -- Show WoWKillboard channel feed in main chat window [Default: Off / Clean Chat]
}

-- Fallback Class Colors (ARGB Hex)
KB.ClassColors = {
    ["WARRIOR"]     = "C79C6E",
    ["PALADIN"]     = "F58CBA",
    ["HUNTER"]      = "ABD473",
    ["ROGUE"]       = "FFF569",
    ["PRIEST"]      = "FFFFFF",
    ["DEATHKNIGHT"] = "C41F3B",
    ["SHAMAN"]      = "0070DE",
    ["MAGE"]        = "40C7EB",
    ["WARLOCK"]     = "8787ED",
    ["MONK"]        = "00FF96",
    ["DRUID"]       = "FF7D0A",
    ["DEMONHUNTER"] = "A330C9",
    ["EVOKER"]      = "33937F",
    ["UNKNOWN"]     = "C7C7CF",
}

-- Faction Colors
KB.FactionColors = {
    ["Alliance"] = "0078FF",
    ["Horde"]    = "B30000",
    ["Neutral"]  = "FFCC00",
}

-- Sound Alert Asset IDs (Default WoW sound IDs)
KB.SoundAlerts = {
    SOLO_KILL       = 8959,   -- RAID_WARNING
    DEATH           = 8960,
    BOUNTY_CLAIMED  = 8456,   -- QUEST_COMPLETE
    DEBTOR_SIGHTED  = 8959,   -- RAID_WARNING siren
}

-- Status Codes for Debtors & Bounties
KB.STATUS = {
    ACTIVE       = "ACTIVE",
    CLAIMED      = "CLAIMED",
    PAID         = "PAID",
    OATHBREAKER  = "OATHBREAKER",
    REDEEMED     = "REDEEMED",
}

-- Theme Definitions: Strict 3-Theme Architecture (100% Template-Free, Zero-Taint)
-- 1. CLASSIC ("Classic Blizzard Stone")
-- 2. ELVUI   ("ElvUI")
-- 3. WKB     ("WKB Theme" - 1:1 Web Mirror of wowkillboard.com)
KB.Themes = {
    ["CLASSIC"] = {
        id = "classic",
        name = "Classic Blizzard Stone",
        mainBackdrop = {
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        },
        mainBg = { 1.0, 1.0, 1.0, 1.0 }, -- Authentic Blizzard Dialog stone texture
        mainBorder = { 1.0, 1.0, 1.0, 1.0 }, -- UI-DialogBox-Border native stone & gold trim
        solidBg = nil, -- Hidden in classic theme to reveal true Blizzard stone
        titleText = "|cffffd100WoW Killboard|r",
        subtitleText = "v%s",
        headerColor = { 1.0, 0.82, 0.0, 1.0 },
        subtitleColor = { 0.80, 0.80, 0.80, 1.0 },
        insetBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        },
        insetBg = { 0.08, 0.07, 0.05, 0.95 }, -- Rich sunken dark slate backing
        insetBorder = { 0.75, 0.60, 0.28, 1.0 }, -- Antique brass/gold border framing
        cardBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        },
        cardBg = { 0.12, 0.09, 0.07, 0.95 }, -- Sunken dark bronze matching dialog stone
        cardBorder = { 0.65, 0.50, 0.22, 0.95 },
        cardHeaderBg = { 0.20, 0.15, 0.10, 0.95 },
        cardHeaderBorder = { 0.55, 0.44, 0.20, 0.85 },
        ribbonBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        },
        ribbonBg = { 0.14, 0.10, 0.07, 0.95 },
        ribbonBorder = { 0.55, 0.44, 0.22, 0.95 },
        btnBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        },
        btnBg = { 0.14, 0.10, 0.07, 0.95 },
        btnBorder = { 0.55, 0.44, 0.22, 0.95 },
        btnActiveBg = { 0.32, 0.22, 0.10, 1.0 },
        btnActiveBorder = { 1.0, 0.84, 0.0, 1.0 },
        btnHoverBg = { 0.24, 0.18, 0.11, 1.0 },
        btnHoverBorder = { 0.90, 0.75, 0.25, 0.95 },
        dividerColor = { 0.65, 0.52, 0.25, 0.85 },
        rowBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        },
        rowBg = { 0.10, 0.08, 0.06, 0.92 },
        rowBgAlt = { 0.07, 0.05, 0.04, 0.95 },
        rowHoverBg = { 0.24, 0.18, 0.11, 0.95 },
        rowBorder = { 0.50, 0.40, 0.20, 0.85 },
        modalBackdrop = {
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        },
        modalBg = { 1.0, 1.0, 1.0, 1.0 },
        modalBorder = { 1.0, 1.0, 1.0, 1.0 },
        bannerBackdrop = nil,
        bannerBg = nil,
        bannerBorder = nil,
        scrollbarRail = { 0.05, 0.04, 0.03, 0.85 },
        scrollbarRailBorder = { 0.45, 0.35, 0.18, 0.8 },
        scrollbarThumb = { 0.70, 0.55, 0.22, 0.95 },
        scrollbarThumbBorder = { 0.90, 0.75, 0.28, 1.0 },
        searchBg = { 0.07, 0.06, 0.04, 0.95 },
        searchBorder = { 0.55, 0.44, 0.22, 0.95 },
        searchFocusBorder = { 1.0, 0.84, 0.0, 1.0 },
        tagColor = "ffd100",
        themeBtnText = "|cffffffffTheme: |r|cffffd100Classic|r",
    },
    ["ELVUI"] = {
        id = "elvui",
        name = "ElvUI",
        mainBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        mainBg = { 0.04, 0.04, 0.04, 0.95 }, -- Hex #0A0A0A
        mainBorder = { 0.0, 0.0, 0.0, 1.0 }, -- 1px solid black border
        solidBg = { 0.04, 0.04, 0.04, 0.95 },
        titleText = "|cffffffffWoW Killboard|r",
        subtitleText = "v%s",
        headerColor = { 1.0, 1.0, 1.0, 1.0 },
        subtitleColor = { 0.70, 0.70, 0.70, 1.0 },
        insetBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        insetBg = { 0.08, 0.08, 0.08, 0.90 }, -- Hex #141414
        insetBorder = { 0.0, 0.0, 0.0, 1.0 },
        cardBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        cardBg = { 0.08, 0.08, 0.08, 0.90 }, -- Hex #141414
        cardBorder = { 0.0, 0.0, 0.0, 1.0 },
        cardHeaderBg = { 0.10, 0.10, 0.10, 1.0 },
        cardHeaderBorder = { 0.0, 0.0, 0.0, 1.0 },
        ribbonBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        ribbonBg = { 0.06, 0.06, 0.06, 0.95 },
        ribbonBorder = { 0.0, 0.0, 0.0, 1.0 },
        btnBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        btnBg = { 0.12, 0.12, 0.12, 1.0 }, -- Flat dark gray button
        btnBorder = { 0.0, 0.0, 0.0, 1.0 }, -- 1px black border
        btnActiveBg = { 0.16, 0.16, 0.16, 1.0 },
        btnActiveBorder = { 1.0, 1.0, 1.0, 1.0 }, -- Bright white accent border
        btnHoverBg = { 0.18, 0.18, 0.18, 1.0 },
        btnHoverBorder = { 1.0, 1.0, 1.0, 0.8 },
        dividerColor = { 0.0, 0.0, 0.0, 1.0 },
        rowBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        rowBg = { 0.08, 0.08, 0.08, 1.0 },
        rowBgAlt = { 0.09, 0.09, 0.09, 1.0 },
        rowHoverBg = { 0.16, 0.16, 0.16, 1.0 },
        rowBorder = { 0.0, 0.0, 0.0, 1.0 },
        modalBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        modalBg = { 0.04, 0.04, 0.04, 0.95 },
        modalBorder = { 0.0, 0.0, 0.0, 1.0 },
        bannerBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        },
        bannerBg = { 0.05, 0.05, 0.05, 0.94 },
        bannerBorder = { 0.18, 0.20, 0.23, 1.0 },
        scrollbarRail = { 0.08, 0.08, 0.08, 1.0 },
        scrollbarRailBorder = { 0.0, 0.0, 0.0, 1.0 },
        scrollbarThumb = { 0.18, 0.18, 0.18, 1.0 },
        scrollbarThumbBorder = { 0.0, 0.0, 0.0, 1.0 },
        searchBg = { 0.08, 0.08, 0.08, 1.0 },
        searchBorder = { 0.0, 0.0, 0.0, 1.0 },
        searchFocusBorder = { 1.0, 1.0, 1.0, 1.0 },
        tagColor = "ffffff",
        themeBtnText = "|cffffffffTheme: |r|cffffffffElvUI|r",
    },
    ["WKB"] = {
        id = "wkb",
        name = "WKB Theme",
        mainBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            tileSize = 0,
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        mainBg = { 0.015, 0.020, 0.030, 0.98 },      -- Hex #040609 Outer Master Window Canvas
        mainBorder = { 0.58, 0.45, 0.22, 1.0 },     -- Hex #947338 1px solid brass outer border
        solidBg = { 0.015, 0.020, 0.030, 0.98 },
        titleText = "|cfffbbf24WoW Killboard|r",
        subtitleText = "v%s",
        headerColor = { 0.78, 0.65, 0.35, 1.0 },    -- Muted Web Gold
        subtitleColor = { 0.50, 0.55, 0.62, 1.0 },  -- Slate Gray
        textPrimary = { 0.984, 0.749, 0.141, 1.00 },   -- #FBBF24 Primary Text (Gold Title)
        textSecondary = { 0.612, 0.639, 0.686, 1.00 }, -- #9CA3AF Secondary Text (Slate Muted)
        canvasBg = { 0.015, 0.020, 0.030, 0.98 },      -- #040609 Master Canvas
        tabActiveBg = { 0.08, 0.11, 0.16, 1.0 },        -- Dark Slate Tab Background
        tabActiveAccent = { 0.85, 0.70, 0.25, 1.0 },    -- 2px Solid Bright Gold Bottom Line
        tabActiveText = { 1.0, 1.0, 1.0, 1.0 },         -- Solid White Bold Font
        panelBg = { 0.043, 0.059, 0.090, 0.95 },       -- #0B0F17 Elevated Card Background Fill
        subPanelBg = { 0.060, 0.080, 0.115, 0.60 },
        borderMuted = { 0.12, 0.16, 0.23, 1.0 },       -- #1E293B Flat 1px Border
        borderGold = { 0.58, 0.45, 0.22, 1.0 },        -- #947338 Brass Border
        insetBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        insetBg = { 0.043, 0.059, 0.090, 0.95 },       -- Hex #0B0F17 Combat Feed Table Container
        insetBorder = { 0.12, 0.16, 0.23, 1.0 },       -- Hex #1E293B Flat 1px Border
        cardBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        cardBg = { 0.043, 0.059, 0.090, 0.95 },        -- Hex #0B0F17 Elevated Slate Fill (3 Right-Sidebar Cards)
        cardBorder = { 0.12, 0.16, 0.23, 1.0 },        -- Hex #1E293B Flat 1px Border
        sidebarContainerBg = { 0.015, 0.023, 0.035, 0.0 },
        sidebarContainerBorder = { 0.015, 0.023, 0.035, 0.0 },
        cardHeaderBg = { 0.025, 0.035, 0.055, 1.0 },
        cardHeaderBorder = { 0.58, 0.45, 0.22, 0.4 },
        ribbonBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        ribbonBg = { 0.025, 0.035, 0.055, 1.0 },       -- Solid dark strip
        ribbonBorder = { 0.58, 0.45, 0.22, 0.4 },      -- 1px bottom border
        btnBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        btnBg = { 0.06, 0.08, 0.12, 0.8 },             -- Inset slate
        btnBorder = { 0.15, 0.19, 0.26, 1.0 },         -- 1px slate
        btnActiveBg = { 0.78, 0.60, 0.24, 1.0 },        -- Solid bright brass gold (#C69B3D)
        btnActiveBorder = { 0.85, 0.70, 0.30, 1.0 },    -- 1px gold
        btnHoverBg = { 0.12, 0.16, 0.24, 1.0 },
        btnHoverBorder = { 0.78, 0.60, 0.24, 0.80 },
        pillActiveText = { 0.05, 0.05, 0.05, 1.0 },    -- Solid dark black
        pillInactiveText = { 0.65, 0.70, 0.75, 1.0 },  -- Muted gray
        dividerColor = { 0.12, 0.16, 0.23, 1.0 },       -- #1E293B
        rowBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        rowBg = { 0.060, 0.080, 0.115, 0.6 },          -- Row Odd
        rowBgAlt = { 0.043, 0.059, 0.090, 0.4 },       -- Row Even
        rowHoverBg = { 0.12, 0.16, 0.23, 0.8 },        -- Highlight on Mouseover
        rowBorder = { 0.12, 0.16, 0.23, 1.0 },         -- #1E293B
        modalBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        modalBg = { 0.015, 0.023, 0.035, 0.98 },
        modalBorder = { 0.58, 0.45, 0.22, 1.0 },
        bannerBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        bannerBg = { 0.015, 0.023, 0.035, 0.98 },
        bannerBorder = { 0.58, 0.45, 0.22, 1.0 },
        scrollbarRail = { 0.025, 0.035, 0.055, 1.0 },
        scrollbarRailBorder = { 0.12, 0.16, 0.23, 1.0 },
        scrollbarThumb = { 0.78, 0.60, 0.24, 1.0 },
        scrollbarThumbBorder = { 0.85, 0.70, 0.30, 1.0 },
        searchBg = { 0.025, 0.035, 0.055, 1.0 },
        searchBorder = { 0.12, 0.16, 0.23, 1.0 },
        searchFocusBorder = { 0.78, 0.60, 0.24, 1.0 },
        tagColor = "fbbf24",
        themeBtnText = "|cffffffffTheme: |r|cfffbbf24WKB Theme|r",
    },
}

-- Backward compatibility and case-insensitive aliases
KB.Themes["classic"]       = KB.Themes["CLASSIC"]
KB.Themes["elvui"]         = KB.Themes["ELVUI"]
KB.Themes["wkb"]           = KB.Themes["WKB"]
KB.Themes["web"]           = KB.Themes["WKB"]
KB.Themes["slate"]         = KB.Themes["WKB"]
KB.Themes["shadownetwork"] = KB.Themes["WKB"]
KB.Themes["web11"]         = KB.Themes["WKB"]
KB.Themes["web_slate"]     = KB.Themes["WKB"]

