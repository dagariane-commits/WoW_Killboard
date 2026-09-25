--[[
    WoWKillboard - CombatTracker.lua
    Real-time PvP combat analysis engine, temporal hostile gang inference,
    damage/healing telemetry, and battleground status detection.
]]

WoWKillboard = WoWKillboard or {}
local KB = WoWKillboard
KB.CombatTracker = {}
local CT = KB.CombatTracker

-- Active combat states
CT.RecentDamage = {}       -- keyed by victimGUID: { [attackerGUID] = { totalDamage, lastTime, class, name } }
CT.HostileCluster = {}     -- active hostile GUIDs in proximity combat: [hostileGUID] = timestamp
CT.SessionStats = {
    damageDone = 0,
    healingDone = 0,
    kills = 0,
    deaths = 0,
}

local frame = CreateFrame("Frame")

-- Modern Client Detection (Forever Beta 16000-16999 or Retail >= 100000)
-- On these modern clients, COMBAT_LOG_EVENT_UNFILTERED is strictly forbidden by Blizzard C++ security.
local _, _, _, tocVersion = GetBuildInfo()
tocVersion = tonumber(tocVersion) or 0
local isModernClient = (tocVersion >= 16000 and tocVersion <= 16999) or (tocVersion >= 100000)

CT.LastKillVictim = nil
CT.LastKillTime = 0
local activeEnemyTarget = nil

-- Get current instance & BG metadata
function CT:GetCombatContext()
    local inInstance, instanceType = IsInInstance()
    local isBG = (instanceType == "pvp") or (C_PvP and C_PvP.IsBattleground and C_PvP.IsBattleground())
    local isArena = (instanceType == "arena") or (C_PvP and C_PvP.IsArena and C_PvP.IsArena())
    local bgName = isBG and (GetSubZoneText() or GetZoneText()) or nil

    return {
        isBattleground = isBG or false,
        isArena = isArena or false,
        instanceType = instanceType or "none",
        battlegroundName = bgName,
    }
end

-- Get Friendly Group Size
function CT:GetFriendlyPartySize()
    if IsInRaid() then
        return GetNumGroupMembers() or 1
    elseif IsInGroup() then
        return (GetNumGroupMembers() or 0)
    else
        return 1  -- Solo
    end
end

-- Clean old combat interactions older than combat window
function CT:PruneCombatInteractions()
    local now = time()
    local cutoff = now - KB.DefaultSettings.combatWindowSeconds

    for victimGUID, attackers in pairs(CT.RecentDamage) do
        local hasRecent = false
        for attackerGUID, data in pairs(attackers) do
            if data.lastTime < cutoff then
                attackers[attackerGUID] = nil
            else
                hasRecent = true
            end
        end
        if not hasRecent then
            CT.RecentDamage[victimGUID] = nil
        end
    end

    for hostileGUID, timestamp in pairs(CT.HostileCluster) do
        if timestamp < cutoff then
            CT.HostileCluster[hostileGUID] = nil
        end
    end
end

-- Calculate hostile party/gang size from active hostile cluster
function CT:GetInferredHostilePartySize()
    CT:PruneCombatInteractions()
    local count = 0
    for _ in pairs(CT.HostileCluster) do
        count = count + 1
    end
    return math.max(1, count)
end

-- Record incoming or outgoing damage
function CT:RecordDamage(timestamp, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, amount, spellName)
    if not KB.Utils.CanAccess(sourceGUID) or not KB.Utils.CanAccess(destGUID) then return end
    if not KB.Utils.CanAccess(sourceFlags) or not KB.Utils.CanAccess(destFlags) then return end

    local isSourcePlayer = bit.band(sourceFlags, COMBATLOG_OBJECT_TYPE_PLAYER) > 0
    local isDestPlayer = bit.band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) > 0

    if not isDestPlayer then return end

    amount = (amount and KB.Utils.CanAccess(amount)) and amount or 0
    local playerGUID = UnitGUID("player")

    -- If player dealt damage, increment session damage telemetry
    if playerGUID and KB.Utils.CanAccess(playerGUID) and sourceGUID == playerGUID then
        CT.SessionStats.damageDone = CT.SessionStats.damageDone + amount
    end

    -- If source is hostile to player, add to HostileCluster
    local isHostile = bit.band(sourceFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) > 0
    if isHostile and isSourcePlayer then
        CT.HostileCluster[sourceGUID] = time()
    end

    -- Track recent damage to victim for killmail attribution
    CT.RecentDamage[destGUID] = CT.RecentDamage[destGUID] or {}
    local vData = CT.RecentDamage[destGUID][sourceGUID] or {
        totalDamage = 0,
        lastTime = time(),
        name = KB.Utils.SafeString(sourceName, "Unknown"),
        guid = sourceGUID,
        spellName = spellName or "Swing",
    }
    vData.totalDamage = vData.totalDamage + amount
    vData.lastTime = time()
    vData.spellName = spellName or vData.spellName
    CT.RecentDamage[destGUID][sourceGUID] = vData
end

-- Record healing telemetry
function CT:RecordHeal(sourceGUID, amount)
    if not sourceGUID or not KB.Utils.CanAccess(sourceGUID) then return end
    local playerGUID = UnitGUID("player")
    if playerGUID and KB.Utils.CanAccess(playerGUID) and sourceGUID == playerGUID then
        CT.SessionStats.healingDone = CT.SessionStats.healingDone + (amount or 0)
    end
end

-- Process death event
function CT:ProcessDeath(victimGUID, victimName, victimFlags, killerGUID, killerName)
    if not victimGUID or not KB.Utils.CanAccess(victimGUID) then return end
    if not victimFlags or not KB.Utils.CanAccess(victimFlags) then return end
    local isDestPlayer = bit.band(victimFlags, COMBATLOG_OBJECT_TYPE_PLAYER) > 0
    if not isDestPlayer then return end

    local playerGUID = UnitGUID("player")
    local now = time()
    local context = CT:GetCombatContext()

    -- Filter check: If user disabled BGs and this is a BG, skip
    if not KB.DefaultSettings.includeBattlegrounds and context.isBattleground then
        return
    end

    -- Check if player died
    if victimGUID == playerGUID then
        CT.SessionStats.deaths = CT.SessionStats.deaths + 1
    end

    -- Gather all attackers who damaged this victim recently
    local attackers = CT.RecentDamage[victimGUID] or {}
    local attackersList = {}
    local totalDamage = 0
    local finalBlowKillerGUID = killerGUID
    local finalBlowKillerName = killerName

    for attGUID, attData in pairs(attackers) do
        local unitInfo = KB.UnitScanner and KB.UnitScanner.GetUnitInfo and KB.UnitScanner:GetUnitInfo(attGUID)
        local attClass = "UNKNOWN"
        local attLevel = 0
        local attGuild = "None"
        local attFaction = "Unknown"

        if playerGUID and attGUID == playerGUID then
            local _, pClass = UnitClass("player")
            attClass = pClass or "UNKNOWN"
            attLevel = UnitLevel("player") or 0
            local pGuild = GetGuildInfo("player")
            attGuild = pGuild or "None"
            attFaction = UnitFactionGroup("player") or "Unknown"
        elseif unitInfo then
            attClass = unitInfo.class or "UNKNOWN"
            attLevel = unitInfo.level or 0
            attGuild = unitInfo.guild or "None"
            attFaction = unitInfo.faction or "Unknown"
        end

        table.insert(attackersList, {
            guid = attGUID,
            name = attData.name or "Unknown",
            damage = attData.totalDamage or 0,
            spell = attData.spellName or "Combat",
            class = attClass,
            level = attLevel,
            guild = attGuild,
            faction = attFaction,
        })
        totalDamage = totalDamage + (attData.totalDamage or 0)
        if not finalBlowKillerGUID then
            finalBlowKillerGUID = attGUID
            finalBlowKillerName = attData.name
        end
    end

    -- If no recorded attackers but we have killerGUID from party kill
    if #attackersList == 0 and finalBlowKillerGUID then
        local unitInfo = KB.UnitScanner and KB.UnitScanner.GetUnitInfo and KB.UnitScanner:GetUnitInfo(finalBlowKillerGUID)
        local attClass = "UNKNOWN"
        local attLevel = 0
        local attGuild = "None"
        local attFaction = "Unknown"
        if playerGUID and finalBlowKillerGUID == playerGUID then
            local _, pClass = UnitClass("player")
            attClass = pClass or "UNKNOWN"
            attLevel = UnitLevel("player") or 0
            local pGuild = GetGuildInfo("player")
            attGuild = pGuild or "None"
            attFaction = UnitFactionGroup("player") or "Unknown"
        elseif unitInfo then
            attClass = unitInfo.class or "UNKNOWN"
            attLevel = unitInfo.level or 0
            attGuild = unitInfo.guild or "None"
            attFaction = unitInfo.faction or "Unknown"
        end

        table.insert(attackersList, {
            guid = finalBlowKillerGUID,
            name = finalBlowKillerName or "Unknown",
            damage = 0,
            spell = "Final Blow",
            class = attClass,
            level = attLevel,
            guild = attGuild,
            faction = attFaction,
        })
    end

    -- Only proceed if there was at least one attacker
    if #attackersList == 0 then return end

    local isSolo = (#attackersList == 1)
    local friendlyPartySize = CT:GetFriendlyPartySize()
    local hostilePartySize = CT:GetInferredHostilePartySize()

    -- Extract unit scanner details for killer & victim
    local killerInfo = KB.UnitScanner:GetUnitInfo(finalBlowKillerGUID) or {
        guid = finalBlowKillerGUID,
        name = finalBlowKillerName or "Unknown",
        level = 0,
        class = "UNKNOWN",
        guild = "None",
        faction = "Unknown",
    }

    local victimInfo = KB.UnitScanner:GetUnitInfo(victimGUID) or {
        guid = victimGUID,
        name = victimName or "Unknown",
        level = 0,
        class = "UNKNOWN",
        guild = "None",
        faction = "Unknown",
    }

    -- If killer was the player
    if finalBlowKillerGUID == playerGUID then
        CT.SessionStats.kills = CT.SessionStats.kills + 1
        killerInfo.name = UnitName("player")
        killerInfo.level = UnitLevel("player")
        local _, pClass = UnitClass("player")
        killerInfo.class = pClass
        local pFaction = UnitFactionGroup("player")
        killerInfo.faction = pFaction
        local pGuild = GetGuildInfo("player")
        killerInfo.guild = pGuild or "None"
    end

    -- Trigger Death Bounty Opportunity if player was killed by an enemy player in the open world
    local inInst, instType = false, "none"
    if IsInInstance then inInst, instType = IsInInstance() end
    local isInstanceCombat = inInst or (instType and instType ~= "none") or context.isBattleground or context.isArena

    if not isInstanceCombat and victimGUID == playerGUID and killerInfo and killerInfo.name and killerInfo.name ~= "Unknown" and killerInfo.name ~= UnitName("player") then
        CT.LastPvpKiller = {
            name = killerInfo.name,
            guid = killerInfo.guid,
            class = killerInfo.class,
            faction = killerInfo.faction,
        }
        local settings = WoWKillboardSettings or {}
        if settings.promptBountyOnDeath ~= false then
            if InCombatLockdown() then
                CT.PendingDeathBounty = CT.LastPvpKiller
            else
                if KB.UI and KB.UI.ShowDeathBountyPrompt then
                    KB.UI:ShowDeathBountyPrompt(CT.LastPvpKiller)
                end
            end
        end
    end

    local location = KB.Utils.GetPlayerLocation()

    -- Dispatch to Killmail Engine
    KB.Killmail:RecordKill({
        timestamp = now,
        isBattleground = context.isBattleground,
        isArena = context.isArena,
        battlegroundName = context.battlegroundName,
        isSolo = isSolo,
        attackersCount = #attackersList,
        attackers = attackersList,
        totalDamage = totalDamage,
        killer = {
            guid = killerInfo.guid,
            name = killerInfo.name,
            level = killerInfo.level,
            class = killerInfo.class,
            guild = killerInfo.guild,
            faction = killerInfo.faction,
            partySize = friendlyPartySize,
            damageDone = CT.SessionStats.damageDone,
            healingDone = CT.SessionStats.healingDone,
        },
        victim = {
            guid = victimInfo.guid,
            name = victimInfo.name,
            level = victimInfo.level,
            class = victimInfo.class,
            guild = victimInfo.guild,
            faction = victimInfo.faction,
            partySize = hostilePartySize,
        },
        location = location,
    })

    -- Clean up victim recent damage
    CT.RecentDamage[victimGUID] = nil
end

-- Helper to parse victim name from CHAT_MSG_COMBAT_HONOR_GAIN
local function ExtractVictimFromHonorMsg(msg)
    if not msg or not KB.Utils.CanAccess(msg) or type(msg) ~= "string" then return nil end
    local victim = msg:match("^(%S+)%s+dies")
    if not victim then
        victim = msg:match("death of (%S+)")
    end
    if victim then
        victim = victim:gsub("[%.,!%?:;]", "")
        if KB.Utils.CanAccess(victim) and victim ~= "" then
            return victim
        end
    end
    return nil
end

-- Process an honorable kill on modern / Forever clients
function CT:OnPlayerHonorableKill(victimName)
    if not victimName or not KB.Utils.CanAccess(victimName) then return end
    local now = time()
    if CT.LastKillVictim == victimName and (now - (CT.LastKillTime or 0)) < 3 then
        return
    end
    CT.LastKillVictim = victimName
    CT.LastKillTime = now

    local victimInfo = KB.UnitScanner:GetUnitInfoByName(victimName) or {
        guid = "UNKNOWN",
        name = victimName,
        level = 0,
        class = "UNKNOWN",
        guild = "None",
        faction = "Unknown",
        partySize = 1,
    }

    if UnitExists("target") and UnitName("target") == victimName then
        local tInfo = KB.UnitScanner:ScanUnit("target")
        if tInfo then victimInfo = tInfo end
    end

    local friendlyPartySize = CT:GetFriendlyPartySize()
    local isSolo = (friendlyPartySize == 1)
    local playerGUID = UnitGUID("player")
    local playerName = UnitName("player")
    local _, pClass = UnitClass("player")
    local pFaction = UnitFactionGroup("player")
    local pGuild = GetGuildInfo("player")

    CT.SessionStats.kills = CT.SessionStats.kills + 1

    local context = CT:GetCombatContext()
    local location = KB.Utils.GetPlayerLocation()

    KB.Killmail:RecordKill({
        timestamp = now,
        isBattleground = context.isBattleground,
        isArena = context.isArena,
        battlegroundName = context.battlegroundName,
        isSolo = isSolo,
        attackersCount = friendlyPartySize,
        attackers = {
            {
                guid = playerGUID or "PLAYER",
                name = playerName or "Player",
                damage = CT.SessionStats.damageDone,
                spell = "Honorable Combat",
            }
        },
        totalDamage = CT.SessionStats.damageDone,
        killer = {
            guid = playerGUID or "PLAYER",
            name = playerName or "Player",
            level = UnitLevel("player") or 0,
            class = pClass or "UNKNOWN",
            guild = pGuild or "None",
            faction = pFaction or "Unknown",
            partySize = friendlyPartySize,
            damageDone = CT.SessionStats.damageDone,
            healingDone = CT.SessionStats.healingDone,
        },
        victim = {
            guid = victimInfo.guid or "UNKNOWN",
            name = victimInfo.name,
            level = victimInfo.level or 0,
            class = victimInfo.class or "UNKNOWN",
            guild = victimInfo.guild or "None",
            faction = victimInfo.faction or "Unknown",
            partySize = 1,
        },
        location = location,
    })
end

-- Process a 1v1 Duel result (Knockout or Forfeit)
function CT:OnDuelCompleted(winnerName, loserName, isFlee)
    if not winnerName or not loserName then return end
    if not KB.Utils.CanAccess(winnerName) or not KB.Utils.CanAccess(loserName) then return end

    local now = time()
    local playerName = UnitName("player")
    local isPlayerWinner = (winnerName == playerName)
    local isPlayerLoser = (loserName == playerName)

    -- Update W/L statistics in WoWKillboardDB
    WoWKillboardDB = WoWKillboardDB or {}
    WoWKillboardDB.stats = WoWKillboardDB.stats or {}
    WoWKillboardDB.stats.duels = WoWKillboardDB.stats.duels or { wins = 0, losses = 0 }

    if isPlayerWinner then
        WoWKillboardDB.stats.duels.wins = WoWKillboardDB.stats.duels.wins + 1
        CT.SessionStats.kills = CT.SessionStats.kills + 1
    elseif isPlayerLoser then
        WoWKillboardDB.stats.duels.losses = WoWKillboardDB.stats.duels.losses + 1
        CT.SessionStats.deaths = CT.SessionStats.deaths + 1
    end

    local killerInfo = KB.UnitScanner:GetUnitInfoByName(winnerName) or {
        guid = isPlayerWinner and UnitGUID("player") or "DUEL_WINNER",
        name = winnerName,
        level = isPlayerWinner and (UnitLevel("player") or 0) or 0,
        class = isPlayerWinner and (select(2, UnitClass("player")) or "UNKNOWN") or "UNKNOWN",
        guild = isPlayerWinner and (GetGuildInfo("player") or "None") or "None",
        faction = isPlayerWinner and (UnitFactionGroup("player") or "Unknown") or "Unknown",
        partySize = 1,
        damageDone = isPlayerWinner and CT.SessionStats.damageDone or 0,
        healingDone = isPlayerWinner and CT.SessionStats.healingDone or 0,
    }

    local victimInfo = KB.UnitScanner:GetUnitInfoByName(loserName) or {
        guid = isPlayerLoser and UnitGUID("player") or "DUEL_LOSER",
        name = loserName,
        level = isPlayerLoser and (UnitLevel("player") or 0) or 0,
        class = isPlayerLoser and (select(2, UnitClass("player")) or "UNKNOWN") or "UNKNOWN",
        guild = isPlayerLoser and (GetGuildInfo("player") or "None") or "None",
        faction = isPlayerLoser and (UnitFactionGroup("player") or "Unknown") or "Unknown",
        partySize = 1,
    }

    local location = KB.Utils.GetPlayerLocation()

    KB.Killmail:RecordKill({
        timestamp = now,
        isDuel = true,
        isBattleground = false,
        isArena = false,
        battlegroundName = isFlee and "Duel (Forfeit)" or "Duel (Knockout)",
        isSolo = true,
        attackersCount = 1,
        attackers = {
            {
                guid = killerInfo.guid,
                name = killerInfo.name,
                damage = killerInfo.damageDone or 0,
                spell = isFlee and "Duel Forfeit" or "Duel Victory",
            }
        },
        totalDamage = killerInfo.damageDone or 0,
        killer = killerInfo,
        victim = victimInfo,
        location = location,
    })
end

-- Event Listener Frame
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if not isModernClient then
            local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, _, destGUID, destName, destFlags, _ = CombatLogGetCurrentEventInfo()

            if subevent == "SWING_DAMAGE" then
                local amount = select(12, CombatLogGetCurrentEventInfo())
                CT:RecordDamage(timestamp, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, amount or 0, "Melee Swing")
            elseif subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" or subevent == "RANGE_DAMAGE" then
                local spellId, spellName, _, amount = select(12, CombatLogGetCurrentEventInfo())
                CT:RecordDamage(timestamp, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, amount or 0, spellName)
            elseif subevent == "SPELL_HEAL" or subevent == "SPELL_PERIODIC_HEAL" then
                local _, _, _, amount = select(12, CombatLogGetCurrentEventInfo())
                CT:RecordHeal(sourceGUID, amount or 0)
            elseif subevent == "PARTY_KILL" then
                CT:ProcessDeath(destGUID, destName, destFlags, sourceGUID, sourceName)
            elseif subevent == "UNIT_DIED" then
                CT:ProcessDeath(destGUID, destName, destFlags, nil, nil)
            end
        end

    elseif event == "CHAT_MSG_COMBAT_HONOR_GAIN" then
        local msg = ...
        local victimName = ExtractVictimFromHonorMsg(msg)
        if victimName then
            CT:OnPlayerHonorableKill(victimName)
        end

    elseif event == "CHAT_MSG_SYSTEM" then
        local msg = ...
        if msg and KB.Utils.CanAccess(msg) then
            local winner, loser = msg:match("^(.+) has defeated (.+) in a duel")
            local isFlee = false
            if not winner then
                loser, winner = msg:match("^(.+) has fled from (.+) in a duel")
                isFlee = true
            end
            if winner and loser then
                CT:OnDuelCompleted(winner, loser, isFlee)
            end
        end

    elseif event == "PLAYER_DEAD" then
        CT.SessionStats.deaths = CT.SessionStats.deaths + 1
        local inInst, instType = false, "none"
        if IsInInstance then inInst, instType = IsInInstance() end
        local isInstanceCombat = inInst or (instType and instType ~= "none")

        if not isInstanceCombat and CT.LastPvpKiller then
            local settings = WoWKillboardSettings or {}
            if settings.promptBountyOnDeath ~= false then
                if InCombatLockdown() then
                    CT.PendingDeathBounty = CT.LastPvpKiller
                else
                    if KB.UI and KB.UI.ShowDeathBountyPrompt then
                        KB.UI:ShowDeathBountyPrompt(CT.LastPvpKiller)
                    end
                end
            end
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        if CT.PendingDeathBounty then
            local pending = CT.PendingDeathBounty
            CT.PendingDeathBounty = nil
            local inInst, instType = false, "none"
            if IsInInstance then inInst, instType = IsInInstance() end
            local isInstanceCombat = inInst or (instType and instType ~= "none")

            if not isInstanceCombat and not InCombatLockdown() and KB.UI and KB.UI.ShowDeathBountyPrompt then
                KB.UI:ShowDeathBountyPrompt(pending)
            end
        end

    elseif event == "PLAYER_TARGET_CHANGED" then
        if UnitExists("target") and UnitIsPlayer("target") and UnitCanAttack("player", "target") then
            local tInfo = KB.UnitScanner and KB.UnitScanner:ScanUnit("target")
            activeEnemyTarget = {
                name = UnitName("target"),
                guid = UnitGUID("target"),
                level = UnitLevel("target") or (tInfo and tInfo.level or 0),
                class = select(2, UnitClass("target")) or (tInfo and tInfo.class or "UNKNOWN"),
                guild = GetGuildInfo("target") or (tInfo and tInfo.guild or "None"),
                faction = UnitFactionGroup("target") or (tInfo and tInfo.faction or "Unknown"),
            }
        else
            activeEnemyTarget = nil
        end

    elseif event == "UNIT_HEALTH" then
        local unit = ...
        if unit == "target" and activeEnemyTarget and UnitAffectingCombat("player") and UnitIsDead("target") then
            if activeEnemyTarget.name then
                CT:OnPlayerHonorableKill(activeEnemyTarget.name)
            end
        end

    elseif event == "UPDATE_BATTLEFIELD_SCORE" then
        if type(GetNumBattlefieldScores) ~= "function" or type(GetBattlefieldScore) ~= "function" then return end
        local numScores = tonumber(GetNumBattlefieldScores()) or 0
        if numScores <= 0 then return end
        local playerName = UnitName("player")
        if not playerName or not KB.Utils.CanAccess(playerName) then return end
        for i = 1, numScores do
            local success, name, killingBlows, honorableKills, deaths, honorGained, faction, race, class, classToken, damageDone, healingDone = pcall(GetBattlefieldScore, i)
            if success and name and KB.Utils.CanAccess(name) and (name == playerName or (type(name) == "string" and name:find(playerName, 1, true))) then
                local dmg = tonumber(damageDone) or 0
                local heal = tonumber(healingDone) or 0
                if dmg > 0 then CT.SessionStats.damageDone = dmg end
                if heal > 0 then CT.SessionStats.healingDone = heal end
                break
            end
        end

    elseif event == "PVP_MATCH_COMPLETE" or event == "UPDATE_BATTLEFIELD_STATUS" then
        local winner = nil
        if type(GetBattlefieldWinner) == "function" then
            local ok, w = pcall(GetBattlefieldWinner)
            if ok then winner = w end
        end
        if winner ~= nil and not CT.RecordedMatchWinner then
            CT.RecordedMatchWinner = true
            local context = CT:GetCombatContext()
            local pFaction = UnitFactionGroup("player")
            local pFactionIndex = (pFaction == "Horde") and 0 or 1
            local isWin = (tonumber(winner) == pFactionIndex) or (tostring(winner) == tostring(pFaction))

            WoWKillboardDB = WoWKillboardDB or {}
            WoWKillboardDB.stats = WoWKillboardDB.stats or {}
            WoWKillboardDB.stats.bgs = WoWKillboardDB.stats.bgs or { wins = 0, losses = 0 }
            WoWKillboardDB.stats.arenas = WoWKillboardDB.stats.arenas or { wins = 0, losses = 0 }

            if context.isArena then
                if isWin then
                    WoWKillboardDB.stats.arenas.wins = WoWKillboardDB.stats.arenas.wins + 1
                    print("|cff00ff00[WoWKB]|r Arena Victory recorded!")
                else
                    WoWKillboardDB.stats.arenas.losses = WoWKillboardDB.stats.arenas.losses + 1
                    print("|cffff3333[WoWKB]|r Arena Defeat recorded.")
                end
            elseif context.isBattleground then
                if isWin then
                    WoWKillboardDB.stats.bgs.wins = WoWKillboardDB.stats.bgs.wins + 1
                    print("|cff00ff00[WoWKB]|r Battleground Victory recorded!")
                else
                    WoWKillboardDB.stats.bgs.losses = WoWKillboardDB.stats.bgs.losses + 1
                    print("|cffff3333[WoWKB]|r Battleground Defeat recorded.")
                end
            end
            if KB.UI and KB.UI.RefreshIfVisible then KB.UI:RefreshIfVisible() end
        elseif winner == nil then
            CT.RecordedMatchWinner = false
        end
    end
end)

-- Safe event registration: NEVER register COMBAT_LOG_EVENT_UNFILTERED on modern clients
if not isModernClient then
    frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end
frame:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN")
frame:RegisterEvent("CHAT_MSG_SYSTEM")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
if frame.RegisterUnitEvent then
    frame:RegisterUnitEvent("UNIT_HEALTH", "target")
else
    frame:RegisterEvent("UNIT_HEALTH")
end
frame:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
frame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
pcall(frame.RegisterEvent, frame, "PVP_MATCH_COMPLETE")
