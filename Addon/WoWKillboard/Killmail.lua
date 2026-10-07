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
    if not data or not data.killer or not data.victim or data.isTest or (data.killId and tostring(data.killId):find("^TEST%-")) then
        return nil
    end

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

    local isSolo = data.isSolo or false
    local attackersCount = data.attackersCount or 1
    local totalDamage = data.totalDamage or 0
    local killerDamage = (data.killer and data.killer.damageDone) or 0
    local isDuel = data.isDuel or false
    local isBattleground = data.isBattleground or false
    local isArena = data.isArena or false

    -- Guardrail 4: Strict Solo Purity Enforcement (0-damage & gang ganks never certified solo)
    if not isDuel then
        if isBattleground or isArena or totalDamage <= 0 or (isKillerSelf and killerDamage <= 0) then
            isSolo = false
            if attackersCount < 2 then attackersCount = 2 end
        end
        if attackersCount > 1 or (data.attackers and #data.attackers > 1) then
            isSolo = false
        end
    end
    if isSolo then
        attackersCount = 1
    end

    local currentRealm = (GetRealmName and GetRealmName()) or "Unknown"
    local currentRuleset = (KB.Utils and KB.Utils.GetRealmRuleset and KB.Utils.GetRealmRuleset()) or "PVP"

    local killmail = {
        killId = killId,
        realm = data.realm or currentRealm,
        ruleset = data.ruleset or currentRuleset,
        timestamp = data.timestamp or time(),
        isDuel = isDuel,
        isBattleground = isBattleground,
        isArena = isArena,
        zone_type = data.zone_type or (isBattleground and "pvp") or (isArena and "arena") or "none",
        battlegroundName = data.battlegroundName,
        isSolo = isSolo,
        attackersCount = attackersCount,
        totalDamage = totalDamage,
        attackers = data.attackers or {},
        finalSpell = data.finalSpell or (data.killer and data.killer.spell) or "Combat Strike",
        killer = {
            guid = data.killer.guid,
            name = data.killer.name or "Unknown",
            level = data.killer.level or 0,
            class = data.killer.class or "UNKNOWN",
            spec = data.killer.spec or (isKillerSelf and playerSpec) or nil,
            guild = data.killer.guild or "None",
            faction = data.killer.faction or "Unknown",
            partySize = data.killer.partySize or 1,
            realm = (data.killer and data.killer.realm) or currentRealm,
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
            realm = (data.victim and data.victim.realm) or currentRealm,
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

    -- Standardized Casualty Broadcast (Format C) if local player is victim
    local myName = UnitName("player") or ""
    local myGUID = UnitGUID("player") or ""
    local isLocalVictim = (killmail.victim.guid and myGUID ~= "" and killmail.victim.guid == myGUID) or
                          (killmail.victim.name and myName ~= "" and (killmail.victim.name == myName or killmail.victim.name:match("^" .. myName .. "%-") or killmail.victim.name:lower() == myName:lower()))
    if isLocalVictim then
        KM:BroadcastCasualty(killmail.victim, killmail.killer, killmail.location, killmail.finalSpell or "Combat")
    end

    return killmail
end

-- Standardized Casualty / Death Broadcast (Format C)
-- Format: [WoWKB] Casualty: <Victim> (Lvl <Level> <Class>) killed by <Killer> (<Spell/Ability>) in <Location>.
-- Example: [WoWKB] Casualty: Dagariane (Lvl 23 Paladin) killed by Defias Pillager (Fireball) in Sentinel Hill.
function KM:BroadcastCasualty(victim, killer, location, spell, isTest)
    if not victim or not killer then return end

    local now = time()
    if not isTest and (now - (KM.LastCasualtyBroadcastTime or 0)) < 3 then return end
    KM.LastCasualtyBroadcastTime = now

    local s = WoWKillboardSettings or (KB.DefaultSettings or {})
    local enableGuild = (s.enableGuildBroadcasts ~= false)
    local enableChat = (s.enableChatBroadcasts == true)

    local vName = victim.name or UnitName("player") or "Player"
    local vLevel = (victim.level and victim.level > 0) and victim.level or (UnitLevel("player") or 60)
    local vClass = (KB.Utils and KB.Utils.GetClassTitle) and KB.Utils.GetClassTitle(victim.class) or (victim.class or "Adventurer")
    local kName = killer.name or "Hostile Threat"
    local spellName = (spell and spell ~= "" and spell ~= "UNKNOWN") and spell or "Combat"
    local locStr = (location and location.subZone and location.subZone ~= "") and location.subZone or ((location and location.zone) or GetZoneText() or "Wilderness")
    local tag = isTest and " [TEST SIMULATION]" or ""

    local casualtyMsg = string.format("[WoWKB] Casualty: %s (Lvl %s %s) killed by %s (%s) in %s.%s",
        vName, tostring(vLevel), vClass, kName, spellName, locStr, tag)

    -- Broadcast to Guild (Default: On)
    if IsInGuild and IsInGuild() and enableGuild then
        pcall(SendChatMessage, casualtyMsg, "GUILD")
    end

    -- Broadcast to Group/Raid
    if IsInGroup and IsInGroup() then
        pcall(SendChatMessage, casualtyMsg, (IsInRaid and IsInRaid()) and "RAID" or "PARTY")
    end

    -- Broadcast to dedicated WoWKillboard channel across the realm (Gated strictly against InCombatLockdown to prevent ADDON_ACTION_BLOCKED)
    if not InCombatLockdown() then
        local chanId = (KB.Sync and KB.Sync.GetChannelId and KB.Sync:GetChannelId("WoWKillboard")) or (GetChannelName and (GetChannelName("WoWKillboard") or GetChannelName("WoWKB")))
        if chanId and chanId > 0 then
            pcall(SendChatMessage, casualtyMsg, "CHANNEL", nil, chanId)
        end

        -- Broadcast to Say (Opt-in only, strictly outside combat)
        local inInstance = IsInInstance and IsInInstance()
        if enableChat and not inInstance then
            pcall(SendChatMessage, casualtyMsg, "SAY")
        end
    end

    return casualtyMsg
end

-- Record a validated PvE death (Player executed by an NPC/Monster)
function KM:RecordPveDeath(data)
    if not data or not data.npc or not data.victim or data.isTest or (data.deathId and tostring(data.deathId):find("^TEST%-")) then return end

    local now = data.timestamp or time()
    local seed = string.format("%s_%s_%s_%s", tostring(now), tostring(data.npc.guid or data.npc.name or "NPC"), tostring(data.victim.guid or ""), tostring(data.location and data.location.mapId or 0))
    local deathId = "PVE-" .. KB.Utils.Hash(seed)

    WoWKillboardDB = WoWKillboardDB or { kills = {}, stats = {}, pveDeaths = {} }
    WoWKillboardDB.pveDeaths = WoWKillboardDB.pveDeaths or {}

    if WoWKillboardDB.pveDeaths[deathId] then
        return
    end

    local currentRealm = (GetRealmName and GetRealmName()) or "Unknown"
    local currentRuleset = (KB.Utils and KB.Utils.GetRealmRuleset and KB.Utils.GetRealmRuleset()) or "PVE"

    local pveRecord = {
        deathId = deathId,
        realm = data.realm or currentRealm,
        ruleset = data.ruleset or currentRuleset,
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
            realm = (data.victim and data.victim.realm) or currentRealm,
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
    local chatMsg = string.format("|cffff2020[WoWKB]|r %s executed by |cffffd700[%s]|r (%s) in %s.", victimStr, pveRecord.npc.name, pveRecord.npc.spell or "Combat", pveRecord.location.zone)
    KB.Utils.SafePrint(chatMsg)

    -- Standardized Casualty Broadcast (Format C) & P2P Sync if local player is victim
    local myName = UnitName("player") or ""
    local myGUID = UnitGUID("player") or ""
    local isLocalVictim = (pveRecord.victim.guid and myGUID ~= "" and pveRecord.victim.guid == myGUID) or
                          (pveRecord.victim.name and myName ~= "" and (pveRecord.victim.name == myName or pveRecord.victim.name:match("^" .. myName .. "%-") or pveRecord.victim.name:lower() == myName:lower()))
    if isLocalVictim then
        KM:BroadcastCasualty(pveRecord.victim, pveRecord.npc, pveRecord.location, pveRecord.npc.spell or "Combat Strike")
        if KB.Sync and KB.Sync.BroadcastPveDeath then
            KB.Sync:BroadcastPveDeath(pveRecord)
        end
    end

    -- Trigger On-Screen Toast Banner for PvE Casualty
    if KB.UI and KB.UI.ShowKillBanner then
        KB.UI:ShowKillBanner({
            killId = deathId,
            timestamp = now,
            isSolo = false,
            isBattleground = false,
            isArena = false,
            isDuel = false,
            attackersCount = 1,
            finalSpell = pveRecord.npc.spell or "Combat Strike",
            npc = pveRecord.npc,
            killer = {
                guid = pveRecord.npc.guid or "CREATURE",
                name = pveRecord.npc.name or "Unknown Monster",
                level = 0,
                class = "WARRIOR",
                guild = "Wilderness Threat",
                faction = "Monster",
                partySize = 1,
                damageDone = pveRecord.npc.damage or 0,
                spell = pveRecord.npc.spell or "Combat Strike",
            },
            victim = pveRecord.victim,
            location = pveRecord.location,
        })
    end

    return pveRecord
end
