--[[
    WoWKillboard - Config.lua
    Configuration constants, settings defaults, and color palettes.
]]

WoWKillboard = WoWKillboard or {}
local KB = WoWKillboard
WoWKB = WoWKillboard

KB.Version = "1.0.5"
KB.Prefix = "WOWKB"
KB.WebDomain = "wowkillboard.com"

-- Default User Settings
KB.DefaultSettings = {
    enabled = true,
    theme = "elvui",             -- "elvui" (Modern Dark Minimalist) or "classic" (Classic WoW Stone & Gold)
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

-- Theme Definitions: Shadow Network Slate vs Classic Blizzard Stone (100% Template-Free)
KB.Themes = {
    ["slate"] = {
        id = "slate",
        name = "Shadow Network Slate",
        mainBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        mainBg = { 0.04, 0.06, 0.09, 0.95 }, -- Charcoal slate fill
        mainBorder = { 0.58, 0.45, 0.22, 1.0 }, -- Slim gold/brass borders
        solidBg = { 0.04, 0.06, 0.09, 0.95 },
        titleText = "|cffffd100WoW Killboard|r",
        subtitleText = "v%s",
        insetBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        insetBg = { 0.04, 0.06, 0.09, 0.95 },
        insetBorder = { 0.58, 0.45, 0.22, 0.5 },
        cardBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        cardBg = { 0.06, 0.09, 0.13, 0.95 }, -- Dark slate container
        cardBorder = { 0.58, 0.45, 0.22, 0.5 },
        cardHeaderBg = { 0.05, 0.08, 0.12, 0.98 }, -- Dark gunmetal
        cardHeaderBorder = { 0.58, 0.45, 0.22, 0.4 },
        btnBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        btnBg = { 0.07, 0.10, 0.15, 0.95 },
        btnBorder = { 0.58, 0.45, 0.22, 0.6 },
        btnActiveBg = { 0.15, 0.20, 0.30, 1.0 },
        btnActiveBorder = { 1.0, 0.82, 0.0, 1.0 }, -- #FFD100 Gold active accent
        btnHoverBg = { 0.12, 0.16, 0.24, 1.0 },
        btnHoverBorder = { 0.58, 0.45, 0.22, 0.9 },
        dividerColor = { 0.58, 0.45, 0.22, 0.35 },
        rowBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        rowBg = { 0.05, 0.07, 0.10, 0.95 },
        rowBgAlt = { 0.06, 0.08, 0.12, 0.95 },
        rowBorder = { 0.58, 0.45, 0.22, 0.25 },
        modalBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        modalBg = { 0.04, 0.06, 0.09, 0.95 },
        modalBorder = { 0.58, 0.45, 0.22, 1.0 },
        bannerBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        },
        bannerBg = { 13/255, 17/255, 23/255, 0.94 },
        bannerBorder = { 0.58, 0.45, 0.22, 0.8 },
        scrollbarRail = { 0.05, 0.07, 0.10, 0.95 },
        scrollbarRailBorder = { 0.58, 0.45, 0.22, 0.3 },
        scrollbarThumb = { 0.58, 0.45, 0.22, 0.95 },
        scrollbarThumbBorder = { 1.0, 0.82, 0.0, 1.0 },
        searchBg = { 0.05, 0.07, 0.10, 0.95 },
        searchBorder = { 0.58, 0.45, 0.22, 0.6 },
        searchFocusBorder = { 1.0, 0.82, 0.0, 1.0 },
        tagColor = "ffd100",
        themeBtnText = "|cffffffffTheme: |r|cffffd100Slate|r",
    },
    ["classic"] = {
        id = "classic",
        name = "Classic Blizzard Stone & Parchment",
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
        insetBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        },
        insetBg = { 0.08, 0.07, 0.05, 0.95 }, -- Rich sunken dark slate backing for maximum contrast
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
        rowBg = { 0.10, 0.08, 0.06, 0.92 }, -- Deep dark slate backing (maximum contrast against text)
        rowBgAlt = { 0.07, 0.05, 0.04, 0.95 }, -- Charcoal slate backing
        rowBorder = { 0.50, 0.40, 0.20, 0.85 }, -- Antique gold beveled border
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
        bannerBackdrop = nil, -- Handled natively by Interface\\AchievementFrame\\UI-Achievement-Alert-Background
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
    ["web"] = {
        id = "web",
        name = "Theme: Shadow Network (Web 1:1)",
        mainBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            tileSize = 0,
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        mainBg = { 0.02, 0.025, 0.035, 0.95 },      -- #040609 Master Window Canvas
        mainBorder = { 0.831, 0.686, 0.216, 0.85 }, -- #D4AF37 Flat 1px Border (Gold Sheen)
        solidBg = { 0.02, 0.025, 0.035, 0.95 },     -- #040609
        titleText = "|cfffbbf24WoW Killboard|r",     -- #FBBF24 Primary Text (Gold Title)
        textPrimary = { 0.984, 0.749, 0.141, 1.00 },   -- #FBBF24 Primary Text (Gold Title)
        textSecondary = { 0.612, 0.639, 0.686, 1.00 }, -- #9CA3AF Secondary Text (Slate Muted)
        canvasBg = { 0.043, 0.059, 0.090, 0.98 },      -- #0B0F17 Main Window Canvas Token
        panelBg = { 0.067, 0.094, 0.153, 1.00 },       -- #111827 Card / Panel Background Token
        subPanelBg = { 0.086, 0.122, 0.188, 0.60 },    -- #161F30 Sub-Panel Token
        borderMuted = { 0.122, 0.161, 0.216, 1.00 },   -- #1F2937 Flat 1px Border (Muted)
        borderGold = { 0.831, 0.686, 0.216, 0.85 },    -- #D4AF37 Flat 1px Border (Gold Sheen)
        subtitleText = "v%s",
        insetBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        insetBg = { 0.05, 0.075, 0.12, 0.90 },       -- #0D131F Combat Log Table Container
        insetBorder = { 0.12, 0.16, 0.23, 1.0 },     -- #1E293B Flat 1px Border
        cardBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        cardBg = { 0.05, 0.075, 0.12, 0.90 },        -- #0D131F Elevated Slate Fill (3 Right-Sidebar Cards)
        cardBorder = { 0.12, 0.16, 0.23, 1.0 },      -- #1E293B Flat 1px Border
        sidebarContainerBg = { 0.02, 0.025, 0.035, 0.0 },
        sidebarContainerBorder = { 0.02, 0.025, 0.035, 0.0 },
        cardHeaderBg = { 0.051, 0.075, 0.122, 1.00 }, -- #0D131F Telemetry Ribbon Fill
        cardHeaderBorder = { 0.12, 0.16, 0.23, 1.0 },
        btnBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        btnBg = { 0.06, 0.08, 0.12, 0.8 },           -- Dark slate fill
        btnBorder = { 0.12, 0.16, 0.23, 1.0 },       -- #1E293B Muted border
        btnActiveBg = { 0.78, 0.60, 0.24, 1.0 },      -- Solid gold fill
        btnActiveBorder = { 0.78, 0.60, 0.24, 1.0 },  -- Solid gold border
        btnHoverBg = { 0.12, 0.16, 0.24, 1.0 },
        btnHoverBorder = { 0.78, 0.60, 0.24, 0.80 },
        dividerColor = { 0.12, 0.16, 0.23, 1.0 },     -- #1E293B
        rowBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        rowBg = { 0.05, 0.075, 0.12, 0.90 },         -- #0D131F
        rowBgAlt = { 0.086, 0.122, 0.188, 0.90 },    -- #161F30
        rowBorder = { 0.12, 0.16, 0.23, 1.0 },       -- #1E293B
        modalBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        modalBg = { 0.02, 0.025, 0.035, 0.95 },      -- #040609
        modalBorder = { 0.831, 0.686, 0.216, 0.85 }, -- #D4AF37
        bannerBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        bannerBg = { 0.02, 0.025, 0.035, 0.95 },
        bannerBorder = { 0.831, 0.686, 0.216, 0.85 },
        scrollbarRail = { 0.051, 0.075, 0.122, 1.00 }, -- #0D131F
        scrollbarRailBorder = { 0.12, 0.16, 0.23, 1.0 },
        scrollbarThumb = { 0.78, 0.60, 0.24, 1.0 },
        scrollbarThumbBorder = { 0.984, 0.749, 0.141, 1.00 },
        searchBg = { 0.051, 0.075, 0.122, 1.00 },
        searchBorder = { 0.12, 0.16, 0.23, 1.0 },
        searchFocusBorder = { 0.78, 0.60, 0.24, 1.0 },
        tagColor = "fbbf24",
        themeBtnText = "|cffffffffTheme: |r|cfffbbf24Web 1:1|r",
    },
    ["elvui"] = {
        id = "elvui",
        name = "ElvUI Minimalist",
        mainBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        mainBg = { 18/255, 18/255, 18/255, 1.0 }, -- #121212 Flat dark slate primary window
        mainBorder = { 0.0, 0.0, 0.0, 1.0 },      -- 1px solid black border
        solidBg = { 18/255, 18/255, 18/255, 1.0 }, -- #121212
        titleText = "|cffffd100WoW Killboard|r",
        subtitleText = "v%s",
        insetBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        insetBg = { 18/255, 18/255, 18/255, 1.0 }, -- #121212 Flat dark slate inset
        insetBorder = { 0.0, 0.0, 0.0, 1.0 },     -- 1px solid black border
        cardBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        cardBg = { 24/255, 24/255, 24/255, 1.0 }, -- #181818 Secondary headers/panels
        cardBorder = { 0.0, 0.0, 0.0, 1.0 },     -- 1px solid black border
        cardHeaderBg = { 26/255, 26/255, 26/255, 1.0 }, -- #1A1A1A
        cardHeaderBorder = { 0.0, 0.0, 0.0, 1.0 },
        btnBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        btnBg = { 30/255, 30/255, 30/255, 1.0 }, -- #1E1E1E Flat button
        btnBorder = { 0.0, 0.0, 0.0, 1.0 },     -- 1px solid black border
        btnActiveBg = { 42/255, 42/255, 42/255, 1.0 },
        btnActiveBorder = { 1.0, 0.82, 0.0, 1.0 }, -- #FFD100 Gold active accent
        btnHoverBg = { 42/255, 42/255, 42/255, 1.0 }, -- #2A2A2A Hover highlight
        btnHoverBorder = { 0.0, 0.0, 0.0, 1.0 },
        dividerColor = { 0.0, 0.0, 0.0, 1.0 },
        rowBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        rowBg = { 20/255, 20/255, 20/255, 1.0 },    -- #141414 Alternating row fill
        rowBgAlt = { 22/255, 22/255, 22/255, 1.0 }, -- #161616 Alternating row fill
        rowBorder = { 0.0, 0.0, 0.0, 1.0 },        -- 1px solid black divider
        modalBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        modalBg = { 18/255, 18/255, 18/255, 1.0 }, -- #121212
        modalBorder = { 0.0, 0.0, 0.0, 1.0 },
        bannerBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        },
        bannerBg = { 13/255, 17/255, 23/255, 0.94 },
        bannerBorder = { 0.18, 0.20, 0.23, 1.0 },
        scrollbarRail = { 20/255, 20/255, 20/255, 1.0 }, -- #141414
        scrollbarRailBorder = { 0.0, 0.0, 0.0, 1.0 },
        scrollbarThumb = { 42/255, 42/255, 42/255, 1.0 }, -- #2A2A2A
        scrollbarThumbBorder = { 0.0, 0.0, 0.0, 1.0 },
        searchBg = { 20/255, 20/255, 20/255, 1.0 }, -- #141414
        searchBorder = { 0.0, 0.0, 0.0, 1.0 },
        searchFocusBorder = { 1.0, 0.82, 0.0, 1.0 },
        tagColor = "ffd100",
        themeBtnText = "|cffffffffTheme: |r|cffffd100ElvUI|r",
    },
}

-- Backward compatibility aliases
KB.Themes["shadownetwork"] = KB.Themes["web"]
KB.Themes["web11"] = KB.Themes["web"]
KB.Themes["web_slate"] = KB.Themes["web"]
