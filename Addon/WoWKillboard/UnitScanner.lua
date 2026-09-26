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

    -- KOS Blacklist & Hostile Radar Check (Hostile player units only)
    if UnitCanAttack and UnitCanAttack("player", unit) and UnitIsPlayer(unit) then
        local isKos = US:CheckKOS(info)
        if not isKos then
            US:CheckHostileRadar(info)
        end
    end

    return info
end

US.LastAlertTime = {}

-- Proximity evaluation for KOS Blacklist & Deserter stain
function US:CheckKOS(info)
    if not info or not info.name then return end
    local name = info.name
    local guid = info.guid
    local guild = info.guild
    local now = time()

    if (now - (US.LastAlertTime[name] or 0)) < 45 then
        return -- Throttle alert to once every 45s per target
    end

    local isDeserter = false
    local deserterInfo = nil
    local isKosGuild = false
    local kosGuildReason = nil
    local isKosPlayer = false
    local kosPlayerReason = nil

    if WoWKillboardDB then
        if WoWKillboardDB.kosDeserters then
            deserterInfo = WoWKillboardDB.kosDeserters[name] or (guid and WoWKillboardDB.kosDeserters[guid])
            if deserterInfo then
                -- Check 30-day expiration if timestamped
                if deserterInfo.expires_at and now > deserterInfo.expires_at then
                    WoWKillboardDB.kosDeserters[name] = nil
                    deserterInfo = nil
                else
                    isDeserter = true
                end
            end
        end

        if not isDeserter and guild and guild ~= "None" and WoWKillboardDB.kosGuilds then
            if WoWKillboardDB.kosGuilds[guild] then
                isKosGuild = true
                kosGuildReason = WoWKillboardDB.kosGuilds[guild].reason or "Defeated in Blood Feud / Blacklisted"
            end
        end

        if not isDeserter and not isKosGuild and WoWKillboardDB.kosPlayers then
            if WoWKillboardDB.kosPlayers[name] then
                isKosPlayer = true
                kosPlayerReason = WoWKillboardDB.kosPlayers[name].reason or "Branded KOS"
            end
        end
    end

    if isDeserter or isKosGuild or isKosPlayer then
        US.LastAlertTime[name] = now
        PlaySound(8959) -- Air-raid alarm sound

        if isDeserter then
            local former = deserterInfo and deserterInfo.former_guild or guild or "Enemy Guild"
            print(string.format("|cffff0000[🚨 KOS DESERTER DETECTED]|r |cffffd100%s|r (Ex-Guild: |cffff5555<%s>|r) - SERVING 30-DAY DESERTER PENANCE! KILL ON SIGHT!",
                name, former))
            if KB.UI and KB.UI.ShowKOSAlert then
                KB.UI:ShowKOSAlert(name, former, "DESERTER", "Serving 30-Day Deserter Penance")
            end
        elseif isKosGuild then
            print(string.format("|cffff0000[🚨 GUILD KOS BLACKLIST]|r |cffffd100%s|r (<%s>) - CONSIGNED TO THE REALM BLACKLIST (%s)! DESTROY ON SIGHT!",
                name, guild, kosGuildReason))
            if KB.UI and KB.UI.ShowKOSAlert then
                KB.UI:ShowKOSAlert(name, guild, "GUILD_KOS", kosGuildReason)
            end
        elseif isKosPlayer then
            print(string.format("|cffff0000[🚨 ENEMY KOS TARGET]|r |cffffd100%s|r is BRANDED KOS (%s)! ENGAGE IMMEDIATELY!",
                name, kosPlayerReason))
            if KB.UI and KB.UI.ShowKOSAlert then
                KB.UI:ShowKOSAlert(name, guild, "PLAYER_KOS", kosPlayerReason)
            end
        end
        return true
    end
    return false
end

US.LastRadarAlert = US.LastRadarAlert or {}

-- Tactical radar telemetry notice when an enemy player hostile is spotted
function US:CheckHostileRadar(info)
    if not info or not info.name then return end
    local s = WoWKillboardSettings or KB.DefaultSettings
    if s and s.enableRadarAlerts == false then return end

    local name = info.name
    local now = time()
    if (now - (US.LastRadarAlert[name] or 0)) < 30 then
        return
    end
    US.LastRadarAlert[name] = now

    local guildTag = (info.guild and info.guild ~= "None" and info.guild ~= "") and (" <" .. info.guild .. ">") or ""
    local classStr = (KB.Utils and KB.Utils.ColorizeByClass) and KB.Utils.ColorizeByClass(info.class or "HOSTILE", info.class) or (info.class or "HOSTILE")
    local levelStr = (info.level and info.level > 0) and tostring(info.level) or "??"
    local zoneStr = GetZoneText() or "Wilderness"

    print(string.format("|cff00ccff[WoWKB Radar]|r Detected Hostile: |cffff3333%s|r%s (Lvl %s %s) in |cffffffff%s|r!",
        name, guildTag, levelStr, classStr, zoneStr))
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
