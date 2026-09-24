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
    theme = "elvui",             -- "elvui" (Modern Dark Gunmetal) or "classic" (Classic WoW Stone & Gold)
    includeBattlegrounds = true,
    filterMode = "ALL",          -- "ALL", "WORLD", "BG"
    trackDamage = true,
    trackHealing = true,
    soundAlerts = true,
    bountyEscrowBanker = "BountyEscrow",
    p2pSyncEnabled = true,
    showMinimapButton = true,
    bountyAlertRadius = 60,       -- alerts when wanted debtor is within proximity
    redemptionTaxPercent = 10,   -- 10% fee when redeeming Oathbreaker status
    combatWindowSeconds = 15,    -- temporal window for grouping/gang inference
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

-- Theme Definitions: Classic WoW UI Theme vs ElvUI Minimalist Theme (100% Template-Free)
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
        mainBg = { 0.05, 0.05, 0.05, 0.98 }, -- True matte charcoal/black (neutral, zero blue tint)
        mainBorder = { 0.0, 0.0, 0.0, 1.0 },  -- 1px solid black razor outline
        titleText = "|cffffffffWoW Killboard|r |cffffd100[zKillboard]|r",
        subtitleText = "|cff888888v%s | ElvUI Minimalist|r",
        cardBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        cardBg = { 0.09, 0.09, 0.09, 0.95 },
        cardBorder = { 0.0, 0.0, 0.0, 1.0 },
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
        rowBg = { 0.09, 0.09, 0.09, 0.92 },
        rowBgAlt = { 0.06, 0.06, 0.06, 0.92 },
        rowBorder = { 0.0, 0.0, 0.0, 0.8 },
        modalBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        modalBg = { 0.06, 0.06, 0.06, 0.98 },
        modalBorder = { 0.0, 0.0, 0.0, 1.0 },
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
            edgeSize = 16,
            insets = { left = 5, right = 5, top = 5, bottom = 5 },
        },
        mainBg = { 1.0, 1.0, 1.0, 0.98 },
        mainBorder = { 1.0, 1.0, 1.0, 1.0 },
        titleText = "|cffffd100WoW Killboard|r |cffffffff[Classic WoW]|r",
        subtitleText = "|cffc7b28cv%s | Classic Blizzard Stone & Gold|r",
        cardBackdrop = {
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        },
        cardBg = { 0.09, 0.07, 0.05, 0.95 },
        cardBorder = { 0.70, 0.55, 0.25, 0.95 },
        btnBackdrop = {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        },
        btnBg = { 0.16, 0.13, 0.10, 0.95 },
        btnBorder = { 0.65, 0.50, 0.22, 0.95 },
        btnActiveBg = { 0.35, 0.26, 0.14, 1.0 },
        btnActiveBorder = { 1.0, 0.85, 0.30, 1.0 },
        btnHoverBg = { 0.26, 0.20, 0.14, 1.0 },
        btnHoverBorder = { 1.0, 0.82, 0.25, 1.0 },
        dividerColor = { 0.60, 0.50, 0.25, 0.8 },
        rowBackdrop = {
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        },
        rowBg = { 0.12, 0.09, 0.07, 0.92 },
        rowBgAlt = { 0.08, 0.06, 0.04, 0.92 },
        rowBorder = { 0.45, 0.35, 0.18, 0.65 },
        modalBackdrop = {
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 16,
            insets = { left = 5, right = 5, top = 5, bottom = 5 },
        },
        modalBg = { 1.0, 1.0, 1.0, 0.98 },
        modalBorder = { 1.0, 0.85, 0.30, 1.0 },
        tagColor = "ffd100",
        themeBtnText = "|cffffffffTheme: |r|cffffd100Classic|r",
    },
}
