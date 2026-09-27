--[[
    WoWKillboard - Sync.lua
    Peer-to-peer Addon communication across Guild, Party, Raid, and Channel
    using Blizzard's C_ChatInfo addon message protocol.
]]

WoWKillboard = WoWKillboard or {}
local KB = WoWKillboard
KB.Sync = {}
local S = KB.Sync

local frame = CreateFrame("Frame")

function S:Init()
    C_ChatInfo.RegisterAddonMessagePrefix(KB.Prefix)
end

-- Broadcast a killmail to group and guild
function S:BroadcastKillmail(killmail)
    if not KB.DefaultSettings.p2pSyncEnabled or not killmail then return end

    -- Serialize compact payload: "KM:killId:timestamp:isSolo:isBG:kName:kClass:kLvl:vName:vClass:vLvl:zone"
    local payload = string.format("KM:%s:%d:%d:%d:%s:%s:%d:%s:%s:%d:%s",
        killmail.killId,
        killmail.timestamp,
        killmail.isSolo and 1 or 0,
        killmail.isBattleground and 1 or 0,
        killmail.killer.name,
        killmail.killer.class,
        killmail.killer.level,
        killmail.victim.name,
        killmail.victim.class,
        killmail.victim.level,
        killmail.location.zone
    )

    if IsInRaid() then
        C_ChatInfo.SendAddonMessage(KB.Prefix, payload, "RAID")
    elseif IsInGroup() then
        C_ChatInfo.SendAddonMessage(KB.Prefix, payload, "PARTY")
    end

    if IsInGuild() then
        C_ChatInfo.SendAddonMessage(KB.Prefix, payload, "GUILD")
    end
end

-- Broadcast a bounty creation
function S:BroadcastBounty(bounty)
    if not KB.DefaultSettings.p2pSyncEnabled or not bounty then return end

    local payload = string.format("BNT:%s:%s:%s:%d:%s",
        bounty.id,
        bounty.targetName,
        bounty.targetClass,
        bounty.amountCopper,
        bounty.placerName
    )

    if IsInGuild() then
        C_ChatInfo.SendAddonMessage(KB.Prefix, payload, "GUILD")
    end
    if IsInGroup() then
        C_ChatInfo.SendAddonMessage(KB.Prefix, payload, IsInRaid() and "RAID" or "PARTY")
    end
end

-- Broadcast a Call for Backup SOS distress beacon
function S:BroadcastDistress(beacon)
    if not KB.DefaultSettings.p2pSyncEnabled or not beacon then return end

    -- Serialize SOS payload: "SOS:id:name:class:lvl:guild:faction:zone:subzone:x:y:hCount:hNames:ts"
    local payload = string.format("SOS:%s:%s:%s:%d:%s:%s:%s:%s:%.1f:%.1f:%d:%s:%d",
        beacon.id or "SOS",
        beacon.character_name or "Unknown",
        beacon.character_class or "WARRIOR",
        beacon.character_level or 60,
        beacon.guild_name or "None",
        beacon.faction or "Unknown",
        beacon.zone or "Wilderness",
        beacon.subzone or "",
        beacon.coord_x or 0,
        beacon.coord_y or 0,
        beacon.hostile_count or 1,
        beacon.hostile_names or "Hostiles",
        beacon.timestamp or time()
    )

    if IsInGuild() then
        C_ChatInfo.SendAddonMessage(KB.Prefix, payload, "GUILD")
    end
    if IsInGroup() then
        C_ChatInfo.SendAddonMessage(KB.Prefix, payload, IsInRaid() and "RAID" or "PARTY")
    end
end

-- Broadcast resolution of a distress beacon
function S:BroadcastDistressResolve()
    local myName = UnitName("player")
    local payload = string.format("SOS_RES:%s", myName)
    if IsInGuild() then
        C_ChatInfo.SendAddonMessage(KB.Prefix, payload, "GUILD")
    end
    if IsInGroup() then
        C_ChatInfo.SendAddonMessage(KB.Prefix, payload, IsInRaid() and "RAID" or "PARTY")
    end
end

-- Broadcast a Guild Event / Rally
function S:BroadcastEvent(evt)
    if not KB.DefaultSettings.p2pSyncEnabled or not evt then return end
    local payload = string.format("EVT:%s:%s:%s:%s:%s:%s",
        evt.id or "EVT",
        evt.title or "Guild Rally",
        evt.guild_name or "Guild",
        evt.creator_name or "Officer",
        evt.zone or "Wilderness",
        evt.time_str or "NOW"
    )
    if IsInGuild() then
        C_ChatInfo.SendAddonMessage(KB.Prefix, payload, "GUILD")
    end
end

-- Broadcast a tactical scout/gank sighting
function S:BroadcastSighting(sighting)
    if not KB.DefaultSettings.p2pSyncEnabled or not sighting then return end

    local safeNotes = (sighting.notes or "Hostile spotted"):gsub(":", ";")
    -- Format: "SPT:id:repName:repGuild:tgtName:tgtClass:tgtLvl:tgtGuild:tgtFaction:zone:subzone:x:y:notes:ts"
    local payload = string.format("SPT:%s:%s:%s:%s:%s:%d:%s:%s:%s:%s:%.1f:%.1f:%s:%d",
        sighting.id or "SPT",
        sighting.reporter_name or "Scout",
        sighting.reporter_guild or "None",
        sighting.target_name or "Unknown",
        sighting.target_class or "WARRIOR",
        sighting.target_level or 60,
        sighting.target_guild or "None",
        sighting.target_faction or "Unknown",
        sighting.zone or "Wilderness",
        sighting.subzone or "",
        sighting.coord_x or 0,
        sighting.coord_y or 0,
        safeNotes,
        sighting.timestamp or time()
    )

    if IsInGuild() then
        C_ChatInfo.SendAddonMessage(KB.Prefix, payload, "GUILD")
    end
    if IsInGroup() then
        C_ChatInfo.SendAddonMessage(KB.Prefix, payload, IsInRaid() and "RAID" or "PARTY")
    end
end


-- Parse incoming peer message
function S:OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= KB.Prefix then return end
    local myName = UnitName("player")
    if sender == myName or sender:find("^" .. myName .. "-") then return end

    local parts = {}
    for part in string.gmatch(message, "[^:]+") do
        table.insert(parts, part)
    end

    local msgType = parts[1]

    if msgType == "KM" and #parts >= 12 then
        local killId = parts[2]
        WoWKillboardDB = WoWKillboardDB or { kills = {} }
        WoWKillboardDB.kills = WoWKillboardDB.kills or {}

        if not WoWKillboardDB.kills[killId] then
            local syncedKM = {
                killId = killId,
                timestamp = tonumber(parts[3]) or time(),
                isSolo = (parts[4] == "1"),
                isBattleground = (parts[5] == "1"),
                isArena = false,
                attackersCount = (parts[4] == "1") and 1 or 2,
                totalDamage = 0,
                killer = {
                    name = parts[6],
                    class = parts[7],
                    level = tonumber(parts[8]) or 0,
                    guild = "None",
                    faction = "Unknown",
                    partySize = 1,
                    damageDone = 0,
                    healingDone = 0,
                },
                victim = {
                    name = parts[9],
                    class = parts[10],
                    level = tonumber(parts[11]) or 0,
                    guild = "None",
                    faction = "Unknown",
                    partySize = 1,
                },
                location = {
                    mapId = 0,
                    zone = parts[12],
                    subZone = "",
                    x = 0,
                    y = 0,
                },
            }

            WoWKillboardDB.kills[killId] = syncedKM

            if KB.Leaderboard and KB.Leaderboard.OnNewKill then
                KB.Leaderboard:OnNewKill(syncedKM)
            end

            -- Trigger Frontline Kill Banner UI alert (respects alertScope, alertMode, raid warning)
            if KB.UI and KB.UI.ShowKillBanner then
                KB.UI:ShowKillBanner(syncedKM)
            end

            if KB.UI and KB.UI.RefreshIfVisible then
                KB.UI:RefreshIfVisible()
            end
        end

    elseif msgType == "BNT" and #parts >= 6 then
        local bntId = parts[2]
        WoWKillboardBounties = WoWKillboardBounties or {}
        if not WoWKillboardBounties[bntId] then
            WoWKillboardBounties[bntId] = {
                id = bntId,
                targetName = parts[3],
                targetClass = parts[4],
                targetFaction = "Unknown",
                amountCopper = tonumber(parts[5]) or 0,
                amountGold = math.floor((tonumber(parts[5]) or 0) / 10000),
                placerName = parts[6],
                status = KB.STATUS.ACTIVE,
                timestamp = time(),
            }

            if KB.UI and KB.UI.RefreshIfVisible then
                KB.UI:RefreshIfVisible()
            end
        end

    elseif msgType == "SOS" and #parts >= 12 then
        local beaconData = {
            id = parts[2],
            character_name = parts[3],
            character_class = parts[4],
            character_level = tonumber(parts[5]) or 60,
            guild_name = parts[6],
            faction = parts[7],
            zone = parts[8],
            subzone = parts[9],
            coord_x = tonumber(parts[10]) or 0,
            coord_y = tonumber(parts[11]) or 0,
            hostile_count = tonumber(parts[12]) or 1,
            hostile_names = parts[13] or "Hostiles",
            timestamp = tonumber(parts[14]) or time(),
            status = "ACTIVE",
        }
        if KB.Reinforcements and KB.Reinforcements.OnIncomingDistress then
            KB.Reinforcements:OnIncomingDistress(beaconData)
        end

    elseif msgType == "SOS_RES" and #parts >= 2 then
        local charName = parts[2]
        if WoWKillboardDistress then
            for _, b in pairs(WoWKillboardDistress) do
                if b.character_name == charName and b.status == "ACTIVE" then
                    b.status = "RESOLVED"
                end
            end
        end
        if KB.UI and KB.UI.ReinforcementAlert and KB.UI.ReinforcementAlert.CurrentBeacon then
            if KB.UI.ReinforcementAlert.CurrentBeacon.character_name == charName then
                KB.UI.ReinforcementAlert:Hide()
            end
        end

    elseif msgType == "EVT" and #parts >= 6 then
        local title = parts[3]
        local guild = parts[4]
        local creator = parts[5]
        local zone = parts[6]
        local timeStr = parts[7] or "NOW"
        print(string.format("|cff00ccff[GUILD EVENT]|r |cffffd100%s|r in |cffffffff%s|r announced by |cff00ff00%s|r (<%s>)! Time: %s.",
            title, zone, creator, guild, timeStr))

    elseif msgType == "SPT" and #parts >= 14 then
        local sighting = {
            id = parts[2],
            reporter_name = parts[3],
            reporter_guild = parts[4],
            target_name = parts[5],
            target_class = parts[6],
            target_level = tonumber(parts[7]) or 60,
            target_guild = parts[8],
            target_faction = parts[9],
            zone = parts[10],
            subzone = parts[11],
            coord_x = tonumber(parts[12]) or 0,
            coord_y = tonumber(parts[13]) or 0,
            notes = parts[14] or "Hostile spotted",
            timestamp = tonumber(parts[15]) or time(),
        }
        if KB.IntelScanner and KB.IntelScanner.OnIncomingSighting then
            KB.IntelScanner:OnIncomingSighting(sighting)
        end
    end
end

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        S:OnAddonMessage(prefix, message, channel, sender)
    elseif event == "PLAYER_ENTERING_WORLD" then
        S:Init()
    end
end)

frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
