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
