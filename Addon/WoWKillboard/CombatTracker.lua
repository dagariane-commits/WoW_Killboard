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
CT.RecentDamage = {}            -- keyed by victimGUID: { [attackerGUID] = { totalDamage, lastTime, class, name } }
CT.RecentDamageByName = {}      -- keyed by normVictim: { [attackerGUID] = { totalDamage, lastTime, class, name } }
CT.HostileCluster = {}          -- active hostile GUIDs in proximity combat: [hostileGUID] = timestamp
CT.FriendlyCluster = {}         -- active friendly GUIDs assisting in proximity combat: [friendlyGUID] = timestamp
CT.RecentVictimNames = {}       -- map victimGUID -> victimName
CT.RecentVictimGUIDs = {}       -- map lower(victimName) -> victimGUID
CT.RecentVictimAssists = {}     -- map victimGUID -> { [assisterGUID] = { name, spell, time, type } }
CT.RecentVictimAssistsByName = {} -- map normVictim -> { [assisterGUID] = { name, spell, time, type } }
CT.ExternalAssistsOnPlayer = {} -- map assisterGUID -> { name, spell, time, type }
CT.PlayerAssistedAllies = {}    -- map allyGUID -> { name, spell, time, type } (allies buffed or healed by player)
CT.LastPlayerDeathTime = 0
CT.LastKillGUID = nil
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
CT.LastLifetimeHK = nil
CT.RecentEngagedEnemies = {}
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
    local cutoff = now - (KB.DefaultSettings.combatWindowSeconds or 30)

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
            if CT.RecentVictimNames[victimGUID] then
                local vName = CT.RecentVictimNames[victimGUID]:lower()
                CT.RecentVictimGUIDs[vName] = nil
                CT.RecentVictimNames[victimGUID] = nil
            end
            CT.RecentVictimAssists[victimGUID] = nil
        end
    end

    for vName, attackers in pairs(CT.RecentDamageByName) do
        local hasRecent = false
        for attackerGUID, data in pairs(attackers) do
            if data.lastTime < cutoff then
                attackers[attackerGUID] = nil
            else
                hasRecent = true
            end
        end
        if not hasRecent then
            CT.RecentDamageByName[vName] = nil
            CT.RecentVictimAssistsByName[vName] = nil
            CT.RecentVictimGUIDs[vName] = nil
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

    for assisterGUID, data in pairs(CT.ExternalAssistsOnPlayer) do
        if data.time < cutoff then
            CT.ExternalAssistsOnPlayer[assisterGUID] = nil
        end
    end

    if CT.PlayerAssistedAllies then
        for allyGUID, data in pairs(CT.PlayerAssistedAllies) do
            if (data.time or 0) < cutoff then
                CT.PlayerAssistedAllies[allyGUID] = nil
            end
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
    local playerName = UnitName("player")
    local now = time()

    local cleanDest = KB.Utils.CleanCombatantName(destName)
    local normDest = KB.Utils.NormalizeCombatantName(destName)
    local cleanSource = KB.Utils.CleanCombatantName(sourceName)

    -- Cache victim name <-> GUID mappings for fast resolution
    if destName and destName ~= "" and destGUID then
        CT.RecentVictimNames[destGUID] = cleanDest or destName
        if normDest and normDest ~= "" then
            CT.RecentVictimGUIDs[normDest] = destGUID
        end
        CT.RecentVictimGUIDs[destName:lower()] = destGUID
    end

    -- If player dealt damage, increment session damage telemetry
    if playerGUID and KB.Utils.CanAccess(playerGUID) and sourceGUID == playerGUID then
        CT.SessionStats.damageDone = CT.SessionStats.damageDone + amount
    end

    -- If source is hostile to player, add to HostileCluster
    local isHostile = HasFlag(sourceFlags, COMBATLOG_OBJECT_REACTION_HOSTILE)
    if isHostile and isSourcePlayer then
        CT.HostileCluster[sourceGUID] = now
    end

    -- If source is friendly to player (or in player's faction), track in FriendlyCluster
    local isFriendly = HasFlag(sourceFlags, COMBATLOG_OBJECT_REACTION_FRIENDLY) or (not isHostile)
    if isFriendly and isSourcePlayer and playerGUID and sourceGUID ~= playerGUID then
        CT.FriendlyCluster[sourceGUID] = now
        -- If an external ally dealt damage to our target, record external contribution
        if destGUID ~= playerGUID then
            local assistData = {
                name = cleanSource or KB.Utils.SafeString(sourceName, "Ally"),
                guid = sourceGUID,
                time = now,
                spell = spellName or "Damage Assist",
                type = "damage",
            }
            CT.RecentVictimAssists[destGUID] = CT.RecentVictimAssists[destGUID] or {}
            CT.RecentVictimAssists[destGUID][sourceGUID] = assistData
            if normDest and normDest ~= "" then
                CT.RecentVictimAssistsByName[normDest] = CT.RecentVictimAssistsByName[normDest] or {}
                CT.RecentVictimAssistsByName[normDest][sourceGUID] = assistData
            end
        end
    end

    -- Track recent damage to victim for killmail attribution
    CT.RecentDamage[destGUID] = CT.RecentDamage[destGUID] or {}
    local vData = CT.RecentDamage[destGUID][sourceGUID] or {
        totalDamage = 0,
        lastTime = now,
        name = cleanSource or KB.Utils.SafeString(sourceName, "Unknown"),
        guid = sourceGUID,
        spellName = spellName or "Swing",
        isPlayer = isSourcePlayer,
    }
    vData.totalDamage = vData.totalDamage + amount
    vData.lastTime = now
    vData.spellName = spellName or vData.spellName
    vData.isPlayer = isSourcePlayer
    CT.RecentDamage[destGUID][sourceGUID] = vData

    if normDest and normDest ~= "" then
        CT.RecentDamageByName[normDest] = CT.RecentDamageByName[normDest] or {}
        CT.RecentDamageByName[normDest][sourceGUID] = vData
    end
end

-- Record healing telemetry
function CT:RecordHeal(sourceGUID, destGUID, amount)
    if not sourceGUID or not KB.Utils.CanAccess(sourceGUID) then return end
    local playerGUID = UnitGUID("player")
    local now = time()
    if playerGUID and KB.Utils.CanAccess(playerGUID) then
        if sourceGUID == playerGUID then
            CT.SessionStats.healingDone = CT.SessionStats.healingDone + (amount or 0)
            if destGUID and destGUID ~= playerGUID then
                -- Player healed an ally: track ally in FriendlyCluster and PlayerAssistedAllies
                CT.FriendlyCluster[destGUID] = now
                CT.PlayerAssistedAllies = CT.PlayerAssistedAllies or {}
                local dstName = (KB.UnitScanner and KB.UnitScanner.GetUnitInfo and KB.UnitScanner:GetUnitInfo(destGUID) and KB.UnitScanner:GetUnitInfo(destGUID).name) or "Ally"
                local cleanDst = KB.Utils.CleanCombatantName(dstName) or dstName
                CT.PlayerAssistedAllies[destGUID] = {
                    name = cleanDst,
                    guid = destGUID,
                    time = now,
                    spell = "Heal",
                    type = "heal",
                }
            end
        elseif destGUID == playerGUID and sourceGUID ~= playerGUID then
            -- External player healed us: record external assist (revokes 100% solo purity)
            CT.FriendlyCluster[sourceGUID] = now
            local srcName = (KB.UnitScanner and KB.UnitScanner.GetUnitInfo and KB.UnitScanner:GetUnitInfo(sourceGUID) and KB.UnitScanner:GetUnitInfo(sourceGUID).name) or "Ally"
            local cleanSrc = KB.Utils.CleanCombatantName(srcName) or srcName
            CT.ExternalAssistsOnPlayer[sourceGUID] = {
                name = cleanSrc,
                guid = sourceGUID,
                time = now,
                spell = "Heal",
                type = "heal",
            }
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
        if (now - (CT.LastPlayerDeathTime or 0)) > 3 then
            CT.SessionStats.deaths = CT.SessionStats.deaths + 1
            CT.LastPlayerDeathTime = now
        end
    end

    local cleanVictim = KB.Utils.CleanCombatantName(victimName)
    local normVictim = KB.Utils.NormalizeCombatantName(victimName)

    -- Gather all attackers who damaged this victim recently (from BOTH GUID and normalized name)
    local attackersList = {}
    local totalDamage = 0
    local finalBlowKillerGUID = killerGUID
    local finalBlowKillerName = killerName
    local hasPlayerAttacker = false
    local topNpcAttacker = nil
    local maxNpcDamage = -1
    local recordedAttackersMap = {}

    local damageSources = {}
    if victimGUID and CT.RecentDamage[victimGUID] then
        for attGUID, attData in pairs(CT.RecentDamage[victimGUID]) do
            damageSources[attGUID] = attData
        end
    end
    if normVictim and CT.RecentDamageByName and CT.RecentDamageByName[normVictim] then
        for attGUID, attData in pairs(CT.RecentDamageByName[normVictim]) do
            if not damageSources[attGUID] then
                damageSources[attGUID] = attData
            else
                damageSources[attGUID].totalDamage = math.max(damageSources[attGUID].totalDamage or 0, attData.totalDamage or 0)
            end
        end
    end

    for attGUID, attData in pairs(damageSources) do
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
        recordedAttackersMap[attGUID] = true
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
        elseif pGUID and victimGUID == pGUID then
            -- Fallback when the PLAYER was slain: locate hostile enemy who engaged player
            local enemy = nil
            if activeEnemyTarget and (now - (activeEnemyTarget.lastSeen or 0)) <= 30 then
                enemy = activeEnemyTarget
            else
                local bestTime = 0
                for _, e in pairs(CT.RecentEngagedEnemies) do
                    if e.lastSeen and e.lastSeen > bestTime and (now - e.lastSeen) <= 30 then
                        enemy = e
                        bestTime = e.lastSeen
                    end
                end
            end
            if not enemy then
                for hGUID, hTime in pairs(CT.HostileCluster) do
                    if (now - hTime) <= 30 then
                        local hInfo = KB.UnitScanner and KB.UnitScanner:GetUnitInfo(hGUID)
                        if hInfo and hInfo.name and hInfo.name ~= UnitName("player") then
                            enemy = hInfo
                            break
                        end
                    end
                end
            end
            if not enemy and UnitExists("target") and UnitCanAttack("player", "target") and UnitIsPlayer("target") then
                enemy = KB.UnitScanner and KB.UnitScanner:ScanUnit("target")
            end

            if enemy and enemy.name and enemy.name ~= UnitName("player") then
                finalBlowKillerGUID = enemy.guid or "UNKNOWN_HOSTILE"
                finalBlowKillerName = enemy.name
                table.insert(attackersList, {
                    guid = finalBlowKillerGUID,
                    name = finalBlowKillerName,
                    damage = 0,
                    spell = "Fatal Strike",
                    class = enemy.class or "UNKNOWN",
                    level = enemy.level or 0,
                    guild = enemy.guild or "None",
                    faction = enemy.faction or "Unknown",
                    isPlayer = true,
                })
                hasPlayerAttacker = true
            end
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
        if fGUID ~= playerGUID and (now - fTime) <= 30 then
            friendlyAssists = friendlyAssists + 1
        end
    end

    -- Merge assists from BOTH RecentVictimAssists[victimGUID] and RecentVictimAssistsByName[normVictim]
    local assistSources = {}
    if victimGUID and CT.RecentVictimAssists[victimGUID] then
        for aGUID, aData in pairs(CT.RecentVictimAssists[victimGUID]) do
            if (now - (aData.time or 0)) <= 30 then
                assistSources[aGUID] = aData
            end
        end
    end
    if normVictim and CT.RecentVictimAssistsByName and CT.RecentVictimAssistsByName[normVictim] then
        for aGUID, aData in pairs(CT.RecentVictimAssistsByName[normVictim]) do
            if (now - (aData.time or 0)) <= 30 and not assistSources[aGUID] then
                assistSources[aGUID] = aData
            end
        end
    end

    for aGUID, aData in pairs(assistSources) do
        if not recordedAttackersMap[aGUID] and aGUID ~= playerGUID then
            local aInfo = KB.UnitScanner and KB.UnitScanner:GetUnitInfo(aGUID)
            table.insert(attackersList, {
                guid = aGUID,
                name = (aInfo and aInfo.name) or aData.name or "Friendly Ally",
                damage = 0,
                spell = aData.spell or "Assist",
                class = (aInfo and aInfo.class) or "UNKNOWN",
                level = (aInfo and aInfo.level) or 0,
                guild = (aInfo and aInfo.guild) or "None",
                faction = (aInfo and aInfo.faction) or (UnitFactionGroup("player") or "Unknown"),
                isPlayer = true,
            })
            recordedAttackersMap[aGUID] = true
        end
    end

    -- Strict 100% Certified Solo Kill Criteria:
    -- 1. Attacker list contains ONLY 1 player
    -- 2. Zero other friendly players debuffed, slowed, stunned or assisted against victim within 30s
    -- 3. Zero external friendly heals received by the player within 30s
    -- 4. Zero external friendly buffs received by the player within 30s
    -- 5. Friendly party/raid size is strictly 1
    -- 6. Zero active friendly cluster participants within 30s
    local hasExternalAttacker = false
    for _, att in ipairs(attackersList) do
        if att.guid ~= playerGUID and (att.name ~= UnitName("player")) then
            hasExternalAttacker = true
            break
        end
    end

    local hasExternalAssistOnVictim = false
    for aGUID, aData in pairs(assistSources) do
        if aGUID ~= playerGUID and aData.name ~= UnitName("player") then
            hasExternalAssistOnVictim = true
            break
        end
    end

    local hasExternalAssistOnPlayer = false
    for hGUID, hData in pairs(CT.ExternalAssistsOnPlayer) do
        if hGUID ~= playerGUID and (now - (hData.time or 0)) <= 30 then
            hasExternalAssistOnPlayer = true
            break
        end
    end

    local hasRecentAssistedAlly = false
    if CT.PlayerAssistedAllies then
        for aGUID, aData in pairs(CT.PlayerAssistedAllies) do
            if aGUID ~= playerGUID and (now - (aData.time or 0)) <= 30 then
                hasRecentAssistedAlly = true
                break
            end
        end
    end

    local inGroup = (CT:GetFriendlyPartySize() > 1)
    local hasNearbyFriendly = (friendlyAssists > 0)

    local isSolo = false
    if finalBlowKillerGUID == playerGUID then
        isSolo = (not hasExternalAttacker)
             and (not hasExternalAssistOnVictim)
             and (not hasExternalAssistOnPlayer)
             and (not hasRecentAssistedAlly)
             and (not inGroup)
             and (not hasNearbyFriendly)
             and (totalDamage > 0)
    else
        isSolo = (#attackersList == 1) and (not inGroup)
    end

    local friendlyPartySize = math.max(CT:GetFriendlyPartySize(), #attackersList)
    if friendlyAssists > 0 then
        friendlyPartySize = friendlyPartySize + friendlyAssists
    end
    if not isSolo and friendlyPartySize < 2 then
        friendlyPartySize = 2
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

    if playerGUID and victimGUID == playerGUID then
        victimInfo.name = UnitName("player")
        victimInfo.level = UnitLevel("player") or 0
        local _, pClass = UnitClass("player")
        victimInfo.class = pClass or "UNKNOWN"
        victimInfo.faction = UnitFactionGroup("player") or "Unknown"
        victimInfo.guild = GetGuildInfo("player") or "None"
    end

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
        if settings.promptMarkOnDeath ~= false and settings.promptBountyOnDeath ~= false then
            CT.PendingDeathBounty = CT.LastPvpKiller
            CT:CheckPendingDeathBounty()
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
        attackersCount = math.max(#attackersList, friendlyPartySize),
        attackers = attackersList,
        totalDamage = totalDamage,
        killer = {
            guid = killerInfo.guid,
            name = killerInfo.name,
            level = killerInfo.level,
            class = killerInfo.class,
            guild = killerInfo.guild,
            faction = killerInfo.faction,
            partySize = (finalBlowKillerGUID == playerGUID) and friendlyPartySize or math.max(1, #attackersList),
            damageDone = (finalBlowKillerGUID == playerGUID) and (totalDamage > 0 and totalDamage or CT.SessionStats.damageDone) or totalDamage,
            healingDone = (finalBlowKillerGUID == playerGUID) and CT.SessionStats.healingDone or 0,
        },
        victim = {
            guid = victimInfo.guid,
            name = victimInfo.name,
            level = victimInfo.level,
            class = victimInfo.class,
            guild = victimInfo.guild,
            faction = victimInfo.faction,
            partySize = (finalBlowKillerGUID == playerGUID) and hostilePartySize or CT:GetFriendlyPartySize(),
        },
        location = location,
    })

    CT.LastKillVictim = cleanVictim or victimInfo.name
    CT.LastKillGUID = victimGUID
    CT.LastKillTime = now
end

local PVP_RANK_PREFIXES = {
    "Grand Marshal%s+", "Field Marshal%s+", "Marshal%s+", "Commander%s+",
    "Lieutenant Commander%s+", "Knight%-Champion%s+", "Knight%-Lieutenant%s+",
    "Knight%s+", "Sergeant Major%s+", "Master Sergeant%s+", "Sergeant%s+",
    "Corporal%s+", "Private%s+",
    "High Warlord%s+", "Warlord%s+", "General%s+", "Lieutenant General%s+",
    "Champion%s+", "Centurion%s+", "Legionnaire%s+", "Blood Guard%s+",
    "Stone Guard%s+", "First Sergeant%s+", "Senior Sergeant%s+", "Grunt%s+",
    "Scout%s+",
}

local function StripRankPrefix(name)
    if not name or type(name) ~= "string" then return name end
    for _, prefix in ipairs(PVP_RANK_PREFIXES) do
        name = name:gsub("^" .. prefix, "")
    end
    return name:match("^%s*(.-)%s*$")
end

-- Helper to parse victim name from CHAT_MSG_COMBAT_HONOR_GAIN
local function ExtractVictimFromHonorMsg(msg)
    if not msg or not KB.Utils.CanAccess(msg) or type(msg) ~= "string" then return nil end
    local clean = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")

    -- Format 1: "%s dies, honorable kill ..."
    local victim = clean:match("^(.-)%s+dies")

    -- Format 2: "... for the death of %s."
    if not victim then
        victim = clean:match("death of%s+([^%.%,%!]+)")
    end

    -- Format 3: "Honorable Kill: %s"
    if not victim then
        victim = clean:match("Honorable Kill:%s*([^%.%,%!%(]+)")
    end

    if victim then
        victim = victim:gsub("[%.,!%?:;]", "")
        victim = StripRankPrefix(victim)
        if KB.Utils.CanAccess(victim) and victim ~= "" then
            return victim
        end
    end
    return nil
end

-- Process an honorable kill across all clients (CLEU, UnitEvents, Chat, HK counter)
function CT:OnPlayerHonorableKill(victimName, explicitGuid, unitToken)
    local now = time()

    local victimInfo = nil
    if unitToken and UnitExists(unitToken) and UnitIsPlayer(unitToken) then
        victimInfo = KB.UnitScanner and KB.UnitScanner:ScanUnit(unitToken)
        if (not victimName or victimName == "") and victimInfo then
            victimName = victimInfo.name
        end
    end

    if (not victimName or victimName == "") and UnitExists("target") and UnitIsPlayer("target") and (UnitIsDead("target") or UnitIsDeadOrGhost("target")) then
        victimName = UnitName("target")
        victimInfo = KB.UnitScanner and KB.UnitScanner:ScanUnit("target")
    end

    if (not victimName or victimName == "") and activeEnemyTarget and (now - (activeEnemyTarget.lastSeen or 0)) <= 30 then
        victimName = activeEnemyTarget.name
        victimInfo = activeEnemyTarget
    end

    if not victimName or victimName == "" then
        local bestEnemy = nil
        local bestTime = 0
        for guid, e in pairs(CT.RecentEngagedEnemies) do
            if e.lastSeen and e.lastSeen > bestTime and (now - e.lastSeen) <= 30 then
                bestEnemy = e
                bestTime = e.lastSeen
            end
        end
        if bestEnemy then
            victimName = bestEnemy.name
            victimInfo = bestEnemy
        end
    end

    if not victimName or victimName == "" then
        victimName = "Hostile Combatant"
    end

    if not KB.Utils.CanAccess(victimName) then return end

    local cleanVictim = KB.Utils.CleanCombatantName(victimName)
    local normVictim = KB.Utils.NormalizeCombatantName(victimName)

    if CT.LastKillVictim and ((cleanVictim and CT.LastKillVictim:lower() == cleanVictim:lower()) or (victimName and CT.LastKillVictim:lower() == victimName:lower())) and (now - (CT.LastKillTime or 0)) < 5 then
        return
    end
    if explicitGuid and CT.LastKillGUID and CT.LastKillGUID == explicitGuid and (now - (CT.LastKillTime or 0)) < 5 then
        return
    end
    CT.LastKillVictim = cleanVictim or victimName
    CT.LastKillTime = now
    if explicitGuid then CT.LastKillGUID = explicitGuid end

    local victimGUID = explicitGuid or (victimInfo and victimInfo.guid)
    if (not victimGUID or victimGUID == "UNKNOWN") and normVictim and CT.RecentVictimGUIDs[normVictim] then
        victimGUID = CT.RecentVictimGUIDs[normVictim]
    end
    if (not victimGUID or victimGUID == "UNKNOWN") and victimName and CT.RecentVictimGUIDs[victimName:lower()] then
        victimGUID = CT.RecentVictimGUIDs[victimName:lower()]
    end
    if (not victimGUID or victimGUID == "UNKNOWN") and UnitExists("target") then
        local tName = UnitName("target")
        if (cleanVictim and tName and tName:lower() == cleanVictim:lower()) or (victimName and tName and tName:lower() == victimName:lower()) then
            victimGUID = UnitGUID("target")
        end
    end
    if (not victimGUID or victimGUID == "UNKNOWN") and activeEnemyTarget then
        if (cleanVictim and activeEnemyTarget.name and activeEnemyTarget.name:lower() == cleanVictim:lower()) or (victimName and activeEnemyTarget.name and activeEnemyTarget.name:lower() == victimName:lower()) then
            victimGUID = activeEnemyTarget.guid
        end
    end
    if (not victimGUID or victimGUID == "UNKNOWN") then
        for guid, e in pairs(CT.RecentEngagedEnemies) do
            local eNorm = KB.Utils.NormalizeCombatantName(e.name)
            if (normVictim and eNorm == normVictim) or (e.name == victimName) or (cleanVictim and e.name == cleanVictim) then
                victimGUID = guid
                break
            end
        end
    end
    if (not victimGUID or victimGUID == "UNKNOWN") then
        for guid, _ in pairs(CT.RecentDamage) do
            local vName = CT.RecentVictimNames[guid]
            local vNorm = KB.Utils.NormalizeCombatantName(vName)
            if (normVictim and vNorm == normVictim) or (vName and victimName and vName:lower() == victimName:lower()) then
                victimGUID = guid
                break
            end
            local uInfo = KB.UnitScanner and KB.UnitScanner:GetUnitInfo(guid)
            if uInfo and uInfo.name and ((cleanVictim and uInfo.name:lower() == cleanVictim:lower()) or (victimName and uInfo.name:lower() == victimName:lower())) then
                victimGUID = guid
                break
            end
        end
    end

    if not victimInfo then
        victimInfo = (victimGUID and KB.UnitScanner:GetUnitInfo(victimGUID)) or KB.UnitScanner:GetUnitInfoByName(victimName) or (cleanVictim and KB.UnitScanner:GetUnitInfoByName(cleanVictim)) or {
            guid = victimGUID or "UNKNOWN",
            name = cleanVictim or victimName,
            level = 0,
            class = "UNKNOWN",
            guild = "None",
            faction = "Unknown",
            partySize = 1,
        }
    end
    if victimGUID and victimGUID ~= "UNKNOWN" and victimInfo then
        victimInfo.guid = victimGUID
    end

    local partySize = CT:GetFriendlyPartySize()
    local playerGUID = UnitGUID("player")
    local playerName = UnitName("player")
    local _, pClass = UnitClass("player")
    local pFaction = UnitFactionGroup("player")
    local pGuild = GetGuildInfo("player")

    CT:PruneCombatInteractions()

    -- Check FriendlyCluster for friendly assists in the last 30 seconds
    local friendlyAssists = 0
    local clusterAssists = {}
    for fGUID, fTime in pairs(CT.FriendlyCluster) do
        if fGUID ~= playerGUID and (now - fTime) <= 30 then
            friendlyAssists = friendlyAssists + 1
            table.insert(clusterAssists, fGUID)
        end
    end

    -- Gather all attackers from RecentDamage and RecentDamageByName for this victim
    local attackersList = {}
    local totalDamage = 0
    local recordedAttackersMap = {}

    local damageSources = {}
    if victimGUID and CT.RecentDamage[victimGUID] then
        for attGUID, attData in pairs(CT.RecentDamage[victimGUID]) do
            damageSources[attGUID] = attData
        end
    end
    if normVictim and CT.RecentDamageByName and CT.RecentDamageByName[normVictim] then
        for attGUID, attData in pairs(CT.RecentDamageByName[normVictim]) do
            if not damageSources[attGUID] then
                damageSources[attGUID] = attData
            else
                damageSources[attGUID].totalDamage = math.max(damageSources[attGUID].totalDamage or 0, attData.totalDamage or 0)
            end
        end
    end

    local playerDamage = 0
    local topPlayerAttacker = nil
    local topPlayerDmg = -1

    for attGUID, attData in pairs(damageSources) do
        local isAttPlayer = attData.isPlayer
        if isAttPlayer == nil then
            isAttPlayer = (attGUID:match("^Player%-") ~= nil)
        end
        local unitInfo = KB.UnitScanner and KB.UnitScanner.GetUnitInfo and KB.UnitScanner:GetUnitInfo(attGUID)
        local attClass = "UNKNOWN"
        local attLevel = 0
        local attGuild = "None"
        local attFaction = "Unknown"
        if playerGUID and attGUID == playerGUID then
            attClass = pClass or "UNKNOWN"
            attLevel = UnitLevel("player") or 0
            attGuild = pGuild or "None"
            attFaction = pFaction or "Unknown"
            playerDamage = attData.totalDamage or 0
        elseif unitInfo then
            attClass = unitInfo.class or "UNKNOWN"
            attLevel = unitInfo.level or 0
            attGuild = unitInfo.guild or "None"
            attFaction = unitInfo.faction or "Unknown"
        end
        local attEntry = {
            guid = attGUID,
            name = attData.name or "Unknown",
            damage = attData.totalDamage or 0,
            spell = attData.spellName or "Combat",
            class = attClass,
            level = attLevel,
            guild = attGuild,
            faction = attFaction,
            isPlayer = isAttPlayer,
        }
        table.insert(attackersList, attEntry)
        totalDamage = totalDamage + (attData.totalDamage or 0)
        recordedAttackersMap[attGUID] = true

        if isAttPlayer and (attData.totalDamage or 0) > topPlayerDmg then
            topPlayerDmg = attData.totalDamage or 0
            topPlayerAttacker = attEntry
        end
    end

    -- If player was not in RecentDamage, insert player
    if playerGUID and not recordedAttackersMap[playerGUID] then
        table.insert(attackersList, {
            guid = playerGUID,
            name = playerName or "Player",
            damage = 0,
            spell = "Support Assist",
            class = pClass or "UNKNOWN",
            level = UnitLevel("player") or 0,
            guild = pGuild or "None",
            faction = pFaction or "Unknown",
            isPlayer = true,
        })
    end

    -- Append friendly cluster participants who assisted recently
    for _, fGUID in ipairs(clusterAssists) do
        if not recordedAttackersMap[fGUID] then
            local fInfo = KB.UnitScanner and KB.UnitScanner:GetUnitInfo(fGUID)
            table.insert(attackersList, {
                guid = fGUID,
                name = (fInfo and fInfo.name) or "Friendly Ally",
                damage = 0,
                spell = "Support Assist",
                class = (fInfo and fInfo.class) or "UNKNOWN",
                level = (fInfo and fInfo.level) or 0,
                guild = (fInfo and fInfo.guild) or "None",
                faction = (fInfo and fInfo.faction) or (pFaction or "Unknown"),
                isPlayer = true,
            })
            recordedAttackersMap[fGUID] = true
        end
    end

    -- Append external allies who contributed assists or debuffs against this victim
    local assistSources = {}
    if victimGUID and CT.RecentVictimAssists[victimGUID] then
        for aGUID, aData in pairs(CT.RecentVictimAssists[victimGUID]) do
            if (now - (aData.time or 0)) <= 30 then
                assistSources[aGUID] = aData
            end
        end
    end
    if normVictim and CT.RecentVictimAssistsByName and CT.RecentVictimAssistsByName[normVictim] then
        for aGUID, aData in pairs(CT.RecentVictimAssistsByName[normVictim]) do
            if (now - (aData.time or 0)) <= 30 and not assistSources[aGUID] then
                assistSources[aGUID] = aData
            end
        end
    end

    for aGUID, aData in pairs(assistSources) do
        if not recordedAttackersMap[aGUID] and aGUID ~= playerGUID then
            local aInfo = KB.UnitScanner and KB.UnitScanner:GetUnitInfo(aGUID)
            table.insert(attackersList, {
                guid = aGUID,
                name = (aInfo and aInfo.name) or aData.name or "Friendly Ally",
                damage = 0,
                spell = aData.spell or "Assist",
                class = (aInfo and aInfo.class) or "UNKNOWN",
                level = (aInfo and aInfo.level) or 0,
                guild = (aInfo and aInfo.guild) or "None",
                faction = (aInfo and aInfo.faction) or (pFaction or "Unknown"),
                isPlayer = true,
            })
            recordedAttackersMap[aGUID] = true
        end
    end

    -- Strict 100% Certified Solo Kill Criteria:
    -- 1. Attacker list contains ONLY 1 player
    -- 2. Zero other friendly players debuffed, slowed, stunned or assisted against victim within 30s
    -- 3. Zero external friendly heals received by the player within 30s
    -- 4. Zero external friendly buffs received by the player within 30s
    -- 5. Zero friendly allies assisted/healed/buffed by the player within 30s
    -- 6. Friendly party/raid size is strictly 1
    -- 7. Zero active friendly cluster participants within 30s
    -- 8. Player MUST have dealt positive damage (> 0) to the victim
    local hasExternalAttacker = false
    for _, att in ipairs(attackersList) do
        if att.guid ~= playerGUID and (att.name ~= playerName) then
            hasExternalAttacker = true
            break
        end
    end

    local hasExternalAssistOnVictim = false
    for aGUID, aData in pairs(assistSources) do
        if aGUID ~= playerGUID and aData.name ~= playerName then
            hasExternalAssistOnVictim = true
            break
        end
    end

    local hasExternalAssistOnPlayer = false
    for hGUID, hData in pairs(CT.ExternalAssistsOnPlayer) do
        if hGUID ~= playerGUID and (now - (hData.time or 0)) <= 30 then
            hasExternalAssistOnPlayer = true
            break
        end
    end

    local hasRecentAssistedAlly = false
    if CT.PlayerAssistedAllies then
        for aGUID, aData in pairs(CT.PlayerAssistedAllies) do
            if aGUID ~= playerGUID and (now - (aData.time or 0)) <= 30 then
                hasRecentAssistedAlly = true
                break
            end
        end
    end

    local inGroup = (partySize > 1)
    local hasNearbyFriendly = (friendlyAssists > 0)
    local hasPlayerDamage = (playerDamage > 0)

    local isSolo = (not hasExternalAttacker)
               and (not hasExternalAssistOnVictim)
               and (not hasExternalAssistOnPlayer)
               and (not hasRecentAssistedAlly)
               and (not inGroup)
               and (not hasNearbyFriendly)
               and hasPlayerDamage

    local attackersCount = math.max(#attackersList, partySize, 1 + friendlyAssists)
    if not isSolo and attackersCount < 2 then
        attackersCount = 2
    end

    -- Determine true killer: if player dealt 0 damage and an ally dealt damage, attribute kill to the ally
    local killerData = nil
    if hasPlayerDamage and (not topPlayerAttacker or topPlayerAttacker.guid == playerGUID) then
        killerData = {
            guid = playerGUID or "PLAYER",
            name = playerName or "Player",
            level = UnitLevel("player") or 0,
            class = pClass or "UNKNOWN",
            guild = pGuild or "None",
            faction = pFaction or "Unknown",
            partySize = attackersCount,
            damageDone = playerDamage,
            healingDone = CT.SessionStats.healingDone or 0,
        }
    elseif topPlayerAttacker and topPlayerAttacker.guid ~= playerGUID and (topPlayerAttacker.damage or 0) > 0 then
        killerData = {
            guid = topPlayerAttacker.guid,
            name = topPlayerAttacker.name,
            level = topPlayerAttacker.level or 0,
            class = topPlayerAttacker.class or "UNKNOWN",
            guild = topPlayerAttacker.guild or "None",
            faction = topPlayerAttacker.faction or (pFaction or "Unknown"),
            partySize = attackersCount,
            damageDone = topPlayerAttacker.damage,
            healingDone = 0,
        }
    elseif #clusterAssists > 0 then
        local firstAllyGUID = clusterAssists[1]
        local aInfo = KB.UnitScanner and KB.UnitScanner:GetUnitInfo(firstAllyGUID)
        killerData = {
            guid = firstAllyGUID,
            name = (aInfo and aInfo.name) or "Friendly Ally",
            level = (aInfo and aInfo.level) or 0,
            class = (aInfo and aInfo.class) or "UNKNOWN",
            guild = (aInfo and aInfo.guild) or "None",
            faction = (aInfo and aInfo.faction) or (pFaction or "Unknown"),
            partySize = attackersCount,
            damageDone = totalDamage,
            healingDone = 0,
        }
    else
        killerData = {
            guid = playerGUID or "PLAYER",
            name = playerName or "Player",
            level = UnitLevel("player") or 0,
            class = pClass or "UNKNOWN",
            guild = pGuild or "None",
            faction = pFaction or "Unknown",
            partySize = attackersCount,
            damageDone = playerDamage,
            healingDone = CT.SessionStats.healingDone or 0,
        }
    end

    if killerData.guid == playerGUID then
        CT.SessionStats.kills = CT.SessionStats.kills + 1
    end

    local context = CT:GetCombatContext()
    local location = KB.Utils.GetPlayerLocation()

    KB.Killmail:RecordKill({
        timestamp = now,
        isBattleground = context.isBattleground,
        isArena = context.isArena,
        battlegroundName = context.battlegroundName,
        isSolo = isSolo,
        attackersCount = attackersCount,
        attackers = attackersList,
        totalDamage = totalDamage,
        killer = killerData,
        victim = {
            guid = (victimInfo and victimInfo.guid) or victimGUID or "UNKNOWN",
            name = (victimInfo and victimInfo.name) or cleanVictim or victimName,
            level = (victimInfo and victimInfo.level) or 0,
            class = (victimInfo and victimInfo.class) or "UNKNOWN",
            guild = (victimInfo and victimInfo.guild) or "None",
            faction = (victimInfo and victimInfo.faction) or "Unknown",
            partySize = 1,
        },
        location = location,
    })
end

-- Manual kill registration for in-game testing (/kb testkill)
function CT:RecordManualKill(customTargetName)
    local targetName = customTargetName
    local targetGuid = nil
    local targetInfo = nil

    if (not targetName or targetName == "") and UnitExists("target") and UnitIsPlayer("target") then
        targetName = UnitName("target")
        targetGuid = UnitGUID("target")
        targetInfo = KB.UnitScanner and KB.UnitScanner:ScanUnit("target")
    end

    if not targetName or targetName == "" then
        targetName = "Target Dummy"
    end

    self:OnPlayerHonorableKill(targetName, targetGuid, "target")
    print(string.format("|cff00ff00[WoWKB]|r Manual killmail registered for |cffffff00%s|r.", targetName))
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

    local function ResolveDuelCombatant(charName, cleanName, defaultGuid)
        -- 1. Check UnitScanner Cache & Known Characters Directory
        local info = KB.UnitScanner and (KB.UnitScanner:GetUnitInfoByName(charName) or KB.UnitScanner:GetUnitInfoByName(cleanName))
        if info and info.level and info.level > 0 and info.level <= 85 and info.class and info.class ~= "UNKNOWN" then
            return {
                guid = info.guid or defaultGuid,
                name = charName,
                level = info.level,
                class = info.class or "UNKNOWN",
                guild = info.guild or "None",
                faction = info.faction or "Unknown",
                partySize = 1,
            }
        end

        -- 2. Check active candidate units (target, mouseover, focus, targettarget, party/raid)
        local candidateUnits = { "target", "mouseover", "focus", "targettarget", "party1", "party2", "party3", "party4" }
        for _, u in ipairs(candidateUnits) do
            if UnitExists(u) and (UnitName(u) == charName or UnitName(u) == cleanName) then
                local scanned = KB.UnitScanner and KB.UnitScanner:ScanUnit(u)
                local uLvl = (scanned and scanned.level and scanned.level > 0 and scanned.level <= 85) and scanned.level or (UnitLevel and UnitLevel(u) or 0)
                if uLvl == -1 or uLvl > 85 then
                    local pGuid = UnitGUID(u)
                    if pGuid and C_PlayerInfo and C_PlayerInfo.GetPlayerLevelByGUID then
                        uLvl = C_PlayerInfo.GetPlayerLevelByGUID(pGuid) or 0
                    else
                        uLvl = 0
                    end
                end
                if uLvl > 0 and uLvl <= 85 then
                    return {
                        guid = (scanned and scanned.guid) or UnitGUID(u) or defaultGuid,
                        name = charName,
                        level = uLvl,
                        class = (scanned and scanned.class ~= "UNKNOWN") and scanned.class or (select(2, UnitClass(u)) or "UNKNOWN"),
                        guild = (scanned and scanned.guild ~= "None") and scanned.guild or (GetGuildInfo and GetGuildInfo(u) or "None"),
                        faction = (scanned and scanned.faction ~= "Unknown") and scanned.faction or (UnitFactionGroup and UnitFactionGroup(u) or "Unknown"),
                        partySize = 1,
                    }
                end
            end
        end

        -- 3. Check visible nameplates (nameplate1 through nameplate40)
        for i = 1, 40 do
            local np = "nameplate" .. i
            if UnitExists(np) and (UnitName(np) == charName or UnitName(np) == cleanName) then
                local scanned = KB.UnitScanner and KB.UnitScanner:ScanUnit(np)
                local npLvl = (scanned and scanned.level and scanned.level > 0 and scanned.level <= 85) and scanned.level or (UnitLevel and UnitLevel(np) or 0)
                if npLvl == -1 or npLvl > 85 then
                    local npGuid = UnitGUID(np)
                    if npGuid and C_PlayerInfo and C_PlayerInfo.GetPlayerLevelByGUID then
                        npLvl = C_PlayerInfo.GetPlayerLevelByGUID(npGuid) or 0
                    else
                        npLvl = 0
                    end
                end
                if npLvl > 0 and npLvl <= 85 then
                    return {
                        guid = (scanned and scanned.guid) or UnitGUID(np) or defaultGuid,
                        name = charName,
                        level = npLvl,
                        class = (scanned and scanned.class ~= "UNKNOWN") and scanned.class or (select(2, UnitClass(np)) or "UNKNOWN"),
                        guild = (scanned and scanned.guild ~= "None") and scanned.guild or (GetGuildInfo and GetGuildInfo(np) or "None"),
                        faction = (scanned and scanned.faction ~= "Unknown") and scanned.faction or (UnitFactionGroup and UnitFactionGroup(np) or "Unknown"),
                        partySize = 1,
                    }
                end
            end
        end

        -- 4. Check historical kill records in database
        if WoWKillboardDB and WoWKillboardDB.kills then
            for _, km in pairs(WoWKillboardDB.kills) do
                if km.killer and (km.killer.name == charName or km.killer.name == cleanName) and km.killer.level and km.killer.level > 0 and km.killer.level <= 85 then
                    return {
                        guid = km.killer.guid or defaultGuid,
                        name = charName,
                        level = km.killer.level,
                        class = (info and info.class ~= "UNKNOWN") and info.class or (km.killer.class or "UNKNOWN"),
                        guild = (info and info.guild ~= "None") and info.guild or (km.killer.guild or "None"),
                        faction = (info and info.faction ~= "Unknown") and info.faction or (km.killer.faction or "Unknown"),
                        partySize = 1,
                    }
                elseif km.victim and (km.victim.name == charName or km.victim.name == cleanName) and km.victim.level and km.victim.level > 0 and km.victim.level <= 85 then
                    return {
                        guid = km.victim.guid or defaultGuid,
                        name = charName,
                        level = km.victim.level,
                        class = (info and info.class ~= "UNKNOWN") and info.class or (km.victim.class or "UNKNOWN"),
                        guild = (info and info.guild ~= "None") and info.guild or (km.victim.guild or "None"),
                        faction = (info and info.faction ~= "Unknown") and info.faction or (km.victim.faction or "Unknown"),
                        partySize = 1,
                    }
                end
            end
        end

        -- 5. Fallback with damage inference if class still unknown
        local cClass = info and info.class or "UNKNOWN"
        if cClass == "UNKNOWN" then
            for _, victimAtts in pairs(CT.RecentDamage) do
                for _, att in pairs(victimAtts) do
                    if att.name == charName or att.name == cleanName then
                        if att.class and att.class ~= "UNKNOWN" then
                            cClass = att.class
                            break
                        elseif att.spellName and KB.UnitScanner and KB.UnitScanner.InferClassFromSpell then
                            local inferred = KB.UnitScanner:InferClassFromSpell(att.guid, att.name, att.spellName)
                            if inferred then cClass = inferred; break end
                        end
                    end
                end
                if cClass ~= "UNKNOWN" then break end
            end
        end

        local fallbackLvl = (info and info.level) or 0
        if fallbackLvl > 85 then fallbackLvl = 0 end

        return {
            guid = (info and info.guid) or defaultGuid,
            name = charName,
            level = fallbackLvl,
            class = cClass,
            guild = (info and info.guild) or "None",
            faction = (info and info.faction) or "Unknown",
            partySize = 1,
        }
    end

    local killerInfo = nil
    if isPlayerWinner then
        killerInfo = {
            guid = UnitGUID("player") or "PLAYER",
            name = winnerName,
            level = UnitLevel("player") or 0,
            class = select(2, UnitClass("player")) or "UNKNOWN",
            guild = GetGuildInfo("player") or "None",
            faction = UnitFactionGroup("player") or "Unknown",
            partySize = 1,
            damageDone = CT.SessionStats.damageDone or 0,
            healingDone = CT.SessionStats.healingDone or 0,
        }
    else
        killerInfo = ResolveDuelCombatant(winnerName, cleanWinner, "DUEL_WINNER")
        killerInfo.damageDone = 0
        killerInfo.healingDone = 0
    end

    local victimInfo = nil
    if isPlayerLoser then
        victimInfo = {
            guid = UnitGUID("player") or "PLAYER",
            name = loserName,
            level = UnitLevel("player") or 0,
            class = select(2, UnitClass("player")) or "UNKNOWN",
            guild = GetGuildInfo("player") or "None",
            faction = UnitFactionGroup("player") or "Unknown",
            partySize = 1,
        }
    else
        victimInfo = ResolveDuelCombatant(loserName, cleanLoser, "DUEL_LOSER")
    end

    local location = KB.Utils.GetPlayerLocation()

    KB.Killmail:RecordKill({
        timestamp = now,
        isDuel = true,
        isBattleground = false,
        isArena = false,
        battlegroundName = isFlee and "Duel (Forfeit)" or "Duel (Knockout)",
        isSolo = false,
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

-- Check and display pending revenge death bounty prompt when not in combat
function CT:CheckPendingDeathBounty()
    if not CT.PendingDeathBounty then return end
    local settings = WoWKillboardSettings or {}
    if settings.promptMarkOnDeath == false or settings.promptBountyOnDeath == false then
        CT.PendingDeathBounty = nil
        return
    end
    local inInst, instType = false, "none"
    if IsInInstance then inInst, instType = IsInInstance() end
    if inInst or (instType and instType ~= "none") then
        CT.PendingDeathBounty = nil
        return
    end

    if not InCombatLockdown() then
        local killer = CT.PendingDeathBounty
        CT.PendingDeathBounty = nil
        if KB.UI and KB.UI.ShowDeathBountyPrompt then
            KB.UI:ShowDeathBountyPrompt(killer)
        end
    else
        if C_Timer and C_Timer.After then
            C_Timer.After(0.5, function() CT:CheckPendingDeathBounty() end)
            C_Timer.After(1.5, function() CT:CheckPendingDeathBounty() end)
        end
    end
end

-- Event Listener Frame
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, _, destGUID, destName, destFlags, _ = GetCombatLogPayload(...)

        local playerGUID = UnitGUID("player")
        if sourceGUID and playerGUID and sourceGUID ~= playerGUID and IsPlayerUnit(sourceGUID, sourceFlags, sourceName) then
            if HasFlag(sourceFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) then
                CT.HostileCluster[sourceGUID] = time()
            else
                CT.FriendlyCluster[sourceGUID] = time()
            end
        end

        if subevent == "SWING_DAMAGE" then
            local amount = select(12, GetCombatLogPayload(...))
            CT:RecordDamage(timestamp, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, amount or 0, "Melee Swing")
        elseif subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" or subevent == "RANGE_DAMAGE" or subevent == "DAMAGE_SHIELD" then
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
        elseif subevent == "SPELL_CAST_SUCCESS" or subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH" or subevent == "SPELL_AURA_APPLIED_DOSE" then
            local spellId, spellName = select(12, GetCombatLogPayload(...))
            if KB.UnitScanner and KB.UnitScanner.InferClassFromSpell then
                KB.UnitScanner:InferClassFromSpell(sourceGUID, sourceName, spellName)
            end
            local playerGUID = UnitGUID("player")
            local now = time()
            if playerGUID and destGUID == playerGUID and sourceGUID ~= playerGUID then
                CT.FriendlyCluster[sourceGUID] = now
                local srcName = KB.Utils.CleanCombatantName(sourceName) or KB.Utils.SafeString(sourceName, "Ally")
                CT.ExternalAssistsOnPlayer[sourceGUID] = {
                    name = srcName,
                    guid = sourceGUID,
                    time = now,
                    spell = spellName or "Buff",
                    type = "buff",
                }
            elseif playerGUID and sourceGUID == playerGUID and destGUID and destGUID ~= playerGUID then
                local isHostile = HasFlag(destFlags, COMBATLOG_OBJECT_REACTION_HOSTILE)
                local isFriendly = HasFlag(destFlags, COMBATLOG_OBJECT_REACTION_FRIENDLY) or (not isHostile)
                if isFriendly then
                    -- Player cast a buff, aura, or assistance spell on a friendly ally!
                    CT.FriendlyCluster[destGUID] = now
                    CT.PlayerAssistedAllies = CT.PlayerAssistedAllies or {}
                    local dstName = KB.Utils.CleanCombatantName(destName) or KB.Utils.SafeString(destName, "Ally")
                    CT.PlayerAssistedAllies[destGUID] = {
                        name = dstName,
                        guid = destGUID,
                        time = now,
                        spell = spellName or "Buff",
                        type = "buff",
                    }
                end
            elseif playerGUID and destGUID ~= playerGUID and sourceGUID ~= playerGUID then
                local isHostile = HasFlag(sourceFlags, COMBATLOG_OBJECT_REACTION_HOSTILE)
                local isFriendly = HasFlag(sourceFlags, COMBATLOG_OBJECT_REACTION_FRIENDLY) or (not isHostile)
                if isFriendly and destGUID then
                    local cleanSrc = KB.Utils.CleanCombatantName(sourceName) or KB.Utils.SafeString(sourceName, "Ally")
                    local cleanDst = KB.Utils.CleanCombatantName(destName)
                    local normDst = KB.Utils.NormalizeCombatantName(destName)
                    local assistData = {
                        name = cleanSrc,
                        guid = sourceGUID,
                        time = now,
                        spell = spellName or "Assist",
                        type = "debuff",
                    }
                    CT.FriendlyCluster[sourceGUID] = now
                    CT.RecentVictimAssists[destGUID] = CT.RecentVictimAssists[destGUID] or {}
                    CT.RecentVictimAssists[destGUID][sourceGUID] = assistData
                    if normDst and normDst ~= "" then
                        CT.RecentVictimAssistsByName[normDst] = CT.RecentVictimAssistsByName[normDst] or {}
                        CT.RecentVictimAssistsByName[normDst][sourceGUID] = assistData
                    end
                    if destName and destName ~= "" then
                        CT.RecentVictimNames[destGUID] = cleanDst or destName
                        if normDst and normDst ~= "" then
                            CT.RecentVictimGUIDs[normDst] = destGUID
                        end
                        CT.RecentVictimGUIDs[destName:lower()] = destGUID
                    end
                end
            end
        elseif subevent == "PARTY_KILL" then
            CT:ProcessDeath(destGUID, destName, destFlags, sourceGUID, sourceName)
        elseif subevent == "UNIT_DIED" then
            CT:ProcessDeath(destGUID, destName, destFlags, nil, nil)
        end

    elseif event == "CHAT_MSG_COMBAT_HONOR_GAIN" then
        local msg = ...
        local victimName = ExtractVictimFromHonorMsg(msg)
        CT:OnPlayerHonorableKill(victimName)

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
        local playerGUID = UnitGUID("player")
        if playerGUID then
            CT:ProcessDeath(playerGUID, UnitName("player"), COMBATLOG_OBJECT_TYPE_PLAYER, nil, nil)
        end
        CT:CheckPendingDeathBounty()

    elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" or event == "PLAYER_REGEN_ENABLED" then
        CT:CheckPendingDeathBounty()

    elseif event == "PLAYER_TARGET_CHANGED" then
        if UnitExists("target") and UnitIsPlayer("target") then
            local isEnemy = UnitIsEnemy("player", "target") or (UnitCanAttack and UnitCanAttack("player", "target")) or (not UnitIsFriend("player", "target"))
            if isEnemy then
                local isDead = (UnitIsDead("target") or UnitIsDeadOrGhost("target")) and true or false
                local tGuid = UnitGUID("target")
                local tName = UnitName("target")
                if isDead and tName and tName ~= "" then
                    if activeEnemyTarget and (activeEnemyTarget.guid == tGuid or activeEnemyTarget.name == tName) then
                        CT:OnPlayerHonorableKill(tName, tGuid, "target")
                    end
                elseif not isDead then
                    local tInfo = KB.UnitScanner and KB.UnitScanner:ScanUnit("target")
                    activeEnemyTarget = {
                        name = tName,
                        guid = tGuid,
                        level = UnitLevel("target") or (tInfo and tInfo.level or 0),
                        class = select(2, UnitClass("target")) or (tInfo and tInfo.class or "UNKNOWN"),
                        guild = GetGuildInfo("target") or (tInfo and tInfo.guild or "None"),
                        faction = UnitFactionGroup("target") or (tInfo and tInfo.faction or "Unknown"),
                        lastSeen = time(),
                    }
                    if tGuid then
                        CT.RecentEngagedEnemies[tGuid] = activeEnemyTarget
                    end
                end
            end
        end

    elseif event == "UNIT_HEALTH" or event == "UNIT_FLAGS" then
        local unit = ...
        if unit == "target" or unit == "focus" or unit == "targettarget" or (unit and unit:match("^nameplate%d+$")) then
            if UnitExists(unit) and UnitIsPlayer(unit) then
                local isDead = (UnitIsDead(unit) or UnitIsDeadOrGhost(unit)) and true or false
                if isDead then
                    local isEnemy = UnitIsEnemy("player", unit) or (UnitCanAttack and UnitCanAttack("player", unit)) or (not UnitIsFriend("player", unit))
                    if isEnemy or (activeEnemyTarget and activeEnemyTarget.guid == UnitGUID(unit)) then
                        local deadName = UnitName(unit)
                        local deadGuid = UnitGUID(unit)
                        if deadName and deadName ~= "" then
                            CT:OnPlayerHonorableKill(deadName, deadGuid, unit)
                        end
                    end
                end
            end
        end

    elseif event == "PLAYER_PVP_KILLS_CHANGED" then
        local currentHK = nil
        if type(GetPVPLifetimeStats) == "function" then
            local ok, hk = pcall(GetPVPLifetimeStats)
            if ok and hk then currentHK = tonumber(hk) end
        end
        if not currentHK and type(GetPVPSessionStats) == "function" then
            local ok, hk = pcall(GetPVPSessionStats)
            if ok and hk then currentHK = tonumber(hk) end
        end

        if currentHK and CT.LastLifetimeHK and currentHK > CT.LastLifetimeHK then
            CT.LastLifetimeHK = currentHK
            CT:OnPlayerHonorableKill(nil)
        elseif currentHK and not CT.LastLifetimeHK then
            CT.LastLifetimeHK = currentHK
        end

    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        if type(GetPVPLifetimeStats) == "function" then
            local ok, hk = pcall(GetPVPLifetimeStats)
            if ok and hk then CT.LastLifetimeHK = tonumber(hk) end
        end
        if not CT.LastLifetimeHK and type(GetPVPSessionStats) == "function" then
            local ok, hk = pcall(GetPVPSessionStats)
            if ok and hk then CT.LastLifetimeHK = tonumber(hk) end
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
-- CLEU is registered cleanly across WoW Forever Beta (1.16/16001), Classic Era (11500), Anniversary (11500), and Modern Retail
pcall(frame.RegisterEvent, frame, "COMBAT_LOG_EVENT_UNFILTERED")

frame:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN")
frame:RegisterEvent("CHAT_MSG_SYSTEM")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("PLAYER_ALIVE")
frame:RegisterEvent("PLAYER_UNGHOST")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("PLAYER_PVP_KILLS_CHANGED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
frame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")

if frame.RegisterUnitEvent then
    pcall(frame.RegisterUnitEvent, frame, "UNIT_FLAGS", "target", "focus", "targettarget")
    pcall(frame.RegisterUnitEvent, frame, "UNIT_HEALTH", "target", "focus", "targettarget")
else
    pcall(frame.RegisterEvent, frame, "UNIT_FLAGS")
    pcall(frame.RegisterEvent, frame, "UNIT_HEALTH")
end
