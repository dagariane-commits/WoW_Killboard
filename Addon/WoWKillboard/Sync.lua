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
