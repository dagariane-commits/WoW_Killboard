--[[
    WoWKillboard - Killmail.lua
    Standardized Killmail Data Model, SavedVariables persistence,
    and event distribution to Sync, Bounty, and UI modules.
]]

WoWKillboard = WoWKillboard or {}
local KB = WoWKillboard
KB.Killmail = {}
local KM = KB.Killmail

-- Record a validated kill
function KM:RecordKill(data)
    if not data or not data.killer or not data.victim then return end

    -- Generate unique hash ID
    local killId = KB.Utils.GenerateKillId(data.timestamp, data.killer.guid, data.victim.guid, data.location.mapId)

    -- Initialize Database if needed
    WoWKillboardDB = WoWKillboardDB or { kills = {}, stats = {} }
    WoWKillboardDB.kills = WoWKillboardDB.kills or {}
    WoWKillboardDB.stats = WoWKillboardDB.stats or {}
    WoWKillboardDB.stats.duels = WoWKillboardDB.stats.duels or { wins = 0, losses = 0 }
    WoWKillboardDB.stats.bgs = WoWKillboardDB.stats.bgs or { wins = 0, losses = 0 }
    WoWKillboardDB.stats.arenas = WoWKillboardDB.stats.arenas or { wins = 0, losses = 0 }

    -- Check duplicate
    if WoWKillboardDB.kills[killId] then
        return -- already recorded
    end

    local killmail = {
        killId = killId,
        timestamp = data.timestamp or time(),
        isDuel = data.isDuel or false,
        isBattleground = data.isBattleground or false,
        isArena = data.isArena or false,
        battlegroundName = data.battlegroundName,
        isSolo = data.isSolo or false,
        attackersCount = data.attackersCount or 1,
        totalDamage = data.totalDamage or 0,
        attackers = data.attackers or {},
        killer = {
            guid = data.killer.guid,
            name = data.killer.name or "Unknown",
            level = data.killer.level or 0,
            class = data.killer.class or "UNKNOWN",
            guild = data.killer.guild or "None",
            faction = data.killer.faction or "Unknown",
            partySize = data.killer.partySize or 1,
            damageDone = data.killer.damageDone or 0,
            healingDone = data.killer.healingDone or 0,
        },
        victim = {
            guid = data.victim.guid,
            name = data.victim.name or "Unknown",
            level = data.victim.level or 0,
            class = data.victim.class or "UNKNOWN",
            guild = data.victim.guild or "None",
            faction = data.victim.faction or "Unknown",
            partySize = data.victim.partySize or 1,
        },
        location = {
            mapId = data.location.mapId or 0,
            zone = data.location.zone or "Unknown Zone",
            subZone = data.location.subZone or "",
            x = data.location.x or 0,
            y = data.location.y or 0,
        },
    }

    -- Persist to database
    WoWKillboardDB.kills[killId] = killmail

    -- Console chat announcement
    local killerStr = KB.Utils.ColorizeByClass(string.format("[%d] %s", killmail.killer.level, killmail.killer.name), killmail.killer.class)
    local victimStr = KB.Utils.ColorizeByClass(string.format("[%d] %s", killmail.victim.level, killmail.victim.name), killmail.victim.class)
    local badge
    if killmail.isDuel then
        badge = "|cffffd700[DUEL]|r"
    elseif killmail.isArena then
        badge = "|cffa335ee[ARENA]|r"
    elseif killmail.isBattleground then
        badge = string.format("|cff00ccff[BG x%d]|r", killmail.attackersCount)
    elseif killmail.isSolo then
        badge = "|cff00ff00[SOLO]|r"
    else
        badge = string.format("|cffff9900[GANG x%d]|r", killmail.attackersCount)
    end
    local locStr = killmail.isBattleground and string.format("|cff00ccff[%s]|r", killmail.battlegroundName or "BG") or string.format("|cffaaaaaa[%s (%s)]|r", killmail.location.zone, killmail.location.subZone ~= "" and killmail.location.subZone or string.format("%.1f, %.1f", killmail.location.x, killmail.location.y))

    local actionVerb = killmail.isDuel and "defeated" or "destroyed"
    local chatMsg = string.format("|cff00ccff[WoWKB]|r %s %s %s %s in %s", badge, killerStr, actionVerb, victimStr, locStr)
    print(chatMsg)

    -- Sound feedback
    if KB.DefaultSettings.soundAlerts then
        if killmail.isSolo then
            PlaySound(KB.SoundAlerts.SOLO_KILL, "Master")
        end
    end

    -- P2P Broadcast
    if KB.Sync and KB.Sync.BroadcastKillmail then
        KB.Sync:BroadcastKillmail(killmail)
    end

    -- Bounty check
    if KB.BountyEngine and KB.BountyEngine.CheckKillForBounty then
        KB.BountyEngine:CheckKillForBounty(killmail)
    end

    -- Update In-Memory Leaderboard
    if KB.Leaderboard and KB.Leaderboard.OnNewKill then
        KB.Leaderboard:OnNewKill(killmail)
    end

    -- Update In-Game UI if open
    if KB.UI and KB.UI.RefreshIfVisible then
        KB.UI:RefreshIfVisible()
    end

    return killmail
end
