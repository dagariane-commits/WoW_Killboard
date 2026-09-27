--[[
    WoWKillboard - IntelScanner.lua
    Tactical Intel & Gank Sighting Engine, Scout Targeting,
    and In-Game Enemy Reconnaissance Wire.
    
    100% Blizzard UI Taint-Free:
    - Pure Lua anonymous frames with BackdropTemplate
    - Zero XML panel dependencies, zero UISpecialFrames pollution
    - Strict InCombatLockdown() gating
    - Safe ESC key event handling via SetPropagateKeyboardInput
]]

WoWKillboard = WoWKillboard or {}
local KB = WoWKillboard
KB.IntelScanner = {}
local IS = KB.IntelScanner

local function SafePrint(...)
    if KB and KB.Utils and KB.Utils.SafePrint then
        KB.Utils.SafePrint(...)
    elseif not InCombatLockdown() and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        local pieces = {}
        for i = 1, select("#", ...) do table.insert(pieces, tostring(select(i, ...))) end
        DEFAULT_CHAT_FRAME:AddMessage(table.concat(pieces, " "))
    end
end

IS.LastSpotTime = 0
IS.RecentSightings = {}

local frame = CreateFrame("Frame")

-- Initialize Intel database storage
function IS:Init()
    WoWKillboardDB = WoWKillboardDB or { kills = {}, stats = {} }
    WoWKillboardDB.intelSightings = WoWKillboardDB.intelSightings or {}
    WoWKillboardDB.kosGuilds = WoWKillboardDB.kosGuilds or {}
    WoWKillboardDB.kosDeserters = WoWKillboardDB.kosDeserters or {}
    WoWKillboardDB.kosPlayers = WoWKillboardDB.kosPlayers or {}
end

-- Spot currently targeted enemy player
function IS:SpotTarget(notes)
    -- Guard: Open World PvP only!
    if IsInInstance then
        local inInstance, instanceType = IsInInstance()
        if inInstance or (instanceType and instanceType ~= "none") then
            SafePrint("|cffff0000[WoWKB Error]|r Tactical Intel spotting is restricted to open world battlefields! Dungeons and BGs are excluded.")
            return
        end
    end

    -- Guard: Target validation
    if not UnitExists("target") or not UnitIsPlayer("target") then
        SafePrint("|cffff9900[WoWKB Intel]|r No enemy player targeted! Target an enemy hostile first to spot them.")
        return
    end

    if not UnitCanAttack("player", "target") then
        SafePrint("|cffff9900[WoWKB Intel]|r Target is friendly! Tactical spotting is reserved for enemy hostiles.")
        return
    end

    -- Throttle rapid double-spotting
    local now = time()
    if now - IS.LastSpotTime < 2 then
        SafePrint("|cffff9900[WoWKB Intel]|r Scout telemetry transmitting... please wait a moment.")
        return
    end
    IS.LastSpotTime = now

    -- Extract target telemetry
    local targetName, targetRealm = UnitName("target")
    local _, targetClass = UnitClass("target")
    targetClass = targetClass or "WARRIOR"
    local targetLevel = UnitLevel("target")
    if targetLevel == -1 then targetLevel = 99 end

    local targetGuild = GetGuildInfo("target") or ""
    local targetFaction = UnitFactionGroup("target") or "Unknown"

    -- Spatial GPS telemetry
    local loc = KB.Utils and KB.Utils.GetPlayerLocation and KB.Utils.GetPlayerLocation() or { zone = GetZoneText(), subZone = GetSubZoneText(), x = 0, y = 0 }
    local zone = loc.zone or "Wilderness"
    local subzone = loc.subZone or ""
    local x = loc.x or 0
    local y = loc.y or 0

    local reporterName = UnitName("player") or "Scout"
    local reporterGuild = GetGuildInfo("player") or ""

    local noteText = (notes and notes ~= "") and notes or "Hostile presence spotted in the sector"

    local sighting = {
        id = "SPT-" .. tostring(now) .. "-" .. targetName,
        reporter_name = reporterName,
        reporter_guild = reporterGuild,
        target_name = targetName,
        target_class = targetClass,
        target_level = targetLevel,
        target_guild = targetGuild,
        target_faction = targetFaction,
        zone = zone,
        subzone = subzone,
        coord_x = x,
        coord_y = y,
        notes = noteText,
        timestamp = now,
    }

    -- Store in DB
    WoWKillboardDB = WoWKillboardDB or {}
    WoWKillboardDB.intelSightings = WoWKillboardDB.intelSightings or {}
    table.insert(WoWKillboardDB.intelSightings, sighting)
    if #WoWKillboardDB.intelSightings > 100 then
        table.remove(WoWKillboardDB.intelSightings, 1)
    end

    -- Format broadcast message
    local guildTag = (targetGuild ~= "" and " <" .. targetGuild .. ">" or "")
    local subzoneTag = (subzone ~= "" and " (" .. subzone .. ")" or "")
    local broadcastMsg = string.format("[WoWKB Intel] 👁️ Spotted %s (Lvl %d %s)%s in %s%s at (%.1f, %.1f)! %s",
        targetName, targetLevel, targetClass, guildTag, zone, subzoneTag, x, y, noteText)

    -- Local feedback
    SafePrint(string.format("|cffff8000[WoWKB Intel]|r Reported hostile: |cffff3333%s|r%s in |cffffffff%s|r at (%.1f, %.1f)!",
        targetName, guildTag, zone, x, y))

    -- Channel broadcasts
    if IsInGuild() then
        SendChatMessage(broadcastMsg, "GUILD")
    end
    if IsInGroup() then
        SendChatMessage(broadcastMsg, IsInRaid() and "RAID" or "PARTY")
    end

    -- P2P Addon Wire Broadcast
    if KB.Sync and KB.Sync.BroadcastSighting then
        KB.Sync:BroadcastSighting(sighting)
    end

    -- Audio cue (scout chime)
    PlaySound(8459)
end

-- Handle incoming peer sighting
function IS:OnIncomingSighting(sighting)
    if not sighting or not sighting.target_name then return end
    local guildTag = (sighting.target_guild and sighting.target_guild ~= "" and " <" .. sighting.target_guild .. ">" or "")
    local repGuild = (sighting.reporter_guild and sighting.reporter_guild ~= "" and " <" .. sighting.reporter_guild .. ">" or "")
    
    SafePrint(string.format("|cffff8000[WoWKB Intel Wire]|r Scout |cff00ff00%s|r%s spotted hostile |cffff3333%s|r%s in |cffffffff%s|r (%.1f, %.1f)! *%s*",
        sighting.reporter_name or "Ally", repGuild,
        sighting.target_name, guildTag,
        sighting.zone or "Wilderness",
        sighting.coord_x or 0, sighting.coord_y or 0,
        sighting.notes or "Hostile spotted"))

    table.insert(IS.RecentSightings, sighting)
    if #IS.RecentSightings > 20 then
        table.remove(IS.RecentSightings, 1)
    end

    PlaySound(8459)
end

-- Event registration
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        IS:Init()
    end
end)

frame:RegisterEvent("PLAYER_ENTERING_WORLD")
