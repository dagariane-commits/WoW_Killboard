--[[
    WoWKillboard - Leaderboard.lua
    In-memory leaderboard aggregation engine with multi-mode filtering
    (All PvP, Open World Only, Battlegrounds Only) and BG telemetry.
]]

WoWKillboard = WoWKillboard or {}
local KB = WoWKillboard
KB.Leaderboard = {}
local LB = KB.Leaderboard

LB.Aggregates = {
    ALL = { players = {}, zones = {}, guilds = {} },
    WORLD = { players = {}, zones = {}, guilds = {} },
    BG = { players = {}, zones = {}, guilds = {} },
    ARENA = { players = {}, zones = {}, guilds = {} },
    DUEL = { players = {}, zones = {}, guilds = {} },
}

-- Check if a kill matches the requested filter mode
function LB:MatchesMode(km, mode)
    mode = mode or "ALL"
    if mode == "ALL" then
        return true
    elseif mode == "WORLD" then
        return (not km.isBattleground and not km.isArena and not km.isDuel)
    elseif mode == "BG" then
        return (km.isBattleground == true)
    elseif mode == "ARENA" then
        return (km.isArena == true)
    elseif mode == "DUEL" then
        return (km.isDuel == true)
    end
    return true
end

-- Rebuild all aggregate statistics from WoWKillboardDB
function LB:Rebuild()
    LB.Aggregates = {
        ALL = { players = {}, zones = {}, guilds = {} },
        WORLD = { players = {}, zones = {}, guilds = {} },
        BG = { players = {}, zones = {}, guilds = {} },
        ARENA = { players = {}, zones = {}, guilds = {} },
        DUEL = { players = {}, zones = {}, guilds = {} },
    }

    if not WoWKillboardDB or not WoWKillboardDB.kills then return end

    for _, km in pairs(WoWKillboardDB.kills) do
        LB:IndexKillmail(km, "ALL")
        if km.isDuel then
            LB:IndexKillmail(km, "DUEL")
        elseif km.isArena then
            LB:IndexKillmail(km, "ARENA")
        elseif km.isBattleground then
            LB:IndexKillmail(km, "BG")
        else
            LB:IndexKillmail(km, "WORLD")
        end
    end
end

-- Index a single killmail into a target bucket
function LB:IndexKillmail(km, mode)
    local bucket = LB.Aggregates[mode]
    if not bucket then return end

    -- Killer Stats
    local kName = km.killer.name
    local pK = bucket.players[kName] or {
        name = kName,
        class = km.killer.class,
        level = km.killer.level,
        guild = km.killer.guild or "None",
        faction = km.killer.faction,
        kills = 0,
        soloKills = 0,
        deaths = 0,
        damageDone = 0,
        healingDone = 0,
    }
    pK.kills = pK.kills + 1
    if km.isSolo then
        pK.soloKills = pK.soloKills + 1
    end
    pK.damageDone = pK.damageDone + (km.killer.damageDone or 0)
    pK.healingDone = pK.healingDone + (km.killer.healingDone or 0)
    bucket.players[kName] = pK

    -- Victim Stats (Deaths)
    local vName = km.victim.name
    local pV = bucket.players[vName] or {
        name = vName,
        class = km.victim.class,
        level = km.victim.level,
        guild = km.victim.guild or "None",
        faction = km.victim.faction,
        kills = 0,
        soloKills = 0,
        deaths = 0,
        damageDone = 0,
        healingDone = 0,
    }
    pV.deaths = pV.deaths + 1
    bucket.players[vName] = pV

    -- Zone Stats
    local zone = km.location.zone or "Unknown"
    bucket.zones[zone] = (bucket.zones[zone] or 0) + 1

    -- Guild Stats
    if km.killer.guild and km.killer.guild ~= "None" and km.killer.guild ~= "" then
        bucket.guilds[km.killer.guild] = (bucket.guilds[km.killer.guild] or 0) + 1
    end
end

function LB:OnNewKill(km)
    LB:IndexKillmail(km, "ALL")
    if km.isDuel then
        LB:IndexKillmail(km, "DUEL")
    elseif km.isArena then
        LB:IndexKillmail(km, "ARENA")
    elseif km.isBattleground then
        LB:IndexKillmail(km, "BG")
    else
        LB:IndexKillmail(km, "WORLD")
    end
end

-- Get Top Killers sorted by total kills
function LB:GetTopKillers(mode, limit)
    mode = mode or "ALL"
    limit = limit or 10
    local bucket = LB.Aggregates[mode]
    if not bucket then return {} end

    local list = {}
    for _, p in pairs(bucket.players) do
        table.insert(list, p)
    end

    table.sort(list, function(a, b)
        if a.kills == b.kills then
            return a.soloKills > b.soloKills
        end
        return a.kills > b.kills
    end)

    local res = {}
    for i = 1, math.min(#list, limit) do
        table.insert(res, list[i])
    end
    return res
end

-- Get Top Solo Killers
function LB:GetTopSoloKillers(mode, limit)
    mode = mode or "ALL"
    limit = limit or 10
    local bucket = LB.Aggregates[mode]
    if not bucket then return {} end

    local list = {}
    for _, p in pairs(bucket.players) do
        if p.soloKills > 0 then
            table.insert(list, p)
        end
    end

    table.sort(list, function(a, b)
        return a.soloKills > b.soloKills
    end)

    local res = {}
    for i = 1, math.min(#list, limit) do
        table.insert(res, list[i])
    end
    return res
end

-- Get Battleground Gladiators (damage, healing, kills, K/D)
function LB:GetBattlegroundGladiators(limit)
    limit = limit or 10
    local bucket = LB.Aggregates["BG"]
    if not bucket then return {} end

    local list = {}
    for _, p in pairs(bucket.players) do
        local kd = (p.deaths > 0) and (p.kills / p.deaths) or p.kills
        table.insert(list, {
            name = p.name,
            class = p.class,
            guild = p.guild,
            kills = p.kills,
            deaths = p.deaths,
            kdRatio = math.floor(kd * 100) / 100,
            damageDone = p.damageDone,
            healingDone = p.healingDone,
        })
    end

    table.sort(list, function(a, b)
        if a.kills == b.kills then
            return a.damageDone > b.damageDone
        end
        return a.kills > b.kills
    end)

    local res = {}
    for i = 1, math.min(#list, limit) do
        table.insert(res, list[i])
    end
    return res
end

-- Get Top Zones
function LB:GetTopZones(mode, limit)
    mode = mode or "ALL"
    limit = limit or 10
    local bucket = LB.Aggregates[mode]
    if not bucket then return {} end

    local list = {}
    for zone, count in pairs(bucket.zones) do
        table.insert(list, { zone = zone, kills = count })
    end

    table.sort(list, function(a, b) return a.kills > b.kills end)

    local res = {}
    for i = 1, math.min(#list, limit) do
        table.insert(res, list[i])
    end
    return res
end

function LB:GetDeadliestZones(limit)
    return LB:GetTopZones("ALL", limit)
end

-- Get Top War Guilds sorted by total kills
function LB:GetTopGuilds(mode, limit)
    mode = mode or "ALL"
    limit = limit or 10
    local bucket = LB.Aggregates[mode]
    if not bucket then return {} end

    local list = {}
    for guildName, count in pairs(bucket.guilds) do
        table.insert(list, { guild = guildName, kills = count })
    end

    table.sort(list, function(a, b) return a.kills > b.kills end)

    local res = {}
    for i = 1, math.min(#list, limit) do
        table.insert(res, list[i])
    end
    return res
end

-- Get Recent Killmails sorted chronologically
function LB:GetRecentKills(mode, limit)
    mode = mode or "ALL"
    limit = limit or 50
    if not WoWKillboardDB or not WoWKillboardDB.kills then return {} end

    local list = {}
    for _, km in pairs(WoWKillboardDB.kills) do
        if LB:MatchesMode(km, mode) then
            table.insert(list, km)
        end
    end

    table.sort(list, function(a, b)
        return (a.timestamp or 0) > (b.timestamp or 0)
    end)

    local res = {}
    for i = 1, math.min(#list, limit) do
        table.insert(res, list[i])
    end
    return res
end
