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
CT.FriendlyCluster = {}    -- active friendly GUIDs assisting in proximity combat: [friendlyGUID] = timestamp
CT.SessionStats = {
    damageDone = 0,
    healingDone = 0,
    kills = 0,
    deaths = 0,
}

local frame = CreateFrame("Frame")

-- Canonical Blizzard Combat Log Bitmask Constants (Cross-Client Guardrail 2 Compliant)
local COMBATLOG_OBJECT_TYPE_PLAYER = _G.COMBATLOG_OBJECT_TYPE_PLAYER or 0x00000400
local COMBATLOG_OBJECT_CONTROL_PLAYER = _G.COMBATLOG_OBJECT_CONTROL_PLAYER or 0x00000100
local COMBATLOG_OBJECT_REACTION_FRIENDLY = _G.COMBATLOG_OBJECT_REACTION_FRIENDLY or 0x00000010
local COMBATLOG_OBJECT_REACTION_HOSTILE = _G.COMBATLOG_OBJECT_REACTION_HOSTILE or 0x00000040

local function HasFlag(flags, mask)
    if not flags or not mask or type(flags) ~= "number" or type(mask) ~= "number" then
        return false
    end
    if bit and bit.band then
        return bit.band(flags, mask) > 0
    elseif bit32 and bit32.band then
        return bit32.band(flags, mask) > 0
    end
    return false
end

local function IsPlayerUnit(guid, flags, name)
    if guid and type(guid) == "string" and guid:match("^Player%-") then
        return true
    end
    if flags and (HasFlag(flags, COMBATLOG_OBJECT_TYPE_PLAYER) or HasFlag(flags, COMBATLOG_OBJECT_CONTROL_PLAYER)) then
        return true
    end
    if guid and KB.UnitScanner and KB.UnitScanner.GetUnitInfo and KB.UnitScanner:GetUnitInfo(guid) then
        return true
    end
    if name and KB.UnitScanner and KB.UnitScanner.GetUnitInfoByName and KB.UnitScanner:GetUnitInfoByName(name) then
        return true
    end
    local pGUID = UnitGUID("player")
    if guid and pGUID and guid == pGUID then return true end
    if guid and UnitExists("target") and UnitGUID("target") == guid and UnitIsPlayer("target") then return true end
    if name and UnitExists("target") and UnitName("target") == name and UnitIsPlayer("target") then return true end
    if guid and UnitExists("mouseover") and UnitGUID("mouseover") == guid and UnitIsPlayer("mouseover") then return true end
    return false
end

-- Cross-Client Dynamic Combat Log Feature Detection (Guardrail 2 Compliant)
-- Supports WoW Forever Beta (_classic_beta_), Classic Era (_classic_era_), Anniversary (_anniversary_), and Modern Retail (_retail_)
local hasCombatLogAPI = (type(CombatLogGetCurrentEventInfo) == "function")

local function GetCombatLogPayload(...)
    if hasCombatLogAPI then
        return CombatLogGetCurrentEventInfo()
    else
        return ...
    end
end

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

    for friendlyGUID, timestamp in pairs(CT.FriendlyCluster) do
        if timestamp < cutoff then
            CT.FriendlyCluster[friendlyGUID] = nil
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

    local isSourcePlayer = IsPlayerUnit(sourceGUID, sourceFlags, sourceName)
    local isDestPlayer = IsPlayerUnit(destGUID, destFlags, destName)

    if not isDestPlayer then return end

    amount = (amount and KB.Utils.CanAccess(amount)) and amount or 0
    local playerGUID = UnitGUID("player")

    -- If player dealt damage, increment session damage telemetry
    if playerGUID and KB.Utils.CanAccess(playerGUID) and sourceGUID == playerGUID then
        CT.SessionStats.damageDone = CT.SessionStats.damageDone + amount
    end

    -- If source is hostile to player, add to HostileCluster
    local isHostile = HasFlag(sourceFlags, COMBATLOG_OBJECT_REACTION_HOSTILE)
    if isHostile and isSourcePlayer then
        CT.HostileCluster[sourceGUID] = time()
    end

    -- If source is friendly to player (or in player's faction), track in FriendlyCluster
    local isFriendly = HasFlag(sourceFlags, COMBATLOG_OBJECT_REACTION_FRIENDLY)
    if isFriendly and isSourcePlayer and playerGUID and sourceGUID ~= playerGUID then
        CT.FriendlyCluster[sourceGUID] = time()
    end

    -- Track recent damage to victim for killmail attribution
    CT.RecentDamage[destGUID] = CT.RecentDamage[destGUID] or {}
    local vData = CT.RecentDamage[destGUID][sourceGUID] or {
        totalDamage = 0,
        lastTime = time(),
        name = KB.Utils.SafeString(sourceName, "Unknown"),
        guid = sourceGUID,
        spellName = spellName or "Swing",
        isPlayer = isSourcePlayer,
    }
    vData.totalDamage = vData.totalDamage + amount
    vData.lastTime = time()
    vData.spellName = spellName or vData.spellName
    vData.isPlayer = isSourcePlayer
    CT.RecentDamage[destGUID][sourceGUID] = vData
end

-- Record healing telemetry
function CT:RecordHeal(sourceGUID, destGUID, amount)
    if not sourceGUID or not KB.Utils.CanAccess(sourceGUID) then return end
    local playerGUID = UnitGUID("player")
    if playerGUID and KB.Utils.CanAccess(playerGUID) then
        if sourceGUID == playerGUID then
            CT.SessionStats.healingDone = CT.SessionStats.healingDone + (amount or 0)
        elseif destGUID == playerGUID and sourceGUID ~= playerGUID then
            -- External player healed us: record friendly assist
            CT.FriendlyCluster[sourceGUID] = time()
        end
    end
end

-- Process death event
function CT:ProcessDeath(victimGUID, victimName, victimFlags, killerGUID, killerName)
    if not victimGUID or not KB.Utils.CanAccess(victimGUID) then return end
    local isDestPlayer = IsPlayerUnit(victimGUID, victimFlags, victimName)
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
    local hasPlayerAttacker = false
    local topNpcAttacker = nil
    local maxNpcDamage = -1

    for attGUID, attData in pairs(attackers) do
        local isAttPlayer = attData.isPlayer
        if isAttPlayer == nil then
            isAttPlayer = (attGUID:match("^Player%-") ~= nil)
        end

        if isAttPlayer then
            hasPlayerAttacker = true
        else
            if (attData.totalDamage or 0) > maxNpcDamage then
                maxNpcDamage = attData.totalDamage or 0
                topNpcAttacker = attData
            end
        end

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
            isPlayer = isAttPlayer,
        })
        totalDamage = totalDamage + (attData.totalDamage or 0)
        if not finalBlowKillerGUID then
            finalBlowKillerGUID = attGUID
            finalBlowKillerName = attData.name
        end
    end

    -- If no recorded attackers but we have killerGUID from party kill
    if #attackersList == 0 and finalBlowKillerGUID then
        local isFinalPlayer = (finalBlowKillerGUID:match("^Player%-") ~= nil)
        if isFinalPlayer then hasPlayerAttacker = true end

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
            isPlayer = isFinalPlayer,
        })
    end

    -- Fallback: If no recorded attackers in RecentDamage, check active target / player attribution
    if #attackersList == 0 then
        local pGUID = UnitGUID("player")
        local isTargetVictim = (UnitExists("target") and (UnitGUID("target") == victimGUID or UnitName("target") == victimName)) or
                               (activeEnemyTarget and (activeEnemyTarget.guid == victimGUID or activeEnemyTarget.name == victimName))
        if isTargetVictim and pGUID then
            finalBlowKillerGUID = pGUID
            finalBlowKillerName = UnitName("player")
            local _, pClass = UnitClass("player")
            local pGuild = GetGuildInfo("player")
            local pFaction = UnitFactionGroup("player")
            table.insert(attackersList, {
                guid = pGUID,
                name = finalBlowKillerName or "Player",
                damage = CT.SessionStats.damageDone or 0,
                spell = "Killing Blow",
                class = pClass or "UNKNOWN",
                level = UnitLevel("player") or 0,
                guild = pGuild or "None",
                faction = pFaction or "Unknown",
                isPlayer = true,
            })
            hasPlayerAttacker = true
        end
    end

    -- Only proceed if there was at least one attacker
    if #attackersList == 0 then return end

    -- Check if this was a pure PvE execution (player died with ZERO player attackers)
    if not hasPlayerAttacker then
        local npc = topNpcAttacker or (finalBlowKillerGUID and {
            guid = finalBlowKillerGUID,
            name = finalBlowKillerName or "Unknown Monster",
            totalDamage = totalDamage,
            spellName = "Execution",
        })

        if npc then
            local npcId = 0
            if npc.guid then
                local parsed = npc.guid:match("Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-") or npc.guid:match("Vehicle%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
                if parsed then npcId = tonumber(parsed) or 0 end
            end

            local victimInfo = KB.UnitScanner and KB.UnitScanner:GetUnitInfo(victimGUID) or {
                guid = victimGUID,
                name = victimName or "Unknown",
                level = 0,
                class = "UNKNOWN",
                guild = "None",
                faction = "Unknown",
            }
            if playerGUID and victimGUID == playerGUID then
                victimInfo.name = UnitName("player")
                victimInfo.level = UnitLevel("player") or 0
                local _, pClass = UnitClass("player")
                victimInfo.class = pClass or "UNKNOWN"
                victimInfo.faction = UnitFactionGroup("player") or "Unknown"
                victimInfo.guild = GetGuildInfo("player") or "None"
            end

            local location = KB.Utils.GetPlayerLocation()

            KB.Killmail:RecordPveDeath({
                timestamp = now,
                npc = {
                    name = npc.name or "Unknown Monster",
                    id = npcId,
                    guid = npc.guid or "UNKNOWN",
                    spell = npc.spellName or "Combat Strike",
                    damage = npc.totalDamage or totalDamage or 0,
                },
                victim = {
                    guid = victimInfo.guid or victimGUID,
                    name = victimInfo.name,
                    level = victimInfo.level or 0,
                    class = victimInfo.class or "UNKNOWN",
                    guild = victimInfo.guild or "None",
                    faction = victimInfo.faction or "Unknown",
                },
                location = location,
            })
        end

        CT.RecentDamage[victimGUID] = nil
        return
    end

    -- If final blow was an NPC during a PvP gank, attribute kill to the highest-damage player attacker
    if finalBlowKillerGUID and not finalBlowKillerGUID:match("^Player%-") then
        local maxPlayerDmg = -1
        for _, att in ipairs(attackersList) do
            if att.isPlayer and att.damage > maxPlayerDmg then
                maxPlayerDmg = att.damage
                finalBlowKillerGUID = att.guid
                finalBlowKillerName = att.name
            end
        end
    end

    CT:PruneCombatInteractions()
    local friendlyAssists = 0
    for fGUID, fTime in pairs(CT.FriendlyCluster) do
        if fGUID ~= playerGUID and (now - fTime) <= 15 then
            friendlyAssists = friendlyAssists + 1
        end
    end

    -- Strict Certified 1v1 Solo Kill criteria:
    -- 1. Attacker list contains ONLY 1 combatant
    -- 2. Friendly party size is strictly 1
    -- 3. Zero active friendly assists or cluster participants in the 15-second sliding window
    local isSolo = (#attackersList == 1) and (CT:GetFriendlyPartySize() == 1) and (friendlyAssists == 0)
    local friendlyPartySize = math.max(CT:GetFriendlyPartySize(), #attackersList)
    if friendlyAssists > 0 then
        friendlyPartySize = friendlyPartySize + friendlyAssists
    end
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

    CT.LastKillVictim = victimInfo.name
    CT.LastKillTime = now

    -- Clean up victim recent damage
    CT.RecentDamage[victimGUID] = nil
end

-- Helper to parse victim name from CHAT_MSG_COMBAT_HONOR_GAIN
local function ExtractVictimFromHonorMsg(msg)
    if not msg or not KB.Utils.CanAccess(msg) or type(msg) ~= "string" then return nil end
    local clean = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("[%.,!%?:;]", "")
    local victim = clean:match("^(.-)%s+dies")
    if not victim then
        victim = clean:match("death of%s+(%S+)")
    end
    if not victim then
        victim = clean:match("Honorable Kill:%s*(%S+)")
    end
    if victim then
        victim = victim:match("^%s*(.-)%s*$") -- trim
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
    if CT.LastKillVictim and (CT.LastKillVictim:lower() == victimName:lower()) and (now - (CT.LastKillTime or 0)) < 5 then
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

    local friendlyPartySize = math.max(2, CT:GetFriendlyPartySize())
    local isSolo = false -- Honorable kill broadcasts without combat log proof indicate group/nearby presence
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
    local function MatchesPlayer(name)
        if not name or not playerName then return false end
        local cName = name:match("^([^-]+)") or name
        cName = cName:match("^%s*(.-)%s*$") -- trim
        if cName:lower() == playerName:lower() then return true end
        -- Check if first word of name matches playerName (handles RP surnames / titles)
        local firstWord = cName:match("^([%w_]+)")
        if firstWord and firstWord:lower() == playerName:lower() then return true end
        -- Check if playerName is contained within cName
        if cName:lower():find(playerName:lower(), 1, true) then return true end
        return false
    end
    local cleanWinner = winnerName:match("^([^-]+)") or winnerName
    local cleanLoser = loserName:match("^([^-]+)") or loserName
    local isPlayerWinner = MatchesPlayer(winnerName) or MatchesPlayer(cleanWinner)
    local isPlayerLoser = MatchesPlayer(loserName) or MatchesPlayer(cleanLoser)

    -- Update W/L and Total statistics in WoWKillboardDB
    WoWKillboardDB = WoWKillboardDB or {}
    WoWKillboardDB.stats = WoWKillboardDB.stats or {}
    WoWKillboardDB.stats.duels = WoWKillboardDB.stats.duels or { wins = 0, losses = 0, total = 0 }
    WoWKillboardDB.stats.duels.total = (WoWKillboardDB.stats.duels.total or 0) + 1

    if isPlayerWinner then
        WoWKillboardDB.stats.duels.wins = (WoWKillboardDB.stats.duels.wins or 0) + 1
        CT.SessionStats.kills = CT.SessionStats.kills + 1
    elseif isPlayerLoser then
        WoWKillboardDB.stats.duels.losses = (WoWKillboardDB.stats.duels.losses or 0) + 1
        CT.SessionStats.deaths = CT.SessionStats.deaths + 1
    end

    local killerInfo = KB.UnitScanner:GetUnitInfoByName(winnerName) or KB.UnitScanner:GetUnitInfoByName(cleanWinner)
    if not killerInfo then
        if UnitExists("target") and (UnitName("target") == winnerName or UnitName("target") == cleanWinner) then
            killerInfo = KB.UnitScanner:ScanUnit("target")
        elseif UnitExists("mouseover") and (UnitName("mouseover") == winnerName or UnitName("mouseover") == cleanWinner) then
            killerInfo = KB.UnitScanner:ScanUnit("mouseover")
        end
    end

    local kClass = isPlayerWinner and (select(2, UnitClass("player")) or "UNKNOWN") or (killerInfo and killerInfo.class or "UNKNOWN")
    if kClass == "UNKNOWN" then
        for _, victimAtts in pairs(CT.RecentDamage) do
            for _, att in pairs(victimAtts) do
                if att.name == winnerName or att.name == cleanWinner then
                    if att.class and att.class ~= "UNKNOWN" then
                        kClass = att.class
                        break
                    elseif att.spellName and KB.UnitScanner and KB.UnitScanner.InferClassFromSpell then
                        local inferred = KB.UnitScanner:InferClassFromSpell(att.guid, att.name, att.spellName)
                        if inferred then kClass = inferred; break end
                    end
                end
            end
            if kClass ~= "UNKNOWN" then break end
        end
    end

    if isPlayerWinner then
        kClass = select(2, UnitClass("player")) or "UNKNOWN"
        killerInfo = {
            guid = UnitGUID("player") or "PLAYER",
            name = winnerName,
            level = UnitLevel("player") or 0,
            class = kClass,
            guild = GetGuildInfo("player") or "None",
            faction = UnitFactionGroup("player") or "Unknown",
            partySize = 1,
            damageDone = CT.SessionStats.damageDone or 0,
            healingDone = CT.SessionStats.healingDone or 0,
        }
    else
        killerInfo = killerInfo or {
            guid = "DUEL_WINNER",
            name = winnerName,
            level = 0,
            class = kClass,
            guild = "None",
            faction = "Unknown",
            partySize = 1,
            damageDone = 0,
            healingDone = 0,
        }
        killerInfo.class = kClass
    end

    local victimInfo = nil
    if isPlayerLoser then
        vClass = select(2, UnitClass("player")) or "UNKNOWN"
        victimInfo = {
            guid = UnitGUID("player") or "PLAYER",
            name = loserName,
            level = UnitLevel("player") or 0,
            class = vClass,
            guild = GetGuildInfo("player") or "None",
            faction = UnitFactionGroup("player") or "Unknown",
            partySize = 1,
        }
    else
        victimInfo = KB.UnitScanner:GetUnitInfoByName(loserName) or KB.UnitScanner:GetUnitInfoByName(cleanLoser)
        if not victimInfo then
            if UnitExists("target") and (UnitName("target") == loserName or UnitName("target") == cleanLoser) then
                victimInfo = KB.UnitScanner:ScanUnit("target")
            elseif UnitExists("mouseover") and (UnitName("mouseover") == loserName or UnitName("mouseover") == cleanLoser) then
                victimInfo = KB.UnitScanner:ScanUnit("mouseover")
            end
        end

        local vClass = victimInfo and victimInfo.class or "UNKNOWN"
        if vClass == "UNKNOWN" then
            for _, victimAtts in pairs(CT.RecentDamage) do
                for _, att in pairs(victimAtts) do
                    if att.name == loserName or att.name == cleanLoser then
                        if att.class and att.class ~= "UNKNOWN" then
                            vClass = att.class
                            break
                        elseif att.spellName and KB.UnitScanner and KB.UnitScanner.InferClassFromSpell then
                            local inferred = KB.UnitScanner:InferClassFromSpell(att.guid, att.name, att.spellName)
                            if inferred then vClass = inferred; break end
                        end
                    end
                end
                if vClass ~= "UNKNOWN" then break end
            end
        end

        victimInfo = victimInfo or {
            guid = "DUEL_LOSER",
            name = loserName,
            level = 0,
            class = vClass,
            guild = "None",
            faction = "Unknown",
            partySize = 1,
        }
        victimInfo.class = vClass
    end

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
        local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, _, destGUID, destName, destFlags, _ = GetCombatLogPayload(...)

        local playerGUID = UnitGUID("player")
        if sourceGUID and playerGUID and sourceGUID ~= playerGUID and IsPlayerUnit(sourceGUID, sourceFlags, sourceName) then
            if HasFlag(sourceFlags, COMBATLOG_OBJECT_REACTION_FRIENDLY) then
                CT.FriendlyCluster[sourceGUID] = time()
            elseif HasFlag(sourceFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) then
                CT.HostileCluster[sourceGUID] = time()
            end
        end

        if subevent == "SWING_DAMAGE" then
            local amount = select(12, GetCombatLogPayload(...))
            CT:RecordDamage(timestamp, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, amount or 0, "Melee Swing")
        elseif subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" or subevent == "RANGE_DAMAGE" then
            local spellId, spellName, _, amount = select(12, GetCombatLogPayload(...))
            if KB.UnitScanner and KB.UnitScanner.InferClassFromSpell then
                KB.UnitScanner:InferClassFromSpell(sourceGUID, sourceName, spellName)
            end
            CT:RecordDamage(timestamp, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, amount or 0, spellName)
        elseif subevent == "SPELL_HEAL" or subevent == "SPELL_PERIODIC_HEAL" then
            local spellId, spellName, _, amount = select(12, GetCombatLogPayload(...))
            if KB.UnitScanner and KB.UnitScanner.InferClassFromSpell then
                KB.UnitScanner:InferClassFromSpell(sourceGUID, sourceName, spellName)
            end
            CT:RecordHeal(sourceGUID, destGUID, amount or 0)
        elseif subevent == "SPELL_CAST_SUCCESS" or subevent == "SPELL_AURA_APPLIED" then
            local spellId, spellName = select(12, GetCombatLogPayload(...))
            if KB.UnitScanner and KB.UnitScanner.InferClassFromSpell then
                KB.UnitScanner:InferClassFromSpell(sourceGUID, sourceName, spellName)
            end
            local playerGUID = UnitGUID("player")
            if playerGUID and destGUID == playerGUID and sourceGUID ~= playerGUID then
                CT.FriendlyCluster[sourceGUID] = time()
            end
        elseif subevent == "PARTY_KILL" then
            CT:ProcessDeath(destGUID, destName, destFlags, sourceGUID, sourceName)
        elseif subevent == "UNIT_DIED" then
            CT:ProcessDeath(destGUID, destName, destFlags, nil, nil)
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
        local playerGUID = UnitGUID("player")
        if playerGUID and CT.RecentDamage[playerGUID] then
            CT:ProcessDeath(playerGUID, UnitName("player"), COMBATLOG_OBJECT_TYPE_PLAYER, nil, nil)
        end

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
        end

    elseif event == "UNIT_HEALTH" then
        local unit = ...
        if unit == "target" and (UnitIsDead("target") or UnitIsDeadOrGhost("target")) then
            local deadName = (activeEnemyTarget and activeEnemyTarget.name) or (UnitExists("target") and UnitIsPlayer("target") and UnitName("target"))
            if deadName then
                CT:OnPlayerHonorableKill(deadName)
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

-- Universal Event Registration across all 4 WoW client flavors (Guardrail 2 Compliant)
pcall(frame.RegisterEvent, frame, "COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN")
frame:RegisterEvent("CHAT_MSG_SYSTEM")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UNIT_HEALTH")
frame:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
frame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
pcall(frame.RegisterEvent, frame, "PVP_MATCH_COMPLETE")
