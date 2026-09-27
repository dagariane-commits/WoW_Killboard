--[[
    WoWKillboard - Core.lua
    Addon lifecycle manager, slash commands, database initialization,
    and minimap button registration.
]]

WoWKillboard = WoWKillboard or {}
local KB = WoWKillboard

local coreFrame = CreateFrame("Frame")

-- Initialize Databases and settings on load
function KB:Initialize()
    -- Initialize SavedVariables
    WoWKillboardDB = WoWKillboardDB or { kills = {}, stats = {} }
    WoWKillboardDB.kills = WoWKillboardDB.kills or {}

    WoWKillboardSettings = WoWKillboardSettings or {}
    for k, v in pairs(KB.DefaultSettings) do
        if WoWKillboardSettings[k] == nil then
            WoWKillboardSettings[k] = v
        end
    end

    WoWKillboardBounties = WoWKillboardBounties or {}
    WoWKillboardDebtLedger = WoWKillboardDebtLedger or {}

    -- Rebuild Leaderboard cache
    if KB.Leaderboard and KB.Leaderboard.Rebuild then
        KB.Leaderboard:Rebuild()
    end

    -- Initialize Reinforcements engine
    if KB.Reinforcements and KB.Reinforcements.Init then
        KB.Reinforcements:Init()
    end

    -- Initialize Intel Scanner & KOS Blacklist engine
    if KB.IntelScanner and KB.IntelScanner.Init then
        KB.IntelScanner:Init()
    end

    -- Create Minimap Button
    KB:CreateMinimapButton()

    print(string.format("|cff00ccffWoW Killboard v%s|r loaded. Type |cffffd100/kb|r, |cffffd100/wowkb|r, or |cffffd100/killboard|r to open dashboard.", KB.Version))
end

-- Slash Commands (Support /killboard, /wowkb, and /kb)
SLASH_WOWKILLBOARD1 = "/killboard"
SLASH_WOWKILLBOARD2 = "/wowkb"
SLASH_WOWKILLBOARD3 = "/kb"

SlashCmdList["WOWKILLBOARD"] = function(msg)
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    cmd = cmd and cmd:lower() or ""

    if cmd == "" then
        if KB.UI then KB.UI:Toggle() end
    elseif cmd == "reset" then
        WoWKillboardDB = { kills = {}, stats = {} }
        if KB.Leaderboard then KB.Leaderboard:Rebuild() end
        if KB.UI then KB.UI:RefreshIfVisible() end
        print("|cff00ccff[WoWKB]|r Database has been reset.")
    elseif cmd == "stats" then
        local s = KB.CombatTracker.SessionStats
        local st = WoWKillboardDB and WoWKillboardDB.stats or {}
        local dW = st.duels and st.duels.wins or 0
        local dL = st.duels and st.duels.losses or 0
        local bgW = st.bgs and st.bgs.wins or 0
        local bgL = st.bgs and st.bgs.losses or 0
        local aW = st.arenas and st.arenas.wins or 0
        local aL = st.arenas and st.arenas.losses or 0
        local kd = (s.deaths > 0) and string.format("%.2f", s.kills / s.deaths) or tostring(s.kills)
        print(string.format("|cff00ccff[WoWKB Stats]|r Kills: |cff00ff00%d|r | Deaths: |cffff3333%d|r | K/D: |cffffd100%s|r | Dmg: |cffff7700%s|r | Heal: |cff00ff66%s|r",
            s.kills, s.deaths, kd, KB.Utils.FormatNumber(s.damageDone), KB.Utils.FormatNumber(s.healingDone)))
        print(string.format("  |cffffd700Duels (1v1):|r %dW - %dL | |cff00ccffBattlegrounds:|r %dW - %dL | |cffa335eeArenas:|r %dW - %dL", dW, dL, bgW, bgL, aW, aL))
    elseif cmd == "bounty" then
        local target, gold = arg:match("^(%S+)%s+(%d+)$")
        if target and gold then
            KB.BountyEngine:PlaceBounty(target, "UNKNOWN", "Unknown", tonumber(gold))
        else
            print("|cffff9900Usage:|r /killboard bounty <TargetName> <GoldAmount> (e.g. /killboard bounty Thrall 250)")
        end
    elseif cmd == "backup" or cmd == "sos" or cmd == "warhorn" or cmd == "calltoarms" then
        if arg == "stop" or arg == "resolve" or arg == "clear" or arg == "off" then
            if KB.Reinforcements then KB.Reinforcements:ResolveBeacon(false) end
        else
            if KB.Reinforcements then KB.Reinforcements:TriggerCallForBackup() end
        end
    elseif cmd == "event" or cmd == "rally" then
        local title, zone, timeStr = arg:match("^([^|]+)%s*|%s*([^|]+)%s*|?%s*(.*)$")
        if title and zone then
            local myGuild = GetGuildInfo("player") or "Guild"
            local myName = UnitName("player")
            local evt = {
                id = "EVT-" .. tostring(time()) .. "-" .. myName,
                title = title:trim(),
                guild_name = myGuild,
                creator_name = myName,
                zone = zone:trim(),
                time_str = (timeStr and timeStr:trim() ~= "") and timeStr:trim() or "NOW",
                created_at = time(),
            }
            WoWKillboardEvents = WoWKillboardEvents or {}
            WoWKillboardEvents[evt.id] = evt
            if KB.Sync and KB.Sync.BroadcastEvent then
                KB.Sync:BroadcastEvent(evt)
            end
            if IsInGuild() then
                SendChatMessage(string.format("[WoWKillboard Event] ⚔️ %s in %s! Announced by %s. Time: %s.",
                    evt.title, evt.zone, myName, evt.time_str), "GUILD")
            end
            print(string.format("|cff00ccff[WoWKB Event]|r Created Guild Rally: |cffffd100%s|r in |cffffffff%s|r!", evt.title, evt.zone))
        else
            print("|cffff9900Usage:|r /killboard event <Title> | <Zone> | <Time> (e.g. /killboard event STV Defense | Stranglethorn Vale | 8:00 PM EST)")
        end
    elseif cmd == "spot" or cmd == "scout" then
        if KB.IntelScanner then
            KB.IntelScanner:SpotTarget(arg)
        end
    elseif cmd == "kos" then
        local action, entity = arg:match("^(%S*)%s*(.-)$")
        action = action and action:lower() or "list"
        WoWKillboardDB = WoWKillboardDB or {}
        WoWKillboardDB.kosGuilds = WoWKillboardDB.kosGuilds or {}
        WoWKillboardDB.kosDeserters = WoWKillboardDB.kosDeserters or {}
        WoWKillboardDB.kosPlayers = WoWKillboardDB.kosPlayers or {}

        if action == "add" and entity ~= "" then
            WoWKillboardDB.kosGuilds[entity] = { reason = "Manual KOS Branding", time = time() }
            print(string.format("|cffff0000[WoWKB KOS]|r Added |cffffd100%s|r to KOS Blacklist.", entity))
        elseif action == "remove" and entity ~= "" then
            WoWKillboardDB.kosGuilds[entity] = nil
            WoWKillboardDB.kosPlayers[entity] = nil
            WoWKillboardDB.kosDeserters[entity] = nil
            print(string.format("|cff00ff00[WoWKB KOS]|r Removed |cffffd100%s|r from KOS Blacklist.", entity))
        else
            print("|cffff0000[WoWKB Realm KOS Blacklist & Deserters]:|r")
            local count = 0
            for g, d in pairs(WoWKillboardDB.kosGuilds) do
                print(string.format("  - Guild: |cffff5555<%s>|r (%s)", g, d.reason or "KOS"))
                count = count + 1
            end
            for dName, dInfo in pairs(WoWKillboardDB.kosDeserters) do
                print(string.format("  - Deserter: |cffff5555%s|r (Ex-<%s>)", dName, dInfo.former_guild or "None"))
                count = count + 1
            end
            if count == 0 then print("  (No active KOS blacklist targets)") end
        end
    elseif cmd == "sync" or cmd == "reload" then
        print("|cff00ccff[WoWKB]|r Flushed combat SavedVariables to disk. Reloading UI to sync with live web platform...")
        ReloadUI()
    elseif cmd == "move" or cmd == "unlock" then
        if KB.UI and KB.UI.ToggleBannerLock then
            KB.UI:ToggleBannerLock()
        end
    elseif cmd == "test" then
        if KB.UI and KB.UI.TestKillBanner then
            KB.UI:TestKillBanner()
            print("|cff00ff00[WoWKB]|r Frontline Kill Banner test preview triggered!")
        end
    elseif cmd == "testkill" or cmd == "mockkill" or cmd == "recordkill" or cmd == "demo" then
        local pName = UnitName("player") or "Hero"
        local _, pClass = UnitClass("player")
        pClass = pClass or "PALADIN"
        local pLevel = UnitLevel("player") or 20
        local pGuild = GetGuildInfo("player") or "None"
        local pFaction = UnitFactionGroup("player") or "Alliance"

        local enemyFaction = (pFaction == "Alliance") and "Horde" or "Alliance"
        local enemyRace = (enemyFaction == "Horde") and "Undead" or "Human"
        local enemyClass = (enemyFaction == "Horde") and "ROGUE" or "WARRIOR"
        local enemyName = (enemyFaction == "Horde") and "Shadowstalker" or "Dawnbreaker"
        local enemyGuild = (enemyFaction == "Horde") and "Grim Syndicate" or "Silver Hand"
        local enemyLevel = math.max(1, pLevel + 1)

        if arg and arg ~= "" then
            enemyName = arg:match("^%s*(.-)%s*$")
        elseif UnitExists("target") then
            local tName = UnitName("target")
            if tName and tName ~= "" then
                enemyName = tName
                local _, tClass = UnitClass("target")
                if tClass then enemyClass = tClass end
                local tRace = UnitRace("target")
                if tRace then enemyRace = tRace end
                local tGuild = GetGuildInfo("target")
                if tGuild then enemyGuild = tGuild end
                local tFaction = UnitFactionGroup("target")
                if tFaction then enemyFaction = tFaction end
                local tLevel = UnitLevel("target")
                if tLevel and tLevel > 0 then enemyLevel = tLevel end
            end
        end

        local loc = KB.Utils and KB.Utils.GetPlayerLocation and KB.Utils.GetPlayerLocation() or { mapId = 1421, zone = GetZoneText() or "Wilderness", subZone = GetSubZoneText() or "", x = 45.2, y = 32.8 }
        local dmgAmount = math.max(650, pLevel * 60)

        local testKill = {
            timestamp = time(),
            isSolo = true,
            isBattleground = false,
            isArena = false,
            isDuel = false,
            attackersCount = 1,
            totalDamage = dmgAmount,
            killer = {
                guid = UnitGUID("player") or "Player-0001",
                name = pName,
                level = pLevel,
                class = pClass,
                guild = pGuild,
                faction = pFaction,
                partySize = 1,
                damageDone = dmgAmount,
                healingDone = math.floor(dmgAmount * 0.25),
            },
            victim = {
                guid = (UnitExists("target") and UnitGUID("target")) or ("Player-DEMO-" .. tostring(time()) .. "-" .. tostring(math.random(100, 999))),
                name = enemyName,
                level = enemyLevel,
                class = enemyClass,
                race = enemyRace,
                guild = enemyGuild,
                faction = enemyFaction,
                partySize = 1,
            },
            location = loc,
            attackers = {
                {
                    guid = UnitGUID("player") or "Player-0001",
                    name = pName,
                    class = pClass,
                    level = pLevel,
                    guild = pGuild,
                    faction = pFaction,
                    damage = dmgAmount,
                    spell = (pClass == "PALADIN") and "Judgement" or ((pClass == "ROGUE") and "Eviscerate" or "Mortal Strike"),
                    isPlayer = true,
                }
            },
        }

        if KB.CombatTracker then
            KB.CombatTracker.SessionStats.kills = KB.CombatTracker.SessionStats.kills + 1
            KB.CombatTracker.SessionStats.damageDone = KB.CombatTracker.SessionStats.damageDone + dmgAmount
        end

        if KB.Killmail and KB.Killmail.RecordKill then
            KB.Killmail:RecordKill(testKill)
        end
        if KB.UI and KB.UI.ShowKillBanner then
            KB.UI:ShowKillBanner(testKill, true)
        end
        print(string.format("|cff00ff00[WoWKB]|r Generated synthetic Open-World PvP Kill against |cffff3333%s|r in %s!", enemyName, loc.zone))

    elseif cmd == "testdeath" then
        local pName = UnitName("player") or "Hero"
        local _, pClass = UnitClass("player")
        pClass = pClass or "PALADIN"
        local pLevel = UnitLevel("player") or 20
        local pGuild = GetGuildInfo("player") or "None"
        local pFaction = UnitFactionGroup("player") or "Alliance"

        local enemyFaction = (pFaction == "Alliance") and "Horde" or "Alliance"
        local enemyClass = (enemyFaction == "Horde") and "WARLOCK" or "MAGE"
        local enemyName = (enemyFaction == "Horde") and "Soulreaper" or "Pyromaster"

        local loc = KB.Utils and KB.Utils.GetPlayerLocation and KB.Utils.GetPlayerLocation() or { mapId = 1421, zone = GetZoneText() or "Wilderness", subZone = GetSubZoneText() or "", x = 45.2, y = 32.8 }
        local dmgAmount = math.max(800, pLevel * 75)

        local testDeath = {
            timestamp = time(),
            isSolo = true,
            isBattleground = false,
            isArena = false,
            isDuel = false,
            attackersCount = 1,
            totalDamage = dmgAmount,
            killer = {
                guid = "Player-DEMO-KILLER-" .. tostring(time()),
                name = enemyName,
                level = math.max(1, pLevel + 2),
                class = enemyClass,
                guild = "Blackout",
                faction = enemyFaction,
                partySize = 1,
                damageDone = dmgAmount,
                healingDone = 0,
            },
            victim = {
                guid = UnitGUID("player") or "Player-0001",
                name = pName,
                level = pLevel,
                class = pClass,
                guild = pGuild,
                faction = pFaction,
                partySize = 1,
            },
            location = loc,
            attackers = {
                {
                    guid = "Player-DEMO-KILLER-" .. tostring(time()),
                    name = enemyName,
                    class = enemyClass,
                    level = math.max(1, pLevel + 2),
                    guild = "Blackout",
                    faction = enemyFaction,
                    damage = dmgAmount,
                    spell = "Shadow Bolt",
                    isPlayer = true,
                }
            },
        }

        if KB.CombatTracker then
            KB.CombatTracker.SessionStats.deaths = KB.CombatTracker.SessionStats.deaths + 1
            KB.CombatTracker.LastPvpKiller = testDeath.killer
        end

        if KB.Killmail and KB.Killmail.RecordKill then
            KB.Killmail:RecordKill(testDeath)
        end

        if KB.UI and KB.UI.ShowDeathBountyPrompt then
            KB.UI:ShowDeathBountyPrompt(testDeath.killer)
        end
        print(string.format("|cffff3333[WoWKB]|r Simulated PvP death against |cffffd100%s|r! Death bounty prompt engaged.", enemyName))
    elseif cmd == "radar" or cmd == "hud" then
        if KB.UI and KB.UI.ToggleRadarHUD then
            KB.UI:ToggleRadarHUD()
        end
    elseif cmd == "alerts" or cmd == "alert" or cmd == "config" then
        if KB.UI and KB.UI.ShowAlertsConfig then
            KB.UI:ShowAlertsConfig()
        end
    elseif cmd == "armory" then
        KB:PrintArmoryDossier(arg)
    elseif cmd == "markprompt" or cmd == "bountyprompt" then
        local mArg = arg and arg:lower():match("^%s*(.-)%s*$") or ""
        WoWKillboardSettings = WoWKillboardSettings or {}
        if mArg == "off" or mArg == "disable" or mArg == "0" then
            WoWKillboardSettings.promptMarkOnDeath = false
            WoWKillboardSettings.promptBountyOnDeath = false
            print("|cffff3333[WoWKB]|r Mark of Spite death popup: |cffff3333Disabled|r.")
        elseif mArg == "on" or mArg == "enable" or mArg == "1" then
            WoWKillboardSettings.promptMarkOnDeath = true
            WoWKillboardSettings.promptBountyOnDeath = true
            print("|cff00ff00[WoWKB]|r Mark of Spite death popup: |cff00ff00Enabled|r.")
        else
            local cur = (WoWKillboardSettings.promptMarkOnDeath ~= false and WoWKillboardSettings.promptBountyOnDeath ~= false)
            local nxt = not cur
            WoWKillboardSettings.promptMarkOnDeath = nxt
            WoWKillboardSettings.promptBountyOnDeath = nxt
            local st = nxt and "|cff00ff00Enabled|r" or "|cffff3333Disabled|r"
            print(string.format("|cff00ccff[WoWKB]|r Mark of Spite death popup toggled to: %s", st))
        end
    elseif cmd == "claim" then
        local code = arg and arg:match("^%s*(.-)%s*$") or ""
        if code and code ~= "" then
            WoWKillboardDB = WoWKillboardDB or {}
            WoWKillboardDB.claimTokens = WoWKillboardDB.claimTokens or {}
            local pName = UnitName("player") or "Player"
            WoWKillboardDB.claimTokens[pName] = {
                code = code,
                time = time(),
                guid = UnitGUID("player") or "UNKNOWN",
                realm = (GetRealmName and GetRealmName()) or "PvP",
            }
            print(string.format("|cff00ff00[WoWKB]|r Claim verification token registered for |cffffd100%s|r: |cffffff00%s|r.", pName, code))
            print("|cff00ccff[WoWKB]|r Run sync client or upload SavedVariables to complete character ownership claim.")
        else
            print("|cffff9900Usage:|r /kb claim <code> (e.g. /kb claim KB-7842)")
        end
    elseif cmd == "theme" then
        local tArg = arg and arg:lower():match("^%s*(.-)%s*$") or ""
        if tArg == "classic" or tArg == "elvui" then
            if KB.UI then KB.UI:SetTheme(tArg) end
        else
            local cur = (KB.UI and KB.UI.GetCurrentThemeName) and KB.UI:GetCurrentThemeName() or "classic"
            local nextTheme = (cur == "classic") and "elvui" or "classic"
            if KB.UI then KB.UI:SetTheme(nextTheme) end
        end
    else
        print("|cff00ccffWoW Killboard — Frontline War Room Commands:|r")
        print("  |cffffd100/kb|r, |cffffd100/wowkb|r, or |cffffd100/killboard|r - Toggle the Frontline War Room Dashboard")
        print("  |cffffd100/kb radar|r or |cffffd100/kbradar|r - Toggle the Tactical Radar HUD floating window")
        print("  |cffffd100/kb alerts|r - Open Combat Alerts & Radar Configuration")
        print("  |cffffd100/kb markprompt [on|off]|r - Toggle Mark of Spite revenge prompt on PvP death")
        print("  |cffffd100/kb claim <code>|r - Register web character ownership verification code")
        print("  |cffffd100/kb move|r - Unlock or lock Kill Banner to reposition on screen")
        print("  |cffffd100/kb test|r - Preview Kill Alert Banner with sound and raid warning")
        print("  |cffffd100/kb testkill|r - Simulate an Open-World PvP Kill (populates feed & stats)")
        print("  |cffffd100/kb testdeath|r - Simulate a PvP Death (prompts revenge blood bounty)")
        print("  |cffffd100/kb armory [Name]|r or |cffffd100/armory [Name]|r - Inspect Character Combat Dossier")
        print("  |cffffd100/spot|r or |cffffd100/scout [notes]|r - Report and broadcast spotted enemy hostile to allies")
        print("  |cffffd100/warhorn|r or |cffffd100/kbsos|r - Sound the War Horn (Call to Arms & muster war party)")
        print("  |cffffd100/warhorn stop|r - Stand down War Horn and close recruitment")
        print("  |cffffd100/kb kos [add|remove|list]|r - View or manage realm KOS Blacklist")
        print("  |cffffd100/kb event <Title> | <Zone> | <Time>|r - Issue War Council Battle Order / Rally")
        print("  |cffffd100/kb theme [classic|elvui]|r - Switch between Classic WoW and ElvUI aesthetics")
        print("  |cffffd100/kb sync|r or |cffffd100/kb reload|r - Flush combat SavedVariables to disk to sync with website")
        print("  |cffffd100/kb stats|r - Review current combat session battle statistics")
        print("  |cffffd100/kb bounty <Name> <Gold>|r - Declare a blood bounty on an enemy player (Open World)")
        print("  |cffffd100/kb reset|r - Clear local battle records")
    end
end

-- Dedicated Quick-Slash Commands for Player Armory Dossier Lookup
SLASH_WOWKB_ARMORY1 = "/armory"
SLASH_WOWKB_ARMORY2 = "/kbarmory"
SlashCmdList["WOWKB_ARMORY"] = function(msg)
    KB:PrintArmoryDossier(msg)
end

SLASH_WOWKB_RADAR1 = "/kbradar"
SlashCmdList["WOWKB_RADAR"] = function()
    if KB.UI and KB.UI.ToggleRadarHUD then
        KB.UI:ToggleRadarHUD()
    end
end

function KB:PrintArmoryDossier(targetName)
    local name = targetName and targetName:trim() or ""
    if name == "" then
        if UnitExists("target") and UnitIsPlayer("target") then
            name = UnitName("target")
        else
            name = UnitName("player")
        end
    end

    if not name or name == "" then
        print("|cffff9900Usage:|r /killboard armory <CharacterName> (or target a player and type /armory)")
        return
    end

    -- Query local battle records
    local killsCount = 0
    local deathsCount = 0
    local soloCount = 0
    local duelCount = 0
    local bgCount = 0
    local charClass = "UNKNOWN"
    local charLevel = 60
    local charGuild = "None"
    local charFaction = "Unknown"

    if WoWKillboardDB and WoWKillboardDB.kills then
        for _, k in ipairs(WoWKillboardDB.kills) do
            local killer = k.killer or {}
            local victim = k.victim or {}
            if killer.name and killer.name:lower() == name:lower() then
                killsCount = killsCount + 1
                if k.isSolo then soloCount = soloCount + 1 end
                if k.isDuel then duelCount = duelCount + 1 end
                if k.isBattleground then bgCount = bgCount + 1 end
                charClass = killer.class or charClass
                charLevel = killer.level or charLevel
                charGuild = killer.guild or charGuild
                charFaction = killer.faction or charFaction
            end
            if victim.name and victim.name:lower() == name:lower() then
                deathsCount = deathsCount + 1
                charClass = victim.class or charClass
                charLevel = victim.level or charLevel
                charGuild = victim.guild or charGuild
                charFaction = victim.faction or charFaction
            end
        end
    end

    -- If target was current target or player, get live unit info
    if UnitExists("target") and UnitIsPlayer("target") and UnitName("target"):lower() == name:lower() then
        charLevel = UnitLevel("target") or charLevel
        local _, c = UnitClass("target")
        if c then charClass = c end
        local f = UnitFactionGroup("target")
        if f then charFaction = f end
        local g = GetGuildInfo("target")
        if g then charGuild = g end
    elseif UnitName("player") and UnitName("player"):lower() == name:lower() then
        charLevel = UnitLevel("player") or charLevel
        local _, c = UnitClass("player")
        if c then charClass = c end
        local f = UnitFactionGroup("player")
        if f then charFaction = f end
        local g = GetGuildInfo("player")
        if g then charGuild = g end
    end

    local kd = (deathsCount > 0) and string.format("%.2f", killsCount / deathsCount) or tostring(killsCount)

    -- Authentic Classic PvP Military Honor Rank Calculation
    local score = killsCount * (1.0 + math.min(tonumber(kd) or 0, 3.0) * 0.2)
    local rankTitle = "Private"
    if charFaction == "Horde" then
        if score >= 100 then rankTitle = "High Warlord"
        elseif score >= 75 then rankTitle = "General"
        elseif score >= 55 then rankTitle = "Lieutenant General"
        elseif score >= 40 then rankTitle = "Champion"
        elseif score >= 30 then rankTitle = "Centurion"
        elseif score >= 22 then rankTitle = "Legionnaire"
        elseif score >= 16 then rankTitle = "Blood Guard"
        elseif score >= 11 then rankTitle = "Stone Guard"
        elseif score >= 7 then rankTitle = "First Sergeant"
        elseif score >= 4 then rankTitle = "Senior Sergeant"
        elseif score >= 2 then rankTitle = "Sergeant"
        elseif score >= 1 then rankTitle = "Grunt"
        else rankTitle = "Scout"
        end
    else
        if score >= 100 then rankTitle = "Grand Marshal"
        elseif score >= 75 then rankTitle = "Field Marshal"
        elseif score >= 55 then rankTitle = "Marshal"
        elseif score >= 40 then rankTitle = "Commander"
        elseif score >= 30 then rankTitle = "Lieutenant Commander"
        elseif score >= 22 then rankTitle = "Knight-Champion"
        elseif score >= 16 then rankTitle = "Knight-Captain"
        elseif score >= 11 then rankTitle = "Knight-Lieutenant"
        elseif score >= 7 then rankTitle = "Knight"
        elseif score >= 4 then rankTitle = "Sergeant Major"
        elseif score >= 2 then rankTitle = "Master Sergeant"
        elseif score >= 1 then rankTitle = "Corporal"
        else rankTitle = "Private"
        end
    end

    local colorHex = "ffffffff"
    if KB.Themes and KB.Themes.CLASS_COLORS and KB.Themes.CLASS_COLORS[charClass:upper()] then
        local rgb = KB.Themes.CLASS_COLORS[charClass:upper()]
        colorHex = string.format("ff%02x%02x%02x", math.floor(rgb[1]*255), math.floor(rgb[2]*255), math.floor(rgb[3]*255))
    end

    local guildPart = (charGuild and charGuild ~= "None" and charGuild ~= "") and string.format(" <%s>", charGuild) or ""
    local factionColor = (charFaction == "Alliance") and "|cff3b82f6Alliance|r" or ((charFaction == "Horde") and "|cffef4444Horde|r" or "|cff94a3b8Neutral|r")

    print(string.format("|cff00e5ff[WoWKB Player Armory]|r |c%s%s|r (Lvl %d %s)%s - %s", colorHex, name, charLevel, charClass, guildPart, factionColor))
    print(string.format("  |cffffd700🎖️ Honor Rank:|r |cffffffff%s|r | |cff00ff00K/D:|r |cffffffff%s|r (|cff00ff00%d|r Kills / |cffff3333%d|r Deaths)",
        rankTitle, kd, killsCount, deathsCount))
    print(string.format("  |cff00e5ffSolo Kills:|r %d | |cffffd700Duels (1v1):|r %d | |cff3b82f6BGs:|r %d", soloCount, duelCount, bgCount))

    -- Check KOS Blacklist or Deserter status
    if WoWKillboardDB then
        if (WoWKillboardDB.kosGuilds and charGuild and WoWKillboardDB.kosGuilds[charGuild]) or (WoWKillboardDB.kosPlayers and WoWKillboardDB.kosPlayers[name]) then
            print("  |cffff0000🚨 TARGET IS ON REALM KOS BLACKLIST! Execute on sight!|r")
        end
        if WoWKillboardDB.kosDeserters and WoWKillboardDB.kosDeserters[name] then
            print("  |cffffaa00⚡ TARGET IS A MARKED GUILD-HOP DESERTER!|r")
        end
    end

    -- Check Active Bounties
    if WoWKillboardBounties then
        for _, b in pairs(WoWKillboardBounties) do
            if b.target_name and b.target_name:lower() == name:lower() and b.status == "ACTIVE" then
                print(string.format("  |cffffd100💰 ACTIVE BLOOD BOUNTY:|r %d Gold! Deliver the killing blow to collect!", b.amount_gold or 0))
                break
            end
        end
    end
end

-- Dedicated Quick-Slash Commands for Tactical Intel Spotting
SLASH_WOWKB_SPOT1 = "/spot"
SLASH_WOWKB_SPOT2 = "/scout"
SLASH_WOWKB_SPOT3 = "/kbspot"
SLASH_WOWKB_SPOT4 = "/kbscout"
SlashCmdList["WOWKB_SPOT"] = function(msg)
    if KB.IntelScanner then
        KB.IntelScanner:SpotTarget(msg)
    end
end

-- Dedicated Emergency Quick-Slash Commands for War Horn / Call for Backup
SLASH_WOWKILLBOARDSOS1 = "/kbsos"
SLASH_WOWKILLBOARDSOS2 = "/kbbackup"
SLASH_WOWKILLBOARDSOS3 = "/warhorn"
SLASH_WOWKILLBOARDSOS4 = "/kbwarhorn"
SLASH_WOWKILLBOARDSOS5 = "/kbrally"
SlashCmdList["WOWKILLBOARDSOS"] = function(msg)
    local arg = msg and msg:lower():trim() or ""
    if arg == "stop" or arg == "resolve" or arg == "clear" or arg == "off" then
        if KB.Reinforcements then KB.Reinforcements:ResolveBeacon(false) end
    else
        if KB.Reinforcements then KB.Reinforcements:TriggerCallForBackup() end
    end
end

-- Dedicated Quick-Slash Commands for Kill Alert Calibration & Testing
SLASH_WOWKB_MOVE1 = "/wowkbmove"
SLASH_WOWKB_MOVE2 = "/kbmove"
SlashCmdList["WOWKB_MOVE"] = function()
    if KB.UI and KB.UI.ToggleBannerLock then KB.UI:ToggleBannerLock() end
end

SLASH_WOWKB_TEST1 = "/wowkbtest"
SLASH_WOWKB_TEST2 = "/kbtest"
SlashCmdList["WOWKB_TEST"] = function()
    if KB.UI and KB.UI.TestKillBanner then KB.UI:TestKillBanner() end
end

SLASH_WOWKB_ALERTS1 = "/wowkbalerts"
SLASH_WOWKB_ALERTS2 = "/kbalerts"
SlashCmdList["WOWKB_ALERTS"] = function()
    if KB.UI and KB.UI.ShowAlertsConfig then KB.UI:ShowAlertsConfig() end
end


-- Lightweight Floating Launcher Button (100% Taint-Free, Zero GameTooltip Touching, Anonymous Frame)
function KB:CreateMinimapButton()
    local btn = CreateFrame("Button", nil, UIParent)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("HIGH")
    btn:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -180, -30)
    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        if not InCombatLockdown() then
            self:StartMoving()
        end
    end)
    btn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    btn:SetClampedToScreen(true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(22, 22)
    icon:SetPoint("CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\Achievement_PVP_P_01") -- PvP Skull Icon

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            if KB.UI then KB.UI:Toggle() end
        elseif button == "RightButton" then
            local cur = (KB.UI and KB.UI.GetCurrentThemeName) and KB.UI:GetCurrentThemeName() or "classic"
            local nextTheme = (cur == "classic") and "elvui" or "classic"
            if KB.UI then KB.UI:SetTheme(nextTheme) end
        end
    end)

    -- Dedicated Private Tooltip (Never touches or taints Blizzard's GameTooltip)
    local tipFrame = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    tipFrame:SetSize(220, 64)
    tipFrame:SetPoint("BOTTOMLEFT", btn, "TOPLEFT", 0, 4)
    tipFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    tipFrame:SetBackdropColor(0.035, 0.045, 0.07, 0.96)
    tipFrame:SetBackdropBorderColor(0.85, 0.65, 0.20, 0.9)
    tipFrame:Hide()

    local tipText = tipFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tipText:SetPoint("CENTER", 0, 0)
    tipText:SetJustifyH("CENTER")

    btn:SetScript("OnEnter", function()
        local killsCount = (WoWKillboardDB and WoWKillboardDB.kills) and KB.Utils.TableLength(WoWKillboardDB.kills) or 0
        local curTheme = (KB.UI and KB.UI.GetCurrentThemeName) and KB.UI:GetCurrentThemeName():upper() or "CLASSIC"
        tipText:SetText(string.format("|cffffd100WoW Killboard|r |cff888888[%s]|r\n|cff10b981Session Kills Logged: %d|r\n|cff00e5ffLeft-Click:|r Dashboard | |cff00e5ffRight-Click:|r Theme\n|cff888888Drag to Reposition|r", curTheme, killsCount))
        tipFrame:Show()
    end)
    btn:SetScript("OnLeave", function() tipFrame:Hide() end)
end

-- Event Router
coreFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "WoWKillboard" then
            KB:Initialize()
        end
    end
end)

coreFrame:RegisterEvent("ADDON_LOADED")

