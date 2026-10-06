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

local function SafePrint(...)
    if KB and KB.Utils and KB.Utils.SafePrint then
        KB.Utils.SafePrint(...)
    elseif not InCombatLockdown() and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        local pieces = {}
        for i = 1, select("#", ...) do table.insert(pieces, tostring(select(i, ...))) end
        DEFAULT_CHAT_FRAME:AddMessage(table.concat(pieces, " "))
    end
end

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
    if InCombatLockdown() then return end
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
        local s = WoWKillboardSettings or (KB.DefaultSettings or {})
        if s.includeCoordinates ~= false then
            return string.format("%s (%.1f, %.1f)",
                RF.ActiveBeacon.zone or "Wilderness",
                RF.ActiveBeacon.coord_x or 0,
                RF.ActiveBeacon.coord_y or 0
            )
        else
            return RF.ActiveBeacon.zone or "Wilderness"
        end
    end
    return "Unknown Location"
end

-- Trigger Call for Backup (World PvP / Defense Alert)
function RF:TriggerCallForBackup()
    -- Guard: Open World PvP only!
    if IsInInstance then
        local inInstance, instanceType = IsInInstance()
        if inInstance or (instanceType and instanceType ~= "none") then
            SafePrint("|cffff0000[WoWKB Error]|r Defense alerts cannot be dispatched within dungeons, raids, or battlegrounds! Open world PvP only.")
            return false, "Instances prohibited"
        end
    end

    local now = time()
    if (now - RF.LastDistressTime) < 15 then
        SafePrint("|cffff9900[WoWKB Alert]|r Defense alert on cooldown. Please wait a few seconds before calling again.")
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

    -- Gather hostile attackers from combat tracker
    local hostileNames = {}
    local hostileCount = 0
    local myGUID = UnitGUID("player")

    if KB.CombatTracker then
        -- Check recent damage dealt to local player
        if KB.CombatTracker.RecentDamage and myGUID and KB.CombatTracker.RecentDamage[myGUID] then
            for attGUID, attData in pairs(KB.CombatTracker.RecentDamage[myGUID]) do
                if (now - (attData.lastTime or 0)) <= 25 then
                    local name = attData.name or "Hostile"
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
    end

    local hostileNamesStr = #hostileNames > 0 and table.concat(hostileNames, ", ") or "1 Hostile"
    local myName = UnitName("player") or "Player"
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

    -- User settings
    local s = WoWKillboardSettings or (KB.DefaultSettings or {})
    local enableChat = (s.enableChatBroadcasts == true)
    local enableGuild = (s.enableGuildBroadcasts ~= false)
    local includeCoords = (s.includeCoordinates ~= false)
    local enableAutoInvite = (s.enableWhisperAutoInvite ~= false)

    -- Coordinates formatting
    local coordsFormatted = string.format("%.1f, %.1f", coordX, coordY)
    local coordsStr = includeCoords and string.format(" (%s)", coordsFormatted) or ""
    local autoInviteStr = enableAutoInvite and ". Auto-invite: whisper 'invite'" or "."

    -- Determine tactical threat and threatSummary
    local threat
    local threatSummary
    if hostileCount > 1 then
        threat = string.format("%d Hostiles", hostileCount)
        threatSummary = string.format("%d Hostiles", hostileCount)
    elseif #hostileNames > 0 and hostileNames[1] ~= "Hostile" and hostileNames[1] ~= "1 Hostile" then
        threat = hostileNames[1]
        threatSummary = hostileNames[1]
    else
        threat = "1 Hostile"
        threatSummary = "1 Hostile"
    end

    -- Format A: Local / Yell Callout (World PvP / Defense):
    -- [WoWKB] Under attack: <Zone> (<Coords>) vs <Threat>!
    -- Example: [WoWKB] Under attack: Stormwind City (66.7, 42.4) vs Defias Pillager!
    local yellMsg = string.format("[WoWKB] Under attack: %s%s vs %s!", zone, coordsStr, threat)

    -- Format B: Guild / Party / Raid Callout (Call for Backup):
    -- [WoWKB] PvP Alert: <Player> engaged in <Zone> (<Coords>) by <ThreatSummary>. Auto-invite: whisper 'invite'
    -- Example: [WoWKB] PvP Alert: Dagariane engaged in Stormwind City (66.7, 42.4) by 1 Hostile. Auto-invite: whisper 'invite'
    local backupMsg = string.format("[WoWKB] PvP Alert: %s engaged in %s%s by %s%s", myName, zone, coordsStr, threatSummary, autoInviteStr)

    -- Local system notice
    SafePrint(string.format("|cff00e5ff[WoWKB Alert]|r Defense alert dispatched for |cffffd100%s|r%s.", zone, coordsStr))
    if enableAutoInvite then
        SafePrint("|cff00ccff[WoWKB]|r Auto-invite active: whispering 'invite' or 'rally' will join the squad.")
    end

    -- Broadcast to Guild Chat (Default: On)
    if IsInGuild() and enableGuild then
        SendChatMessage(backupMsg, "GUILD")
    end

    -- Broadcast to Group/Raid
    if IsInGroup() then
        SendChatMessage(backupMsg, IsInRaid() and "RAID" or "PARTY")
    end

    -- Local Yell (Default: Off / Opt-in, strictly outside combat)
    local inInstance = IsInInstance and IsInInstance()
    if enableChat and not inInstance and not InCombatLockdown() then
        pcall(SendChatMessage, yellMsg, "YELL")
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
        SafePrint("|cff00ff00[WoWKB Alert]|r Area secured. Defense alert resolved.")
        local s = WoWKillboardSettings or (KB.DefaultSettings or {})
        if IsInGuild() and (s.enableGuildBroadcasts ~= false) then
            SendChatMessage("[WoWKB] Threat resolved. Area secured.", "GUILD")
        end
    end

    if KB.Sync and KB.Sync.BroadcastDistressResolve then
        KB.Sync:BroadcastDistressResolve()
    end
end

-- Create a custom Vanguard War Council Rally with rich metadata
function RF:CreateCustomRally(params)
    params = params or {}
    local now = time()
    local myName = UnitName("player") or "Player"
    local _, myClass = UnitClass("player")
    myClass = myClass or "WARRIOR"
    local myLevel = UnitLevel("player") or 60
    local myGuild = GetGuildInfo("player") or "None"
    local myFaction = UnitFactionGroup("player") or "Alliance"

    local groupType = params.groupType or "PARTY" -- "PARTY" (5-Man) or "RAID" (40-Man)
    local contentType = params.contentType or "WORLD" -- "WORLD" (Open World PvP) or "BG" (Battleground)
    local zone = params.zone or GetZoneText() or "Azeroth"
    local subzone = params.subzone or GetSubZoneText() or ""
    local minLevel = tonumber(params.minLevel) or 1
    local maxLevel = tonumber(params.maxLevel) or 60
    local roles = params.roles or { tank = true, heal = true, dps = true }
    local message = params.message or "Muster Vanguard Strike Team!"

    local loc = KB.Utils and KB.Utils.GetPlayerLocation and KB.Utils.GetPlayerLocation()
    local coordX = (loc and loc.x) or 0
    local coordY = (loc and loc.y) or 0

    local rallyId = string.format("RALLY-%d-%s", now, myName)
    local rally = {
        id = rallyId,
        character_name = myName,
        character_class = myClass,
        character_level = myLevel,
        guild_name = myGuild,
        faction = myFaction,
        group_type = groupType,
        content_type = contentType,
        zone = zone,
        subzone = subzone,
        coord_x = coordX,
        coord_y = coordY,
        min_level = minLevel,
        max_level = maxLevel,
        roles = roles,
        message = message,
        hostile_count = 1,
        hostile_names = (contentType == "BG") and "Enemy Vanguard" or "Hostile Combatants",
        timestamp = now,
        status = "ACTIVE",
    }

    RF.ActiveBeacon = rally
    RF.AutoInviteActive = true
    RF.AutoInviteExpiry = now + 900 -- 15 minutes active rally window
    if groupType == "RAID" then
        EnsureRaidConversion()
    end

    WoWKillboardDB = WoWKillboardDB or {}
    WoWKillboardDB.distressBeacon = rally
    WoWKillboardDB.rallies = WoWKillboardDB.rallies or {}
    WoWKillboardDB.rallies[rallyId] = rally

    PlaySound(8959)

    -- Broadcast via P2P Addon Network
    if KB.Sync and KB.Sync.BroadcastDistress then
        KB.Sync:BroadcastDistress(rally)
    end

    local roleList = {}
    if roles.tank then table.insert(roleList, "Tank") end
    if roles.heal then table.insert(roleList, "Healer") end
    if roles.dps then table.insert(roleList, "DPS") end
    local roleStr = #roleList > 0 and table.concat(roleList, "/") or "Any"

    local typeStr = (groupType == "RAID") and "40-Man Raid" or "5-Man Squad"
    local contentStr = (contentType == "BG") and "Battleground" or "Open World"

    local s = WoWKillboardSettings or (KB.DefaultSettings or {})
    local enableGuild = (s.enableGuildBroadcasts ~= false)
    local enableAutoInvite = (s.enableWhisperAutoInvite ~= false)
    local autoInviteSuffix = enableAutoInvite and " Auto-invite: whisper 'invite'" or ""

    SafePrint(string.format("|cff00e5ff[WoWKB Alert]|r Squad mustered: |cffffd100%s|r (%s) in |cffffffff%s|r! Lvl %d-%d [%s].%s",
        typeStr, contentStr, zone, minLevel, maxLevel, roleStr, enableAutoInvite and " Whisper 'invite' to join." or ""))

    if IsInGuild() and enableGuild then
        SendChatMessage(string.format("[WoWKB Alert] Squad formed: %s (%s) in %s. Lvl %d-%d [%s] - %s.%s",
            typeStr, contentStr, zone, minLevel, maxLevel, roleStr, message, autoInviteSuffix), "GUILD")
    end

    return true, rally
end

-- Handle incoming whisper for auto-invite
function RF:OnWhisper(msg, sender)
    if not RF:IsBeaconActive() then return end
    if not msg or not sender then return end
    if issecretvalue and (issecretvalue(msg) or issecretvalue(sender)) then return end
    if KB.Utils and KB.Utils.CanAccess and (not KB.Utils.CanAccess(msg) or not KB.Utils.CanAccess(sender)) then return end
    if type(msg) ~= "string" then return end

    local s = WoWKillboardSettings or (KB.DefaultSettings or {})
    if s.enableWhisperAutoInvite == false then return end

    local ok, lowerMsg = pcall(string.lower, msg)
    if not ok or not lowerMsg then return end
    local cleanMsg = lowerMsg:match("^%s*(.-)%s*$")
    if AUTO_INVITE_KEYWORDS[cleanMsg] then
        -- Anti-spam debounce: limit whisper replies to once every 30 seconds per sender
        local now = time()
        RF.InvitedWhisperers = RF.InvitedWhisperers or {}
        if (now - (RF.InvitedWhisperers[sender] or 0)) < 30 then return end
        RF.InvitedWhisperers[sender] = now

        EnsureRaidConversion()
        InvitePlayer(sender)
        local loc = RF:GetBeaconLocationStr()
        SendChatMessage(string.format("[WoWKB] Auto-invite accepted. Coordinates: %s.", loc), "WHISPER", nil, sender)
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
    local s = WoWKillboardSettings or (KB.DefaultSettings or {})
    local coordsStr = (s.includeCoordinates ~= false) and string.format(" (%.1f, %.1f)", beaconData.coord_x or 0, beaconData.coord_y or 0) or ""
    local threatStr = beaconData.hostile_names or (beaconData.hostile_count and string.format("%d Hostiles", beaconData.hostile_count) or "1 Hostile")
    SafePrint(string.format("|cff00e5ff[WoWKB Alert]|r |cffffd100%s|r (%s) engaged in |cffffffff%s|r%s by %s. Whisper |cffffd100'/w %s invite'|r to join.",
        beaconData.character_name,
        beaconData.character_class or "WARRIOR",
        beaconData.zone or "Wilderness",
        coordsStr,
        threatStr,
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
            group_type = b.group_type or "PARTY",
            content_type = b.content_type or "WORLD",
            zone = b.zone or "Wilderness",
            subzone = b.subzone or "",
            coord_x = b.coord_x or 0,
            coord_y = b.coord_y or 0,
            min_level = b.min_level or 1,
            max_level = b.max_level or 60,
            roles = b.roles or { tank = true, heal = true, dps = true },
            message = b.message or b.hostile_names or "Call to Arms",
            hostile_count = b.hostile_count or 1,
            hostile_names = b.hostile_names or "Hostiles",
            timestamp = b.timestamp or now,
            status = "ACTIVE",
            isSelf = true,
        })
    end

    -- 2. Peer beacons in WoWKillboardDistress and WoWKillboardDB.rallies
    local peerRallies = {}
    if WoWKillboardDistress then
        for bId, b in pairs(WoWKillboardDistress) do
            peerRallies[bId] = b
        end
    end
    if WoWKillboardDB and WoWKillboardDB.rallies then
        for bId, b in pairs(WoWKillboardDB.rallies) do
            if not peerRallies[bId] then
                peerRallies[bId] = b
            end
        end
    end

    for bId, b in pairs(peerRallies) do
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
                        group_type = b.group_type or "PARTY",
                        content_type = b.content_type or "WORLD",
                        zone = b.zone or "Wilderness",
                        subzone = b.subzone or "",
                        coord_x = b.coord_x or 0,
                        coord_y = b.coord_y or 0,
                        min_level = b.min_level or 1,
                        max_level = b.max_level or 60,
                        roles = b.roles or { tank = true, heal = true, dps = true },
                        message = b.message or b.hostile_names or "Call to Arms",
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

    -- Sort by newest first
    table.sort(openRallies, function(a, b) return (a.timestamp or 0) > (b.timestamp or 0) end)
    return openRallies
end

-- Request to join an active rally via auto-invite whisper
function RF:RequestJoinRally(leaderName)
    if not leaderName or leaderName == "" then return false end
    SendChatMessage("invite", "WHISPER", nil, leaderName)
    SafePrint(string.format("|cff00e5ff[WoWKB]|r Sent squad join request to |cffffd100%s|r.", leaderName))
    return true
end

-- Frame event dispatcher
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_WHISPER" then
        local msg, sender = ...
        if msg and type(msg) == "string" and (not issecretvalue or not issecretvalue(msg)) then
            RF:OnWhisper(msg, sender)
        end
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
