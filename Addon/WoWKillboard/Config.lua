--[[
    WoWKillboard - Config.lua
    Configuration constants, settings defaults, and color palettes.
]]

WoWKillboard = WoWKillboard or {}
local KB = WoWKillboard

KB.Version = "1.0.0"
KB.Prefix = "WOWKB"

-- Default User Settings
KB.DefaultSettings = {
    enabled = true,
    theme = "tactical",          -- "tactical" (Aegis Obsidian Gold), "elvui" (Modern Dark Gunmetal), or "classic" (Classic WoW Stone & Gold)
    includeBattlegrounds = true,
    filterMode = "ALL",          -- "ALL", "WORLD", "BG"
    trackDamage = true,
    trackHealing = true,
    soundAlerts = true,
    alertMode = "SOUND_AND_BANNER", -- "SOUND_AND_BANNER", "BANNER_ONLY", "OFF"
    alertScope = "ZONE",             -- "ZONE" (Same zone only), "ALL" (All realm kills), "MINE" (Only my kills/deaths)
    alertRaidWarning = true,         -- show secondary Raid Warning screen text
    bannerPosition = nil,            -- saved position: { point, relPoint, x, y }
    bountyEscrowBanker = "BountyEscrow",
    p2pSyncEnabled = true,
    showMinimapButton = true,
    bountyAlertRadius = 60,       -- alerts when wanted debtor is within proximity
    redemptionTaxPercent = 10,   -- 10% fee when redeeming Oathbreaker status
    combatWindowSeconds = 15,    -- temporal window for grouping/gang inference
    enableRadarAlerts = true,    -- announce detected enemy players in chat on target
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
    ["UNKNOWN"]     = "AAAAAA",
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

-- Theme Definitions: Aegis Tactical vs Classic WoW UI vs ElvUI Minimalist (100% Template-Free)
KB.Themes = {
    ["tactical"] = {
        id = "tactical",
        name = "Aegis Tactical",
        mainBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        },
        mainBg = { 0.04, 0.05, 0.08, 1.0 }, -- 100% OPAQUE Deep Obsidian Dark Iron
        mainBorder = { 0.65, 0.52, 0.22, 1.0 }, -- Antique Brass / Gold
        solidBg = { 0.04, 0.05, 0.08, 1.0 },
        titleText = "|cffffffffWoW Killboard|r |cffffd100[Aegis Tactical]|r",
        subtitleText = "|cffc7b28cv%s | Obsidian Plate & Aged Brass|r",
        insetBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        },
        insetBg = { 0.025, 0.03, 0.045, 1.0 }, -- Sunken obsidian vault
        insetBorder = { 0.35, 0.28, 0.16, 0.95 },
        cardBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        },
        cardBg = { 0.06, 0.08, 0.12, 1.0 },
        cardBorder = { 0.55, 0.44, 0.20, 0.95 },
        cardHeaderBg = { 0.09, 0.12, 0.17, 1.0 },
        cardHeaderBorder = { 0.35, 0.28, 0.16, 0.8 },
        btnBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        },
        btnBg = { 0.08, 0.10, 0.15, 1.0 },
        btnBorder = { 0.45, 0.35, 0.18, 0.95 },
        btnActiveBg = { 0.25, 0.18, 0.07, 1.0 },
        btnActiveBorder = { 1.0, 0.82, 0.0, 1.0 }, -- Radiant WoW Gold
        btnHoverBg = { 0.14, 0.17, 0.24, 1.0 },
        btnHoverBorder = { 0.85, 0.65, 0.25, 1.0 },
        dividerColor = { 0.35, 0.28, 0.16, 0.9 },
        rowBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        rowBg = { 0.05, 0.06, 0.09, 1.0 },
        rowBgAlt = { 0.035, 0.045, 0.065, 1.0 },
        rowBorder = { 0.22, 0.18, 0.12, 0.6 },
        modalBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        },
        modalBg = { 0.04, 0.05, 0.07, 1.0 },
        modalBorder = { 0.70, 0.55, 0.25, 1.0 },
        tagColor = "ffd100",
        themeBtnText = "|cffffffffTheme: |r|cffffd100Tactical|r",
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
        mainBg = { 0.05, 0.05, 0.05, 1.0 }, -- True matte charcoal/black (100% OPAQUE)
        mainBorder = { 0.0, 0.0, 0.0, 1.0 },  -- 1px solid black razor outline
        solidBg = { 0.05, 0.05, 0.05, 1.0 },
        titleText = "|cffffffffWoW Killboard|r |cffffd100[zKillboard]|r",
        subtitleText = "|cff888888v%s | ElvUI Minimalist|r",
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
        tagColor = "ffd100",
        themeBtnText = "|cffffffffTheme: |r|cffffd100ElvUI|r",
    },
    ["classic"] = {
        id = "classic",
        name = "Classic WoW UI",
        mainBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = false,
            edgeSize = 24,
            insets = { left = 6, right = 6, top = 6, bottom = 6 },
        },
        mainBg = { 0.06, 0.06, 0.08, 1.0 }, -- 100% OPAQUE Heavy Blizzard Dark Iron / Stone
        mainBorder = { 1.0, 1.0, 1.0, 1.0 }, -- UI-DialogBox-Border native stone & gold trim
        solidBg = { 0.06, 0.06, 0.08, 1.0 },
        titleText = "|cffffd100WoW Killboard|r |cffffffff[Classic WoW]|r",
        subtitleText = "|cffc7b28cv%s | Classic Blizzard Stone & Gold|r",
        insetBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        },
        insetBg = { 0.03, 0.03, 0.045, 1.0 }, -- Sunken obsidian vault
        insetBorder = { 0.55, 0.44, 0.22, 0.95 },
        cardBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        },
        cardBg = { 0.08, 0.08, 0.10, 1.0 },
        cardBorder = { 0.70, 0.55, 0.25, 0.95 },
        cardHeaderBg = { 0.12, 0.11, 0.10, 1.0 },
        cardHeaderBorder = { 0.50, 0.40, 0.20, 0.8 },
        btnBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        },
        btnBg = { 0.14, 0.12, 0.10, 1.0 },
        btnBorder = { 0.65, 0.50, 0.22, 0.95 },
        btnActiveBg = { 0.35, 0.26, 0.14, 1.0 },
        btnActiveBorder = { 1.0, 0.85, 0.30, 1.0 },
        btnHoverBg = { 0.24, 0.19, 0.14, 1.0 },
        btnHoverBorder = { 1.0, 0.82, 0.25, 1.0 },
        dividerColor = { 0.60, 0.50, 0.25, 0.8 },
        rowBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        },
        rowBg = { 0.07, 0.07, 0.09, 1.0 },
        rowBgAlt = { 0.05, 0.05, 0.07, 1.0 },
        rowBorder = { 0.40, 0.32, 0.16, 0.65 },
        modalBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = false,
            edgeSize = 24,
            insets = { left = 6, right = 6, top = 6, bottom = 6 },
        },
        modalBg = { 0.06, 0.06, 0.08, 1.0 },
        modalBorder = { 1.0, 0.85, 0.30, 1.0 },
        tagColor = "ffd100",
        themeBtnText = "|cffffffffTheme: |r|cffffd100Classic|r",
    },
}
