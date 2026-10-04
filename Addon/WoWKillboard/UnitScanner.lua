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

    realm = (realm and KB.Utils.CanAccess(realm) and realm ~= "") and realm or GetRealmName()
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
    local guildName = (not InCombatLockdown() and GetGuildInfo and GetGuildInfo(unit)) or "None"
    guildName = KB.Utils.CanAccess(guildName) and guildName or "None"

    -- If level is -1 (skull level / >10 lvls higher), check C_PlayerInfo or format as ?? (level 0)
    if level == -1 then
        if C_PlayerInfo and C_PlayerInfo.GetPlayerLevelByGUID then
            local pLvl = C_PlayerInfo.GetPlayerLevelByGUID(guid)
            if pLvl and pLvl > 0 and pLvl <= 85 then
                level = pLvl
            else
                level = 0
            end
        else
            level = 0
        end
    elseif level > 85 then
        level = 0
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

    -- Persist to Known Characters Directory in WoWKillboardDB
    WoWKillboardDB = WoWKillboardDB or {}
    WoWKillboardDB.characters = WoWKillboardDB.characters or {}
    local charEntry = WoWKillboardDB.characters[name] or {}
    charEntry.name = name
    charEntry.realm = realm
    charEntry.guid = guid
    if classFilename and classFilename ~= "UNKNOWN" then
        charEntry.class = classFilename
    end
    if race and race ~= "Unknown" then
        charEntry.race = race
    end
    if info.level > 0 then
        charEntry.level = info.level
    end
    if englishFaction and englishFaction ~= "Unknown" then
        charEntry.faction = englishFaction
    end
    if guildName and guildName ~= "None" then
        charEntry.guild = guildName
    end
    charEntry.lastSeen = time()
    WoWKillboardDB.characters[name] = charEntry

    -- KOS Blacklist & Hostile Radar Check (Hostile player units only, gated against InCombatLockdown)
    if not InCombatLockdown() and UnitCanAttack and UnitCanAttack("player", unit) and UnitIsPlayer(unit) then
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
            KB.Utils.SafePrint(string.format("|cffff0000[KOS DESERTER DETECTED]|r |cffffd100%s|r (Ex-Guild: |cffff5555<%s>|r) - SERVING 30-DAY DESERTER PENANCE! KILL ON SIGHT!",
                name, former))
            if KB.UI and KB.UI.ShowKOSAlert then
                KB.UI:ShowKOSAlert(name, former, "DESERTER", "Serving 30-Day Deserter Penance")
            end
        elseif isKosGuild then
            KB.Utils.SafePrint(string.format("|cffff0000[GUILD KOS BLACKLIST]|r |cffffd100%s|r (<%s>) - CONSIGNED TO THE REALM BLACKLIST (%s)! DESTROY ON SIGHT!",
                name, guild, kosGuildReason))
            if KB.UI and KB.UI.ShowKOSAlert then
                KB.UI:ShowKOSAlert(name, guild, "GUILD_KOS", kosGuildReason)
            end
        elseif isKosPlayer then
            KB.Utils.SafePrint(string.format("|cffff0000[ENEMY KOS TARGET]|r |cffffd100%s|r is BRANDED KOS (%s)! ENGAGE IMMEDIATELY!",
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
    if (now - (US.LastRadarAlert[name] or 0)) < 15 then
        return
    end
    US.LastRadarAlert[name] = now

    -- Pass spotted hostile to the floating moveable Radar HUD
    if KB.UI and KB.UI.UpdateRadarHUD then
        KB.UI:UpdateRadarHUD(info)
    end

    -- Mute chat spam by default; only print if radarChatAlerts is explicitly enabled
    if s and s.radarChatAlerts then
        local guildTag = (info.guild and info.guild ~= "None" and info.guild ~= "") and (" <" .. info.guild .. ">") or ""
        local classStr = (KB.Utils and KB.Utils.ColorizeByClass) and KB.Utils.ColorizeByClass(info.class or "HOSTILE", info.class) or (info.class or "HOSTILE")
        local levelStr = (info.level and info.level > 0) and tostring(info.level) or "??"
        local zoneStr = GetZoneText() or "Wilderness"

        KB.Utils.SafePrint(string.format("|cff00ccff[WoWKB Radar]|r Detected Hostile: |cffff3333%s|r%s (Lvl %s %s) in |cffffffff%s|r!",
            name, guildTag, levelStr, classStr, zoneStr))
    end
end


-- Known class ability signature dictionary for proactive combat sniffing
local CLASS_SPELL_SIGNATURES = {
    -- WARRIOR
    ["Charge"] = "WARRIOR",
    ["Intercept"] = "WARRIOR",
    ["Heroic Strike"] = "WARRIOR",
    ["Mortal Strike"] = "WARRIOR",
    ["Bloodthirst"] = "WARRIOR",
    ["Shield Slam"] = "WARRIOR",
    ["Overpower"] = "WARRIOR",
    ["Rend"] = "WARRIOR",
    ["Battle Shout"] = "WARRIOR",
    ["Sunder Armor"] = "WARRIOR",
    ["Thunder Clap"] = "WARRIOR",
    ["Whirlwind"] = "WARRIOR",
    ["Execute"] = "WARRIOR",
    ["Shield Block"] = "WARRIOR",
    ["Pummel"] = "WARRIOR",
    ["Hamstring"] = "WARRIOR",
    ["Demoralizing Shout"] = "WARRIOR",
    ["Berserker Rage"] = "WARRIOR",
    ["Bloodrage"] = "WARRIOR",
    ["Sweeping Strikes"] = "WARRIOR",
    ["Disarm"] = "WARRIOR",

    -- PALADIN
    ["Judgement"] = "PALADIN",
    ["Holy Light"] = "PALADIN",
    ["Flash of Light"] = "PALADIN",
    ["Blessing of Might"] = "PALADIN",
    ["Blessing of Protection"] = "PALADIN",
    ["Hammer of Justice"] = "PALADIN",
    ["Consecration"] = "PALADIN",
    ["Seal of Righteousness"] = "PALADIN",
    ["Seal of Command"] = "PALADIN",
    ["Lay on Hands"] = "PALADIN",
    ["Divine Shield"] = "PALADIN",
    ["Exorcism"] = "PALADIN",
    ["Hammer of Wrath"] = "PALADIN",
    ["Cleanse"] = "PALADIN",

    -- ROGUE
    ["Sinister Strike"] = "ROGUE",
    ["Eviscerate"] = "ROGUE",
    ["Backstab"] = "ROGUE",
    ["Stealth"] = "ROGUE",
    ["Gouge"] = "ROGUE",
    ["Kidney Shot"] = "ROGUE",
    ["Ambush"] = "ROGUE",
    ["Sprint"] = "ROGUE",
    ["Vanish"] = "ROGUE",
    ["Cheap Shot"] = "ROGUE",
    ["Blind"] = "ROGUE",
    ["Sap"] = "ROGUE",
    ["Slice and Dice"] = "ROGUE",
    ["Rupture"] = "ROGUE",
    ["Garrote"] = "ROGUE",
    ["Kick"] = "ROGUE",

    -- HUNTER
    ["Auto Shot"] = "HUNTER",
    ["Aimed Shot"] = "HUNTER",
    ["Arcane Shot"] = "HUNTER",
    ["Multi-Shot"] = "HUNTER",
    ["Serpent Sting"] = "HUNTER",
    ["Hunter's Mark"] = "HUNTER",
    ["Concussive Shot"] = "HUNTER",
    ["Feign Death"] = "HUNTER",
    ["Disengage"] = "HUNTER",
    ["Raptor Strike"] = "HUNTER",
    ["Wing Clip"] = "HUNTER",
    ["Explosive Trap"] = "HUNTER",
    ["Freezing Trap"] = "HUNTER",

    -- MAGE
    ["Frostbolt"] = "MAGE",
    ["Fireball"] = "MAGE",
    ["Arcane Missiles"] = "MAGE",
    ["Fire Blast"] = "MAGE",
    ["Frost Nova"] = "MAGE",
    ["Blink"] = "MAGE",
    ["Polymorph"] = "MAGE",
    ["Arcane Explosion"] = "MAGE",
    ["Blizzard"] = "MAGE",
    ["Cone of Cold"] = "MAGE",
    ["Pyroblast"] = "MAGE",
    ["Scorch"] = "MAGE",
    ["Ice Barrier"] = "MAGE",
    ["Ice Block"] = "MAGE",

    -- WARLOCK
    ["Shadow Bolt"] = "WARLOCK",
    ["Corruption"] = "WARLOCK",
    ["Immolate"] = "WARLOCK",
    ["Life Tap"] = "WARLOCK",
    ["Curse of Agony"] = "WARLOCK",
    ["Drain Life"] = "WARLOCK",
    ["Fear"] = "WARLOCK",
    ["Searing Pain"] = "WARLOCK",
    ["Hellfire"] = "WARLOCK",
    ["Rain of Fire"] = "WARLOCK",
    ["Soul Fire"] = "WARLOCK",
    ["Death Coil"] = "WARLOCK",
    ["Shadowburn"] = "WARLOCK",
    ["Conflagrate"] = "WARLOCK",

    -- PRIEST
    ["Smite"] = "PRIEST",
    ["Shadow Word: Pain"] = "PRIEST",
    ["Power Word: Shield"] = "PRIEST",
    ["Lesser Heal"] = "PRIEST",
    ["Heal"] = "PRIEST",
    ["Flash Heal"] = "PRIEST",
    ["Greater Heal"] = "PRIEST",
    ["Renew"] = "PRIEST",
    ["Mind Blast"] = "PRIEST",
    ["Mind Flay"] = "PRIEST",
    ["Psychic Scream"] = "PRIEST",
    ["Dispel Magic"] = "PRIEST",
    ["Holy Nova"] = "PRIEST",

    -- SHAMAN
    ["Lightning Bolt"] = "SHAMAN",
    ["Chain Lightning"] = "SHAMAN",
    ["Earth Shock"] = "SHAMAN",
    ["Flame Shock"] = "SHAMAN",
    ["Frost Shock"] = "SHAMAN",
    ["Healing Wave"] = "SHAMAN",
    ["Lesser Healing Wave"] = "SHAMAN",
    ["Chain Heal"] = "SHAMAN",
    ["Purge"] = "SHAMAN",
    ["Ghost Wolf"] = "SHAMAN",

    -- DRUID
    ["Wrath"] = "DRUID",
    ["Moonfire"] = "DRUID",
    ["Rejuvenation"] = "DRUID",
    ["Healing Touch"] = "DRUID",
    ["Regrowth"] = "DRUID",
    ["Entangling Roots"] = "DRUID",
    ["Maul"] = "DRUID",
    ["Claw"] = "DRUID",
    ["Shred"] = "DRUID",
    ["Rake"] = "DRUID",
    ["Rip"] = "DRUID",
    ["Ferocious Bite"] = "DRUID",
    ["Swipe"] = "DRUID",
}

function US:InferClassFromSpell(guid, name, spellName)
    if not spellName then return nil end
    local detectedClass = CLASS_SPELL_SIGNATURES[spellName]
    if not detectedClass then return nil end

    if guid and KB.Utils.CanAccess(guid) then
        local entry = US.Cache[guid] or { guid = guid, name = name or "Unknown", level = 0, guild = "None", faction = "Unknown" }
        if not entry.class or entry.class == "UNKNOWN" then
            entry.class = detectedClass
        end
        US.Cache[guid] = entry
    end
    if name and KB.Utils.CanAccess(name) then
        local existingGUID = US.NameCache[name]
        if existingGUID and US.Cache[existingGUID] then
            if not US.Cache[existingGUID].class or US.Cache[existingGUID].class == "UNKNOWN" then
                US.Cache[existingGUID].class = detectedClass
            end
        elseif guid then
            US.NameCache[name] = guid
        end
    end
    return detectedClass
end

-- Retrieve cached unit info by GUID or name
function US:GetUnitInfo(guid)
    if not guid or not KB.Utils.CanAccess(guid) then return nil end
    return US.Cache[guid]
end

function US:GetUnitInfoByName(name)
    if not name or not KB.Utils.CanAccess(name) then return nil end
    local guid = US.NameCache[name]
    if guid and KB.Utils.CanAccess(guid) and US.Cache[guid] then
        return US.Cache[guid]
    end
    if WoWKillboardDB and WoWKillboardDB.characters and WoWKillboardDB.characters[name] then
        return WoWKillboardDB.characters[name]
    end
    return nil
end

-- Get total number of unique characters indexed by the scanner directory
function US:GetKnownCharactersCount()
    if not WoWKillboardDB or not WoWKillboardDB.characters then return 0 end
    local count = 0
    for _ in pairs(WoWKillboardDB.characters) do
        count = count + 1
    end
    return count
end

-- Event handler for unit scanner (100% taint-free, zero secure nameplate hooks)
frame:SetScript("OnEvent", function(self, event, unit)
    if InCombatLockdown() then return end
    if event == "PLAYER_TARGET_CHANGED" then
        US:ScanUnit("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        US:ScanUnit("mouseover")
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
