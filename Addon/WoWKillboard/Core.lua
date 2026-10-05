--[[
    WoWKillboard - Core.lua
    Addon lifecycle manager, slash commands, database initialization,
    and minimap button registration.
]]

WoWKillboard = WoWKillboard or {}
local KB = WoWKillboard

local function SafePrint(...)
    if KB and KB.Utils and KB.Utils.SafePrint then
        KB.Utils.SafePrint(...)
    elseif not InCombatLockdown() and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        local pieces = {}
        for i = 1, select("#", ...) do table.insert(pieces, tostring(select(i, ...))) end
        DEFAULT_CHAT_FRAME:AddMessage(table.concat(pieces, " "))
    end
end

local coreFrame = CreateFrame("Frame")

-- Self-Healing Kill History Sanitizer (Corrects victim self-insertion & assists in RAM)
function KB:SanitizeKillHistory()
    if not WoWKillboardDB or not WoWKillboardDB.kills then return end

    local fixedCount = 0
    for killId, km in pairs(WoWKillboardDB.kills) do
        if type(km) == "table" then
            local modified = false

            -- 1. Remove victim self-insertion from attackers list
            if km.victim and km.attackers and type(km.attackers) == "table" then
                local vName = km.victim.name and km.victim.name:lower() or ""
                local vGuid = km.victim.guid or ""
                local cleanedAttackers = {}
                local removedVictim = false

                for _, att in ipairs(km.attackers) do
                    local aName = att.name and att.name:lower() or ""
                    local aGuid = att.guid or ""
                    local isSelfVictim = false

                    if vGuid ~= "" and aGuid ~= "" and vGuid == aGuid then
                        isSelfVictim = true
                    elseif vName ~= "" and aName ~= "" and vName == aName then
                        isSelfVictim = true
                    end

                    if isSelfVictim then
                        removedVictim = true
                        modified = true
                    else
                        table.insert(cleanedAttackers, att)
                    end
                end

                if removedVictim then
                    km.attackers = cleanedAttackers
                    km.attackersCount = #cleanedAttackers
                    if km.attackersCount <= 1 and not km.isDuel and not km.isBattleground then
                        if (km.totalDamage or 0) > 0 and (km.killer and (km.killer.damageDone or 0) > 0) then
                            km.isSolo = true
                        else
                            km.isSolo = false
                            km.attackersCount = 2
                        end
                    end
                end
            end

            -- 2. Strict Guardrail 4 Solo Purity & 0-Damage Sanitization:
            -- A kill is NEVER certified solo if totalDamage <= 0, killerDamage <= 0, or multiple attackers exist
            if not km.isDuel then
                local kDmg = (km.killer and km.killer.damageDone) or 0
                local totDmg = km.totalDamage or 0
                local kLvl = (km.killer and km.killer.level) or 0
                local vLvl = (km.victim and km.victim.level) or 0
                local hasLevelDisparity = (vLvl > 0 and kLvl > 0 and (vLvl - kLvl) >= 5 and kDmg < 100)

                if km.isSolo then
                    if totDmg <= 0 or kDmg <= 0 or hasLevelDisparity or (km.attackersCount and km.attackersCount > 1) or (km.attackers and #km.attackers > 1) or km.isBattleground or km.isArena then
                        km.isSolo = false
                        km.attackersCount = math.max(2, km.attackersCount or 2)
                        modified = true
                    end
                elseif (km.attackersCount and km.attackersCount <= 1) and not km.isSolo then
                    -- If not certified solo, ensure attackersCount reflects an assisted/gang engagement
                    km.attackersCount = 2
                    modified = true
                end
            end

            if modified then
                fixedCount = fixedCount + 1
            end
        end
    end
end

-- Cross-Machine Realm Intelligence & Two-Way Player Career Synchronization
function KB:SyncRealmData()
    local rData = WoWKillboard_RealmData or (WoWKillboardDB and WoWKillboardDB.RealmData)
    if not rData then return false end

    WoWKillboardDB = WoWKillboardDB or { kills = {}, stats = {} }
    WoWKillboardDB.kills = WoWKillboardDB.kills or {}
    WoWKillboardDB.RealmData = rData
    WoWKillboard_RealmData = rData

    local pName = UnitName("player")
    if not pName or pName == "" or pName == "Unknown" then
        return false
    end
    local pLower = pName:lower()

    local function IsPlayerMatch(targetName)
        if not targetName then return false end
        local tLower = targetName:lower()
        if tLower == pLower then return true end
        if tLower:find("^" .. pLower:gsub("%-", "%%-") .. "%-") then return true end
        if pLower:find("^" .. tLower:gsub("%-", "%%-") .. "%-") then return true end
        return false
    end

    local imported = 0
    if rData.RecentKills then
        for _, km in ipairs(rData.RecentKills) do
            if km and type(km) == "table" and km.killer and type(km.killer) == "table" and km.killer.name and km.victim and type(km.victim) == "table" and km.victim.name then
                local kId = km.killId or (km.killer.name .. (km.victim.name or "") .. tostring(km.timestamp or 0))
                local isMe = false
                if IsPlayerMatch(km.killer.name) then
                    isMe = true
                elseif IsPlayerMatch(km.victim.name) then
                    isMe = true
                elseif km.attackers then
                    for _, att in pairs(km.attackers) do
                        if att and att.name and IsPlayerMatch(att.name) then
                            isMe = true
                            break
                        end
                    end
                end

                local matchRealm = not KB.Leaderboard or KB.Leaderboard:MatchesRealm(km)
                if isMe and matchRealm and kId and not WoWKillboardDB.kills[kId] then
                    WoWKillboardDB.kills[kId] = km
                    imported = imported + 1
                end
            end
        end
    end

    if imported > 0 then
        if KB.SanitizeKillHistory then
            KB:SanitizeKillHistory()
        end
        if KB.Leaderboard and KB.Leaderboard.Rebuild then
            KB.Leaderboard:Rebuild()
        end
    end

    if rData.LatestVersion and type(rData.LatestVersion) == "string" then
        if KB.Sync and KB.Sync.CompareVersions then
            if KB.Sync:CompareVersions(rData.LatestVersion, KB.Version) > 0 then
                KB.LatestKnownVersion = rData.LatestVersion
            end
        end
    end
    return true
end

-- Initialize Databases and settings on load
function KB:Initialize()
    -- Initialize SavedVariables
    WoWKillboardDB = WoWKillboardDB or { kills = {}, stats = {}, pveDeaths = {} }
    WoWKillboardDB.kills = WoWKillboardDB.kills or {}
    WoWKillboardDB.pveDeaths = WoWKillboardDB.pveDeaths or {}
    WoWKillboardDB.realmRulesets = WoWKillboardDB.realmRulesets or {}

    -- Auto-tag untagged legacy kills/deaths involving the local character or active realm
    local myRealm = (GetRealmName and GetRealmName()) or ""
    local myRuleset = (KB.Utils and KB.Utils.GetRealmRuleset and KB.Utils.GetRealmRuleset()) or "PVP"
    local myName = UnitName("player") or ""
    if myRealm ~= "" then
        for _, km in pairs(WoWKillboardDB.kills) do
            if type(km) == "table" and (not km.realm or km.realm == "" or km.realm == "Unknown") then
                local kName = (km.killer and km.killer.name) or ""
                local vName = (km.victim and km.victim.name) or ""
                local kRealm = (km.killer and km.killer.realm) or ""
                local vRealm = (km.victim and km.victim.realm) or ""
                if (myName ~= "" and (kName:lower() == myName:lower() or vName:lower() == myName:lower())) then
                    km.realm = myRealm
                    km.ruleset = myRuleset
                    if km.killer and (not km.killer.realm or km.killer.realm == "") then km.killer.realm = myRealm end
                    if km.victim and (not km.victim.realm or km.victim.realm == "") then km.victim.realm = myRealm end
                elseif kRealm ~= "" and kRealm ~= "Unknown" then
                    km.realm = kRealm
                    km.ruleset = km.ruleset or myRuleset
                elseif vRealm ~= "" and vRealm ~= "Unknown" then
                    km.realm = vRealm
                    km.ruleset = km.ruleset or myRuleset
                end
            end
        end
        for _, pd in pairs(WoWKillboardDB.pveDeaths) do
            if type(pd) == "table" and (not pd.realm or pd.realm == "" or pd.realm == "Unknown") then
                local vRealm = (pd.victim and pd.victim.realm) or ""
                if vRealm ~= "" and vRealm ~= "Unknown" then
                    pd.realm = vRealm
                    pd.ruleset = pd.ruleset or myRuleset or "PVE"
                else
                    pd.realm = myRealm
                    pd.ruleset = pd.ruleset or myRuleset or "PVE"
                    if pd.victim and (not pd.victim.realm or pd.victim.realm == "" or pd.victim.realm == "Unknown") then
                        pd.victim.realm = myRealm
                    end
                end
            end
        end
    end

    -- Two-Way Sync Realm Data Linking & Player Historical Merge
    KB:SyncRealmData()

    WoWKillboardSettings = WoWKillboardSettings or {}
    for k, v in pairs(KB.DefaultSettings) do
        if WoWKillboardSettings[k] == nil then
            WoWKillboardSettings[k] = v
        end
    end

    -- Default Theme Migration: ensure all upgraded clients display the new ElvUI specification
    if not WoWKillboardSettings.hasMigratedToElvUI then
        WoWKillboardSettings.theme = "elvui"
        WoWKillboardSettings.hasMigratedToElvUI = true
    end

    WoWKillboardBounties = WoWKillboardBounties or {}
    WoWKillboardDebtLedger = WoWKillboardDebtLedger or {}

    -- Self-Healing Kill History Sanitizer (Corrects victim self-insertion & assists in RAM)
    KB:SanitizeKillHistory()

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

    -- Pre-allocate overlay frames outside combat (Guardrail 1 Compliant)
    if KB.UI and KB.UI.InitHUDs then
        KB.UI:InitHUDs()
    end

    SafePrint(string.format("|cff00ccff[WKB]|r |cffffd100WoW Killboard v%s|r loaded. Type |cffffd100/kb|r to open dashboard or |cffffd100/kb help|r for commands.", KB.Version))
    SafePrint("|cff00ff66[Sync]|r Upload your kills at |cffffff00wowkillboard.com/upload|r (or download the auto-sync companion).")
end

-- Slash Commands (Support /killboard, /wowkb, and /kb)
SLASH_WOWKILLBOARD1 = "/killboard"
SLASH_WOWKILLBOARD2 = "/wowkb"
SLASH_WOWKILLBOARD3 = "/kb"

SlashCmdList["WOWKILLBOARD"] = function(msg)
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    cmd = cmd and cmd:lower() or ""

    if cmd == "" then
        KB:SyncRealmData()
        if KB.UI then KB.UI:Toggle() end
    elseif cmd == "reset" then
        if InCombatLockdown and InCombatLockdown() then
            SafePrint("|cffff9900[WKB]|r Cannot reset database during combat.")
            return
        end
        if arg ~= "confirm" then
            SafePrint("|cffff3333[WoWKB Warning]|r Resetting will wipe all local unsynced kills, duels, and combat stats.")
            SafePrint("  To permanently reset local records, type: |cffffd100/kb reset confirm|r")
            return
        end
        WoWKillboardDB = { kills = {}, stats = {}, pveDeaths = {} }
        WoWKillboardDebtLedger = {}
        WoWKillboardBounties = {}
        WoWKillboardDistress = {}
        WoWKillboardEvents = {}
        if WoWKillboard_RealmData then
            WoWKillboard_RealmData.RecentKills = {}
            WoWKillboard_RealmData.RecentPveDeaths = {}
            WoWKillboard_RealmData.Bounties = {}
            WoWKillboard_RealmData.RealmTotalCarnage = 0
            WoWKillboard_RealmData.SoloRatio = 0
            WoWKillboard_RealmData.DeadliestZones = {}
            WoWKillboard_RealmData.TopGankers24h = {}
            WoWKillboard_RealmData.PveTotalDeaths = 0
            WoWKillboard_RealmData.PveTopExecutioners = {}
            WoWKillboard_RealmData.PveTopVictims = {}
        end
        if KB.CombatTracker and KB.CombatTracker.SessionStats then
            KB.CombatTracker.SessionStats.kills = 0
            KB.CombatTracker.SessionStats.deaths = 0
            KB.CombatTracker.SessionStats.damageDone = 0
            KB.CombatTracker.SessionStats.healingDone = 0
        end
        if KB.Leaderboard and KB.Leaderboard.Rebuild then KB.Leaderboard:Rebuild() end
        if KB.UI and KB.UI.RefreshIfVisible then KB.UI:RefreshIfVisible() end
        SafePrint("|cff00ff00[WKB]|r Complete local database, bounties, distress beacons, and cached realm statistics reset to 0.")
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
        SafePrint(string.format("|cff00ccff[WoWKB Stats]|r Kills: |cff00ff00%d|r | Deaths: |cffff3333%d|r | K/D: |cffffd100%s|r | Dmg: |cffff7700%s|r | Heal: |cff00ff66%s|r",
            s.kills, s.deaths, kd, KB.Utils.FormatNumber(s.damageDone), KB.Utils.FormatNumber(s.healingDone)))
        SafePrint(string.format("  |cffffd700Duels (1v1):|r %dW - %dL | |cff00ccffBattlegrounds:|r %dW - %dL | |cffa335eeArenas:|r %dW - %dL", dW, dL, bgW, bgL, aW, aL))
    elseif cmd == "bounty" then
        local target, gold = arg:match("^(%S+)%s+(%d+)$")
        if target and gold then
            KB.BountyEngine:PlaceBounty(target, "UNKNOWN", "Unknown", tonumber(gold))
        else
            SafePrint("|cffff9900Usage:|r /killboard bounty <TargetName> <GoldAmount> (e.g. /killboard bounty Thrall 250)")
        end
    elseif cmd == "backup" or cmd == "sos" or cmd == "warhorn" or cmd == "calltoarms" then
        if arg == "stop" or arg == "resolve" or arg == "clear" or arg == "off" then
            if KB.Reinforcements then KB.Reinforcements:ResolveBeacon(false) end
        else
            if KB.Reinforcements then KB.Reinforcements:TriggerCallForBackup() end
        end
    elseif cmd == "manhunt" or cmd == "rally" then
        if KB.UI then
            KB.UI:ShowTab("RALLIES")
            if arg and arg ~= "" and KB.UI.ShowRallyDialog then
                KB.UI:ShowRallyDialog()
            end
        end
    elseif cmd == "event" then
        if (not arg or arg == "") and KB.UI and KB.UI.ShowRallyDialog then
            KB.UI:ShowRallyDialog()
            return
        end
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
            local s = WoWKillboardSettings or (KB.DefaultSettings or {})
            if IsInGuild() and (s.enableGuildBroadcasts ~= false) then
                SendChatMessage(string.format("[WoWKB Alert] Event scheduled: %s in %s. Time: %s. Lead: %s.",
                    evt.title, evt.zone, evt.time_str, myName), "GUILD")
            end
            SafePrint(string.format("|cff00ccff[WoWKB Event]|r Created Guild Rally: |cffffd100%s|r in |cffffffff%s|r!", evt.title, evt.zone))
        else
            SafePrint("|cffff9900Usage:|r /killboard event <Title> | <Zone> | <Time> (e.g. /killboard event STV Defense | Stranglethorn Vale | 8:00 PM EST)")
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
            SafePrint(string.format("|cffff0000[WoWKB KOS]|r Added |cffffd100%s|r to KOS Blacklist.", entity))
        elseif action == "remove" and entity ~= "" then
            WoWKillboardDB.kosGuilds[entity] = nil
            WoWKillboardDB.kosPlayers[entity] = nil
            WoWKillboardDB.kosDeserters[entity] = nil
            SafePrint(string.format("|cff00ff00[WoWKB KOS]|r Removed |cffffd100%s|r from KOS Blacklist.", entity))
        else
            SafePrint("|cffff0000[WoWKB Realm KOS Blacklist & Deserters]:|r")
            local count = 0
            for g, d in pairs(WoWKillboardDB.kosGuilds) do
                SafePrint(string.format("  - Guild: |cffff5555<%s>|r (%s)", g, d.reason or "KOS"))
                count = count + 1
            end
            for dName, dInfo in pairs(WoWKillboardDB.kosDeserters) do
                SafePrint(string.format("  - Deserter: |cffff5555%s|r (Ex-<%s>)", dName, dInfo.former_guild or "None"))
                count = count + 1
            end
            if count == 0 then SafePrint("  (No active KOS blacklist targets)") end
        end
    elseif cmd == "sync" or cmd == "reload" then
        WoWKillboardDB = WoWKillboardDB or {}
        WoWKillboardDB.lastManualSync = time()
        SafePrint("|cff00ccff[WoWKB]|r Flushed combat SavedVariables to disk. Reloading UI to sync with live web platform...")
        ReloadUI()
    elseif cmd == "move" or cmd == "unlock" or cmd == "preview" then
        if KB.UI and KB.UI.ToggleBannerLock then
            KB.UI:ToggleBannerLock()
        end
    elseif cmd == "test" then
        local subArg = (arg or ""):lower():match("^%s*(.-)%s*$")
        if subArg:find("broadcast") or subArg:find("net") or subArg:find("party") or subArg:find("channel") then
            local mode = (subArg:find("pvp") or subArg:find("player") or subArg:find("death")) and "pvp" or "pve"
            if KB.Sync and KB.Sync.BroadcastTestCasualty then
                KB.Sync:BroadcastTestCasualty(mode)
            end
        elseif KB.UI and KB.UI.TestKillBanner then
            KB.UI:TestKillBanner(arg)
        end
    elseif cmd == "testparty" or cmd == "testnet" or cmd == "testbroadcast" then
        local subArg = (arg or ""):lower():match("^%s*(.-)%s*$")
        if subArg == "chat" or subArg == "format" or subArg == "formats" then
            local pName = UnitName("player") or "Dagariane"
            local _, pClass = UnitClass("player")
            pClass = pClass or "PALADIN"
            local pLevel = UnitLevel("player") or 23
            local cTitle = (KB.Utils and KB.Utils.GetClassTitle) and KB.Utils.GetClassTitle(pClass) or "Paladin"
            local loc = (KB.Utils and KB.Utils.GetPlayerLocation) and KB.Utils.GetPlayerLocation() or { zone = "Stormwind City", subZone = "Sentinel Hill", x = 66.7, y = 42.4 }
            local zone = (loc.zone and loc.zone ~= "" and loc.zone ~= "Unknown Zone") and loc.zone or "Stormwind City"
            local subzone = (loc.subZone and loc.subZone ~= "") and loc.subZone or "Sentinel Hill"
            local x = (loc.x and loc.x > 0) and loc.x or 66.7
            local y = (loc.y and loc.y > 0) and loc.y or 42.4

            SafePrint("|cffffd100[WoWKB]|r --- Standardized Military/Tactical Chat Telemetry ---")
            SafePrint(string.format("|cff00e5ff[Format A - Local/Yell]:|r [WoWKB] Under attack: %s (%.1f, %.1f) vs Defias Pillager!", zone, x, y))
            SafePrint(string.format("|cff00e5ff[Format B - Guild/Party]:|r [WoWKB] PvP Alert: %s engaged in %s (%.1f, %.1f) by 1 Hostile. Auto-invite: whisper 'invite'", pName, zone, x, y))
            SafePrint(string.format("|cff00e5ff[Format C - Casualty]:|r [WoWKB] Casualty: %s (Lvl %d %s) killed by Defias Pillager (Fireball) in %s.", pName, pLevel, cTitle, subzone))
        else
            local targetPeer = nil
            local mode = "pve"
            if subArg and subArg ~= "" then
                local first, rest = subArg:match("^(%S+)%s*(.*)$")
                if first == "pvp" or first == "player" or first == "death" then
                    mode = "pvp"
                    if rest and rest ~= "" then targetPeer = rest end
                elseif first == "pve" or first == "npc" or first == "mob" then
                    mode = "pve"
                    if rest and rest ~= "" then targetPeer = rest end
                else
                    targetPeer = subArg
                end
            end
            if KB.Sync and KB.Sync.BroadcastTestCasualty then
                KB.Sync:BroadcastTestCasualty(mode, targetPeer)
            end
        end
    elseif cmd == "announce" or cmd == "alert" then
        if not arg or arg:match("^%s*$") then
            if KB.UI and KB.UI.ShowAnnouncementModal then
                KB.UI:ShowAnnouncementModal()
            else
                SafePrint("|cffff3333[WoWKB]|r Usage: /kb announce <message>  (e.g., /kb announce Update v1.0.4 releasing in 10 minutes!)")
            end
        else
            if KB.Sync and KB.Sync.BroadcastAdminAlert then
                KB.Sync:BroadcastAdminAlert(arg, "UPDATE")
            end
        end
    elseif cmd == "update" then
        if not arg or arg:match("^%s*$") then
            if KB.UI and KB.UI.ShowAnnouncementModal then
                KB.UI:ShowAnnouncementModal()
            else
                SafePrint("|cffff3333[WoWKB]|r Usage: /kb update <minutes> [notes]  (e.g., /kb update 10 or /kb update 5 server reboot)")
            end
        else
            local mins, extra = arg:match("^(%d+)%s*(.*)$")
            local alertMsg
            if mins then
                local extraText = (extra and extra ~= "") and string.format(" (%s)", extra) or ""
                alertMsg = string.format("Addon update releasing in %s minute(s)%s. Please save combat logs and prepare to /reload or update via CurseForge/GitHub.", mins, extraText)
            else
                alertMsg = arg
            end
            if KB.Sync and KB.Sync.BroadcastAdminAlert then
                KB.Sync:BroadcastAdminAlert(alertMsg, "UPDATE")
            end
        end
    elseif cmd == "broadcast" then
        if arg and not arg:match("^%s*$") then
            if KB.Sync and KB.Sync.BroadcastAdminAlert then
                KB.Sync:BroadcastAdminAlert(arg, "UPDATE")
            end
        else
            local s = WoWKillboardSettings or (KB.DefaultSettings or {})
            s.enableChatBroadcasts = not s.enableChatBroadcasts
            SafePrint(string.format("|cff00e5ff[WoWKB]|r Chat Broadcasts (Yell/Say): %s. (Tip: Use |cffffd100/kb announce <msg>|r or |cffffd100/kb update <mins>|r to broadcast realm announcements).", s.enableChatBroadcasts and "|cff00ff00ENABLED|r" or "|cffff3333DISABLED (Opt-in)|r"))
        end
    elseif cmd == "chat" then
        local s = WoWKillboardSettings or (KB.DefaultSettings or {})
        s.enableChatBroadcasts = not s.enableChatBroadcasts
        SafePrint(string.format("|cff00e5ff[WoWKB]|r Chat Broadcasts (Yell/Say): %s.", s.enableChatBroadcasts and "|cff00ff00ENABLED|r" or "|cffff3333DISABLED (Opt-in)|r"))
    elseif cmd == "channel" then
        local sub = (arg or ""):lower():match("^%s*(.-)%s*$")
        local s = WoWKillboardSettings or (KB.DefaultSettings or {})
        if sub == "show" or sub == "on" or sub == "enable" then
            s.showChannelInChat = true
        elseif sub == "hide" or sub == "off" or sub == "disable" then
            s.showChannelInChat = false
        else
            s.showChannelInChat = not s.showChannelInChat
        end
        if KB.db and KB.db.settings then KB.db.settings.showChannelInChat = s.showChannelInChat end
        if KB.Sync and KB.Sync.ApplyChatVisibility then KB.Sync:ApplyChatVisibility() end
        if s.showChannelInChat then
            SafePrint("|cff00e5ff[WoWKB]|r Casualty Feed in Chat: |cff00ff00ENABLED|r. The '|cffffd100WoWKillboard|r' channel is now streaming to your chat window.")
        else
            SafePrint("|cff00e5ff[WoWKB]|r Casualty Feed in Chat: |cffff3333HIDDEN|r. The '|cffffd100WoWKillboard|r' channel has been detached from your chat frames for quiet play.")
        end
    elseif cmd == "stream" or cmd == "delivery" then
        local sub = (arg or ""):lower():match("^%s*(.-)%s*$")
        local s = WoWKillboardSettings or (KB.DefaultSettings or {})
        if sub == "both" or sub == "dual" or sub == "all" then
            s.showChannelInChat = true
            s.alertMode = "SOUND_AND_BANNER"
            s.soundAlerts = true
            SafePrint("|cff00e5ff[WoWKB Delivery]|r Preset: |cff00ff00Both (Heads-Up + Live Chat Stream)|r. Visual banners, audio warhorn, and chat log active.")
        elseif sub == "chat" or sub == "silent" or sub == "log" then
            s.showChannelInChat = true
            s.alertMode = "OFF"
            s.soundAlerts = false
            SafePrint("|cff00e5ff[WoWKB Delivery]|r Preset: |cffffd100Silent Chat Stream Only|r. Casualties stream into your chat window without screen banners or audio horns.")
        elseif sub == "banner" or sub == "headsup" or sub == "toast" or sub == "clean" then
            s.showChannelInChat = false
            s.alertMode = "SOUND_AND_BANNER"
            s.soundAlerts = true
            SafePrint("|cff00e5ff[WoWKB Delivery]|r Preset: |cff00e5ffHeads-Up Banner Only|r. Visual banners and audio active; chat windows remain clean.")
        elseif sub == "off" or sub == "mute" or sub == "none" then
            s.showChannelInChat = false
            s.alertMode = "OFF"
            s.soundAlerts = false
            SafePrint("|cff00e5ff[WoWKB Delivery]|r Preset: |cffff3333All Alerts Muted|r. Banners and chat feed suppressed. Combat logged silently.")
        else
            SafePrint("|cffff9900Usage:|r /kb stream [both | chat | banner | off]  (or /kb channel [show | hide])")
        end
        if KB.db and KB.db.settings then
            KB.db.settings.showChannelInChat = s.showChannelInChat
            KB.db.settings.alertMode = s.alertMode
            KB.db.settings.soundAlerts = s.soundAlerts
        end
        if KB.Sync and KB.Sync.ApplyChatVisibility then KB.Sync:ApplyChatVisibility() end
    elseif cmd == "guild" then
        local s = WoWKillboardSettings or (KB.DefaultSettings or {})
        s.enableGuildBroadcasts = (s.enableGuildBroadcasts == false)
        SafePrint(string.format("|cff00e5ff[WoWKB]|r Guild Broadcasts: %s.", s.enableGuildBroadcasts and "|cff00ff00ENABLED|r" or "|cffff3333DISABLED|r"))
    elseif cmd == "coords" then
        local s = WoWKillboardSettings or (KB.DefaultSettings or {})
        s.includeCoordinates = (s.includeCoordinates == false)
        SafePrint(string.format("|cff00e5ff[WoWKB]|r Include Coordinates: %s.", s.includeCoordinates and "|cff00ff00ENABLED|r" or "|cffff3333DISABLED|r"))
    elseif cmd == "autoinvite" then
        local s = WoWKillboardSettings or (KB.DefaultSettings or {})
        s.enableWhisperAutoInvite = (s.enableWhisperAutoInvite == false)
        SafePrint(string.format("|cff00e5ff[WoWKB]|r Whisper Auto-Invite: %s.", s.enableWhisperAutoInvite and "|cff00ff00ENABLED|r" or "|cffff3333DISABLED|r"))
    elseif cmd == "theme" then
        if KB.UI and KB.UI.CycleTheme then
            KB.UI:CycleTheme()
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
            if tName and KB.Utils.CanAccess(tName) and tName ~= "" then
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
            finalSpell = (pClass == "PALADIN") and "Judgement" or ((pClass == "ROGUE") and "Eviscerate" or "Mortal Strike"),
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
        SafePrint(string.format("|cff00ff00[WoWKB]|r Generated synthetic Open-World PvP Kill against |cffff3333%s|r in %s!", enemyName, loc.zone))

    elseif cmd == "stress" or cmd == "stresstest" then
        local count = tonumber(arg) or 25
        if count < 1 then count = 1 end
        if count > 250 then count = 250 end

        local startTime = (debugprofilestop and debugprofilestop()) or (GetTime() * 1000)
        local initialMem = collectgarbage("count")

        local pName = UnitName("player") or "Hero"
        local _, pClass = UnitClass("player")
        pClass = pClass or "WARRIOR"
        local pLevel = UnitLevel("player") or 60
        local pGuild = GetGuildInfo("player") or "Ironclad Vanguard"
        local pFaction = UnitFactionGroup("player") or "Alliance"

        local enemyFaction = (pFaction == "Alliance") and "Horde" or "Alliance"
        local classes = {"WARRIOR", "ROGUE", "MAGE", "PRIEST", "WARLOCK", "HUNTER", "DRUID", "SHAMAN", "PALADIN"}
        local races = (enemyFaction == "Horde") and {"Orc", "Undead", "Tauren", "Troll"} or {"Human", "Dwarf", "NightElf", "Gnome"}
        local zones = {
            { mapId = 1421, zone = "Silverpine Forest", subZone = "The Sepulcher", x = 43.5, y = 40.2 },
            { mapId = 1424, zone = "Hillsbrad Foothills", subZone = "Southshore", x = 50.1, y = 57.4 },
            { mapId = 1417, zone = "Arathi Highlands", subZone = "Refuge Pointe", x = 46.8, y = 45.2 },
            { mapId = 1448, zone = "Stranglethorn Vale", subZone = "Booty Bay", x = 27.4, y = 77.1 },
            { mapId = 1445, zone = "Blackrock Mountain", subZone = "Blackrock Spire", x = 48.0, y = 35.0 },
        }
        local names = {"Grimclaw", "Shadowstrike", "Bloodhoof", "Voidwhisper", "Ironhide", "Frostweaver", "Deathbringer", "Nightstalker", "Sunstrider", "Stormherald"}

        local injected = 0
        local now = time()
        for i = 1, count do
            local eClass = classes[((i - 1) % #classes) + 1]
            local eRace = races[((i - 1) % #races) + 1]
            local loc = zones[((i - 1) % #zones) + 1]
            local baseName = names[((i - 1) % #names) + 1]
            local eName = baseName .. "-" .. tostring(i)
            local eGuid = string.format("Player-STRESS-%d-%d", now, i)
            local dmgAmount = math.random(800, 3500)

            local testKill = {
                timestamp = now - (count - i) * 15,
                isSolo = (i % 2 == 1),
                isBattleground = (i % 5 == 0),
                isArena = false,
                isDuel = false,
                attackersCount = (i % 2 == 1) and 1 or math.random(2, 4),
                totalDamage = dmgAmount,
                finalSpell = (pClass == "MAGE" and "Pyroblast") or (pClass == "ROGUE" and "Eviscerate") or (pClass == "WARLOCK" and "Shadow Bolt") or (pClass == "HUNTER" and "Aimed Shot") or (pClass == "DRUID" and "Starfire") or (pClass == "PRIEST" and "Mind Blast") or (pClass == "SHAMAN" and "Chain Lightning") or (pClass == "PALADIN" and "Judgment") or "Mortal Strike",
                killer = {
                    guid = UnitGUID("player") or "Player-0001",
                    name = pName,
                    level = pLevel,
                    class = pClass,
                    guild = pGuild,
                    faction = pFaction,
                    partySize = 1,
                    damageDone = dmgAmount,
                    healingDone = math.floor(dmgAmount * 0.2),
                },
                victim = {
                    guid = eGuid,
                    name = eName,
                    level = math.random(55, 60),
                    class = eClass,
                    race = eRace,
                    guild = "Syndicate",
                    faction = enemyFaction,
                    partySize = 1,
                },
                location = {
                    mapId = loc.mapId,
                    zone = loc.zone,
                    subZone = loc.subZone,
                    x = loc.x + (math.random(-50, 50) / 100),
                    y = loc.y + (math.random(-50, 50) / 100),
                },
                attackers = {
                    {
                        guid = UnitGUID("player") or "Player-0001",
                        name = pName,
                        class = pClass,
                        level = pLevel,
                        guild = pGuild,
                        faction = pFaction,
                        damage = dmgAmount,
                        spell = "Attack",
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
                injected = injected + 1
            end
        end

        if KB.UI and KB.UI.TestKillBanner and injected > 0 then
            KB.UI:TestKillBanner()
        end

        local endTime = (debugprofilestop and debugprofilestop()) or (GetTime() * 1000)
        local elapsed = endTime - startTime
        local finalMem = collectgarbage("count")
        local memDelta = finalMem - initialMem
        local totalKills = 0
        if WoWKillboardDB and WoWKillboardDB.kills then
            for _ in pairs(WoWKillboardDB.kills) do totalKills = totalKills + 1 end
        end

        SafePrint(string.format("|cff00ff00[WoWKB Stress]|r Injected |cffffd100%d|r kills in |cffffffff%.2f ms|r. Total DB: |cff00ccff%d|r kills. Addon Mem: |cffffffff%.1f KB|r (+%.1f KB). Zero UI taint.",
            injected, elapsed, totalKills, finalMem, memDelta))
        SafePrint("  Use |cffffd100/kb|r to view your feed or |cffffd100/kb reset confirm|r to purge stress records.")

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
            finalSpell = (enemyClass == "MAGE" and "Pyroblast") or "Shadow Bolt",
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

        if KB.UI and KB.UI.ShowKillBanner then
            KB.UI:ShowKillBanner(testDeath, true)
        end
        if KB.UI and KB.UI.ShowDeathBountyPrompt then
            KB.UI:ShowDeathBountyPrompt(testDeath.killer)
        end
        SafePrint(string.format("|cffff3333[WoWKB]|r Simulated PvP death against |cffffd100%s|r! Death alert and bounty prompt engaged.", enemyName))
    elseif cmd == "radar" or cmd == "hud" then
        if KB.UI and KB.UI.ToggleRadarHUD then
            KB.UI:ToggleRadarHUD()
        end
    elseif cmd == "wire" or cmd == "feed" then
        if KB.UI and KB.UI.ToggleCombatWire then
            KB.UI:ToggleCombatWire()
        end
    elseif cmd == "alerts" or cmd == "alert" or cmd == "config" then
        if KB.UI and KB.UI.ShowAlertsConfig then
            KB.UI:ShowAlertsConfig()
        end
    elseif cmd == "toast" or cmd == "toasts" then
        local tArg = arg and arg:lower():match("^%s*(.-)%s*$") or ""
        WoWKillboardSettings = WoWKillboardSettings or {}
        if tArg == "off" or tArg == "disable" or tArg == "0" then
            WoWKillboardSettings.alertMode = "OFF"
            SafePrint("|cffff3333[WoWKB]|r Combat alerts and toasts: |cffff3333OFF|r. Use |cffffd100/kb toast on|r or |cffffd100/kb unmute|r to re-enable.")
        elseif tArg == "on" or tArg == "enable" or tArg == "1" then
            WoWKillboardSettings.alertMode = "SOUND_AND_BANNER"
            SafePrint("|cff00ff00[WoWKB]|r Combat alerts and toasts: |cff00ff00Sound + Banner Enabled|r.")
        elseif tArg == "mute" or tArg == "silent" then
            WoWKillboardSettings.alertMode = "BANNER_ONLY"
            SafePrint("|cffffd100[WoWKB]|r Combat toasts set to silent (|cffffd100Banner Only|r, audio muted).")
        elseif tArg == "mine" or tArg == "solo" then
            WoWKillboardSettings.alertScope = "MINE"
            SafePrint("|cff00ff00[WoWKB]|r Toast scope set to |cffffd100Personal Only|r (only shows your own kills and deaths).")
        elseif tArg == "zone" then
            WoWKillboardSettings.alertScope = "ZONE"
            SafePrint("|cff00ff00[WoWKB]|r Toast scope set to |cffffd100Current Zone|r (filters out combat from other zones).")
        elseif tArg == "all" or tArg == "realm" or tArg == "hardcore" then
            WoWKillboardSettings.alertScope = "ALL"
            SafePrint("|cff00ff00[WoWKB]|r Toast scope set to |cffffd100Entire Realm|r (Hardcore broadcast mode: alerts for all realm kills).")
        elseif tArg == "test" or tArg == "pvp" or tArg == "kill" then
            if KB.UI and KB.UI.TestKillBanner then
                KB.UI:TestKillBanner(tArg)
            end
        elseif tArg == "testdeath" or tArg == "death" then
            if KB.UI and KB.UI.TestKillBanner then
                KB.UI:TestKillBanner("death")
            end
        elseif tArg == "testpve" or tArg == "pve" then
            if KB.UI and KB.UI.TestKillBanner then
                KB.UI:TestKillBanner("pve")
            end
        elseif tArg == "move" or tArg == "unlock" or tArg == "preview" then
            if KB.UI and KB.UI.ToggleBannerLock then
                KB.UI:ToggleBannerLock()
            end
        else
            local curMode = WoWKillboardSettings.alertMode or "SOUND_AND_BANNER"
            local curScope = WoWKillboardSettings.alertScope or "ZONE"
            if curMode == "OFF" then
                WoWKillboardSettings.alertMode = "SOUND_AND_BANNER"
                SafePrint(string.format("|cff00ff00[WoWKB]|r Toasts toggled |cff00ff00ON|r (Sound + Banner) | Scope: |cffffd100%s|r.", curScope))
            else
                WoWKillboardSettings.alertMode = "OFF"
                SafePrint(string.format("|cffff3333[WoWKB]|r Toasts toggled |cffff3333OFF|r | Scope: |cffffd100%s|r.", curScope))
            end
            SafePrint("  |cff94a3b8Quick Commands: /kb toast [on|off|mute|mine|zone|all|test|move] or /kb alerts|r")
        end
        if KB.UI and KB.UI.AlertsDialog and KB.UI.AlertsDialog.UpdateControls then
            KB.UI.AlertsDialog:UpdateControls()
        end
    elseif cmd == "mute" or cmd == "silence" then
        WoWKillboardSettings = WoWKillboardSettings or {}
        local curMode = WoWKillboardSettings.alertMode or "SOUND_AND_BANNER"
        if curMode == "OFF" then
            WoWKillboardSettings.alertMode = "SOUND_AND_BANNER"
            SafePrint("|cff00ff00[WoWKB]|r Combat alerts and toasts unmuted (|cff00ff00ON|r).")
        else
            WoWKillboardSettings.alertMode = "OFF"
            SafePrint("|cffff3333[WoWKB]|r Combat alerts and toasts muted (|cffff3333OFF|r). Type |cffffd100/kb unmute|r or |cffffd100/kb mute|r to toggle.")
        end
        if KB.UI and KB.UI.AlertsDialog and KB.UI.AlertsDialog.UpdateControls then
            KB.UI.AlertsDialog:UpdateControls()
        end
    elseif cmd == "unmute" then
        WoWKillboardSettings = WoWKillboardSettings or {}
        WoWKillboardSettings.alertMode = "SOUND_AND_BANNER"
        SafePrint("|cff00ff00[WoWKB]|r Combat alerts and toasts unmuted (|cff00ff00Sound + Banner Enabled|r).")
        if KB.UI and KB.UI.AlertsDialog and KB.UI.AlertsDialog.UpdateControls then
            KB.UI.AlertsDialog:UpdateControls()
        end
    elseif cmd == "armory" then
        KB:PrintArmoryDossier(arg)
    elseif cmd == "export" then
        if KB.UI and KB.UI.ShowExportDialog then
            KB.UI:ShowExportDialog()
        end
    elseif cmd == "markprompt" or cmd == "bountyprompt" then
        local mArg = arg and arg:lower():match("^%s*(.-)%s*$") or ""
        WoWKillboardSettings = WoWKillboardSettings or {}
        if mArg == "off" or mArg == "disable" or mArg == "0" then
            WoWKillboardSettings.promptMarkOnDeath = false
            WoWKillboardSettings.promptBountyOnDeath = false
            SafePrint("|cffff3333[WoWKB]|r Mark of Spite death popup: |cffff3333Disabled|r.")
        elseif mArg == "on" or mArg == "enable" or mArg == "1" then
            WoWKillboardSettings.promptMarkOnDeath = true
            WoWKillboardSettings.promptBountyOnDeath = true
            SafePrint("|cff00ff00[WoWKB]|r Mark of Spite death popup: |cff00ff00Enabled|r.")
        else
            local cur = (WoWKillboardSettings.promptMarkOnDeath ~= false and WoWKillboardSettings.promptBountyOnDeath ~= false)
            local nxt = not cur
            WoWKillboardSettings.promptMarkOnDeath = nxt
            WoWKillboardSettings.promptBountyOnDeath = nxt
            local st = nxt and "|cff00ff00Enabled|r" or "|cffff3333Disabled|r"
            SafePrint(string.format("|cff00ccff[WoWKB]|r Mark of Spite death popup toggled to: %s", st))
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
            SafePrint(string.format("|cff00ff00[WoWKB]|r Claim verification token registered for |cffffd100%s|r: |cffffff00%s|r.", pName, code))
            SafePrint("|cff00ccff[WoWKB]|r Type |cffffd100/reload|r to flush to disk and lock ownership immediately.")
        else
            SafePrint("|cffff9900Usage:|r /kb claim <code> (e.g. /kb claim KB-7842)")
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
    elseif cmd == "profile" or cmd == "web" or cmd == "url" or cmd == "link" then
        local pTarget = arg and arg:match("^%s*(.-)%s*$")
        if not pTarget or pTarget == "" then
            pTarget = (UnitExists("target") and UnitIsPlayer("target")) and (UnitName("target")) or (UnitName("player"))
        end
        if KB.UI and KB.UI.ShowCharacterWebLink then
            KB.UI:ShowCharacterWebLink(pTarget)
        end
    elseif cmd == "welcome" or cmd == "beta" or cmd == "about" then
        if KB.UI and KB.UI.ShowWelcomeModal then
            KB.UI:ShowWelcomeModal(true)
        end
    elseif cmd == "feedback" then
        local cleanArg = arg and arg:match("^%s*(.-)%s*$") or ""
        if cleanArg == "" then
            if KB.UI and KB.UI.ShowWelcomeModal then
                KB.UI:ShowWelcomeModal(true)
            elseif KB.UI and KB.UI.ShowBugReportModal then
                KB.UI:ShowBugReportModal()
            end
        else
            KB:SubmitBugReport(cleanArg)
        end
    elseif cmd == "bug" or cmd == "report" then
        local cleanArg = arg and arg:match("^%s*(.-)%s*$") or ""
        if cleanArg == "" then
            if KB.UI and KB.UI.ShowBugReportModal then
                KB.UI:ShowBugReportModal()
            else
                SafePrint("|cffff9900Usage:|r /kb bug <describe what happened> (e.g. /kb bug Kills not recording in Arathi Basin)")
            end
        else
            KB:SubmitBugReport(cleanArg)
        end
    elseif cmd == "promo" or cmd == "macro" or cmd == "macros" or cmd == "share" then
        if KB.UI and KB.UI.ShowPromoModal then
            KB.UI:ShowPromoModal()
        else
            local enemy = "the Horde"
            if UnitFactionGroup then
                local f = UnitFactionGroup("player")
                if f == "Alliance" then enemy = "the Horde" elseif f == "Horde" then enemy = "the Alliance" end
            end
            SafePrint("|cff00ccff[WoW Killboard] In-Game Chat Macros (search 'wkb' on CurseForge):|r")
            SafePrint(string.format("  |cffffd100[1. General/Zone]:|r /1 Hey if you like world pvp, check out 'wkb' on CurseForge. Tracks your kills and stats against %s (wowkillboard.com)", enemy))
            SafePrint("  |cffffd100[2. Post-Duel]:|r /s gg! Tracking duels and world pvp kills with 'wkb' on CurseForge (wowkillboard.com)")
            SafePrint("  |cffffd100[3. Guild/Squad]:|r /g Hey grab 'wkb' on CurseForge if you do world pvp. Tracks our kills, duels, and bounties in guild (wowkillboard.com)")
            SafePrint(string.format("  |cffffd100[4. World PvP]:|r /s Anyone hunting around here? Grab 'wkb' on CurseForge so we can track kills and bounties against %s (wowkillboard.com)", enemy))
            SafePrint("  |cff38bdf8[5. Direct Link]:|r Search \"wkb\" in CurseForge App or visit https://www.curseforge.com/wow/addons/wkb")
        end
    elseif cmd == "net" or cmd == "network" or cmd == "channel" then
        local chanId = (KB.Sync and KB.Sync.GetChannelId and KB.Sync:GetChannelId("WoWKillboard")) or nil
        local isChanConnected = (chanId and chanId > 0)
        local statusColor = isChanConnected and "|cff00ff00" or "|cffff3333"
        local statusText = isChanConnected and string.format("Connected (#%d, Hidden from Chat)", chanId) or "Connecting / Offline (rejoining...)"
        SafePrint("|cff00ccff[WoW Killboard] Realm Network Status:|r")
        SafePrint(string.format("  |cffffd100Realm Channel:|r %s%s|r", statusColor, statusText))
        SafePrint(string.format("  |cffffd100P2P Sync:|r %s", (KB.DefaultSettings and KB.DefaultSettings.p2pSyncEnabled) and "|cff00ff00Enabled|r" or "|cffff3333Disabled|r"))
        SafePrint("  |cffffd100Quick Test:|r Type |cffffff00/testnet|r to broadcast a casualty alert to any player on the realm.")
        if not isChanConnected and KB.Sync and KB.Sync.JoinGlobalChannel then
            KB.Sync:JoinGlobalChannel()
        end
    elseif cmd == "changelog" or cmd == "update" or cmd == "whatsnew" or cmd == "notes" then
        if KB.UI and KB.UI.ShowChangelogModal then
            KB.UI:ShowChangelogModal(true)
        end
    else
        SafePrint("|cff00ccffWoW Killboard: Frontline War Room Commands:|r")
        SafePrint("  |cffffd100/kb|r, |cffffd100/wowkb|r, or |cffffd100/killboard|r - Toggle the Frontline War Room Dashboard")
        SafePrint("  |cffffd100/kb net|r or |cffffd100/kb channel|r - Inspect Realm Network connection and channel state")
        SafePrint("  |cffffd100/kb changelog|r or |cffffd100/kb update|r - Open What's New & Version Changelog")
        SafePrint("  |cffffd100/kb promo|r or |cffffd100/kb macro|r - Open Promotional In-Game Macros & Community Sharing Hub")
        SafePrint("  |cffffd100/kb welcome|r or |cffffd100/kb beta|r - Open Early Preview & Feedback Guide")
        SafePrint("  |cffffd100/kb feedback|r or |cffffd100/kb bug|r - Submit feedback or report an issue")
        SafePrint("  |cffffd100/kb wire|r or |cffffd100/kb feed|r - Toggle The Shadow Network floating feed window")
        SafePrint("  |cffffd100/kb manhunt|r or |cffffd100/kb rally|r - Muster a Vanguard hunting squad")
        SafePrint("  |cffffd100/kb radar|r or |cffffd100/kbradar|r - Toggle the Tactical Radar HUD floating window")
        SafePrint("  |cffffd100/kb alerts|r - Open Combat Alerts & Radar Configuration")
        SafePrint("  |cffffd100/kb toast [on|off|mute|mine|zone|all]|r - Configure or toggle on-screen kill/death toast alerts")
        SafePrint("  |cffffd100/kb mute|r or |cffffd100/kbmute|r - Quickly silence / unmute combat toasts")
        SafePrint("  |cffffd100/kb markprompt [on|off]|r - Toggle Mark of Spite revenge prompt on PvP death")
        SafePrint("  |cffffd100/kb claim <code>|r - Register web character ownership verification code")
        SafePrint("  |cffffd100/kb export|r - Open in-game combat export window")
        SafePrint("  |cffffd100/kb move|r - Unlock or lock Kill Banner to reposition on screen")
        SafePrint("  |cffffd100/kb test [kill|death|pvp|pve]|r - Preview Kill Alert Banner locally")
        SafePrint("  |cffffd100/kb test broadcast [pve|pvp]|r or |cffffd100/kb testnet|r - Broadcast simulated casualty to Party & Realm Channel (zero DB write)")
        SafePrint("  |cffffd100/kb announce <message>|r - Broadcast custom alert/announcement to Realm Channel & Party")
        SafePrint("  |cffffd100/kb update <minutes> [notes]|r - Broadcast scheduled update warning countdown across Realm Network")
        SafePrint("  |cffffd100/kb testkill|r - Simulate an Open-World PvP Kill (populates feed & stats)")
        SafePrint("  |cffffd100/kb testdeath|r - Simulate a PvP Death (prompts revenge blood bounty)")
        SafePrint("  |cffffd100/kb stress [N]|r - Stress test addon with N (default 25) simulated kills")
        SafePrint("  |cffffd100/kb armory [Name]|r or |cffffd100/armory [Name]|r - Inspect Champion Combat Profile")
        SafePrint("  |cffffd100/kb profile [Name]|r or |cffffd100/kb web|r - Open public web combat profile dialog")
        SafePrint("  |cffffd100/spot|r or |cffffd100/scout [notes]|r - Report and broadcast spotted enemy hostile to allies")
        SafePrint("  |cffffd100/warhorn|r or |cffffd100/kbsos|r - Sound the War Horn (Call to Arms & muster war party)")
        SafePrint("  |cffffd100/warhorn stop|r - Stand down War Horn and close recruitment")
        SafePrint("  |cffffd100/kb kos [add|remove|list]|r - View or manage realm KOS Blacklist")
        SafePrint("  |cffffd100/kb event <Title> | <Zone> | <Time>|r - Issue War Council Battle Order / Rally")
        SafePrint("  |cffffd100/kb theme [classic|elvui]|r - Switch between Classic WoW and ElvUI aesthetics")
        SafePrint("  |cffffd100/kb sync|r or |cffffd100/kb reload|r - Flush combat SavedVariables to disk to sync with website")
        SafePrint("  |cffffd100/kb stats|r - Review current combat session battle statistics")
        SafePrint("  |cffffd100/kb bounty <Name> <Gold>|r - Declare a blood bounty on an enemy player (Open World)")
        SafePrint("  |cffffd100/kb reset confirm|r - Clear local battle records")
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

SLASH_WOWKB_MUTE1 = "/kbmute"
SlashCmdList["WOWKB_MUTE"] = function()
    WoWKillboardSettings = WoWKillboardSettings or {}
    local curMode = WoWKillboardSettings.alertMode or "SOUND_AND_BANNER"
    if curMode == "OFF" then
        WoWKillboardSettings.alertMode = "SOUND_AND_BANNER"
        SafePrint("|cff00ff00[WoWKB]|r Combat alerts and toasts unmuted (|cff00ff00ON|r).")
    else
        WoWKillboardSettings.alertMode = "OFF"
        SafePrint("|cffff3333[WoWKB]|r Combat alerts and toasts muted (|cffff3333OFF|r). Type |cffffd100/kbmute|r again to unmute.")
    end
    if KB.UI and KB.UI.AlertsDialog and KB.UI.AlertsDialog.UpdateControls then
        KB.UI.AlertsDialog:UpdateControls()
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
        SafePrint("|cffff9900Usage:|r /killboard armory <CharacterName> (or target a player and type /armory)")
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

    SafePrint(string.format("|cff00e5ff[WoWKB Player Armory]|r |c%s%s|r (Lvl %d %s)%s - %s", colorHex, name, charLevel, charClass, guildPart, factionColor))
    SafePrint(string.format("  |cffffd700[Rank] Honor Rank:|r |cffffffff%s|r | |cff00ff00K/D:|r |cffffffff%s|r (|cff00ff00%d|r Kills / |cffff3333%d|r Deaths)",
        rankTitle, kd, killsCount, deathsCount))
    SafePrint(string.format("  |cff00e5ffSolo Kills:|r %d | |cffffd700Duels (1v1):|r %d | |cff3b82f6BGs:|r %d", soloCount, duelCount, bgCount))

    -- Check KOS Blacklist or Deserter status
    if WoWKillboardDB then
        if (WoWKillboardDB.kosGuilds and charGuild and WoWKillboardDB.kosGuilds[charGuild]) or (WoWKillboardDB.kosPlayers and WoWKillboardDB.kosPlayers[name]) then
            SafePrint("  |cffff0000[!] TARGET IS ON REALM KOS BLACKLIST! Execute on sight!|r")
        end
        if WoWKillboardDB.kosDeserters and WoWKillboardDB.kosDeserters[name] then
            SafePrint("  |cffffaa00[*] TARGET IS A MARKED GUILD-HOP DESERTER!|r")
        end
    end

    -- Check Active Bounties
    if WoWKillboardBounties then
        for _, b in pairs(WoWKillboardBounties) do
            if b.target_name and b.target_name:lower() == name:lower() and b.status == "ACTIVE" then
                SafePrint(string.format("  |cffffd100[Bounty] ACTIVE BLOOD BOUNTY:|r %d Gold! Deliver the killing blow to collect!", b.amount_gold or 0))
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
SlashCmdList["WOWKILLBOARDSOS"] = function(msg)
    local arg = msg and msg:lower():trim() or ""
    if arg == "stop" or arg == "resolve" or arg == "clear" or arg == "off" then
        if KB.Reinforcements then KB.Reinforcements:ResolveBeacon(false) end
    else
        if KB.Reinforcements then KB.Reinforcements:TriggerCallForBackup() end
    end
end

-- Dedicated Quick-Slash Commands for Vanguard Manhunts
SLASH_WOWKB_MANHUNT1 = "/manhunt"
SLASH_WOWKB_MANHUNT2 = "/kbmanhunt"
SLASH_WOWKB_MANHUNT3 = "/kbrally"
SlashCmdList["WOWKB_MANHUNT"] = function(msg)
    if KB.UI then
        KB.UI:ShowTab("RALLIES")
        local arg = msg and msg:match("^%s*(.-)%s*$") or ""
        if arg ~= "" and KB.UI.ShowRallyDialog then
            KB.UI:ShowRallyDialog()
        end
    end
end

-- Dedicated Quick-Slash Commands for Early Beta Welcome & Feedback
SLASH_WOWKB_WELCOME1 = "/wowkbwelcome"
SLASH_WOWKB_WELCOME2 = "/kbwelcome"
SLASH_WOWKB_WELCOME3 = "/kbbeta"
SlashCmdList["WOWKB_WELCOME"] = function()
    if KB.UI and KB.UI.ShowWelcomeModal then
        KB.UI:ShowWelcomeModal(true)
    end
end

-- Dedicated Quick-Slash Commands for Changelog & Updates
SLASH_WOWKB_CHANGELOG1 = "/wowkbchangelog"
SLASH_WOWKB_CHANGELOG2 = "/kbchangelog"
SLASH_WOWKB_CHANGELOG3 = "/kbupdate"
SLASH_WOWKB_CHANGELOG4 = "/whatsnew"
SlashCmdList["WOWKB_CHANGELOG"] = function()
    if KB.UI and KB.UI.ShowChangelogModal then
        KB.UI:ShowChangelogModal(true)
    end
end

SLASH_WOWKB_FEEDBACK1 = "/wowkbfeedback"
SLASH_WOWKB_FEEDBACK2 = "/kbfeedback"
SlashCmdList["WOWKB_FEEDBACK"] = function(msg)
    local arg = msg and msg:match("^%s*(.-)%s*$") or ""
    if arg ~= "" then
        KB:SubmitBugReport(arg)
    else
        if KB.UI and KB.UI.ShowWelcomeModal then
            KB.UI:ShowWelcomeModal(true)
        elseif KB.UI and KB.UI.ShowBugReportModal then
            KB.UI:ShowBugReportModal()
        end
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
SlashCmdList["WOWKB_TEST"] = function(msg)
    if KB.UI and KB.UI.TestKillBanner then KB.UI:TestKillBanner(msg) end
end

SLASH_WOWKB_ALERTS1 = "/wowkbalerts"
SLASH_WOWKB_ALERTS2 = "/kbalerts"
SlashCmdList["WOWKB_ALERTS"] = function()
    if KB.UI and KB.UI.ShowAlertsConfig then KB.UI:ShowAlertsConfig() end
end

-- Dedicated Quick-Slash Commands for Network Broadcast Testing & Announcements
SLASH_WOWKB_TESTNET1 = "/kbtestnet"
SLASH_WOWKB_TESTNET2 = "/kbtestparty"
SLASH_WOWKB_TESTNET3 = "/testnet"
SlashCmdList["WOWKB_TESTNET"] = function(msg)
    local subArg = (msg or ""):match("^%s*(.-)%s*$")
    local mode = "pve"
    local targetPeer = nil
    if subArg and subArg ~= "" then
        local first, rest = subArg:match("^(%S+)%s*(.*)$")
        if first:lower() == "pvp" or first:lower() == "player" or first:lower() == "death" then
            mode = "pvp"
            if rest and rest ~= "" then targetPeer = rest end
        elseif first:lower() == "pve" or first:lower() == "npc" or first:lower() == "mob" then
            mode = "pve"
            if rest and rest ~= "" then targetPeer = rest end
        else
            targetPeer = subArg
        end
    end
    if KB.Sync and KB.Sync.BroadcastTestCasualty then
        KB.Sync:BroadcastTestCasualty(mode, targetPeer)
    end
end

SLASH_WOWKB_ANNOUNCE1 = "/kbannounce"
SLASH_WOWKB_ANNOUNCE2 = "/announce"
SlashCmdList["WOWKB_ANNOUNCE"] = function(msg)
    local clean = msg and msg:match("^%s*(.-)%s*$") or ""
    if clean == "" then
        if KB.UI and KB.UI.ShowAnnouncementModal then
            KB.UI:ShowAnnouncementModal()
        end
    else
        if KB.Sync and KB.Sync.BroadcastAdminAlert then
            KB.Sync:BroadcastAdminAlert(clean, "UPDATE")
        end
    end
end

SLASH_WOWKB_CHANNEL1 = "/kbchannel"
SlashCmdList["WOWKB_CHANNEL"] = function(msg)
    SlashCmdList["WOWKILLBOARD"]("channel " .. (msg or ""))
end

SLASH_WOWKB_STREAM1 = "/kbstream"
SlashCmdList["WOWKB_STREAM"] = function(msg)
    SlashCmdList["WOWKILLBOARD"]("stream " .. (msg or ""))
end

-- Lightweight Floating Launcher Button (100% Taint-Free, Zero GameTooltip Touching, Anonymous Frame)
function KB:UpdateMinimapTheme()
    local btn = KB.MinimapButton
    if not btn then return end
    local curTheme = (KB.UI and KB.UI.GetCurrentThemeName) and KB.UI:GetCurrentThemeName() or "classic"
    local isClassic = (curTheme == "classic")

    -- Ensure native BackdropTemplate does not occlude child textures on un-modded clients
    if btn.SetBackdrop then
        btn:SetBackdrop(nil)
    end

    if isClassic then
        -- Classic Forever Theme: Circular Blizzard minimap border
        if btn.Bg then btn.Bg:Hide() end
        if btn.BorderTop then btn.BorderTop:Hide() end
        if btn.BorderBottom then btn.BorderBottom:Hide() end
        if btn.BorderLeft then btn.BorderLeft:Hide() end
        if btn.BorderRight then btn.BorderRight:Hide() end

        if btn.Border then
            btn.Border:Show()
            btn.Border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
            btn.Border:SetSize(54, 54)
            btn.Border:ClearAllPoints()
            btn.Border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
        end
        if btn.Icon then
            btn.Icon:Show()
            btn.Icon:SetTexture("Interface\\Icons\\Achievement_PVP_P_01")
            btn.Icon:SetTexCoord(0, 1, 0, 1)
            btn.Icon:SetSize(22, 22)
            btn.Icon:ClearAllPoints()
            btn.Icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
        end
        if btn.TipFrame then
            btn.TipFrame:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 12, edgeSize = 12,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            btn.TipFrame:SetBackdropColor(0.08, 0.07, 0.05, 0.95)
            btn.TipFrame:SetBackdropBorderColor(0.85, 0.65, 0.20, 0.95)
        end
    else
        -- ElvUI Minimalist Theme: Sleek square 1px black border with cropped icon
        if btn.Border then
            btn.Border:Hide()
        end
        if btn.Bg then
            btn.Bg:Show()
            btn.Bg:SetColorTexture(0.06, 0.06, 0.06, 1.0)
        end
        if btn.BorderTop then btn.BorderTop:Show() end
        if btn.BorderBottom then btn.BorderBottom:Show() end
        if btn.BorderLeft then btn.BorderLeft:Show() end
        if btn.BorderRight then btn.BorderRight:Show() end

        if btn.Icon then
            btn.Icon:Show()
            btn.Icon:SetTexture("Interface\\Icons\\Achievement_PVP_P_01")
            btn.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            btn.Icon:SetSize(28, 28)
            btn.Icon:ClearAllPoints()
            btn.Icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
        end
        if btn.TipFrame then
            btn.TipFrame:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
                insets = { left = 0, right = 0, top = 0, bottom = 0 }
            })
            btn.TipFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.98)
            btn.TipFrame:SetBackdropBorderColor(0.0, 0.0, 0.0, 1.0)
        end
    end
end

function KB:CreateMinimapButton()
    local btn = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
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

    -- Background texture for flat themes
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(btn)
    bg:Hide()
    btn.Bg = bg

    -- PvP Skull/Chevron Icon in ARTWORK layer
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(22, 22)
    icon:SetPoint("CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\Achievement_PVP_P_01")
    btn.Icon = icon

    -- Circular Classic Tracking Border in OVERLAY layer
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    btn.Border = border

    -- 1px Square Flat Borders for ElvUI Theme (Guaranteed taint-free & zero backdrop occlusion)
    local bTop = btn:CreateTexture(nil, "OVERLAY")
    bTop:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    bTop:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
    bTop:SetHeight(1)
    bTop:SetColorTexture(0.0, 0.0, 0.0, 1.0)
    bTop:Hide()
    btn.BorderTop = bTop

    local bBottom = btn:CreateTexture(nil, "OVERLAY")
    bBottom:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    bBottom:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    bBottom:SetHeight(1)
    bBottom:SetColorTexture(0.0, 0.0, 0.0, 1.0)
    bBottom:Hide()
    btn.BorderBottom = bBottom

    local bLeft = btn:CreateTexture(nil, "OVERLAY")
    bLeft:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    bLeft:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    bLeft:SetWidth(1)
    bLeft:SetColorTexture(0.0, 0.0, 0.0, 1.0)
    bLeft:Hide()
    btn.BorderLeft = bLeft

    local bRight = btn:CreateTexture(nil, "OVERLAY")
    bRight:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
    bRight:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    bRight:SetWidth(1)
    bRight:SetColorTexture(0.0, 0.0, 0.0, 1.0)
    bRight:Hide()
    btn.BorderRight = bRight

    KB.MinimapButton = btn

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
    tipFrame:Hide()
    btn.TipFrame = tipFrame

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

    KB:UpdateMinimapTheme()

    -- Optional LibDataBroker Registration for Titan Panel, ElvUI DataTexts, ChocolateBar
    if LibStub then
        local ldb = LibStub:GetLibrary("LibDataBroker-1.1", true)
        if ldb and not KB.LDBDataObject then
            KB.LDBDataObject = ldb:NewDataObject("WoWKillboard", {
                type = "data source",
                text = "WoWKB",
                icon = "Interface\\Icons\\Achievement_PVP_P_01",
                OnClick = function(self, button)
                    if button == "LeftButton" then
                        if KB.UI then KB.UI:Toggle() end
                    elseif button == "RightButton" then
                        local cur = (KB.UI and KB.UI.GetCurrentThemeName) and KB.UI:GetCurrentThemeName() or "classic"
                        local nextTheme = (cur == "classic") and "elvui" or "classic"
                        if KB.UI then KB.UI:SetTheme(nextTheme) end
                    end
                end,
                OnTooltipShow = function(tooltip)
                    local killsCount = (WoWKillboardDB and WoWKillboardDB.kills) and KB.Utils.TableLength(WoWKillboardDB.kills) or 0
                    local curTheme = (KB.UI and KB.UI.GetCurrentThemeName) and KB.UI:GetCurrentThemeName():upper() or "CLASSIC"
                    tooltip:AddLine("|cffffd100WoW Killboard|r |cff888888[" .. curTheme .. "]|r")
                    tooltip:AddLine(string.format("|cff10b981Session Kills Logged: %d|r", killsCount))
                    tooltip:AddLine("|cff00e5ffLeft-Click:|r Toggle Dashboard")
                    tooltip:AddLine("|cff00e5ffRight-Click:|r Toggle Theme")
                end,
            })
        end
    end
end

-- First-Time Login Early Beta & Feedback Welcome Dialog Trigger
local pendingWelcome = false

local function TriggerWelcomeModal(isManual)
    if InCombatLockdown and InCombatLockdown() then
        if not isManual then
            pendingWelcome = true
        else
            SafePrint("|cffff9900[WoWKB]|r Cannot open Welcome dialog during combat.")
        end
        return
    end

    if KB.UI and KB.UI.ShowWelcomeModal then
        KB.UI:ShowWelcomeModal(isManual or false)
    end
end

-- Event Router
coreFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "WoWKillboard" then
            KB:Initialize()
        end
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        KB:SyncRealmData()
        if KB.UI and KB.UI.InitHUDs then
            KB.UI:InitHUDs()
        end
        -- Wait 2.5s for fonts, world loading, and SavedVariables to settle
        local function CheckPostLoginModals()
            local s = WoWKillboardSettings or {}
            if not s.hasSeenBetaWelcome then
                TriggerWelcomeModal(false)
            elseif s.lastSeenChangelogVersion ~= KB.Version then
                s.lastSeenChangelogVersion = KB.Version
                if not InCombatLockdown() and KB.UI and KB.UI.ShowChangelogModal then
                    KB.UI:ShowChangelogModal(false)
                end
            end
        end

        if C_Timer and C_Timer.After then
            C_Timer.After(2.5, CheckPostLoginModals)
        else
            CheckPostLoginModals()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if KB.UI and KB.UI.InitHUDs then
            KB.UI:InitHUDs()
        end
        if pendingWelcome then
            pendingWelcome = false
            local s = WoWKillboardSettings or {}
            if not s.hasSeenBetaWelcome then
                TriggerWelcomeModal(false)
            end
        end
    end
end)

coreFrame:RegisterEvent("ADDON_LOADED")
coreFrame:RegisterEvent("PLAYER_LOGIN")
coreFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
coreFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

-- Diagnostic Taint & Action Block Interceptor (Telemetry-First Diagnostics)
local diagFrame = CreateFrame("Frame")
diagFrame:RegisterEvent("ADDON_ACTION_BLOCKED")
diagFrame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
diagFrame:SetScript("OnEvent", function(self, event, addon, func)
    local aStr = tostring(addon or "UnknownAddon")
    local fStr = tostring(func or "UnknownFunc")
    local inCombat = InCombatLockdown() and "YES" or "NO"
    local alert = string.format("|cffff0000[WoWKB Diagnostic]|r %s: Blocked |cffffd100%s|r by |cffffff00%s|r (InCombat: %s)", event, fStr, aStr, inCombat)
    if KB.Utils and KB.Utils.SafePrint then
        KB.Utils.SafePrint(alert)
    elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(alert)
    end
    WoWKillboardDB = WoWKillboardDB or {}
    WoWKillboardDB.lastBlockedAction = {
        timestamp = date("%Y-%m-%d %H:%M:%S"),
        event = event,
        addon = aStr,
        func = fStr,
        inCombat = InCombatLockdown(),
    }
end)

-- ============================================================================
-- Automated Bug Reporting & AI Diagnostics Dispatch
-- ============================================================================
function KB:SubmitBugReport(userDescription)
    local cleanDesc = userDescription and userDescription:match("^%s*(.-)%s*$") or ""
    if cleanDesc == "" then
        SafePrint("|cffff9900[WoWKB]|r Cannot submit an empty bug report. Describe what happened.")
        return nil
    end

    WoWKillboardDB = WoWKillboardDB or {}
    WoWKillboardDB.bugReports = WoWKillboardDB.bugReports or {}

    local pName = UnitName("player") or "Player"
    local _, pClass = UnitClass("player")
    local pLevel = UnitLevel("player") or 0
    local pFaction = UnitFactionGroup("player") or "Alliance"
    local pRealm = (GetRealmName and GetRealmName()) or "Unknown"
    local loc = (KB.Utils and KB.Utils.GetPlayerLocation) and KB.Utils:GetPlayerLocation() or {}
    local inCombat = (InCombatLockdown and InCombatLockdown()) and true or false
    local partySize = (GetNumGroupMembers and GetNumGroupMembers()) or (GetNumSubgroupMembers and GetNumSubgroupMembers() + 1) or 1
    local buildVer, buildNum = GetBuildInfo()
    local ticketId = string.format("BUG-%d-%04d", time(), math.random(1000, 9999))

    local report = {
        id = ticketId,
        timestamp = time(),
        reporter = pName,
        realm = pRealm,
        class = pClass or "WARRIOR",
        level = pLevel,
        faction = pFaction,
        clientFlavor = KB.ClientFlavor or "CLASSIC_ERA",
        gameBuild = tostring(buildVer) .. " (" .. tostring(buildNum) .. ")",
        zone = loc.zone or GetRealZoneText() or "Unknown",
        subzone = loc.subZone or GetSubZoneText() or "",
        mapId = loc.mapId or 0,
        coordinates = string.format("%.1f, %.1f", loc.x or 0, loc.y or 0),
        inCombat = inCombat,
        partySize = partySize,
        userReport = cleanDesc,
        lastBlockedAction = WoWKillboardDB.lastBlockedAction or nil,
        addonVersion = KB.Version or "1.0.0",
        aiStatus = "PENDING_SYNC",
    }

    WoWKillboardDB.bugReports[ticketId] = report

    SafePrint(string.format("|cff00ccff[WoWKB Bug Dispatch]|r Ticket |cffffd100[%s]|r logged!", ticketId))
    SafePrint(string.format("  Telemetry: |cffffffff%s (%s)|r in |cffffffff%s|r | Combat: %s",
        pName, pRealm, report.zone, inCombat and "|cffff3333In Combat|r" or "|cff00ff00Safe|r"))
    SafePrint("|cff10b981[AI Diagnostician]|r Run |cffffd100WoWKillboardSync.exe|r or reload UI to transmit this ticket to the AI diagnostic agent.")
    return ticketId
end


