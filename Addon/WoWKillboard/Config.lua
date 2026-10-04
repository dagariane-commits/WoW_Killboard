--[[
    WoWKillboard - Config.lua
    Configuration constants, settings defaults, and color palettes.
]]

WoWKillboard = WoWKillboard or {}
local KB = WoWKillboard



KB.Version = "1.0.1"
KB.Prefix = "WOWKB"
KB.WebDomain = "wowkillboard.com"

-- Default User Settings
KB.DefaultSettings = {
    enabled = true,
    theme = "classic",           -- "classic" (Classic WoW Stone & Gold) or "elvui" (Modern Dark Gunmetal)
    includeBattlegrounds = true,
    filterMode = "WORLD",        -- "WORLD", "BG", "DUEL", "ARENA"
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

-- Theme Definitions: Classic WoW UI vs ElvUI Minimalist (100% Template-Free)
KB.Themes = {
    ["elvui"] = {
        id = "elvui",
        name = "ElvUI Minimalist",
        mainBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        mainBg = { 0.05, 0.05, 0.05, 1.0 }, -- True matte charcoal/black (100% OPAQUE)
        mainBorder = { 0.0, 0.0, 0.0, 1.0 },  -- 1px solid black razor outline
        solidBg = { 0.05, 0.05, 0.05, 1.0 },
        titleText = "|cffffd100WoW Killboard|r",
        subtitleText = "v%s",
        insetBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        insetBg = { 0.03, 0.03, 0.03, 1.0 },
        insetBorder = { 0.0, 0.0, 0.0, 1.0 },
        cardBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        cardBg = { 0.09, 0.09, 0.09, 1.0 },
        cardBorder = { 0.0, 0.0, 0.0, 1.0 },
        cardHeaderBg = { 0.12, 0.12, 0.12, 1.0 },
        cardHeaderBorder = { 0.0, 0.0, 0.0, 1.0 },
        btnBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        btnBg = { 0.12, 0.12, 0.12, 1.0 },
        btnBorder = { 0.0, 0.0, 0.0, 1.0 },
        btnActiveBg = { 0.20, 0.20, 0.20, 1.0 },
        btnActiveBorder = { 1.0, 0.82, 0.0, 1.0 }, -- ElvUI signature Gold accent
        btnHoverBg = { 0.18, 0.18, 0.18, 1.0 },
        btnHoverBorder = { 0.45, 0.45, 0.45, 1.0 },
        dividerColor = { 0.0, 0.0, 0.0, 1.0 },
        rowBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        rowBg = { 0.09, 0.09, 0.09, 1.0 },
        rowBgAlt = { 0.06, 0.06, 0.06, 1.0 },
        rowBorder = { 0.0, 0.0, 0.0, 0.8 },
        modalBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        modalBg = { 0.06, 0.06, 0.06, 1.0 },
        modalBorder = { 0.0, 0.0, 0.0, 1.0 },
        bannerBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        },
        bannerBg = { 0.06, 0.08, 0.11, 0.85 },
        bannerBorder = { 0.55, 0.50, 0.40, 0.90 },
        scrollbarRail = { 0.03, 0.03, 0.03, 1.0 },
        scrollbarRailBorder = { 0.0, 0.0, 0.0, 1.0 },
        scrollbarThumb = { 0.25, 0.25, 0.25, 1.0 },
        scrollbarThumbBorder = { 0.0, 0.0, 0.0, 1.0 },
        searchBg = { 0.08, 0.08, 0.08, 1.0 },
        searchBorder = { 0.0, 0.0, 0.0, 1.0 },
        searchFocusBorder = { 1.0, 0.82, 0.0, 1.0 },
        tagColor = "ffd100",
        themeBtnText = "|cffffffffTheme: |r|cffffd100ElvUI|r",
    },
    ["classic"] = {
        id = "classic",
        name = "Classic WoW UI",
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
}
