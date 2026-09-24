--[[
    WoWKillboard - UnitScanner.lua
    Proximity scanner that caches player levels, classes, guilds, and factions
    via targets, mouseovers, focus, and nameplates.
]]

WoWKillboard = WoWKillboard or {}
local KB = WoWKillboard
KB.UnitScanner = {}
local US = KB.UnitScanner

US.Cache = {}       -- keyed by GUID: { guid, name, realm, level, class, race, faction, guild, lastSeen }
US.NameCache = {}   -- keyed by "Name-Realm": GUID

local frame = CreateFrame("Frame")

-- Inspect a given unit token and update cache
function US:ScanUnit(unit)
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then
        return
    end

    if not KB.Utils.CanAccess(unit) then return end

    local guid = UnitGUID(unit)
    if not guid or not KB.Utils.CanAccess(guid) then return end

    local name, realm = UnitName(unit)
    if not name or not KB.Utils.CanAccess(name) then return end

    realm = (realm and realm ~= "" and KB.Utils.CanAccess(realm)) and realm or GetRealmName()
    realm = KB.Utils.CanAccess(realm) and realm or "UnknownRealm"
    local fullName = name .. "-" .. realm

    local level = UnitLevel(unit)
    level = (KB.Utils.CanAccess(level) and tonumber(level)) or 0
    local _, classFilename = UnitClass(unit)
    classFilename = KB.Utils.CanAccess(classFilename) and classFilename or "UNKNOWN"
    local race = UnitRace(unit)
    race = KB.Utils.CanAccess(race) and race or "Unknown"
    local englishFaction, _ = UnitFactionGroup(unit)
    englishFaction = KB.Utils.CanAccess(englishFaction) and englishFaction or "Unknown"
    local guildName, _, _, _ = GetGuildInfo(unit)
    guildName = KB.Utils.CanAccess(guildName) and guildName or "None"

    -- If level is -1, it's a boss/skull level player (>10 lvls higher)
    if level == -1 then
        level = 99
    end

    local existing = US.Cache[guid]
    local info = {
        guid = guid,
        name = name,
        realm = realm,
        fullName = fullName,
        level = level > 0 and level or (existing and existing.level or 0),
        class = classFilename or (existing and existing.class or "UNKNOWN"),
        race = race or "Unknown",
        faction = englishFaction or "Unknown",
        guild = guildName or (existing and existing.guild or "None"),
        lastSeen = time(),
    }

    US.Cache[guid] = info
    US.NameCache[fullName] = guid
    US.NameCache[name] = guid

    return info
end

-- Retrieve cached unit info by GUID or name
function US:GetUnitInfo(guid)
    if not guid or not KB.Utils.CanAccess(guid) then return nil end
    return US.Cache[guid]
end

function US:GetUnitInfoByName(name)
    if not name or not KB.Utils.CanAccess(name) then return nil end
    local guid = US.NameCache[name]
    if guid and KB.Utils.CanAccess(guid) then
        return US.Cache[guid]
    end
    return nil
end

-- Event handler for unit scanner (100% taint-free, no secure nameplate hooks)
frame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_TARGET_CHANGED" then
        US:ScanUnit("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        if not InCombatLockdown() then
            US:ScanUnit("mouseover")
        end
    elseif event == "PLAYER_FOCUS_CHANGED" then
        US:ScanUnit("focus")
    elseif event == "PLAYER_ENTERING_WORLD" then
        US:ScanUnit("player")
    end
end)

frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
