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
    if not km or type(km) ~= "table" then return false end
    mode = (mode or "WORLD"):upper()
    local zType = km.zone_type or km.zoneType
    local isBG = (km.isBattleground == true) or (zType == "pvp")
    local isArena = (km.isArena == true) or (zType == "arena") or (km.mode == "ARENA")
    local isDuel = (km.isDuel == true) or (km.is_duel == true) or (km.mode == "DUEL")

    if mode == "WORLD" then
        return (not isBG and not isArena and not isDuel and (not zType or zType == "none" or zType == ""))
    elseif mode == "BG" then
        return isBG
    elseif mode == "ARENA" then
        return isArena
    elseif mode == "DUEL" then
        return isDuel
    elseif mode == "ALL" then
        return (not isDuel)
    end
    return (not isDuel)
end

-- Check if a combat record belongs to the active realm / ruleset
function LB:MatchesRealm(km)
    if not km or type(km) ~= "table" then return false end
    if WoWKillboardSettings and WoWKillboardSettings.isolateRealms == false then
        return true
    end
    local myRealm = (GetRealmName and GetRealmName()) or ""
    if myRealm == "" then return true end

    local kmRealm = km.realm or (km.killer and km.killer.realm) or (km.victim and km.victim.realm) or km.targetRealm or km.placerRealm
    if kmRealm and kmRealm ~= "" and kmRealm ~= "Unknown" then
        local cleanKm = kmRealm:lower():gsub("%s+", "")
        local cleanMy = myRealm:lower():gsub("%s+", "")
        return cleanKm == cleanMy
    end

    -- Bounty Support: If this is an active bounty declared by or targeting active player, or in local database
    if km.placerName or km.targetName then
        local myName = (UnitName and UnitName("player")) or ""
        if (km.placerName and myName ~= "" and km.placerName:lower() == myName:lower()) or (km.targetName and myName ~= "" and km.targetName:lower() == myName:lower()) then
            km.realm = myRealm
            return true
        end
        local bId = km.id or km.bountyId
        if bId and WoWKillboardBounties and WoWKillboardBounties[bId] then
            km.realm = myRealm
            return true
        end
    end

    -- Fallback for un-stamped records loaded in this client: Inherit active realm
    if not kmRealm or kmRealm == "" or kmRealm == "Unknown" then
        km.realm = myRealm
        return true
    end

    -- Strict Isolation: If realm explicitly belongs to another realm, strictly reject
    return false
end

-- Rebuild all aggregate statistics from WoWKillboardDB and shared WoWKillboard_RealmData
function LB:Rebuild()
    LB.Aggregates = {
        ALL = { players = {}, zones = {}, guilds = {} },
        WORLD = { players = {}, zones = {}, guilds = {} },
        BG = { players = {}, zones = {}, guilds = {} },
        ARENA = { players = {}, zones = {}, guilds = {} },
        DUEL = { players = {}, zones = {}, guilds = {} },
    }

    local seenKills = {}

    -- 1. Index local account kills (Strictly filtered by active realm)
    if WoWKillboardDB and WoWKillboardDB.kills then
        for _, km in pairs(WoWKillboardDB.kills) do
            if km and type(km) == "table" and km.killer and type(km.killer) == "table" and km.killer.name and km.victim and type(km.victim) == "table" and km.victim.name then
                local kId = km.killId or (km.killer.name .. (km.victim.name or "") .. tostring(km.timestamp or 0))
                if kId and not seenKills[kId] and LB:MatchesRealm(km) then
                    seenKills[kId] = true
                    local zType = km.zone_type or km.zoneType
                    local isBG = (km.isBattleground == true) or (zType == "pvp")
                    local isArena = (km.isArena == true) or (zType == "arena") or (km.mode == "ARENA")
                    local isDuel = (km.isDuel == true) or (km.is_duel == true) or (km.mode == "DUEL")

                    if not isDuel then
                        LB:IndexKillmail(km, "ALL")
                    end
                    if isDuel then
                        LB:IndexKillmail(km, "DUEL")
                    elseif isArena then
                        LB:IndexKillmail(km, "ARENA")
                    elseif isBG then
                        LB:IndexKillmail(km, "BG")
                    else
                        LB:IndexKillmail(km, "WORLD")
                    end
                end
            end
        end
    end

    -- 2. Index shared realm kills from two-way sync (Filtered by active realm)
    local rData = WoWKillboard_RealmData or (WoWKillboardDB and WoWKillboardDB.RealmData)
    if rData and rData.RecentKills then
        for _, km in ipairs(rData.RecentKills) do
            if km and type(km) == "table" and km.killer and type(km.killer) == "table" and km.killer.name and km.victim and type(km.victim) == "table" and km.victim.name then
                local kId = km.killId or (km.killer.name .. (km.victim.name or "") .. tostring(km.timestamp or 0))
                if kId and not seenKills[kId] and LB:MatchesRealm(km) then
                    seenKills[kId] = true
                    local zType = km.zone_type or km.zoneType
                    local isBG = (km.isBattleground == true) or (zType == "pvp")
                    local isArena = (km.isArena == true) or (zType == "arena") or (km.mode == "ARENA")
                    local isDuel = (km.isDuel == true) or (km.is_duel == true) or (km.mode == "DUEL")

                    if not isDuel then
                        LB:IndexKillmail(km, "ALL")
                    end
                    if isDuel then
                        LB:IndexKillmail(km, "DUEL")
                    elseif isArena then
                        LB:IndexKillmail(km, "ARENA")
                    elseif isBG then
                        LB:IndexKillmail(km, "BG")
                    else
                        LB:IndexKillmail(km, "WORLD")
                    end
                end
            end
        end
    end

    -- 3. Rebuild PvE Aggregates (Wilderness Bestiary & Hazard Telemetry)
    LB.PveAggregates = {
        monsters = {},
        victims = {},
        zones = {},
        totalDeaths = 0,
        deaths = {},
    }

    local seenPve = {}
    local function IndexPve(pd)
        if not pd or type(pd) ~= "table" then return end
        local dId = pd.deathId or pd.death_id or (pd.victim and pd.npc and (tostring(pd.victim.name or "") .. tostring(pd.npc.name or "") .. tostring(pd.timestamp or 0)))
        if dId and seenPve[dId] then return end
        if dId then seenPve[dId] = true end

        local nName = (pd.npc and pd.npc.name) or pd.npc_name or "Unknown Entity"
        local nSpell = (pd.npc and pd.npc.spell) or pd.npc_spell or "Combat Strike"
        local nDmg = tonumber((pd.npc and pd.npc.damage) or pd.npc_damage or 0) or 0
        local nId = tonumber((pd.npc and pd.npc.id) or pd.npc_id or 0) or 0
        local vName = (pd.victim and pd.victim.name) or pd.victim_name or "Unknown"
        local vClass = (pd.victim and pd.victim.class) or pd.victim_class or "WARRIOR"
        local vLevel = tonumber((pd.victim and pd.victim.level) or pd.victim_level or 0) or 0
        local vGuild = (pd.victim and pd.victim.guild) or pd.victim_guild or "None"
        local vFaction = (pd.victim and pd.victim.faction) or pd.victim_faction or "Unknown"
        local zName = (pd.location and pd.location.zone) or pd.zone or "Azeroth"
        local subZone = (pd.location and pd.location.subZone) or pd.subzone or ""
        local ts = tonumber(pd.timestamp or 0) or 0

        local cleanRecord = {
            deathId = dId or ("PVE-" .. tostring(ts)),
            timestamp = ts,
            npc = { name = nName, spell = nSpell, damage = nDmg, id = nId },
            victim = { name = vName, class = vClass, level = vLevel, guild = vGuild, faction = vFaction },
            location = { zone = zName, subZone = subZone },
        }

        table.insert(LB.PveAggregates.deaths, cleanRecord)
        LB.PveAggregates.totalDeaths = LB.PveAggregates.totalDeaths + 1

        -- Monster Aggregation
        local m = LB.PveAggregates.monsters[nName] or {
            name = nName,
            kills = 0,
            topSpell = nSpell,
            maxDamage = nDmg,
            zone = zName,
            id = nId,
        }
        m.kills = m.kills + 1
        if nDmg > (m.maxDamage or 0) then
            m.maxDamage = nDmg
            if nSpell and nSpell ~= "Combat Strike" then m.topSpell = nSpell end
        end
        LB.PveAggregates.monsters[nName] = m

        -- Victim Aggregation
        local v = LB.PveAggregates.victims[vName] or {
            name = vName,
            class = vClass,
            level = vLevel,
            guild = vGuild,
            deaths = 0,
        }
        v.deaths = v.deaths + 1
        LB.PveAggregates.victims[vName] = v

        -- Zone Aggregation
        LB.PveAggregates.zones[zName] = (LB.PveAggregates.zones[zName] or 0) + 1
    end

    -- Index local SavedVariables PvE deaths
    if WoWKillboardDB and WoWKillboardDB.pveDeaths then
        for _, pd in pairs(WoWKillboardDB.pveDeaths) do
            if LB:MatchesRealm(pd) then
                IndexPve(pd)
            end
        end
    end

    -- Index two-way synced PvE deaths
    if rData then
        local pveList = rData.RecentPveDeaths or rData.PveDeaths
        if pveList and type(pveList) == "table" then
            for _, pd in ipairs(pveList) do
                if LB:MatchesRealm(pd) then
                    IndexPve(pd)
                end
            end
        end
    end

    -- Sort deaths descending by timestamp
    table.sort(LB.PveAggregates.deaths, function(a, b)
        return (a.timestamp or 0) > (b.timestamp or 0)
    end)
end

-- Index a single killmail into a target bucket
function LB:IndexKillmail(km, mode)
    if not km or type(km) ~= "table" then return end
    if not km.killer or type(km.killer) ~= "table" or not km.killer.name then return end
    if not km.victim or type(km.victim) ~= "table" or not km.victim.name then return end

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
    local zone = (km.location and km.location.zone) or "Unknown"
    bucket.zones[zone] = (bucket.zones[zone] or 0) + 1

    -- Guild Stats
    if km.killer.guild and km.killer.guild ~= "None" and km.killer.guild ~= "" then
        bucket.guilds[km.killer.guild] = (bucket.guilds[km.killer.guild] or 0) + 1
    end
end

function LB:OnNewKill(km)
    local zType = km.zone_type or km.zoneType
    local isBG = (km.isBattleground == true) or (zType == "pvp")
    local isArena = (km.isArena == true) or (zType == "arena") or (km.mode == "ARENA")
    local isDuel = (km.isDuel == true) or (km.is_duel == true) or (km.mode == "DUEL")

    if not isDuel then
        LB:IndexKillmail(km, "ALL")
    end
    if isDuel then
        LB:IndexKillmail(km, "DUEL")
    elseif isArena then
        LB:IndexKillmail(km, "ARENA")
    elseif isBG then
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

-- Get Recent Killmails sorted chronologically (merges local account + shared realm kills)
function LB:GetRecentKills(mode, limit)
    mode = mode or "ALL"
    limit = limit or 50

    local list = {}
    local seenKills = {}

    -- 1. Local account kills
    if WoWKillboardDB and WoWKillboardDB.kills then
        for _, km in pairs(WoWKillboardDB.kills) do
            if km and type(km) == "table" and km.killer and type(km.killer) == "table" and km.killer.name and km.victim and type(km.victim) == "table" and km.victim.name then
                local kId = km.killId or (km.killer.name .. (km.victim.name or "") .. tostring(km.timestamp or 0))
                if kId and not seenKills[kId] and LB:MatchesMode(km, mode) and LB:MatchesRealm(km) then
                    seenKills[kId] = true
                    table.insert(list, km)
                end
            end
        end
    end

    -- 2. Shared realm kills from two-way sync
    local rData = WoWKillboard_RealmData or (WoWKillboardDB and WoWKillboardDB.RealmData)
    if rData and rData.RecentKills then
        for _, km in ipairs(rData.RecentKills) do
            if km and type(km) == "table" and km.killer and type(km.killer) == "table" and km.killer.name and km.victim and type(km.victim) == "table" and km.victim.name then
                local kId = km.killId or (km.killer.name .. (km.victim.name or "") .. tostring(km.timestamp or 0))
                if kId and not seenKills[kId] and LB:MatchesMode(km, mode) and LB:MatchesRealm(km) then
                    seenKills[kId] = true
                    table.insert(list, km)
                end
            end
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

-- Get a player's rank and full stats in a given mode
function LB:GetPlayerRankAndStats(playerName, mode)
    mode = mode or "WORLD"
    local bucket = LB.Aggregates[mode]
    if not bucket then return nil, nil, 0 end

    local list = {}
    for _, p in pairs(bucket.players) do
        table.insert(list, p)
    end

    table.sort(list, function(a, b)
        if a.kills == b.kills then
            return (a.soloKills or 0) > (b.soloKills or 0)
        end
        return (a.kills or 0) > (b.kills or 0)
    end)

    for rank, p in ipairs(list) do
        if p.name == playerName then
            return rank, p, #list
        end
    end

    return nil, nil, #list
end

-- Get a guild's rank and stats in a given mode
function LB:GetGuildRankAndStats(guildName, mode)
    if not guildName or guildName == "" or guildName == "None" then return nil, nil, 0 end
    mode = mode or "WORLD"
    local bucket = LB.Aggregates[mode]
    if not bucket then return nil, nil, 0 end

    local list = {}
    for gName, count in pairs(bucket.guilds) do
        table.insert(list, { guild = gName, kills = count })
    end

    table.sort(list, function(a, b) return a.kills > b.kills end)

    for rank, g in ipairs(list) do
        if g.guild == guildName then
            return rank, g, #list
        end
    end

    return nil, nil, #list
end

-- Get Mode Telemetry Summary (Total Kills, Solo Kill %, Faction Split)
function LB:GetModeSummary(mode)
    mode = mode or "WORLD"
    local totalKills = 0
    local soloKills = 0
    local allianceKills = 0
    local hordeKills = 0
    local seenKills = {}

    -- 1. Index local account kills
    if WoWKillboardDB and WoWKillboardDB.kills then
        for _, km in pairs(WoWKillboardDB.kills) do
            if km and type(km) == "table" and km.killer and type(km.killer) == "table" and km.killer.name and km.victim and type(km.victim) == "table" and km.victim.name then
                local kId = km.killId or (km.killer.name .. (km.victim.name or "") .. tostring(km.timestamp or 0))
                if kId and not seenKills[kId] and LB:MatchesMode(km, mode) and LB:MatchesRealm(km) then
                    seenKills[kId] = true
                    totalKills = totalKills + 1
                    if km.isSolo then soloKills = soloKills + 1 end
                    local f = km.killer.faction
                    if f == "Alliance" then
                        allianceKills = allianceKills + 1
                    elseif f == "Horde" then
                        hordeKills = hordeKills + 1
                    end
                end
            end
        end
    end

    -- 2. Index shared realm kills from two-way sync
    local rData = WoWKillboard_RealmData or (WoWKillboardDB and WoWKillboardDB.RealmData)
    if rData and rData.RecentKills then
        for _, km in ipairs(rData.RecentKills) do
            if km and type(km) == "table" and km.killer and type(km.killer) == "table" and km.killer.name and km.victim and type(km.victim) == "table" and km.victim.name then
                local kId = km.killId or (km.killer.name .. (km.victim.name or "") .. tostring(km.timestamp or 0))
                if kId and not seenKills[kId] and LB:MatchesMode(km, mode) and LB:MatchesRealm(km) then
                    seenKills[kId] = true
                    totalKills = totalKills + 1
                    if km.isSolo then soloKills = soloKills + 1 end
                    local f = km.killer.faction
                    if f == "Alliance" then
                        allianceKills = allianceKills + 1
                    elseif f == "Horde" then
                        hordeKills = hordeKills + 1
                    end
                end
            end
        end
    end

    -- Use top-level server telemetry summary if mode is WORLD/ALL and server aggregate is higher
    if (mode == "WORLD" or mode == "ALL") and rData and rData.RealmTotalCarnage and rData.RealmTotalCarnage > totalKills then
        totalKills = rData.RealmTotalCarnage
        local soloR = rData.SoloRatio or 0
        local fSplit = rData.FactionSplit or { Alliance = 50, Horde = 50 }
        return {
            totalKills = totalKills,
            soloKills = math.floor(totalKills * (soloR / 100)),
            soloPct = math.floor(soloR),
            alliancePct = math.floor(fSplit.Alliance or 50),
            hordePct = math.floor(fSplit.Horde or 50),
        }
    end

    local soloPct = (totalKills > 0) and math.floor((soloKills / totalKills) * 100) or 0
    local factionTot = allianceKills + hordeKills
    local aPct = (factionTot > 0) and math.floor((allianceKills / factionTot) * 100) or 50
    local hPct = 100 - aPct

    return {
        totalKills = totalKills,
        soloKills = soloKills,
        soloPct = soloPct,
        alliancePct = aPct,
        hordePct = hPct,
    }
end

-- =========================================================================
-- PvE Bestiary & Wilderness Mortality Query API
-- =========================================================================

-- Retrieve recent PvE wilderness deaths, optionally filtered
function LB:GetRecentPveDeaths(limit, filterType)
    limit = limit or 40
    filterType = (filterType or "ALL"):upper()
    local list = {}
    local deaths = (LB.PveAggregates and LB.PveAggregates.deaths) or {}

    for _, pd in ipairs(deaths) do
        local match = true
        if filterType == "ELITES" or filterType == "BG" then
            -- Elite or high damage NPCs
            local dmg = (pd.npc and pd.npc.damage) or 0
            match = (dmg >= 1000)
        elseif filterType == "BOSSES" or filterType == "DUEL" then
            local nName = (pd.npc and pd.npc.name) or ""
            match = (nName:find("Baron") or nName:find("Ragnaros") or nName:find("Onyxia") or (pd.npc and pd.npc.damage and pd.npc.damage >= 5000))
        elseif filterType == "ENVIRONMENT" or filterType == "ARENA" then
            local nName = (pd.npc and pd.npc.name) or ""
            match = (nName:find("Environmental") or nName:find("Falling") or nName:find("Drowning") or nName:find("Lava") or nName:find("Fatigue") or nName:find("Slime"))
        end

        if match then
            table.insert(list, pd)
            if #list >= limit then break end
        end
    end

    return list
end

-- Retrieve Top Deadly NPCs ranked by mortal body count
function LB:GetTopDeadlyNpcs(limit)
    limit = limit or 15
    local list = {}
    local monsters = (LB.PveAggregates and LB.PveAggregates.monsters) or {}

    for _, m in pairs(monsters) do
        table.insert(list, m)
    end

    table.sort(list, function(a, b)
        if (a.kills or 0) ~= (b.kills or 0) then
            return (a.kills or 0) > (b.kills or 0)
        end
        return (a.maxDamage or 0) > (b.maxDamage or 0)
    end)

    local res = {}
    for i = 1, math.min(limit, #list) do
        table.insert(res, list[i])
    end
    return res
end

-- Retrieve Top Deadly Zones ranked by mortal casualties
function LB:GetTopPveZones(limit)
    limit = limit or 10
    local list = {}
    local zones = (LB.PveAggregates and LB.PveAggregates.zones) or {}

    for zName, count in pairs(zones) do
        table.insert(list, { zone = zName, deaths = count })
    end

    table.sort(list, function(a, b)
        return (a.deaths or 0) > (b.deaths or 0)
    end)

    local res = {}
    for i = 1, math.min(limit, #list) do
        table.insert(res, list[i])
    end
    return res
end

-- Retrieve Top Fallen Mortals (Players executed most frequently by wilderness)
function LB:GetTopPveVictims(limit)
    limit = limit or 15
    local list = {}
    local victims = (LB.PveAggregates and LB.PveAggregates.victims) or {}

    for _, v in pairs(victims) do
        table.insert(list, v)
    end

    table.sort(list, function(a, b)
        return (a.deaths or 0) > (b.deaths or 0)
    end)

    local res = {}
    for i = 1, math.min(limit, #list) do
        table.insert(res, list[i])
    end
    return res
end

-- Retrieve high-level summary of PvE statistics
function LB:GetPveSummary()
    local deaths = (LB.PveAggregates and LB.PveAggregates.deaths) or {}
    local monsters = (LB.PveAggregates and LB.PveAggregates.monsters) or {}
    local zones = (LB.PveAggregates and LB.PveAggregates.zones) or {}

    local topM = nil
    local topMKills = 0
    for _, m in pairs(monsters) do
        if (m.kills or 0) > topMKills then
            topMKills = m.kills
            topM = m.name
        end
    end

    local topZ = nil
    local topZDeaths = 0
    for zName, count in pairs(zones) do
        if count > topZDeaths then
            topZDeaths = count
            topZ = zName
        end
    end

    local mCount = 0
    for _ in pairs(monsters) do mCount = mCount + 1 end

    local total = (LB.PveAggregates and LB.PveAggregates.totalDeaths) or #deaths
    return {
        totalDeaths = total,
        uniqueMonsters = mCount,
        topMonster = topM or "None Encountered",
        topMonsterKills = topMKills,
        deadliestZone = topZ or "Unknown",
        deadliestZoneDeaths = topZDeaths,
    }
end
