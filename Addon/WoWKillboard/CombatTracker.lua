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
    assists = 0,
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
    if not InCombatLockdown() then
        if guid and UnitExists("target") and UnitGUID("target") == guid and UnitIsPlayer("target") then return true end
        if name and UnitExists("target") and UnitName("target") == name and UnitIsPlayer("target") then return true end
        if guid and UnitExists("mouseover") and UnitGUID("mouseover") == guid and UnitIsPlayer("mouseover") then return true end
    end
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
CT.LastHostileNpc = nil
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

-- Get Friendly Group Size (Cross-Client Guardrail 2 Compliant)
function CT:GetFriendlyPartySize()
    local num = 0
    if IsInRaid and IsInRaid() then
        if GetNumGroupMembers then num = GetNumGroupMembers() end
        if (not num or num <= 0) and GetNumRaidMembers then num = GetNumRaidMembers() end
    elseif (IsInGroup and IsInGroup()) or (GetNumPartyMembers and GetNumPartyMembers() > 0) then
        if GetNumGroupMembers then num = GetNumGroupMembers() end
        if (not num or num <= 0) and GetNumPartyMembers then num = GetNumPartyMembers() + 1 end
    end
    if not num or num <= 0 then
        num = 1
    end
    return num
end

-- Retrieve all friendly party or raid members with their combatant metadata (Cross-Client Guardrail 2 Compliant)
function CT:GetPartyMembersList()
    local list = {}
    local pGUID = UnitGUID("player")
    local pName = UnitName("player")
    local _, pClass = UnitClass("player")
    local pLvl = UnitLevel("player") or 0
    local pGuild = (not InCombatLockdown() and GetGuildInfo("player")) or "None"
    local pFaction = UnitFactionGroup("player") or "Unknown"

    table.insert(list, {
        guid = pGUID or "PLAYER",
        name = pName or "Player",
        class = pClass or "UNKNOWN",
        level = pLvl,
        guild = pGuild,
        faction = pFaction,
        isPlayer = true,
        unit = "player",
    })

    if IsInRaid and IsInRaid() then
        local num = (GetNumGroupMembers and GetNumGroupMembers()) or (GetNumRaidMembers and GetNumRaidMembers()) or 0
        for i = 1, num do
            local unit = "raid" .. i
            if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                local uGUID = UnitGUID(unit)
                local uName = UnitName(unit)
                local _, uClass = UnitClass(unit)
                local uLvl = UnitLevel(unit) or 0
                local uGuild = (not InCombatLockdown() and GetGuildInfo(unit)) or "None"
                local uFaction = UnitFactionGroup(unit) or pFaction
                if uName and uName ~= "" then
                    table.insert(list, {
                        guid = uGUID or ("RAID_" .. i),
                        name = uName,
                        class = uClass or "UNKNOWN",
                        level = uLvl,
                        guild = uGuild,
                        faction = uFaction,
                        isPlayer = true,
                        unit = unit,
                    })
                end
            end
        end
    elseif (IsInGroup and IsInGroup()) or (GetNumPartyMembers and GetNumPartyMembers() > 0) then
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) then
                local uGUID = UnitGUID(unit)
                local uName = UnitName(unit)
                local _, uClass = UnitClass(unit)
                local uLvl = UnitLevel(unit) or 0
                local uGuild = (not InCombatLockdown() and GetGuildInfo(unit)) or "None"
                local uFaction = UnitFactionGroup(unit) or pFaction
                if uName and uName ~= "" then
                    table.insert(list, {
                        guid = uGUID or ("PARTY_" .. i),
                        name = uName,
                        class = uClass or "UNKNOWN",
                        level = uLvl,
                        guild = uGuild,
                        faction = uFaction,
                        isPlayer = true,
                        unit = unit,
                    })
                end
            end
        end
    end

    return list
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
function CT:RecordHeal(sourceGUID, destGUID, amount, sourceName, spellName)
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
                local dstInfo = KB.UnitScanner and KB.UnitScanner.GetUnitInfo and KB.UnitScanner:GetUnitInfo(destGUID)
                local dstName = (dstInfo and dstInfo.name) or "Ally"
                local cleanDst = KB.Utils.CleanCombatantName(dstName) or dstName
                CT.PlayerAssistedAllies[destGUID] = {
                    name = cleanDst,
                    guid = destGUID,
                    time = now,
                    spell = spellName or "Heal",
                    class = (dstInfo and dstInfo.class) or "UNKNOWN",
                    level = (dstInfo and dstInfo.level) or 0,
                    type = "heal",
                }
            end
        elseif destGUID == playerGUID and sourceGUID ~= playerGUID then
            -- External player healed us: record external assist (revokes 100% solo purity)
            CT.FriendlyCluster[sourceGUID] = now
            local uInfo = KB.UnitScanner and KB.UnitScanner.GetUnitInfo and KB.UnitScanner:GetUnitInfo(sourceGUID)
            local srcName = (uInfo and uInfo.name) or KB.Utils.CleanCombatantName(sourceName) or KB.Utils.SafeString(sourceName, "Ally")
            local cleanSrc = KB.Utils.CleanCombatantName(srcName) or srcName
            CT.ExternalAssistsOnPlayer[sourceGUID] = {
                name = cleanSrc,
                guid = sourceGUID,
                time = now,
                spell = spellName or "Heal Assist",
                class = (uInfo and uInfo.class) or "UNKNOWN",
                level = (uInfo and uInfo.level) or 0,
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
    local maxNpcDamage = 0
    local damageSources = {}
    local recordedAttackersMap = {}
    if victimGUID then recordedAttackersMap[victimGUID] = true end
    if cleanVictim then recordedAttackersMap[cleanVictim] = true end
    if victimName then recordedAttackersMap[victimName] = true end
    if normVictim then recordedAttackersMap[normVictim] = true end
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
        if attData.name then recordedAttackersMap[attData.name] = true end
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
        recordedAttackersMap[finalBlowKillerGUID] = true
        if finalBlowKillerName then recordedAttackersMap[finalBlowKillerName] = true end
    end

    local isFallbackAttribution = false
    -- Fallback: If no recorded attackers in RecentDamage, check active target / player attribution
    if #attackersList == 0 then
        isFallbackAttribution = true
        local pGUID = UnitGUID("player")
        local isTargetVictim = (UnitExists("target") and (UnitGUID("target") == victimGUID or UnitName("target") == victimName)) or
                               (activeEnemyTarget and (activeEnemyTarget.guid == victimGUID or activeEnemyTarget.name == victimName))

        -- Check if an ally was buffed/assisted recently or is in FriendlyCluster
        local assistedAlly = nil
        if CT.PlayerAssistedAllies then
            for aGUID, aData in pairs(CT.PlayerAssistedAllies) do
                if aGUID ~= pGUID and (now - (aData.time or 0)) <= 45 then
                    assistedAlly = aData
                    break
                end
            end
        end
        if not assistedAlly and CT.FriendlyCluster then
            for fGUID, fTime in pairs(CT.FriendlyCluster) do
                if fGUID ~= pGUID and (now - fTime) <= 45 then
                    local fInfo = KB.UnitScanner and KB.UnitScanner:GetUnitInfo(fGUID)
                    assistedAlly = { guid = fGUID, name = (fInfo and fInfo.name) or "Friendly Ally", class = (fInfo and fInfo.class) or "UNKNOWN" }
                    break
                end
            end
        end

        if assistedAlly and isTargetVictim then
            -- Player assisted an ally who engaged the target: attribute killing blow to the ally!
            finalBlowKillerGUID = assistedAlly.guid
            finalBlowKillerName = assistedAlly.name
            local aInfo = KB.UnitScanner and KB.UnitScanner:GetUnitInfo(assistedAlly.guid)
            table.insert(attackersList, {
                guid = assistedAlly.guid,
                name = assistedAlly.name or "Friendly Ally",
                damage = 0,
                spell = "Killing Blow",
                class = (aInfo and aInfo.class) or assistedAlly.class or "UNKNOWN",
                level = (aInfo and aInfo.level) or 0,
                guild = (aInfo and aInfo.guild) or "None",
                faction = (aInfo and aInfo.faction) or UnitFactionGroup("player") or "Unknown",
                isPlayer = true,
            })
            recordedAttackersMap[assistedAlly.guid] = true
            if assistedAlly.name then recordedAttackersMap[assistedAlly.name] = true end

            -- Also insert player as support assist
            local _, pClass = UnitClass("player")
            table.insert(attackersList, {
                guid = pGUID,
                name = UnitName("player") or "Player",
                damage = 0,
                spell = "Support Assist",
                class = pClass or "UNKNOWN",
                level = UnitLevel("player") or 0,
                guild = (not InCombatLockdown() and GetGuildInfo("player")) or "None",
                faction = UnitFactionGroup("player") or "Unknown",
                isPlayer = true,
            })
            recordedAttackersMap[pGUID] = true
            recordedAttackersMap[UnitName("player")] = true
            hasPlayerAttacker = true
        elseif isTargetVictim and pGUID then
            finalBlowKillerGUID = pGUID
            finalBlowKillerName = UnitName("player")
            local _, pClass = UnitClass("player")
            local pGuild = (not InCombatLockdown() and GetGuildInfo("player")) or "None"
            local pFaction = UnitFactionGroup("player")
            table.insert(attackersList, {
                guid = pGUID,
                name = finalBlowKillerName or "Player",
                damage = 0,
                spell = "Assisted Blow",
                class = pClass or "UNKNOWN",
                level = UnitLevel("player") or 0,
                guild = pGuild or "None",
                faction = pFaction or "Unknown",
                isPlayer = true,
            })
            recordedAttackersMap[pGUID] = true
            recordedAttackersMap[finalBlowKillerName] = true
            hasPlayerAttacker = true
        elseif pGUID and victimGUID == pGUID then
            -- Fallback when the PLAYER was slain: locate hostile enemy who engaged player
            local enemy = nil
            if activeEnemyTarget and (now - (activeEnemyTarget.lastSeen or 0)) <= 45 then
                enemy = activeEnemyTarget
            else
                local bestTime = 0
                for _, e in pairs(CT.RecentEngagedEnemies) do
                    if e.lastSeen and e.lastSeen > bestTime and (now - e.lastSeen) <= 45 then
                        enemy = e
                        bestTime = e.lastSeen
                    end
                end
            end
            if not enemy and CT.LastHostileNpc and (now - (CT.LastHostileNpc.lastSeen or 0)) <= 45 then
                enemy = CT.LastHostileNpc
            end
            if not enemy then
                for hGUID, hTime in pairs(CT.HostileCluster) do
                    if (now - hTime) <= 45 then
                        local hInfo = KB.UnitScanner and KB.UnitScanner:GetUnitInfo(hGUID)
                        if hInfo and hInfo.name and hInfo.name ~= UnitName("player") then
                            enemy = hInfo
                            break
                        end
                    end
                end
            end
            -- Live target verification on death
            if not enemy and UnitExists("target") and (UnitIsEnemy("player", "target") or UnitCanAttack("player", "target")) then
                local isTargetPlayer = UnitIsPlayer("target")
                if isTargetPlayer then
                    enemy = KB.UnitScanner and KB.UnitScanner:ScanUnit("target")
                else
                    local tGuid = UnitGUID("target")
                    local tName = UnitName("target")
                    if tName and tName ~= "" and tName ~= UnitName("player") then
                        local npcId = 0
                        if tGuid then
                            local parsed = tGuid:match("Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-") or tGuid:match("Vehicle%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
                            if parsed then npcId = tonumber(parsed) or 0 end
                        end
                        enemy = {
                            guid = tGuid or "UNKNOWN_CREATURE",
                            name = tName,
                            id = npcId,
                            level = UnitLevel("target") or 0,
                            class = "MONSTER",
                            guild = "None",
                            faction = "Hostile NPC",
                            isPlayer = false,
                        }
                    end
                end
            end
            -- Target's target check if enemy was attacking player
            if not enemy and UnitExists("targettarget") and UnitIsUnit("targettarget", "player") and UnitExists("target") then
                local tGuid = UnitGUID("target")
                local tName = UnitName("target")
                if tName and tName ~= "" and tName ~= UnitName("player") then
                    local isTP = UnitIsPlayer("target")
                    local npcId = 0
                    if not isTP and tGuid then
                        local parsed = tGuid:match("Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-") or tGuid:match("Vehicle%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
                        if parsed then npcId = tonumber(parsed) or 0 end
                    end
                    enemy = {
                        guid = tGuid or "UNKNOWN_CREATURE",
                        name = tName,
                        id = npcId,
                        level = UnitLevel("target") or 0,
                        class = isTP and "UNKNOWN" or "MONSTER",
                        guild = "None",
                        faction = "Hostile NPC",
                        isPlayer = isTP,
                    }
                end
            end

            if enemy and enemy.name and enemy.name ~= UnitName("player") then
                finalBlowKillerGUID = enemy.guid or "UNKNOWN_HOSTILE"
                finalBlowKillerName = enemy.name
                local isEnemyPlayer = (enemy.isPlayer == true) or (enemy.guid and enemy.guid:match("^Player%-") ~= nil)
                table.insert(attackersList, {
                    guid = finalBlowKillerGUID,
                    name = finalBlowKillerName,
                    damage = 0,
                    spell = "Fatal Strike",
                    class = enemy.class or (isEnemyPlayer and "UNKNOWN" or "MONSTER"),
                    level = enemy.level or 0,
                    guild = enemy.guild or "None",
                    faction = enemy.faction or "Unknown",
                    isPlayer = isEnemyPlayer,
                })
                recordedAttackersMap[finalBlowKillerGUID] = true
                if finalBlowKillerName then recordedAttackersMap[finalBlowKillerName] = true end
                if isEnemyPlayer then
                    hasPlayerAttacker = true
                else
                    topNpcAttacker = {
                        guid = finalBlowKillerGUID,
                        name = finalBlowKillerName,
                        id = enemy.id or 0,
                        totalDamage = 0,
                        spellName = "Fatal Strike",
                    }
                end
            end
        end
    end

    -- Only proceed if there was at least one attacker, or if the local player died (fatal fall / environment)
    if #attackersList == 0 then
        if playerGUID and victimGUID == playerGUID then
            CT.SessionStats.pveDeaths = (CT.SessionStats.pveDeaths or 0) + 1
            local pClass = select(2, UnitClass("player"))
            local fallbackNpc = (CT.LastHostileNpc and (now - (CT.LastHostileNpc.lastSeen or 0)) <= 45 and CT.LastHostileNpc) or {
                name = "Environmental Hazard",
                id = 0,
                guid = "ENVIRONMENT",
                spell = "Fatal Impact / Mishap",
                damage = 0,
            }
            KB.Killmail:RecordPveDeath({
                timestamp = now,
                npc = {
                    name = fallbackNpc.name or "Unknown Monster",
                    id = fallbackNpc.id or 0,
                    guid = fallbackNpc.guid or "UNKNOWN",
                    spell = fallbackNpc.spell or "Fatal Strike",
                    damage = fallbackNpc.damage or 0,
                },
                victim = {
                    guid = playerGUID,
                    name = UnitName("player"),
                    level = UnitLevel("player") or 0,
                    class = pClass or "UNKNOWN",
                    guild = (not InCombatLockdown() and GetGuildInfo("player")) or "None",
                    faction = UnitFactionGroup("player") or "Unknown",
                },
                location = KB.Utils.GetPlayerLocation(),
            })
        end
        return
    end

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
                CT.SessionStats.pveDeaths = (CT.SessionStats.pveDeaths or 0) + 1
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
        if fGUID ~= playerGUID and (now - fTime) <= 45 then
            friendlyAssists = friendlyAssists + 1
        end
    end

    -- Merge assists from:
    -- 1. RecentVictimAssists[victimGUID] / RecentVictimAssistsByName[normVictim] (debuffs, CC, roots, stuns on victim)
    -- 2. If player is on the attacking side, ExternalAssistsOnPlayer (allies who healed or buffed the player during combat)
    local assistSources = {}
    if victimGUID and CT.RecentVictimAssists[victimGUID] then
        for aGUID, aData in pairs(CT.RecentVictimAssists[victimGUID]) do
            if (now - (aData.time or 0)) <= 45 then
                assistSources[aGUID] = aData
            end
        end
    end
    if normVictim and CT.RecentVictimAssistsByName and CT.RecentVictimAssistsByName[normVictim] then
        for aGUID, aData in pairs(CT.RecentVictimAssistsByName[normVictim]) do
            if (now - (aData.time or 0)) <= 45 and not assistSources[aGUID] then
                assistSources[aGUID] = aData
            end
        end
    end
    if (finalBlowKillerGUID == playerGUID or hasPlayerAttacker) and victimGUID ~= playerGUID and CT.ExternalAssistsOnPlayer then
        for aGUID, aData in pairs(CT.ExternalAssistsOnPlayer) do
            if aGUID ~= playerGUID and (now - (aData.time or 0)) <= 45 and not assistSources[aGUID] then
                assistSources[aGUID] = aData
            end
        end
    end

    for aGUID, aData in pairs(assistSources) do
        if not recordedAttackersMap[aGUID] and (not aData.name or not recordedAttackersMap[aData.name]) and aGUID ~= victimGUID and aData.name ~= victimName then
            local aInfo = KB.UnitScanner and KB.UnitScanner:GetUnitInfo(aGUID)
            table.insert(attackersList, {
                guid = aGUID,
                name = (aInfo and aInfo.name) or aData.name or "Friendly Ally",
                damage = 0,
                spell = aData.spell or "Assist",
                class = (aInfo and aInfo.class) or aData.class or "UNKNOWN",
                level = (aInfo and aInfo.level) or aData.level or 0,
                guild = (aInfo and aInfo.guild) or "None",
                faction = (aInfo and aInfo.faction) or (UnitFactionGroup("player") or "Unknown"),
                isPlayer = true,
            })
            recordedAttackersMap[aGUID] = true
            if aData.name then recordedAttackersMap[aData.name] = true end
        end
    end

    -- Pull in active party/raid members so group engagements track all squad members
    -- Strict guard: ONLY pull in player's party members if the player was on the ATTACKING side!
    -- When the player is the VICTIM (victimGUID == playerGUID), party members are victims, NOT attackers!
    if victimGUID ~= playerGUID then
        local partyMembers = CT:GetPartyMembersList()
        for _, m in ipairs(partyMembers) do
            if m.guid ~= victimGUID and m.name ~= victimName and not recordedAttackersMap[m.guid] and not recordedAttackersMap[m.name] then
                table.insert(attackersList, {
                    guid = m.guid,
                    name = m.name,
                    damage = 0,
                    spell = "Squad Assist",
                    class = m.class or "UNKNOWN",
                    level = m.level or 0,
                    guild = m.guild or "None",
                    faction = m.faction or (UnitFactionGroup("player") or "Unknown"),
                    isPlayer = true,
                })
                recordedAttackersMap[m.guid] = true
                recordedAttackersMap[m.name] = true
            end
        end
    end

    -- Strict 100% Certified Solo Kill Criteria:
    -- 1. Attacker list contains ONLY 1 player
    -- 2. Zero other friendly players debuffed, slowed, stunned or assisted against victim within 45s
    -- 3. Zero external friendly heals received by the player within 45s
    -- 4. Zero external friendly buffs received by the player within 45s
    -- 5. Friendly party/raid size is strictly 1
    -- 6. Zero active friendly cluster participants within 45s
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
        if hGUID ~= playerGUID and (now - (hData.time or 0)) <= 45 then
            hasExternalAssistOnPlayer = true
            break
        end
    end

    local hasRecentAssistedAlly = false
    if CT.PlayerAssistedAllies then
        for aGUID, aData in pairs(CT.PlayerAssistedAllies) do
            if aGUID ~= playerGUID and (now - (aData.time or 0)) <= 45 then
                hasRecentAssistedAlly = true
                break
            end
        end
    end

    local inGroup = (CT:GetFriendlyPartySize() > 1)
    local hasNearbyFriendly = (friendlyAssists > 0)
    local isInstanceCombat = (context.isBattleground or context.isArena)

    -- Extract unit scanner details for killer & victim
    local killerInfo = KB.UnitScanner and KB.UnitScanner:GetUnitInfo(finalBlowKillerGUID) or {
        guid = finalBlowKillerGUID,
        name = finalBlowKillerName or "Unknown",
        level = 0,
        class = "UNKNOWN",
        guild = "None",
        faction = "Unknown",
    }

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
        victimInfo.guild = (not InCombatLockdown() and GetGuildInfo("player")) or "None"
    end

    if playerGUID and finalBlowKillerGUID == playerGUID then
        killerInfo.name = UnitName("player")
        killerInfo.level = UnitLevel("player") or 0
        local _, pClass = UnitClass("player")
        killerInfo.class = pClass or "UNKNOWN"
        killerInfo.faction = UnitFactionGroup("player") or "Unknown"
        killerInfo.guild = (not InCombatLockdown() and GetGuildInfo("player")) or "None"
    end

    local playerDamage = 0
    for _, att in ipairs(attackersList) do
        if att.guid == playerGUID or (att.name and att.name == UnitName("player")) then
            playerDamage = math.max(playerDamage, att.damage or 0)
        end
    end

    local killerDamage = 0
    for _, att in ipairs(attackersList) do
        if att.guid == finalBlowKillerGUID or att.name == finalBlowKillerName then
            killerDamage = math.max(killerDamage, att.damage or 0)
        end
    end

    local hostilePartySize = CT:GetInferredHostilePartySize()
    local isHostileGang = (hostilePartySize > 1)

    local vLvl = (victimInfo and victimInfo.level) or 0
    local kLvl = (killerInfo and killerInfo.level) or (finalBlowKillerGUID == playerGUID and (UnitLevel("player") or 0)) or 0
    local isLevelDisparity = (vLvl > 0 and kLvl > 0 and (vLvl - kLvl) >= 5 and (finalBlowKillerGUID == playerGUID and playerDamage < 100 or killerDamage < 100))

    local isSolo = false
    if victimGUID == playerGUID then
        -- Player is victim: solo only if pure 1v1 engagement with no gang around and positive damage
        isSolo = (not isInstanceCombat)
             and (#attackersList == 1)
             and (not inGroup)
             and (not isHostileGang)
             and (totalDamage > 0 or killerDamage > 0)
    elseif finalBlowKillerGUID == playerGUID then
        -- Player is killer: solo only if 100% pure solo engagement with positive damage, no fallback tag, no level disparity
        isSolo = (not isInstanceCombat)
             and (not hasExternalAttacker)
             and (not hasExternalAssistOnVictim)
             and (not hasExternalAssistOnPlayer)
             and (not hasRecentAssistedAlly)
             and (not inGroup)
             and (not hasNearbyFriendly)
             and (#attackersList == 1)
             and (playerDamage > 0)
             and (not isLevelDisparity)
             and (not isFallbackAttribution)
    else
        -- Third party kill observed: solo only if 1 attacker, positive damage, and reasonable level
        local firstAtt = attackersList[1]
        local attDmg = firstAtt and (firstAtt.damage or 0) or 0
        isSolo = (not isInstanceCombat)
             and (#attackersList == 1)
             and (totalDamage > 0 or attDmg > 0)
             and (not isLevelDisparity)
    end

    local friendlyPartySize = math.max(CT:GetFriendlyPartySize(), (victimGUID ~= playerGUID and #attackersList or 1))
    if victimGUID ~= playerGUID and friendlyAssists > 0 then
        friendlyPartySize = friendlyPartySize + friendlyAssists
    end
    if victimGUID ~= playerGUID and not isSolo and friendlyPartySize < 2 then
        friendlyPartySize = 2
    end

    local attackersCount = #attackersList
    if victimGUID == playerGUID then
        attackersCount = math.max(#attackersList, 1)
        if not isSolo and attackersCount < 2 then
            attackersCount = math.max(2, hostilePartySize)
        end
    else
        attackersCount = math.max(#attackersList, friendlyPartySize)
        if not isSolo and attackersCount < 2 then
            attackersCount = 2
        end
    end
    if isSolo then
        attackersCount = 1
    end

    -- If killer was the player
    if finalBlowKillerGUID == playerGUID then
        CT.SessionStats.kills = CT.SessionStats.kills + 1
    elseif inGroup or (playerDamage and playerDamage > 0) then
        CT.SessionStats.assists = (CT.SessionStats.assists or 0) + 1
    end

    -- Trigger Death Bounty Opportunity if player was killed by an enemy player in the open world
    local inInst, instType = false, "none"
    if IsInInstance then inInst, instType = IsInInstance() end
    local isBG = context.isBattleground or (C_PvP and C_PvP.IsBattleground and C_PvP.IsBattleground())
    local isArena = context.isArena or (C_PvP and C_PvP.IsArena and C_PvP.IsArena())
    local isInstanceCombat = inInst or (instType and instType ~= "none") or isBG or isArena

    if not isInstanceCombat and victimGUID == playerGUID and killerInfo and killerInfo.name and killerInfo.name ~= "Unknown" and killerInfo.name ~= UnitName("player") then
        CT.LastPvpKiller = {
            name = killerInfo.name,
            guid = killerInfo.guid,
            class = killerInfo.class,
            faction = killerInfo.faction,
        }
        local settings = WoWKillboardSettings or {}
        if settings.promptMarkOnDeath ~= false and settings.promptBountyOnDeath ~= false and settings.ignoreDeathBounties ~= true then
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
        attackersCount = attackersCount,
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
            damageDone = (finalBlowKillerGUID == playerGUID) and math.max(playerDamage, 0) or math.max(killerDamage, totalDamage),
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

    if (not victimInfo or victimInfo.class == "UNKNOWN") and activeEnemyTarget then
        if (cleanVictim and activeEnemyTarget.name and activeEnemyTarget.name:lower() == cleanVictim:lower()) or (victimName and activeEnemyTarget.name and activeEnemyTarget.name:lower() == victimName:lower()) then
            victimInfo = {
                guid = activeEnemyTarget.guid or victimGUID or "UNKNOWN",
                name = activeEnemyTarget.name or cleanVictim or victimName,
                level = activeEnemyTarget.level or 0,
                class = activeEnemyTarget.class or "UNKNOWN",
                guild = activeEnemyTarget.guild or "None",
                faction = activeEnemyTarget.faction or "Unknown",
                partySize = 1,
            }
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

    if not victimGUID or victimGUID == "UNKNOWN" then
        if cleanVictim and cleanVictim ~= "" then
            victimGUID = "Player-Named-" .. cleanVictim
        else
            victimGUID = "Player-Named-" .. (victimName or "Hostile")
        end
    end
    if victimInfo then
        victimInfo.guid = victimGUID
    end

    local partyMembers = CT:GetPartyMembersList()
    local partySize = math.max(CT:GetFriendlyPartySize(), #partyMembers)
    local playerGUID = UnitGUID("player")
    local playerName = UnitName("player")
    local _, pClass = UnitClass("player")
    local pFaction = UnitFactionGroup("player")
    local pGuild = (not InCombatLockdown() and GetGuildInfo("player")) or "None"

    CT:PruneCombatInteractions()

    -- Check FriendlyCluster for friendly assists in the last 45 seconds
    local friendlyAssists = 0
    local clusterAssists = {}
    for fGUID, fTime in pairs(CT.FriendlyCluster) do
        if fGUID ~= playerGUID and (now - fTime) <= 45 then
            friendlyAssists = friendlyAssists + 1
            table.insert(clusterAssists, fGUID)
        end
    end

    -- Gather all attackers from RecentDamage and RecentDamageByName for this victim
    local attackersList = {}
    local totalDamage = 0
    local recordedAttackersMap = {}
    if victimGUID then recordedAttackersMap[victimGUID] = true end
    if cleanVictim then recordedAttackersMap[cleanVictim] = true end
    if victimName then recordedAttackersMap[victimName] = true end
    if normVictim then recordedAttackersMap[normVictim] = true end

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
        if attData.name then recordedAttackersMap[attData.name] = true end

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
        recordedAttackersMap[playerGUID] = true
        if playerName then recordedAttackersMap[playerName] = true end
    end

    -- Pull in all active party/raid members so group encounters accurately track squad participants
    for _, m in ipairs(partyMembers) do
        if m.guid and not recordedAttackersMap[m.guid] and not recordedAttackersMap[m.name] and m.guid ~= victimGUID and m.name ~= victimName then
            table.insert(attackersList, {
                guid = m.guid,
                name = m.name,
                damage = 0,
                spell = "Squad Assist",
                class = m.class or "UNKNOWN",
                level = m.level or 0,
                guild = m.guild or "None",
                faction = m.faction or pFaction or "Unknown",
                isPlayer = true,
            })
            recordedAttackersMap[m.guid] = true
            recordedAttackersMap[m.name] = true
        end
    end

    -- Append friendly cluster participants who assisted recently
    for _, fGUID in ipairs(clusterAssists) do
        if not recordedAttackersMap[fGUID] and fGUID ~= victimGUID then
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

    -- Append external allies who contributed assists or debuffs against this victim, OR healed/buffed the player
    local assistSources = {}
    if victimGUID and CT.RecentVictimAssists[victimGUID] then
        for aGUID, aData in pairs(CT.RecentVictimAssists[victimGUID]) do
            if (now - (aData.time or 0)) <= 45 then
                assistSources[aGUID] = aData
            end
        end
    end
    if normVictim and CT.RecentVictimAssistsByName and CT.RecentVictimAssistsByName[normVictim] then
        for aGUID, aData in pairs(CT.RecentVictimAssistsByName[normVictim]) do
            if (now - (aData.time or 0)) <= 45 and not assistSources[aGUID] then
                assistSources[aGUID] = aData
            end
        end
    end
    if CT.ExternalAssistsOnPlayer then
        for aGUID, aData in pairs(CT.ExternalAssistsOnPlayer) do
            if aGUID ~= playerGUID and (now - (aData.time or 0)) <= 45 and not assistSources[aGUID] then
                assistSources[aGUID] = aData
            end
        end
    end

    for aGUID, aData in pairs(assistSources) do
        if not recordedAttackersMap[aGUID] and (not aData.name or not recordedAttackersMap[aData.name]) and aGUID ~= playerGUID and aGUID ~= victimGUID and aData.name ~= victimName then
            local aInfo = KB.UnitScanner and KB.UnitScanner:GetUnitInfo(aGUID)
            table.insert(attackersList, {
                guid = aGUID,
                name = (aInfo and aInfo.name) or aData.name or "Friendly Ally",
                damage = 0,
                spell = aData.spell or "Assist",
                class = (aInfo and aInfo.class) or aData.class or "UNKNOWN",
                level = (aInfo and aInfo.level) or aData.level or 0,
                guild = (aInfo and aInfo.guild) or "None",
                faction = (aInfo and aInfo.faction) or (pFaction or "Unknown"),
                isPlayer = true,
            })
            recordedAttackersMap[aGUID] = true
            if aData.name then recordedAttackersMap[aData.name] = true end
        end
    end

    -- Strict 100% Certified Solo Kill Criteria:
    -- 1. Attacker list contains ONLY 1 player
    -- 2. Zero other friendly players debuffed, slowed, stunned or assisted against victim within 45s
    -- 3. Zero external friendly heals received by the player within 45s
    -- 4. Zero external friendly buffs received by the player within 45s
    -- 5. Zero friendly allies assisted/healed/buffed by the player within 45s
    -- 6. Friendly party/raid size is strictly 1
    -- 7. Zero active friendly cluster participants within 45s
    -- 8. Player MUST have dealt positive damage (> 0) to the victim or engaged actively
    local hasExternalAttacker = false
    for _, att in ipairs(attackersList) do
        if att.guid ~= playerGUID and (att.name ~= playerName) and att.guid ~= victimGUID then
            hasExternalAttacker = true
            break
        end
    end

    local hasExternalAssistOnVictim = false
    for aGUID, aData in pairs(assistSources) do
        if aGUID ~= playerGUID and aData.name ~= playerName and aGUID ~= victimGUID then
            hasExternalAssistOnVictim = true
            break
        end
    end

    local hasExternalAssistOnPlayer = false
    for hGUID, hData in pairs(CT.ExternalAssistsOnPlayer) do
        if hGUID ~= playerGUID and (now - (hData.time or 0)) <= 45 then
            hasExternalAssistOnPlayer = true
            break
        end
    end

    local hasRecentAssistedAlly = false
    if CT.PlayerAssistedAllies then
        for aGUID, aData in pairs(CT.PlayerAssistedAllies) do
            if aGUID ~= playerGUID and (now - (aData.time or 0)) <= 45 then
                hasRecentAssistedAlly = true
                break
            end
        end
    end

    local context = CT:GetCombatContext()
    local isInstanceCombat = (context.isBattleground or context.isArena)
    local inGroup = (partySize > 1)
    local hasNearbyFriendly = (friendlyAssists > 0)
    local hasPlayerDamage = (playerDamage > 0)

    -- Check if player is actively in combat or engaged
    local isPlayerInCombat = InCombatLockdown() or (CT.LastCombatTime and (now - CT.LastCombatTime) <= 30)
    local isTargetEngaged = (unitToken ~= nil)
                         or (explicitGuid ~= nil and explicitGuid ~= "UNKNOWN")
                         or (UnitExists("target") and UnitIsPlayer("target"))
                         or (activeEnemyTarget and (now - (activeEnemyTarget.lastSeen or 0)) <= 30)
                         or (victimGUID and CT.RecentEngagedEnemies and CT.RecentEngagedEnemies[victimGUID] ~= nil)
                         or (cleanVictim and CT.RecentVictimGUIDs and CT.RecentVictimGUIDs[cleanVictim:lower()] ~= nil)
                         or (normVictim and CT.RecentVictimGUIDs and CT.RecentVictimGUIDs[normVictim] ~= nil)

    local vLvl = (victimInfo and victimInfo.level) or 0
    local pLvl = UnitLevel("player") or 0
    local isLevelDisparity = (vLvl > 0 and pLvl > 0 and (vLvl - pLvl) >= 5 and playerDamage < 100)

    local isSolo = (not isInstanceCombat)
               and (not hasExternalAttacker)
               and (not hasExternalAssistOnVictim)
               and (not hasExternalAssistOnPlayer)
               and (not hasRecentAssistedAlly)
               and (not inGroup)
               and (not hasNearbyFriendly)
               and (hasPlayerDamage or (isCLEUForbidden and (isTargetEngaged or isPlayerInCombat) and not isLevelDisparity and pLvl >= 10))
               and (not isLevelDisparity)

    local attackersCount = math.max(#attackersList, partySize, 1 + friendlyAssists)
    if isInstanceCombat or not isSolo then
        if attackersCount < 2 then attackersCount = 2 end
    end
    if isSolo then
        attackersCount = 1
    end

    -- Check if any party teammate was in the squad
    local partyTeammate = nil
    if partyMembers and #partyMembers > 1 then
        for _, m in ipairs(partyMembers) do
            if m.guid ~= playerGUID and m.name ~= playerName then
                partyTeammate = m
                break
            end
        end
    end

    -- Bystander Protection (Combat safety directive):
    -- A player is ONLY a passive bystander if:
    -- 1. Not in combat
    -- 2. No enemy targeted or engaged in the last 30s
    -- 3. Zero recorded damage dealt
    -- 4. Not in a party (solo)
    -- 5. Zero friendly cluster assists or allied buffs
    -- 6. No explicit target token or GUID
    local isBystander = (not isPlayerInCombat)
                    and (not isTargetEngaged)
                    and (not hasPlayerDamage)
                    and (not partyTeammate)
                    and (not topPlayerAttacker or (topPlayerAttacker.damage or 0) <= 0)
                    and (#clusterAssists == 0)
                    and (not CT.PlayerAssistedAllies or not next(CT.PlayerAssistedAllies))
                    and (not explicitGuid or explicitGuid == "UNKNOWN")
                    and (not unitToken)

    if isBystander then
        return
    end

    -- Determine true killer:
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
    elseif partyTeammate and not (isPlayerInCombat or isTargetEngaged or hasPlayerDamage) then
        -- Player was purely healing/assisting a party teammate: attribute kill to their party teammate!
        killerData = {
            guid = partyTeammate.guid,
            name = partyTeammate.name,
            level = partyTeammate.level or 0,
            class = partyTeammate.class or "UNKNOWN",
            guild = partyTeammate.guild or "None",
            faction = partyTeammate.faction or (pFaction or "Unknown"),
            partySize = attackersCount,
            damageDone = totalDamage,
            healingDone = 0,
        }
    elseif #clusterAssists > 0 and not (isPlayerInCombat or isTargetEngaged or hasPlayerDamage) then
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
    elseif CT.PlayerAssistedAllies and next(CT.PlayerAssistedAllies) and not (isPlayerInCombat or isTargetEngaged or hasPlayerDamage) then
        local firstAllyGUID, aData = next(CT.PlayerAssistedAllies)
        local aInfo = KB.UnitScanner and KB.UnitScanner:GetUnitInfo(firstAllyGUID)
        killerData = {
            guid = firstAllyGUID,
            name = (aInfo and aInfo.name) or (aData and aData.name) or "Friendly Ally",
            level = (aInfo and aInfo.level) or 0,
            class = (aInfo and aInfo.class) or "UNKNOWN",
            guild = (aInfo and aInfo.guild) or "None",
            faction = (aInfo and aInfo.faction) or (pFaction or "Unknown"),
            partySize = attackersCount,
            damageDone = totalDamage,
            healingDone = 0,
        }
    else
        -- Active player is the killer!
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
        for _, att in ipairs(attackersList) do
            if att.guid == playerGUID then
                if att.spell == "Support Assist" or not att.spell then
                    att.spell = "Killing Blow"
                end
                break
            end
        end
    else
        CT.SessionStats.assists = (CT.SessionStats.assists or 0) + 1
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
    KB.Utils.SafePrint(string.format("|cff00ff00[WoWKB]|r Manual killmail registered for |cffffff00%s|r.", targetName))
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
    local function ExtractNameAndRealm(raw)
        if not raw then return "", "" end
        raw = raw:match("^%s*(.-)%s*$") -- trim
        -- Check hyphen (e.g. Tinaomi-Elianco)
        local n, r = raw:match("^([^-]+)%-(.+)$")
        if n and r then
            return n:match("^%s*(.-)%s*$"), r:match("^%s*(.-)%s*$")
        end
        -- Check space (e.g. Tinaomi Elianco)
        n, r = raw:match("^([%S]+)%s+(.+)$")
        if n and r then
            return n:match("^%s*(.-)%s*$"), r:match("^%s*(.-)%s*$")
        end
        return raw, ""
    end

    local cleanWinner = ExtractNameAndRealm(winnerName)
    local cleanLoser = ExtractNameAndRealm(loserName)
    local isPlayerWinner = MatchesPlayer(winnerName) or MatchesPlayer(cleanWinner)
    local isPlayerLoser = MatchesPlayer(loserName) or MatchesPlayer(cleanLoser)

    if isPlayerWinner then
        winnerName = playerName
    else
        winnerName = cleanWinner
    end

    if isPlayerLoser then
        loserName = playerName
    else
        loserName = cleanLoser
    end

    -- If neither winner nor loser is the local player, this is an ambient spectator duel
    -- Do not record stranger duels into the local player's killmail feed or duel statistics
    if not isPlayerWinner and not isPlayerLoser then
        return
    end

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
    if settings.promptMarkOnDeath == false or settings.promptBountyOnDeath == false or settings.ignoreDeathBounties == true then
        CT.PendingDeathBounty = nil
        return
    end
    local inInst, instType = false, "none"
    if IsInInstance then inInst, instType = IsInInstance() end
    local context = CT:GetCombatContext()
    local isBG = context.isBattleground or (C_PvP and C_PvP.IsBattleground and C_PvP.IsBattleground())
    local isArena = context.isArena or (C_PvP and C_PvP.IsArena and C_PvP.IsArena())
    if inInst or (instType and instType ~= "none") or isBG or isArena then
        CT.PendingDeathBounty = nil
        return
    end

    if InCombatLockdown() then
        return
    end

    local killer = CT.PendingDeathBounty
    CT.PendingDeathBounty = nil
    if KB.UI and KB.UI.ShowDeathBountyPrompt then
        KB.UI:ShowDeathBountyPrompt(killer)
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
        elseif subevent == "ENVIRONMENTAL_DAMAGE" then
            local environmentalType, amount = select(12, GetCombatLogPayload(...))
            local hazardName = environmentalType or "Environmental Hazard"
            CT:RecordDamage(timestamp, "Environment", hazardName, 0, destGUID, destName, destFlags, amount or 0, hazardName)
        elseif subevent == "SPELL_HEAL" or subevent == "SPELL_PERIODIC_HEAL" then
            local spellId, spellName, _, amount = select(12, GetCombatLogPayload(...))
            if KB.UnitScanner and KB.UnitScanner.InferClassFromSpell then
                KB.UnitScanner:InferClassFromSpell(sourceGUID, sourceName, spellName)
            end
            CT:RecordHeal(sourceGUID, destGUID, amount or 0, sourceName, spellName)
        elseif subevent == "SPELL_CAST_SUCCESS" or subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH" or subevent == "SPELL_AURA_APPLIED_DOSE" then
            local spellId, spellName = select(12, GetCombatLogPayload(...))
            if KB.UnitScanner and KB.UnitScanner.InferClassFromSpell then
                KB.UnitScanner:InferClassFromSpell(sourceGUID, sourceName, spellName)
            end
            local playerGUID = UnitGUID("player")
            local now = time()
            if playerGUID and destGUID == playerGUID and sourceGUID ~= playerGUID then
                CT.FriendlyCluster[sourceGUID] = now
                local uInfo = KB.UnitScanner and KB.UnitScanner.GetUnitInfo and KB.UnitScanner:GetUnitInfo(sourceGUID)
                local srcName = (uInfo and uInfo.name) or KB.Utils.CleanCombatantName(sourceName) or KB.Utils.SafeString(sourceName, "Ally")
                CT.ExternalAssistsOnPlayer[sourceGUID] = {
                    name = srcName,
                    guid = sourceGUID,
                    time = now,
                    spell = spellName or "Buff",
                    class = (uInfo and uInfo.class) or "UNKNOWN",
                    level = (uInfo and uInfo.level) or 0,
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
            -- Instant death detection for engaged/damaged hostile players (Zero-delay RW Banner)
            if destGUID and IsPlayerUnit(destGUID, destFlags, destName) then
                local pGUID = UnitGUID("player")
                if pGUID and destGUID ~= pGUID then
                    local isEngaged = (UnitExists("target") and (UnitGUID("target") == destGUID or UnitName("target") == destName))
                                   or (activeEnemyTarget and (activeEnemyTarget.guid == destGUID or activeEnemyTarget.name == destName))
                                   or (CT.RecentEngagedEnemies and CT.RecentEngagedEnemies[destGUID])
                                   or (CT.RecentDamage and CT.RecentDamage[destGUID])
                    if isEngaged then
                        local unitTok = (UnitExists("target") and UnitGUID("target") == destGUID) and "target" or nil
                        CT:OnPlayerHonorableKill(destName, destGUID, unitTok)
                    end
                end
            end
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

    elseif event == "PLAYER_REGEN_DISABLED" then
        CT.LastCombatTime = time()
        if KB.UI and KB.UI.OnPlayerRegenDisabled then
            KB.UI:OnPlayerRegenDisabled()
        end

    elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" or event == "PLAYER_REGEN_ENABLED" then
        CT.LastCombatTime = time()
        if event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
            CT.LastHostileNpc = nil
        end
        if KB.Utils and KB.Utils.FlushPrintQueue then
            KB.Utils.FlushPrintQueue()
        end
        if KB.UI and KB.UI.OnPlayerRegenEnabled then
            KB.UI:OnPlayerRegenEnabled()
        end
        CT:CheckPendingDeathBounty()

    elseif event == "PLAYER_TARGET_CHANGED" then
        if UnitExists("target") then
            local isEnemy = UnitIsEnemy("player", "target") or (UnitCanAttack and UnitCanAttack("player", "target")) or (not UnitIsFriend("player", "target"))
            if isEnemy then
                local isDead = (UnitIsDead("target") or UnitIsDeadOrGhost("target")) and true or false
                local tGuid = UnitGUID("target")
                local tName = UnitName("target")
                local isTargetPlayer = UnitIsPlayer("target")

                if isTargetPlayer then
                    if isDead and tName and tName ~= "" then
                        CT:OnPlayerHonorableKill(tName, tGuid, "target")
                    elseif not isDead then
                        local tInfo = KB.UnitScanner and KB.UnitScanner:ScanUnit("target")
                        activeEnemyTarget = {
                            name = tName,
                            guid = tGuid,
                            level = UnitLevel("target") or (tInfo and tInfo.level or 0),
                            class = select(2, UnitClass("target")) or (tInfo and tInfo.class or "UNKNOWN"),
                            guild = (not InCombatLockdown() and GetGuildInfo("target")) or (tInfo and tInfo.guild or "None"),
                            faction = UnitFactionGroup("target") or (tInfo and tInfo.faction or "Unknown"),
                            lastSeen = time(),
                            isPlayer = true,
                        }
                        if tGuid then
                            CT.RecentEngagedEnemies[tGuid] = activeEnemyTarget
                        end
                    end
                else
                    -- Hostile NPC / Monster target tracking for PvE mortality attribution
                    if not isDead and tName and tName ~= "" then
                        local npcId = 0
                        if tGuid then
                            local parsed = tGuid:match("Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-") or tGuid:match("Vehicle%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
                            if parsed then npcId = tonumber(parsed) or 0 end
                        end
                        local npcData = {
                            name = tName,
                            guid = tGuid or "UNKNOWN_CREATURE",
                            id = npcId,
                            level = UnitLevel("target") or 0,
                            class = "MONSTER",
                            guild = "None",
                            faction = "Hostile NPC",
                            lastSeen = time(),
                            isPlayer = false,
                        }
                        CT.LastHostileNpc = npcData
                        activeEnemyTarget = npcData
                        if tGuid then
                            CT.RecentEngagedEnemies[tGuid] = npcData
                        end
                    end
                end
            end
        end

    elseif event == "PLAYER_PVP_KILLS_CHANGED" then
        local currentHK = nil
        if type(GetPVPLifetimeStats) == "function" then
            local hk = GetPVPLifetimeStats()
            if hk then currentHK = tonumber(hk) end
        end
        if not currentHK and type(GetPVPSessionStats) == "function" then
            local hk = GetPVPSessionStats()
            if hk then currentHK = tonumber(hk) end
        end

        if currentHK and CT.LastLifetimeHK and currentHK > CT.LastLifetimeHK then
            CT.LastLifetimeHK = currentHK
            CT:OnPlayerHonorableKill(nil)
        elseif currentHK and not CT.LastLifetimeHK then
            CT.LastLifetimeHK = currentHK
        end

    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        if type(GetPVPLifetimeStats) == "function" then
            local hk = GetPVPLifetimeStats()
            if hk then CT.LastLifetimeHK = tonumber(hk) end
        end
        if not CT.LastLifetimeHK and type(GetPVPSessionStats) == "function" then
            local hk = GetPVPSessionStats()
            if hk then CT.LastLifetimeHK = tonumber(hk) end
        end

    elseif event == "UPDATE_BATTLEFIELD_SCORE" then
        if type(GetNumBattlefieldScores) ~= "function" or type(GetBattlefieldScore) ~= "function" then return end
        local numScores = tonumber(GetNumBattlefieldScores()) or 0
        if numScores <= 0 then return end
        local playerName = UnitName("player")
        if not playerName or not KB.Utils.CanAccess(playerName) then return end
        for i = 1, numScores do
            local name, killingBlows, honorableKills, deaths, honorGained, faction, race, class, classToken, damageDone, healingDone = GetBattlefieldScore(i)
            if name and KB.Utils.CanAccess(name) and (name == playerName or (type(name) == "string" and name:find(playerName, 1, true))) then
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
            winner = GetBattlefieldWinner()
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
                    KB.Utils.SafePrint("|cff00ff00[WoWKB]|r Arena Victory recorded!")
                else
                    WoWKillboardDB.stats.arenas.losses = WoWKillboardDB.stats.arenas.losses + 1
                    KB.Utils.SafePrint("|cffff3333[WoWKB]|r Arena Defeat recorded.")
                end
            elseif context.isBattleground then
                if isWin then
                    WoWKillboardDB.stats.bgs.wins = WoWKillboardDB.stats.bgs.wins + 1
                    KB.Utils.SafePrint("|cff00ff00[WoWKB]|r Battleground Victory recorded!")
                else
                    WoWKillboardDB.stats.bgs.losses = WoWKillboardDB.stats.bgs.losses + 1
                    KB.Utils.SafePrint("|cffff3333[WoWKB]|r Battleground Defeat recorded.")
                end
            end
            if KB.UI and KB.UI.RefreshIfVisible then KB.UI:RefreshIfVisible() end
        elseif winner == nil then
            CT.RecordedMatchWinner = false
        end
    end
end)

-- Universal Event Registration across all 4 WoW client flavors (Guardrail 2 Compliant)
-- In Modern Retail (12.0+) and WoW Forever Beta (16001+), COMBAT_LOG_EVENT_UNFILTERED is restricted
-- to Blizzard UI only. Calling RegisterEvent on it triggers an immediate ADDON_ACTION_BLOCKED popup.
local isCLEUForbidden = false
if GetBuildInfo then
    local _, _, _, tocversion = GetBuildInfo()
    tocversion = tonumber(tocversion) or 11500
    if tocversion >= 16000 or tocversion >= 120000 then
        isCLEUForbidden = true
    end
end

if not isCLEUForbidden and type(CombatLogGetCurrentEventInfo) == "function" then
    frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

frame:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN")
frame:RegisterEvent("CHAT_MSG_SYSTEM")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("PLAYER_ALIVE")
frame:RegisterEvent("PLAYER_UNGHOST")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("PLAYER_PVP_KILLS_CHANGED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
frame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")

