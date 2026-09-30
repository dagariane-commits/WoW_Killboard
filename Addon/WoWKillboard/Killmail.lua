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
    WoWKillboardDB = WoWKillboardDB or { kills = {}, stats = {}, pveDeaths = {} }
    WoWKillboardDB.kills = WoWKillboardDB.kills or {}
    WoWKillboardDB.pveDeaths = WoWKillboardDB.pveDeaths or {}
    WoWKillboardDB.stats = WoWKillboardDB.stats or {}
    WoWKillboardDB.stats.duels = WoWKillboardDB.stats.duels or { wins = 0, losses = 0 }
    WoWKillboardDB.stats.bgs = WoWKillboardDB.stats.bgs or { wins = 0, losses = 0 }
    WoWKillboardDB.stats.arenas = WoWKillboardDB.stats.arenas or { wins = 0, losses = 0 }

    -- Check duplicate
    if WoWKillboardDB.kills[killId] then
        return -- already recorded
    end

    local playerGUID = (UnitGUID and UnitGUID("player")) or ""
    local isKillerSelf = (data.killer and data.killer.guid and playerGUID ~= "" and data.killer.guid == playerGUID)
    local isVictimSelf = (data.victim and data.victim.guid and playerGUID ~= "" and data.victim.guid == playerGUID)
    local playerSpec = (KB.Utils and KB.Utils.GetPlayerSpec and KB.Utils.GetPlayerSpec()) or nil

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
            spec = data.killer.spec or (isKillerSelf and playerSpec) or nil,
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
            spec = data.victim.spec or (isVictimSelf and playerSpec) or nil,
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

    -- Console chat announcement (Do not spam chat for bystander duels)
    local isPlayerInvolved = (killmail.killer.name == UnitName("player") or killmail.victim.name == UnitName("player"))
    if not killmail.isDuel or isPlayerInvolved then
        local kLvlStr = (killmail.killer.level and killmail.killer.level > 0 and killmail.killer.level <= 85) and tostring(killmail.killer.level) or "??"
        local vLvlStr = (killmail.victim.level and killmail.victim.level > 0 and killmail.victim.level <= 85) and tostring(killmail.victim.level) or "??"
        local killerStr = KB.Utils.ColorizeByClass(string.format("[%s] %s", kLvlStr, killmail.killer.name), killmail.killer.class)
        local victimStr = KB.Utils.ColorizeByClass(string.format("[%s] %s", vLvlStr, killmail.victim.name), killmail.victim.class)
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

        -- Route to Combat Wire floating pop-out window
        if KB.UI and KB.UI.AddCombatWireEntry then
            KB.UI:AddCombatWireEntry(killmail, chatMsg)
        end

        -- Only print to main chat window if user explicitly selected "CHAT" feed mode
        local s = WoWKillboardSettings or (KB.DefaultSettings or {})
        local feedMode = s.combatFeedMode or "POPOUT"
        if feedMode == "CHAT" then
            KB.Utils.SafePrint(chatMsg)
        end
    end

    -- Frontline Kill Banner UI Alert & Audio Dispatch (Duels NEVER trigger banner or sirens)
    if not killmail.isDuel and KB.UI and KB.UI.ShowKillBanner then
        KB.UI:ShowKillBanner(killmail)
    end

    -- P2P Broadcast (Duels NEVER broadcast across group/guild P2P)
    if not killmail.isDuel and KB.Sync and KB.Sync.BroadcastKillmail then
        KB.Sync:BroadcastKillmail(killmail)
    end

    -- Bounty check (Duels cannot fulfill open-world bounties)
    if not killmail.isDuel and KB.BountyEngine and KB.BountyEngine.CheckKillForBounty then
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

-- Record a validated PvE death (Player executed by an NPC/Monster)
function KM:RecordPveDeath(data)
    if not data or not data.npc or not data.victim then return end

    local now = data.timestamp or time()
    local seed = string.format("%s_%s_%s_%s", tostring(now), tostring(data.npc.guid or data.npc.name or "NPC"), tostring(data.victim.guid or ""), tostring(data.location and data.location.mapId or 0))
    local deathId = "PVE-" .. KB.Utils.Hash(seed)

    WoWKillboardDB = WoWKillboardDB or { kills = {}, stats = {}, pveDeaths = {} }
    WoWKillboardDB.pveDeaths = WoWKillboardDB.pveDeaths or {}

    if WoWKillboardDB.pveDeaths[deathId] then
        return
    end

    local pveRecord = {
        deathId = deathId,
        timestamp = now,
        npc = {
            name = data.npc.name or "Unknown Monster",
            id = data.npc.id or 0,
            guid = data.npc.guid or "UNKNOWN",
            spell = data.npc.spell or "Combat Strike",
            damage = data.npc.damage or 0,
        },
        victim = {
            guid = data.victim.guid or "UNKNOWN",
            name = data.victim.name or "Unknown",
            level = data.victim.level or 0,
            class = data.victim.class or "UNKNOWN",
            guild = data.victim.guild or "None",
            faction = data.victim.faction or "Unknown",
        },
        location = data.location or {
            mapId = 0,
            zone = "Unknown Zone",
            subZone = "",
            x = 0,
            y = 0,
        },
    }

    WoWKillboardDB.pveDeaths[deathId] = pveRecord

    -- Console chat feedback
    local victimStr = KB.Utils.ColorizeByClass(string.format("[%d] %s", pveRecord.victim.level, pveRecord.victim.name), pveRecord.victim.class)
    local chatMsg = string.format("|cffff2020[WoWKB PvE]|r %s was executed by |cffffd700[%s]|r (%s) in %s!", victimStr, pveRecord.npc.name, pveRecord.npc.spell or "Combat", pveRecord.location.zone)
    KB.Utils.SafePrint(chatMsg)

    return pveRecord
end
