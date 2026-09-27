--[[
    WoWKillboard - Reinforcements.lua
    Call for Backup (SOS) Distress Beacon System, Open Auto-Invite Party Engine,
    and In-Game Guild Defense Alert Dispatcher.
    
    100% Blizzard UI Taint-Free:
    - Pure Lua anonymous frames with BackdropTemplate
    - Zero XML panel dependencies, zero UISpecialFrames pollution
    - Strict InCombatLockdown() gating with deferred delivery via PLAYER_REGEN_ENABLED
    - Safe ESC key event handling via SetPropagateKeyboardInput
]]

WoWKillboard = WoWKillboard or {}
local KB = WoWKillboard
KB.Reinforcements = {}
local RF = KB.Reinforcements

-- Active state tracking
RF.ActiveBeacon = nil
RF.AutoInviteActive = false
RF.AutoInviteExpiry = 0
RF.LastDistressTime = 0
RF.PendingAlerts = {}

local frame = CreateFrame("Frame")

-- Auto-invite whisper keywords
local AUTO_INVITE_KEYWORDS = {
    ["rally"]  = true,
    ["backup"] = true,
    ["invite"] = true,
    ["inv"]    = true,
    ["sos"]    = true,
    ["help"]   = true,
    ["join"]   = true,
    ["squad"]  = true,
    ["war"]    = true,
}

-- Cross-client safe player invitation
local function InvitePlayer(playerName)
    if not playerName or playerName == "" then return end
    if C_PartyInfo and C_PartyInfo.InviteUnit then
        C_PartyInfo.InviteUnit(playerName)
    elseif InviteUnit then
        InviteUnit(playerName)
    end
end

-- Convert group to raid when group size reaches 5
local function EnsureRaidConversion()
    if IsInGroup() and not IsInRaid() and (GetNumGroupMembers() >= 5) and UnitIsGroupLeader("player") then
        if C_PartyInfo and C_PartyInfo.ConvertToRaid then
            C_PartyInfo.ConvertToRaid()
        elseif ConvertToRaid then
            ConvertToRaid()
        end
    end
end

-- Initialize Reinforcements engine
function RF:Init()
    WoWKillboardDB = WoWKillboardDB or { kills = {}, stats = {} }
    WoWKillboardDistress = WoWKillboardDistress or {}
    WoWKillboardEvents = WoWKillboardEvents or {}
end

-- Check if local player currently has an active distress beacon
function RF:IsBeaconActive()
    if RF.ActiveBeacon and RF.AutoInviteActive then
        if time() <= RF.AutoInviteExpiry then
            return true
        else
            RF:ResolveBeacon(true)
            return false
        end
    end
    return false
end

-- Get current beacon location description string
function RF:GetBeaconLocationStr()
    if RF.ActiveBeacon then
        return string.format("%s (%s) at (%.1f, %.1f)",
            RF.ActiveBeacon.zone or "Wilderness",
            (RF.ActiveBeacon.subzone and RF.ActiveBeacon.subzone ~= "") and RF.ActiveBeacon.subzone or "Wilderness",
            RF.ActiveBeacon.coord_x or 0,
            RF.ActiveBeacon.coord_y or 0
        )
    end
    return "Unknown Location"
end

-- Trigger Call for Backup (War Horn Distress Beacon)
function RF:TriggerCallForBackup()
    -- Guard: Open World PvP only!
    if IsInInstance then
        local inInstance, instanceType = IsInInstance()
        if inInstance or (instanceType and instanceType ~= "none") then
            print("|cffff0000[WoWKB Error]|r The War Horn cannot be sounded within dungeons, raids, or battlegrounds! Open world PvP only.")
            return false, "Instances prohibited"
        end
    end

    local now = time()
    if (now - RF.LastDistressTime) < 15 then
        print("|cffff9900[WoWKB War Horn]|r War Horn on cooldown. Please wait a few seconds before sounding the horn again.")
        return false, "Cooldown active"
    end
    RF.LastDistressTime = now

    -- Gather real-time spatial GPS coordinates
    local mapId, zone, subzone, coordX, coordY = 0, "Unknown Zone", "", 0, 0
    if KB.Utils and KB.Utils.GetPlayerLocation then
        local loc = KB.Utils.GetPlayerLocation()
        mapId = loc.mapId or 0
        zone = (loc.zone and loc.zone ~= "") and loc.zone or (GetZoneText() or "Wilderness")
        subzone = (loc.subZone and loc.subZone ~= "") and loc.subZone or (GetSubZoneText() or "")
        coordX = loc.x or 0
        coordY = loc.y or 0
    elseif KB.Utils and KB.Utils.GetGPSCoordinates then
        mapId, zone, subzone, coordX, coordY = KB.Utils.GetGPSCoordinates()
    else
        zone = GetZoneText() or "Wilderness"
        subzone = GetSubZoneText() or ""
    end
    local coordsFormatted = string.format("%.1f, %.1f", coordX, coordY)

    -- Gather hostile attackers from combat tracker
    local hostileNames = {}
    local hostileCount = 0
    local myGUID = UnitGUID("player")

    if KB.CombatTracker then
        -- Check recent damage dealt to local player
        if KB.CombatTracker.RecentDamage and myGUID and KB.CombatTracker.RecentDamage[myGUID] then
            for attGUID, attData in pairs(KB.CombatTracker.RecentDamage[myGUID]) do
                if (now - (attData.lastTime or 0)) <= 25 then
                    local name = attData.name or "Unknown Hostile"
                    table.insert(hostileNames, name)
                    hostileCount = hostileCount + 1
                end
            end
        end

        -- Check hostile cluster proximity
        if hostileCount == 0 and KB.CombatTracker.HostileCluster then
            for hGUID, hTime in pairs(KB.CombatTracker.HostileCluster) do
                if (now - hTime) <= 25 then
                    hostileCount = hostileCount + 1
                end
            end
        end
    end

    -- Check current target if hostile player
    if hostileCount == 0 and UnitExists("target") and UnitCanAttack("player", "target") and UnitIsPlayer("target") then
        local tName = UnitName("target")
        if tName then
            table.insert(hostileNames, tName)
            hostileCount = 1
        end
    end

    if hostileCount == 0 then
        hostileCount = 1
        table.insert(hostileNames, "Enemy Hostiles")
    end

    local hostileNamesStr = table.concat(hostileNames, ", ")
    local myName = UnitName("player")
    local _, myClass = UnitClass("player")
    myClass = myClass or "WARRIOR"
    local myLevel = UnitLevel("player") or 60
    local myGuild = GetGuildInfo("player") or "None"
    local myFaction = UnitFactionGroup("player") or "Unknown"

    -- Construct distress beacon payload
    local beaconId = string.format("SOS-%d-%s", now, myName)
    local beacon = {
        id = beaconId,
        character_name = myName,
        character_class = myClass,
        character_level = myLevel,
        guild_name = myGuild,
        faction = myFaction,
        zone = zone,
        subzone = subzone or "",
        coord_x = coordX,
        coord_y = coordY,
        hostile_count = hostileCount,
        hostile_names = hostileNamesStr,
        timestamp = now,
        status = "ACTIVE",
    }

    RF.ActiveBeacon = beacon
    RF.AutoInviteActive = true
    RF.AutoInviteExpiry = now + 600 -- 10 minutes open auto-invite window

    -- Persist into SavedVariables for desktop sync watcher ingestion
    WoWKillboardDB = WoWKillboardDB or {}
    WoWKillboardDB.distressBeacon = beacon
    WoWKillboardDistress = WoWKillboardDistress or {}
    WoWKillboardDistress[beaconId] = beacon

    -- Play alert siren
    PlaySound(8959)

    -- Local system notice
    print(string.format("|cffff0000[WoWKB WAR HORN]|r |cffffffffTHE WAR HORN SOUNDS!|r Broadcasting frontline coordinates |cff00ffcc(%s)|r in |cffffd100%s|r.", coordsFormatted, zone))
    print("|cff00ccff[WoWKB WAR HORN]|r War Party Muster is |cff00ff00ACTIVE|r. Anyone whispering |cffffd100'rally'|r, |cffffd100'backup'|r, or |cffffd100'invite'|r will automatically join your unit.")

    -- Broadcast to Guild Chat
    if IsInGuild() then
        SendChatMessage(string.format("[WoWKillboard] 📯 WAR HORN SOUNDED! Vanguard under attack in %s (%s) by %d hostile(s) (%s)! Whisper 'rally' or 'invite' to muster!",
            zone, coordsFormatted, hostileCount, hostileNamesStr), "GUILD")
    end

    -- Broadcast to Group/Raid
    if IsInGroup() then
        SendChatMessage(string.format("[WoWKillboard] 📯 CALL TO ARMS: %s (%s) engaged by %s! Whisper 'rally' to reinforce!",
            zone, coordsFormatted, hostileNamesStr), IsInRaid() and "RAID" or "PARTY")
    end

    -- Local Yell (if outside instances)
    local inInstance = IsInInstance()
    if not inInstance then
        SendChatMessage(string.format("[WoWKillboard] 📯 WAR HORN SOUNDED at %s (%s)! Engaged by %s! To arms!",
            zone, coordsFormatted, hostileNamesStr), "YELL")
    end

    -- Broadcast via P2P Addon Network across Guild and Party
    if KB.Sync and KB.Sync.BroadcastDistress then
        KB.Sync:BroadcastDistress(beacon)
    end

    return true, beacon
end

-- Resolve / Cancel active distress beacon
function RF:ResolveBeacon(silent)
    if not RF.ActiveBeacon and not RF.AutoInviteActive then return end

    if RF.ActiveBeacon then
        RF.ActiveBeacon.status = "RESOLVED"
        if WoWKillboardDB and WoWKillboardDB.distressBeacon then
            WoWKillboardDB.distressBeacon.status = "RESOLVED"
        end
        if WoWKillboardDistress and RF.ActiveBeacon.id and WoWKillboardDistress[RF.ActiveBeacon.id] then
            WoWKillboardDistress[RF.ActiveBeacon.id].status = "RESOLVED"
        end
    end

    RF.ActiveBeacon = nil
    RF.AutoInviteActive = false
    RF.AutoInviteExpiry = 0

    if not silent then
        print("|cff00ff00[WoWKB WAR HORN]|r The front is secured. War Horn dismissed and recruitment closed.")
        if IsInGuild() then
            SendChatMessage("[WoWKillboard] ⚔️ The front is secured. The enemy has fallen or retreated. War Horn dismissed. Blood and Honor!", "GUILD")
        end
    end

    if KB.Sync and KB.Sync.BroadcastDistressResolve then
        KB.Sync:BroadcastDistressResolve()
    end
end

-- Handle incoming whisper for auto-invite
function RF:OnWhisper(msg, sender)
    if not RF:IsBeaconActive() then return end
    if not msg or not sender then return end

    local cleanMsg = msg:lower():match("^%s*(.-)%s*$")
    if AUTO_INVITE_KEYWORDS[cleanMsg] then
        EnsureRaidConversion()
        InvitePlayer(sender)
        local loc = RF:GetBeaconLocationStr()
        SendChatMessage(string.format("[WoWKillboard] Drafting you into the Vanguard! Rally coordinates: %s. Watch for enemy hostiles!", loc), "WHISPER", nil, sender)
    end
end

-- Process incoming distress alert from peer addon
function RF:OnIncomingDistress(beaconData)
    if not beaconData or not beaconData.character_name then return end
    local myName = UnitName("player")
    if beaconData.character_name == myName then return end

    -- Persist into SavedVariables for Rallies tab display
    WoWKillboardDistress = WoWKillboardDistress or {}
    local bId = beaconData.id or string.format("SOS-%d-%s", beaconData.timestamp or time(), beaconData.character_name)
    beaconData.id = bId
    beaconData.status = "ACTIVE"
    WoWKillboardDistress[bId] = beaconData

    -- Play warning siren
    PlaySound(8959)

    -- Print tactical notification to chat frame
    local coordsStr = string.format("%.1f, %.1f", beaconData.coord_x or 0, beaconData.coord_y or 0)
    print(string.format("|cffff2222[WoWKB WAR HORN ALERT]|r |cffffd100%s|r (%s) is engaged in mortal combat in |cff00ccff%s|r at |cff00ffcc(%s)|r! Swarmed by |cffff4444%d|r hostiles (%s). Whisper |cffffd100'/w %s rally'|r to join the war party!",
        beaconData.character_name,
        beaconData.character_class or "WARRIOR",
        beaconData.zone or "Wilderness",
        coordsStr,
        beaconData.hostile_count or 1,
        beaconData.hostile_names or "Hostiles",
        beaconData.character_name
    ))

    -- Queue alert if in combat lockdown
    if InCombatLockdown() then
        table.insert(RF.PendingAlerts, beaconData)
    else
        if KB.UI and KB.UI.ShowReinforcementAlert then
            KB.UI:ShowReinforcementAlert(beaconData)
        end
    end
end

-- Fetch all open rallies for player's faction (sorted by newest)
function RF:GetOpenRallies()
    RF:Init()
    local myFaction = UnitFactionGroup("player") or "Unknown"
    local myName = UnitName("player")
    local openRallies = {}
    local now = time()

    -- 1. Local Player's own beacon (if active)
    if RF:IsBeaconActive() and RF.ActiveBeacon then
        local b = RF.ActiveBeacon
        table.insert(openRallies, {
            id = b.id or ("SOS-" .. (b.timestamp or now)),
            character_name = b.character_name or myName,
            character_class = b.character_class or "WARRIOR",
            character_level = b.character_level or 60,
            guild_name = b.guild_name or "None",
            faction = b.faction or myFaction,
            zone = b.zone or "Wilderness",
            subzone = b.subzone or "",
            coord_x = b.coord_x or 0,
            coord_y = b.coord_y or 0,
            hostile_count = b.hostile_count or 1,
            hostile_names = b.hostile_names or "Hostiles",
            timestamp = b.timestamp or now,
            status = "ACTIVE",
            isSelf = true,
        })
    end

    -- 2. Peer beacons in WoWKillboardDistress
    if WoWKillboardDistress then
        for bId, b in pairs(WoWKillboardDistress) do
            if b.status == "ACTIVE" and (now - (b.timestamp or now)) < 1800 then -- 30 min window
                if b.character_name and b.character_name ~= myName then
                    -- Filter by same faction
                    if not b.faction or b.faction == "Unknown" or b.faction == myFaction then
                        table.insert(openRallies, {
                            id = b.id or bId,
                            character_name = b.character_name,
                            character_class = b.character_class or "WARRIOR",
                            character_level = b.character_level or 60,
                            guild_name = b.guild_name or "None",
                            faction = b.faction or myFaction,
                            zone = b.zone or "Wilderness",
                            subzone = b.subzone or "",
                            coord_x = b.coord_x or 0,
                            coord_y = b.coord_y or 0,
                            hostile_count = b.hostile_count or 1,
                            hostile_names = b.hostile_names or "Hostiles",
                            timestamp = b.timestamp or now,
                            status = "ACTIVE",
                            isSelf = false,
                        })
                    end
                end
            end
        end
    end

    -- Sort by newest first
    table.sort(openRallies, function(a, b) return (a.timestamp or 0) > (b.timestamp or 0) end)
    return openRallies
end

-- Request to join an active rally via auto-invite whisper
function RF:RequestJoinRally(leaderName)
    if not leaderName or leaderName == "" then return false end
    SendChatMessage("rally", "WHISPER", nil, leaderName)
    print(string.format("|cff00ff00[WoWKB Rally]|r Sent join request to Vanguard commander |cffffd100%s|r! Awaiting squad invite...", leaderName))
    return true
end

-- Frame event dispatcher
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_WHISPER" then
        local msg, sender = ...
        RF:OnWhisper(msg, sender)
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Deliver any queued reinforcement alerts safely outside combat lockdown
        if #RF.PendingAlerts > 0 and not InCombatLockdown() then
            for _, alertData in ipairs(RF.PendingAlerts) do
                if KB.UI and KB.UI.ShowReinforcementAlert then
                    KB.UI:ShowReinforcementAlert(alertData)
                end
            end
            RF.PendingAlerts = {}
        end
    elseif event == "PLAYER_LOGIN" then
        RF:Init()
    end
end)

frame:RegisterEvent("CHAT_MSG_WHISPER")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_LOGIN")
