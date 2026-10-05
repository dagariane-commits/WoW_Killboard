--[[
    WoWKillboard - Sync.lua
    Peer-to-peer Addon communication across Guild, Party, Raid, and Channel
    using Blizzard's C_ChatInfo addon message protocol.
]]

WoWKillboard = WoWKillboard or {}
local KB = WoWKillboard
KB.Sync = {}
local S = KB.Sync

local frame = CreateFrame("Frame")

-- Immediate prefix registration at file load for cross-client parity
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    pcall(C_ChatInfo.RegisterAddonMessagePrefix, KB.Prefix or "WOWKB")
elseif RegisterAddonMessagePrefix then
    pcall(RegisterAddonMessagePrefix, KB.Prefix or "WOWKB")
end

-- Helper functions for secret-value safe string operations (Zero Taint Guardrail)
local function IsSecret(val)
    return (issecretvalue and issecretvalue(val)) == true
end

local function SafeFind(str, pattern, init, plain)
    if not str or type(str) ~= "string" or IsSecret(str) then return nil end
    local ok, r1, r2 = pcall(string.find, str, pattern, init, plain)
    return ok and r1 or nil, ok and r2 or nil
end

local function SafeMatch(str, pattern, init)
    if not str or type(str) ~= "string" or IsSecret(str) then return nil end
    local ok, r1, r2, r3, r4, r5, r6 = pcall(string.match, str, pattern, init)
    if ok then return r1, r2, r3, r4, r5, r6 end
    return nil
end

local function SafeGsub(str, pattern, repl, n)
    if not str or type(str) ~= "string" or IsSecret(str) then return str end
    local ok, res = pcall(string.gsub, str, pattern, repl, n)
    return ok and res or str
end

local function SafeLower(str)
    if not str or type(str) ~= "string" or IsSecret(str) then return "" end
    local ok, res = pcall(string.lower, str)
    return ok and res or ""
end

-- Helper to identify WoWKillboard channel across full string or base name
local function IsWoWKillboardChannel(channelBase, channelName)
    if channelBase and type(channelBase) == "string" and not IsSecret(channelBase) then
        local lower = SafeLower(channelBase)
        if lower == "wowkillboard" or lower == "wowkb" or SafeFind(lower, "wowkillboard", 1, true) or SafeFind(lower, "wowkb", 1, true) then
            return true
        end
    end
    if channelName and type(channelName) == "string" and not IsSecret(channelName) then
        local lower = SafeLower(channelName)
        if lower == "wowkillboard" or lower == "wowkb" or SafeFind(lower, "wowkillboard", 1, true) or SafeFind(lower, "wowkb", 1, true) then
            return true
        end
    end
    return false
end

-- Chatter suppression filter: guarantees the channel remains a 100% pure telemetry feed
-- Completely silences non-addon chatter, spam, or player conversation from displaying in any chat frame
if ChatFrame_AddMessageEventFilter then
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", function(self, event, msg, sender, lang, channelName, target, flags, zoneChannelID, channelNumber, channelBase, ...)
        if msg and IsSecret(msg) then
            return false, msg, sender, lang, channelName, target, flags, zoneChannelID, channelNumber, channelBase, ...
        end
        if IsWoWKillboardChannel(channelBase, channelName) then
            if msg and type(msg) == "string" then
                -- Permit structured WoWKB telemetry broadcasts
                if SafeFind(msg, "^%[WoWKB%] Casualty:") or SafeFind(msg, "^%[WoWKB Alert%]") or SafeFind(msg, "^%[WoWKB Update%]") or SafeFind(msg, "^%[WoWKB Test Broadcast%]") or SafeFind(msg, "^%[WoWKB") or SafeFind(msg, "^%[WoW Killboard%]") then
                    -- Format prefix with crisp UI colors
                    local styledMsg = SafeGsub(msg, "^%[WoWKB%]", "|cffffd100[WoWKB]|r")
                    styledMsg = SafeGsub(styledMsg, "^%[WoWKB Alert%]", "|cffff3838[WoWKB Alert]|r")
                    styledMsg = SafeGsub(styledMsg, "^%[WoWKB Update%]", "|cff38bdf8[WoWKB Update]|r")
                    return false, styledMsg, sender, lang, channelName, target, flags, zoneChannelID, channelNumber, channelBase, ...
                end
            end
            -- If the local player inadvertently typed into the dedicated channel, provide immediate feedback
            local myName = UnitName("player")
            if sender and myName and not IsSecret(sender) and (sender == myName or SafeFind(sender, "^" .. myName .. "%-")) then
                if KB.Utils and KB.Utils.SafePrint then
                    KB.Utils.SafePrint("|cffff3838[WoWKB]|r The '|cffffd100WoWKillboard|r' channel is a dedicated telemetry feed. Player chatting is disabled.")
                end
            end
            -- Drop/suppress message from chat window completely
            return true
        end
        return false, msg, sender, lang, channelName, target, flags, zoneChannelID, channelNumber, channelBase, ...
    end)
end

-- Hide custom channel from all chat windows to eliminate visual clutter
function S:HideChannelFromChat(chanName)
    chanName = chanName or "WoWKillboard"
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local cf = _G["ChatFrame" .. i]
        if cf and ChatFrame_RemoveChannel then
            pcall(ChatFrame_RemoveChannel, cf, chanName)
        end
    end
end

-- Attach custom channel to default chat window for silent running combat log
function S:ShowChannelInChat(chanName)
    chanName = chanName or "WoWKillboard"
    if InCombatLockdown and InCombatLockdown() then return end
    if DEFAULT_CHAT_FRAME and ChatFrame_AddChannel then
        pcall(ChatFrame_AddChannel, DEFAULT_CHAT_FRAME, chanName)
    end
end

-- Apply user's chat window visibility preference (Show Channel vs Clean Silent Chat)
function S:ApplyChatVisibility(chanName)
    chanName = chanName or "WoWKillboard"
    if InCombatLockdown and InCombatLockdown() then return end
    local s = WoWKillboardSettings or KB.DefaultSettings or {}
    local showInChat = (s.showChannelInChat == true)
    if showInChat then
        S:ShowChannelInChat(chanName)
    else
        S:HideChannelFromChat(chanName)
    end
end

-- Robust channel ID lookup across all client versions, channel order, and stride lengths
function S:GetChannelId(chanName)
    chanName = chanName or "WoWKillboard"
    -- 0. Fast-path: Return cached index if valid and confirmed by client
    if S.channelIndex and S.channelIndex > 0 and GetChannelName then
        local id = GetChannelName(S.channelIndex)
        if id and tonumber(id) == S.channelIndex then
            return S.channelIndex
        end
    end
    -- 1. Direct Blizzard lookup (O(1) fast-path, standard across Classic Era, Beta, Anniversary, Retail)
    if GetChannelName then
        local id = GetChannelName(chanName)
        if id and tonumber(id) and tonumber(id) > 0 then
            S.channelIndex = tonumber(id)
            return tonumber(id)
        end
        id = GetChannelName("WoWKB")
        if id and tonumber(id) and tonumber(id) > 0 then
            S.channelIndex = tonumber(id)
            return tonumber(id)
        end
    end
    -- 2. List iteration fallback with dynamic stride detection (stride 2: [id, name], stride 3: [id, name, disabled])
    if GetChannelList then
        local ok, list = pcall(function() return { GetChannelList() } end)
        if ok and type(list) == "table" and #list > 0 then
            local stride = (type(list[3]) == "boolean") and 3 or 2
            local lowerTarget = SafeLower(chanName)
            for i = 1, #list, stride do
                local id = list[i]
                local name = list[i+1]
                if type(name) == "string" and type(id) == "number" and id > 0 then
                    local lowerName = SafeLower(name)
                    if lowerName == lowerTarget or SafeFind(lowerName, lowerTarget, 1, true) then
                        S.channelIndex = id
                        return id
                    end
                end
            end
        end
    end
    return nil
end

function S:JoinGlobalChannel()
    if InCombatLockdown and InCombatLockdown() then return end
    local chanName = "WoWKillboard"
    local id = S:GetChannelId(chanName)
    if id and id > 0 then
        S.channelIndex = id
        S:ApplyChatVisibility(chanName)
        return id
    end
    if JoinChannelByName then
        pcall(JoinChannelByName, chanName)
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(2.0, function()
            local afterId = S:GetChannelId(chanName)
            if afterId and afterId > 0 then
                S.channelIndex = afterId
                S:ApplyChatVisibility(chanName)
            end
        end)
    end
    return nil
end

-- Process Blizzard channel notices (YOU_JOINED, YOU_LEFT, etc.)
function S:OnChannelNotice(notice, player, _, channelName, _, _, _, _, baseName)
    local name = baseName or channelName or ""
    if type(name) == "string" and not IsSecret(name) then
        local lowerName = SafeLower(name)
        if SafeFind(lowerName, "wowkillboard", 1, true) or SafeFind(lowerName, "wowkb", 1, true) then
            if notice == "YOU_JOINED" or notice == "YOU_CHANGED" then
                local id = S:GetChannelId("WoWKillboard")
                if id and id > 0 then
                    S.channelIndex = id
                    S:ApplyChatVisibility("WoWKillboard")
                end
            elseif notice == "YOU_LEFT" or notice == "SUSPENDED" then
                S.channelIndex = nil
            end
        end
    end
end

-- Safely transmit a message and optional AddonMessage payload to the dedicated WoWKillboard realm channel
function S:BroadcastToGlobalChannel(chatText, addonPayload)
    local chanId = S:GetChannelId("WoWKillboard")
    if chanId and chanId > 0 then
        S.channelIndex = chanId
        if chatText and chatText ~= "" then
            pcall(SendChatMessage, chatText, "CHANNEL", nil, chanId)
        end
        if addonPayload and addonPayload ~= "" and KB.Utils and KB.Utils.SendAddonMessage then
            KB.Utils.SendAddonMessage(KB.Prefix, addonPayload, "CHANNEL", chanId)
        end
        return true
    else
        S:JoinGlobalChannel()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.4, function()
                local retryId = S:GetChannelId("WoWKillboard")
                if retryId and retryId > 0 then
                    S.channelIndex = retryId
                    if chatText and chatText ~= "" then
                        pcall(SendChatMessage, chatText, "CHANNEL", nil, retryId)
                    end
                    if addonPayload and addonPayload ~= "" and KB.Utils and KB.Utils.SendAddonMessage then
                        KB.Utils.SendAddonMessage(KB.Prefix, addonPayload, "CHANNEL", retryId)
                    end
                else
                    C_Timer.After(1.0, function()
                        local secondRetryId = S:GetChannelId("WoWKillboard")
                        if secondRetryId and secondRetryId > 0 then
                            S.channelIndex = secondRetryId
                            if chatText and chatText ~= "" then
                                pcall(SendChatMessage, chatText, "CHANNEL", nil, secondRetryId)
                            end
                            if addonPayload and addonPayload ~= "" and KB.Utils and KB.Utils.SendAddonMessage then
                                KB.Utils.SendAddonMessage(KB.Prefix, addonPayload, "CHANNEL", secondRetryId)
                            end
                        end
                    end)
                end
            end)
        end
        return false
    end
end

-- Backward-compatible wrapper for SendToGlobalChannel
function S:SendToGlobalChannel(msg)
    return S:BroadcastToGlobalChannel(msg, nil)
end

-- Broadcast a Simulated/Test Casualty across Party, Guild, and Realm Channel without saving to database
function S:BroadcastTestCasualty(mode, targetPeer)
    local myName = UnitName("player") or "Dagariane"
    local _, pClass = UnitClass("player")
    pClass = pClass or "PALADIN"
    local pLevel = UnitLevel("player") or 23
    local pGuild = (GetGuildInfo and GetGuildInfo("player")) or "Knights of Azeroth"
    local pFaction = (UnitFactionGroup and UnitFactionGroup("player")) or "Alliance"
    local cTitle = (KB.Utils and KB.Utils.GetClassTitle) and KB.Utils.GetClassTitle(pClass) or "Paladin"
    local loc = (KB.Utils and KB.Utils.GetPlayerLocation) and KB.Utils.GetPlayerLocation() or { zone = "Westfall", subZone = "Sentinel Hill", x = 42.5, y = 58.3 }
    local zone = (loc.zone and loc.zone ~= "" and loc.zone ~= "Unknown Zone") and loc.zone or "Westfall"
    local subZone = (loc.subZone and loc.subZone ~= "") and loc.subZone or "Sentinel Hill"

    mode = (mode and tostring(mode):lower()) or "pve"
    local isPve = (mode == "pve" or mode == "npc" or mode == "mob" or mode == "pillager")
    local testId = "TEST-CASUALTY-" .. tostring(time())

    local killerName, killerClass, killerLevel, killerSpell, killerGuild, killerFaction, killerDamage
    if isPve then
        killerName = "Defias Pillager"
        killerClass = "MAGE"
        killerLevel = 15
        killerSpell = "Fireball"
        killerGuild = "Wilderness Threat"
        killerFaction = "Monster"
        killerDamage = math.max(600, pLevel * 50)
    else
        killerFaction = (pFaction == "Alliance") and "Horde" or "Alliance"
        killerClass = (killerFaction == "Horde") and "ROGUE" or "WARRIOR"
        killerName = (killerFaction == "Horde") and "Shadowstalker" or "Dawnbreaker"
        killerGuild = (killerFaction == "Horde") and "Grim Syndicate" or "Silver Hand"
        killerLevel = math.max(1, pLevel + 1)
        killerSpell = (killerClass == "ROGUE") and "Ambush" or "Mortal Strike"
        killerDamage = math.max(800, pLevel * 75)
    end

    -- AddonMessage payload format:
    -- TEST_CASUALTY:<mode>:<testId>:<kName>:<kClass>:<kLvl>:<kSpell>:<kDmg>:<vName>:<vClass>:<vLvl>:<vGuild>:<vFaction>:<zone>:<subZone>
    local payload = string.format("TEST_CASUALTY:%s:%s:%s:%s:%d:%s:%d:%s:%s:%d:%s:%s:%s:%s",
        isPve and "PVE" or "PVP",
        testId,
        killerName:gsub(":", " "),
        killerClass,
        killerLevel,
        killerSpell:gsub(":", " "),
        killerDamage,
        myName:gsub(":", " "),
        pClass,
        pLevel,
        pGuild:gsub(":", " "),
        pFaction,
        zone:gsub(":", " "),
        subZone:gsub(":", " ")
    )

    -- 1. Broadcast via AddonMessage across Party, Raid, Guild, and direct peer Whispers
    local isRaid = (KB.Utils and KB.Utils.IsInRaid and KB.Utils.IsInRaid()) or (IsInRaid and IsInRaid())
    local isGroup = (KB.Utils and KB.Utils.IsInGroup and KB.Utils.IsInGroup()) or (IsInGroup and IsInGroup())
    local sentPeerCount = 0

    if isRaid then
        if KB.Utils and KB.Utils.SendAddonMessage then
            KB.Utils.SendAddonMessage(KB.Prefix, payload, "RAID")
            sentPeerCount = sentPeerCount + 1
        end
    elseif isGroup then
        if KB.Utils and KB.Utils.SendAddonMessage then
            KB.Utils.SendAddonMessage(KB.Prefix, payload, "PARTY")
            sentPeerCount = sentPeerCount + 1
        end
    end
    if IsInGuild and IsInGuild() then
        if KB.Utils and KB.Utils.SendAddonMessage then
            KB.Utils.SendAddonMessage(KB.Prefix, payload, "GUILD")
            sentPeerCount = sentPeerCount + 1
        end
    end

    -- Direct Target Peer: If explicit targetPeer passed (e.g. /testnet <player>), whisper them directly
    if targetPeer and targetPeer ~= "" and targetPeer ~= myName then
        if KB.Utils and KB.Utils.SendAddonMessage then
            KB.Utils.SendAddonMessage(KB.Prefix, payload, "WHISPER", targetPeer)
            sentPeerCount = sentPeerCount + 1
        end
    end

    -- Direct Peer Fallback: Also dispatch directly to party members via whisper AddonMessage
    local numMembers = (GetNumGroupMembers and GetNumGroupMembers()) or (GetNumPartyMembers and GetNumPartyMembers() + 1) or 0
    if numMembers and numMembers > 1 then
        for i = 1, numMembers do
            local unit = (isRaid and "raid" or "party") .. i
            local pName, pRealm = UnitName(unit)
            if pName and pName ~= myName and not pName:lower():find(myName:lower()) then
                local peer = (pRealm and pRealm ~= "") and (pName .. "-" .. pRealm) or pName
                if KB.Utils and KB.Utils.SendAddonMessage then
                    KB.Utils.SendAddonMessage(KB.Prefix, payload, "WHISPER", peer)
                    sentPeerCount = sentPeerCount + 1
                end
            end
        end
    end

    -- Also if player currently has another player targeted, dispatch directly to target
    if UnitExists("target") and UnitIsPlayer("target") then
        local tName, tRealm = UnitName("target")
        if tName and tName ~= myName then
            local peer = (tRealm and tRealm ~= "") and (tName .. "-" .. tRealm) or tName
            if KB.Utils and KB.Utils.SendAddonMessage then
                KB.Utils.SendAddonMessage(KB.Prefix, payload, "WHISPER", peer)
                sentPeerCount = sentPeerCount + 1
            end
        end
    end

    -- 2. Standardized Chat Casualty Broadcast (Format C) with explicit [TEST SIMULATION] tag
    local chatMsg = string.format("[WoWKB] Casualty: %s (Lvl %d %s) killed by %s (%s) in %s. [TEST SIMULATION]",
        myName, pLevel, cTitle, killerName, killerSpell, subZone)

    -- Broadcast to Party/Raid chat if in group
    if isGroup then
        pcall(SendChatMessage, chatMsg, isRaid and "RAID" or "PARTY")
    end

    -- Broadcast to dedicated WoWKillboard realm channel (both chat Format C and AddonMessage payload)
    local sentChan = S:BroadcastToGlobalChannel(chatMsg, payload)
    if sentChan then
        sentPeerCount = sentPeerCount + 1
    end

    -- 3. Trigger local test display immediately
    local testData = {
        killId = testId,
        timestamp = time(),
        isTest = true,
        isPveDeath = isPve,
        isSolo = not isPve,
        npc = isPve and { name = killerName, spell = killerSpell, damage = killerDamage } or nil,
        killer = {
            name = killerName,
            class = killerClass,
            level = killerLevel,
            guild = killerGuild,
            faction = killerFaction,
            spell = killerSpell,
            damage = killerDamage,
        },
        victim = {
            name = myName,
            class = pClass,
            level = pLevel,
            guild = pGuild,
            faction = pFaction,
        },
        location = { zone = zone, subZone = subZone, x = loc.x or 0, y = loc.y or 0 },
    }

    if KB.UI and KB.UI.ShowKillBanner then
        KB.UI:ShowKillBanner(testData, true)
    end

    local printMsg = string.format("|cff00ff00[WoWKB Test Broadcast]|r Simulated %s casualty broadcasted to Realm Network! (|cffffd100Zero database pollution|r)", isPve and "PvE" or "PvP")
    if KB.Utils and KB.Utils.SafePrint then
        KB.Utils.SafePrint(printMsg)
    elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(printMsg)
    end

    if not sentChan then
        local note = "|cff38bdf8[WoWKB Network]|r Connecting to realm channel 'WoWKillboard'... Broadcast queued and will transmit in 1.5s."
        if KB.Utils and KB.Utils.SafePrint then
            KB.Utils.SafePrint(note)
        elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(note)
        end
    end
end

-- Process incoming test casualty broadcast from remote peer (Displays alert without writing to database)
function S:OnIncomingTestCasualty(testData, sender)
    if not testData then return end
    local myName = UnitName("player")
    local isSelf = (KB.Utils and KB.Utils.IsSelfSender and KB.Utils.IsSelfSender(sender, myName))
    if isSelf then return end

    -- Deduplication window: Prevent duplicate toasts if both AddonMessage and ChatMessage arrive within 5s
    S.recentTestAlerts = S.recentTestAlerts or {}
    local testKey = (testData and (testData.killId or testData.deathId)) or (tostring(sender) .. ":" .. tostring(testData.timestamp or time()))
    local now = time()
    if S.recentTestAlerts[testKey] and (now - S.recentTestAlerts[testKey]) < 5 then
        return
    end
    S.recentTestAlerts[testKey] = now

    testData.realm = testData.realm or (GetRealmName and GetRealmName()) or ""
    testData.ruleset = testData.ruleset or (KB.Utils and KB.Utils.GetRealmRuleset and KB.Utils.GetRealmRuleset()) or "PVE"
    if testData.killer and not testData.killer.realm then testData.killer.realm = testData.realm end
    if testData.victim and not testData.victim.realm then testData.victim.realm = testData.realm end

    local s = WoWKillboardSettings or KB.DefaultSettings or {}
    local alertMode = s.alertMode or "SOUND_AND_BANNER"
    local soundEnabled = (s.soundAlerts ~= false)

    -- Sound Alert (Soundkit 8959 = PvP Solo Kill, 5274 = Raid Warning)
    if soundEnabled and alertMode == "SOUND_AND_BANNER" then
        pcall(PlaySound, 8959, "Master")
        pcall(PlaySound, 5274, "Master")
    end

    -- Trigger Kill Banner with isTest = true (Only if banner alerts are not turned off)
    if alertMode ~= "OFF" and KB.UI and KB.UI.ShowKillBanner then
        KB.UI:ShowKillBanner(testData, true)
    end

    local kName = (testData.killer and testData.killer.name) or "Hostile"
    local vName = (testData.victim and testData.victim.name) or sender or "Combatant"
    local locStr = (testData.location and (testData.location.subZone or testData.location.zone)) or "Wilderness"

    local alertStatus = (alertMode == "OFF") and "|cffff9900(Chat Stream Only - Toast Muted)|r" or "|cffffd100Alert and toast verified!|r"
    local alertMsg = string.format("|cff38bdf8[WoWKB Network Test]|r Received simulated casualty broadcast from |cff00e5ff%s|r (%s killed by %s in %s). %s (Not saved to history).",
        sender or vName, vName, kName, locStr, alertStatus)
    if KB.Utils and KB.Utils.SafePrint then
        KB.Utils.SafePrint(alertMsg)
    elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(alertMsg)
    end
end

-- Broadcast an administrative update warning across channel, party, and guild
function S:BroadcastAdminAlert(message, alertType)
    if not message or message == "" then return end
    alertType = alertType or "UPDATE"
    local myName = UnitName("player") or "Admin"
    local cleanMsg = tostring(message):gsub(":", ";"):gsub("\n", " ")

    -- 1. Send to dedicated WoWKillboard realm channel
    local chanMsg = string.format("[WoWKB Alert] %s: %s", myName, cleanMsg)
    S:SendToGlobalChannel(chanMsg)

    -- 2. Send via AddonMessage to Party/Raid and Guild
    local payload = string.format("SYS_ALERT:%s:%s:%s", myName, alertType, cleanMsg)
    local isRaid = (KB.Utils and KB.Utils.IsInRaid and KB.Utils.IsInRaid()) or (IsInRaid and IsInRaid())
    local isGroup = (KB.Utils and KB.Utils.IsInGroup and KB.Utils.IsInGroup()) or (IsInGroup and IsInGroup())
    if isRaid then
        if KB.Utils and KB.Utils.SendAddonMessage then
            KB.Utils.SendAddonMessage(KB.Prefix, payload, "RAID")
        end
    elseif isGroup then
        if KB.Utils and KB.Utils.SendAddonMessage then
            KB.Utils.SendAddonMessage(KB.Prefix, payload, "PARTY")
        end
    end
    if IsInGuild and IsInGuild() then
        if KB.Utils and KB.Utils.SendAddonMessage then
            KB.Utils.SendAddonMessage(KB.Prefix, payload, "GUILD")
        end
    end

    -- 3. Also display locally
    S:OnIncomingAdminAlert(myName, alertType, cleanMsg)
end

-- Process incoming system/update alert from channel or addon message
function S:OnIncomingAdminAlert(sender, alertType, message)
    if not message or message == "" then return end
    local now = time()
    S.recentAlerts = S.recentAlerts or {}
    local key = tostring(sender) .. ":" .. tostring(message)
    if S.recentAlerts[key] and (now - S.recentAlerts[key]) < 8 then
        return
    end
    S.recentAlerts[key] = now

    -- Audio notification
    pcall(PlaySound, 5274) -- SOUNDKIT.RAID_WARNING

    -- Formatted Chat Banner
    local border = "|cffffd100" .. string.rep("=", 60) .. "|r"
    local title = string.format("|cffff3838[WoWKB SYSTEM UPDATE ALERT]|r |cffffd100From:|r |cff00e5ff%s|r", sender or "Operator")
    local body = string.format("|cffffffff%s|r", message)

    if KB.Utils and KB.Utils.SafePrint then
        KB.Utils.SafePrint(border)
        KB.Utils.SafePrint(title)
        KB.Utils.SafePrint(body)
        KB.Utils.SafePrint(border)
    elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(border)
        DEFAULT_CHAT_FRAME:AddMessage(title)
        DEFAULT_CHAT_FRAME:AddMessage(body)
        DEFAULT_CHAT_FRAME:AddMessage(border)
    end

    -- On-Screen Raid Notice if available
    if RaidNotice_AddMessage and RaidWarningFrame then
        pcall(RaidNotice_AddMessage, RaidWarningFrame, string.format("|cffff3838[WoWKB UPDATE]|r |cffffffff%s|r", message), ChatTypeInfo["RAID_WARNING"] or { r = 1, g = 0.3, b = 0.3 })
    end

    -- High-priority On-Screen Toast
    if KB.UI and KB.UI.TriggerToast then
        KB.UI:TriggerToast({
            type = "pve_casualty",
            title = "SYSTEM UPDATE NOTICE",
            text = string.format("%s: %s", sender or "Operator", message),
            duration = 10,
        })
    end
end

function S:Init()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, KB.Prefix or "WOWKB")
    elseif RegisterAddonMessagePrefix then
        pcall(RegisterAddonMessagePrefix, KB.Prefix or "WOWKB")
    end
    S:JoinGlobalChannel()
end

-- Broadcast a killmail to group and guild
function S:BroadcastKillmail(killmail)
    if not KB.DefaultSettings.p2pSyncEnabled or not killmail or killmail.isDuel then return end

    -- Serialize compact payload: "KM:killId:timestamp:isSolo:isBG:kName:kClass:kLvl:vName:vClass:vLvl:zone:subZone:spell"
    local subZone = (killmail.location and killmail.location.subZone) or ""
    local spell = killmail.finalSpell or (killmail.killer and killmail.killer.spell) or "Combat Strike"
    subZone = subZone:gsub(":", " ")
    spell = spell:gsub(":", " ")
    local payload = string.format("KM:%s:%d:%d:%d:%s:%s:%d:%s:%s:%d:%s:%s:%s",
        killmail.killId,
        killmail.timestamp,
        killmail.isSolo and 1 or 0,
        killmail.isBattleground and 1 or 0,
        killmail.killer.name,
        killmail.killer.class,
        killmail.killer.level,
        killmail.victim.name,
        killmail.victim.class,
        killmail.victim.level,
        killmail.location.zone,
        subZone,
        spell
    )

    local isRaid = (KB.Utils and KB.Utils.IsInRaid and KB.Utils.IsInRaid()) or (IsInRaid and IsInRaid())
    local isGroup = (KB.Utils and KB.Utils.IsInGroup and KB.Utils.IsInGroup()) or (IsInGroup and IsInGroup())
    if isRaid then
        if KB.Utils and KB.Utils.SendAddonMessage then
            KB.Utils.SendAddonMessage(KB.Prefix, payload, "RAID")
        end
    elseif isGroup then
        if KB.Utils and KB.Utils.SendAddonMessage then
            KB.Utils.SendAddonMessage(KB.Prefix, payload, "PARTY")
        end
    end

    if IsInGuild and IsInGuild() then
        if KB.Utils and KB.Utils.SendAddonMessage then
            KB.Utils.SendAddonMessage(KB.Prefix, payload, "GUILD")
        end
    end

    -- Global realm channel broadcast (Format C chat and AddonMessage payload for anyone with the addon)
    local vTitle = (KB.Utils and KB.Utils.GetClassTitle) and KB.Utils.GetClassTitle(killmail.victim.class) or killmail.victim.class
    local locName = (subZone ~= "" and subZone) or killmail.location.zone or "Wilderness"
    local chatMsg = string.format("[WoWKB] Casualty: %s (Lvl %d %s) killed by %s (%s) in %s.",
        killmail.victim.name, killmail.victim.level, vTitle, killmail.killer.name, spell, locName)
    S:BroadcastToGlobalChannel(chatMsg, payload)
end

-- Broadcast a PvE death to group and guild
function S:BroadcastPveDeath(pveRecord)
    if not KB.DefaultSettings or not KB.DefaultSettings.p2pSyncEnabled or not pveRecord then return end
    local deathId = pveRecord.deathId or "PVE-0"
    local npc = pveRecord.npc or {}
    local vic = pveRecord.victim or {}
    local loc = pveRecord.location or {}
    local npcName = (npc.name or "Hostile Threat"):gsub(":", " ")
    local npcSpell = (npc.spell or "Combat Strike"):gsub(":", " ")
    local vName = (vic.name or "Player"):gsub(":", " ")
    local vClass = (vic.class or "UNKNOWN"):gsub(":", " ")
    local vGuild = (vic.guild or "None"):gsub(":", " ")
    local vFaction = (vic.faction or "Unknown"):gsub(":", " ")
    local zone = (loc.zone or "Wilderness"):gsub(":", " ")
    local subZone = (loc.subZone or ""):gsub(":", " ")

    local payload = string.format("PVE:%s:%d:%s:%d:%s:%d:%s:%s:%d:%s:%s:%s:%s",
        deathId,
        pveRecord.timestamp or time(),
        npcName,
        npc.id or 0,
        npcSpell,
        npc.damage or 0,
        vName,
        vClass,
        vic.level or 0,
        vGuild,
        vFaction,
        zone,
        subZone
    )

    local isRaid = (KB.Utils and KB.Utils.IsInRaid and KB.Utils.IsInRaid()) or (IsInRaid and IsInRaid())
    local isGroup = (KB.Utils and KB.Utils.IsInGroup and KB.Utils.IsInGroup()) or (IsInGroup and IsInGroup())
    if isRaid then
        if KB.Utils and KB.Utils.SendAddonMessage then
            KB.Utils.SendAddonMessage(KB.Prefix, payload, "RAID")
        end
    elseif isGroup then
        if KB.Utils and KB.Utils.SendAddonMessage then
            KB.Utils.SendAddonMessage(KB.Prefix, payload, "PARTY")
        end
    end

    if IsInGuild and IsInGuild() then
        if KB.Utils and KB.Utils.SendAddonMessage then
            KB.Utils.SendAddonMessage(KB.Prefix, payload, "GUILD")
        end
    end

    -- Global realm channel broadcast (Format C chat and AddonMessage payload for anyone with the addon)
    local vTitle = (KB.Utils and KB.Utils.GetClassTitle) and KB.Utils.GetClassTitle(vClass) or vClass
    local locName = (subZone ~= "" and subZone) or zone
    local chatMsg = string.format("[WoWKB] Casualty: %s (Lvl %d %s) killed by %s (%s) in %s.",
        vName, vic.level or 0, vTitle, npcName, npcSpell, locName)
    S:BroadcastToGlobalChannel(chatMsg, payload)
end

-- Broadcast a bounty creation
function S:BroadcastBounty(bounty)
    if not KB.DefaultSettings.p2pSyncEnabled or not bounty then return end

    local payload = string.format("BNT:%s:%s:%s:%d:%s",
        bounty.id,
        bounty.targetName,
        bounty.targetClass,
        bounty.amountCopper,
        bounty.placerName
    )

    if IsInGuild and IsInGuild() then
        if KB.Utils and KB.Utils.SendAddonMessage then
            KB.Utils.SendAddonMessage(KB.Prefix, payload, "GUILD")
        end
    end
    local isRaid = (KB.Utils and KB.Utils.IsInRaid and KB.Utils.IsInRaid()) or (IsInRaid and IsInRaid())
    local isGroup = (KB.Utils and KB.Utils.IsInGroup and KB.Utils.IsInGroup()) or (IsInGroup and IsInGroup())
    if isRaid then
        if KB.Utils and KB.Utils.SendAddonMessage then
            KB.Utils.SendAddonMessage(KB.Prefix, payload, "RAID")
        end
    elseif isGroup then
        if KB.Utils and KB.Utils.SendAddonMessage then
            KB.Utils.SendAddonMessage(KB.Prefix, payload, "PARTY")
        end
    end

    -- Faction-wide Broadcast to Realm Chat Channel (WoWKillboard is faction-segregated)
    local copper = bounty.amountCopper or (bounty.amountGold and bounty.amountGold * 10000) or 0
    local goldStr = (KB.Utils and KB.Utils.FormatMoney and KB.Utils.FormatMoney(copper)) or (tostring(bounty.amountGold or 0) .. "g")
    local tClass = (KB.Utils and KB.Utils.GetClassTitle) and KB.Utils.GetClassTitle(bounty.targetClass) or (bounty.targetClass or "Unknown")
    local bountyChatMsg = string.format("[WoWKB Bounty Alert] %s placed a %s Mark of Spite on %s (%s)!",
        bounty.placerName, goldStr, bounty.targetName, tClass)

    local chanId = (KB.Sync and KB.Sync.GetChannelId and KB.Sync:GetChannelId("WoWKillboard")) or (GetChannelName and (GetChannelName("WoWKillboard") or GetChannelName("WoWKB")))
    if chanId and chanId > 0 then
        pcall(SendChatMessage, bountyChatMsg, "CHANNEL", nil, chanId)
    end
    if IsInGuild and IsInGuild() then
        pcall(SendChatMessage, bountyChatMsg, "GUILD")
    end
    if isRaid then
        pcall(SendChatMessage, bountyChatMsg, "RAID")
    elseif isGroup then
        pcall(SendChatMessage, bountyChatMsg, "PARTY")
    end
end

-- Broadcast a Call for Backup SOS distress beacon
function S:BroadcastDistress(beacon)
    if not KB.DefaultSettings.p2pSyncEnabled or not beacon then return end

    -- Serialize SOS payload: "SOS:id:name:class:lvl:guild:faction:zone:subzone:x:y:hCount:hNames:ts"
    local payload = string.format("SOS:%s:%s:%s:%d:%s:%s:%s:%s:%.1f:%.1f:%d:%s:%d",
        beacon.id or "SOS",
        beacon.character_name or "Unknown",
        beacon.character_class or "WARRIOR",
        beacon.character_level or 60,
        beacon.guild_name or "None",
        beacon.faction or "Unknown",
        beacon.zone or "Wilderness",
        beacon.subzone or "",
        beacon.coord_x or 0,
        beacon.coord_y or 0,
        beacon.hostile_count or 1,
        beacon.hostile_names or "Hostiles",
        beacon.timestamp or time()
    )

    if IsInGuild and IsInGuild() then
        if KB.Utils and KB.Utils.SendAddonMessage then
            KB.Utils.SendAddonMessage(KB.Prefix, payload, "GUILD")
        end
    end
    local isRaid = (KB.Utils and KB.Utils.IsInRaid and KB.Utils.IsInRaid()) or (IsInRaid and IsInRaid())
    local isGroup = (KB.Utils and KB.Utils.IsInGroup and KB.Utils.IsInGroup()) or (IsInGroup and IsInGroup())
    if isRaid then
        if KB.Utils and KB.Utils.SendAddonMessage then
            KB.Utils.SendAddonMessage(KB.Prefix, payload, "RAID")
        end
    elseif isGroup then
        if KB.Utils and KB.Utils.SendAddonMessage then
            KB.Utils.SendAddonMessage(KB.Prefix, payload, "PARTY")
        end
    end
end

-- Broadcast resolution of a distress beacon
function S:BroadcastDistressResolve()
    local myName = UnitName("player")
    local payload = string.format("SOS_RES:%s", myName)
    if IsInGuild and IsInGuild() then
        if KB.Utils and KB.Utils.SendAddonMessage then
            KB.Utils.SendAddonMessage(KB.Prefix, payload, "GUILD")
        end
    end
    local isRaid = (KB.Utils and KB.Utils.IsInRaid and KB.Utils.IsInRaid()) or (IsInRaid and IsInRaid())
    local isGroup = (KB.Utils and KB.Utils.IsInGroup and KB.Utils.IsInGroup()) or (IsInGroup and IsInGroup())
    if isRaid then
        if KB.Utils and KB.Utils.SendAddonMessage then
            KB.Utils.SendAddonMessage(KB.Prefix, payload, "RAID")
        end
    elseif isGroup then
        if KB.Utils and KB.Utils.SendAddonMessage then
            KB.Utils.SendAddonMessage(KB.Prefix, payload, "PARTY")
        end
    end
end

-- Broadcast a Guild Event / Rally
function S:BroadcastEvent(evt)
    if not KB.DefaultSettings.p2pSyncEnabled or not evt then return end
    local payload = string.format("EVT:%s:%s:%s:%s:%s:%s",
        evt.id or "EVT",
        evt.title or "Guild Rally",
        evt.guild_name or "Guild",
        evt.creator_name or "Officer",
        evt.zone or "Wilderness",
        evt.time_str or "NOW"
    )
    if IsInGuild and IsInGuild() then
        if KB.Utils and KB.Utils.SendAddonMessage then
            KB.Utils.SendAddonMessage(KB.Prefix, payload, "GUILD")
        end
    end
end

-- Broadcast a tactical scout/gank sighting
function S:BroadcastSighting(sighting)
    if not KB.DefaultSettings.p2pSyncEnabled or not sighting then return end

    local safeNotes = (sighting.notes or "Hostile spotted"):gsub(":", ";")
    -- Format: "SPT:id:repName:repGuild:tgtName:tgtClass:tgtLvl:tgtGuild:tgtFaction:zone:subzone:x:y:notes:ts"
    local payload = string.format("SPT:%s:%s:%s:%s:%s:%d:%s:%s:%s:%s:%.1f:%.1f:%s:%d",
        sighting.id or "SPT",
        sighting.reporter_name or "Scout",
        sighting.reporter_guild or "None",
        sighting.target_name or "Unknown",
        sighting.target_class or "WARRIOR",
        sighting.target_level or 60,
        sighting.target_guild or "None",
        sighting.target_faction or "Unknown",
        sighting.zone or "Wilderness",
        sighting.subzone or "",
        sighting.coord_x or 0,
        sighting.coord_y or 0,
        safeNotes,
        sighting.timestamp or time()
    )

    if IsInGuild and IsInGuild() then
        if KB.Utils and KB.Utils.SendAddonMessage then
            KB.Utils.SendAddonMessage(KB.Prefix, payload, "GUILD")
        end
    end
    local isRaid = (KB.Utils and KB.Utils.IsInRaid and KB.Utils.IsInRaid()) or (IsInRaid and IsInRaid())
    local isGroup = (KB.Utils and KB.Utils.IsInGroup and KB.Utils.IsInGroup()) or (IsInGroup and IsInGroup())
    if isRaid then
        if KB.Utils and KB.Utils.SendAddonMessage then
            KB.Utils.SendAddonMessage(KB.Prefix, payload, "RAID")
        end
    elseif isGroup then
        if KB.Utils and KB.Utils.SendAddonMessage then
            KB.Utils.SendAddonMessage(KB.Prefix, payload, "PARTY")
        end
    end
end

-- Compare two semantic version strings (e.g., "1.0.1" vs "1.0.2")
-- Returns 1 if v1 > v2, -1 if v1 < v2, 0 if v1 == v2
function S:CompareVersions(v1, v2)
    if not v1 or not v2 then return 0 end
    if v1 == v2 then return 0 end
    local function parse(v)
        local parts = {}
        for num in string.gmatch(tostring(v), "%d+") do
            table.insert(parts, tonumber(num) or 0)
        end
        while #parts < 3 do table.insert(parts, 0) end
        return parts
    end
    local p1 = parse(v1)
    local p2 = parse(v2)
    local maxLen = math.max(#p1, #p2)
    for i = 1, maxLen do
        local n1 = p1[i] or 0
        local n2 = p2[i] or 0
        if n1 > n2 then return 1 end
        if n1 < n2 then return -1 end
    end
    return 0
end

-- Broadcast current addon version to guild and group (debounced)
local lastVersionBroadcast = 0
function S:BroadcastVersion()
    if not KB.DefaultSettings or not KB.DefaultSettings.p2pSyncEnabled then return end
    if not KB.Version then return end
    local now = time()
    if now - lastVersionBroadcast < 15 then return end
    lastVersionBroadcast = now

    local payload = "VER:" .. tostring(KB.Version)
    if IsInGuild and IsInGuild() then
        if KB.Utils and KB.Utils.SendAddonMessage then
            KB.Utils.SendAddonMessage(KB.Prefix, payload, "GUILD")
        end
    end
    local isRaid = (KB.Utils and KB.Utils.IsInRaid and KB.Utils.IsInRaid()) or (IsInRaid and IsInRaid())
    local isGroup = (KB.Utils and KB.Utils.IsInGroup and KB.Utils.IsInGroup()) or (IsInGroup and IsInGroup())
    if isRaid then
        if KB.Utils and KB.Utils.SendAddonMessage then
            KB.Utils.SendAddonMessage(KB.Prefix, payload, "RAID")
        end
    elseif isGroup then
        if KB.Utils and KB.Utils.SendAddonMessage then
            KB.Utils.SendAddonMessage(KB.Prefix, payload, "PARTY")
        end
    end
end

-- Process peer version notification with rate limiting and combat lockdown gating
function S:CheckPeerVersion(peerVer, sender)
    if not peerVer or type(peerVer) ~= "string" then return end
    if not peerVer:match("^%d+%.%d+") then return end

    if S:CompareVersions(peerVer, KB.Version) > 0 then
        KB.LatestKnownVersion = peerVer
        if not S.hasNotifiedNewVersion then
            if InCombatLockdown and InCombatLockdown() then
                S.pendingNewVersion = peerVer
            else
                S.hasNotifiedNewVersion = true
                local msg = string.format(
                    "|cff00ccff[WoWKB]|r |cffffd100A newer version of WoW Killboard is available!|r (|cff00ff00v%s|r) — Type |cffffffff/kb changelog|r or update via CurseForge (search 'wkb').",
                    peerVer
                )
                if KB.Utils and KB.Utils.SafePrint then
                    KB.Utils.SafePrint(msg)
                elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                    DEFAULT_CHAT_FRAME:AddMessage(msg)
                end
            end
        end
    end
end

-- Delimiter-preserving tokenizer to prevent column shifting on empty fields (::)
local function ParseMessageParts(message)
    if not message then return {} end
    if _G.strsplit then
        return { _G.strsplit(":", message) }
    end
    local parts = {}
    local start = 1
    local sep_start, sep_end = string.find(message, ":", start, true)
    while sep_start do
        table.insert(parts, string.sub(message, start, sep_start - 1))
        start = sep_end + 1
        sep_start, sep_end = string.find(message, ":", start, true)
    end
    table.insert(parts, string.sub(message, start))
    return parts
end

-- Parse incoming peer message
function S:OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= KB.Prefix then return end
    local myName = UnitName("player")
    local isSelf = (KB.Utils and KB.Utils.IsSelfSender and KB.Utils.IsSelfSender(sender, myName))
    if isSelf then return end

    local parts = ParseMessageParts(message)

    local msgType = parts[1]

    if msgType == "KM" and #parts >= 12 then
        local killId = parts[2]
        WoWKillboardDB = WoWKillboardDB or { kills = {} }
        WoWKillboardDB.kills = WoWKillboardDB.kills or {}

        if not WoWKillboardDB.kills[killId] then
            local subZone = (parts[13] and parts[13] ~= "") and parts[13] or ""
            local finalSpell = (parts[14] and parts[14] ~= "") and parts[14] or "Combat Strike"
            local syncedKM = {
                killId = killId,
                timestamp = tonumber(parts[3]) or time(),
                isDuel = false,
                isSolo = (parts[4] == "1"),
                isBattleground = (parts[5] == "1"),
                isArena = false,
                attackersCount = (parts[4] == "1") and 1 or 2,
                totalDamage = 0,
                finalSpell = finalSpell,
                killer = {
                    name = parts[6],
                    class = parts[7],
                    level = tonumber(parts[8]) or 0,
                    guild = "None",
                    faction = "Unknown",
                    partySize = 1,
                    damageDone = 0,
                    healingDone = 0,
                    spell = finalSpell,
                },
                victim = {
                    name = parts[9],
                    class = parts[10],
                    level = tonumber(parts[11]) or 0,
                    guild = "None",
                    faction = "Unknown",
                    partySize = 1,
                },
                location = {
                    mapId = 0,
                    zone = parts[12],
                    subZone = subZone,
                    x = 0,
                    y = 0,
                },
                realm = (GetRealmName and GetRealmName()) or "",
                ruleset = (KB.Utils and KB.Utils.GetRealmRuleset and KB.Utils.GetRealmRuleset()) or "PVP",
            }
            if syncedKM.killer then syncedKM.killer.realm = syncedKM.realm end
            if syncedKM.victim then syncedKM.victim.realm = syncedKM.realm end

            WoWKillboardDB.kills[killId] = syncedKM

            if KB.Leaderboard and KB.Leaderboard.OnNewKill then
                KB.Leaderboard:OnNewKill(syncedKM)
            end

            -- Trigger Frontline Kill Banner UI alert (respects alertScope, alertMode, raid warning)
            if KB.UI and KB.UI.ShowKillBanner then
                KB.UI:ShowKillBanner(syncedKM)
            end

            if KB.UI and KB.UI.RefreshIfVisible then
                KB.UI:RefreshIfVisible()
            end
        end

    elseif msgType == "PVE" and #parts >= 13 then
        local deathId = parts[2]
        WoWKillboardDB = WoWKillboardDB or { kills = {}, stats = {}, pveDeaths = {} }
        WoWKillboardDB.pveDeaths = WoWKillboardDB.pveDeaths or {}

        if not WoWKillboardDB.pveDeaths[deathId] then
            local ts = tonumber(parts[3]) or time()
            local npcName = parts[4] or "Hostile Threat"
            local npcId = tonumber(parts[5]) or 0
            local npcSpell = parts[6] or "Combat Strike"
            local npcDmg = tonumber(parts[7]) or 0
            local vName = parts[8] or "Adventurer"
            local vClass = parts[9] or "UNKNOWN"
            local vLvl = tonumber(parts[10]) or 0
            local vGuild = parts[11] or "None"
            local vFaction = parts[12] or "Unknown"
            local zone = parts[13] or "Wilderness"
            local subZone = parts[14] or ""

            local syncedPve = {
                deathId = deathId,
                timestamp = ts,
                isPveDeath = true,
                npc = {
                    name = npcName,
                    id = npcId,
                    guid = "CREATURE",
                    spell = npcSpell,
                    damage = npcDmg,
                },
                killer = {
                    guid = "CREATURE",
                    name = npcName,
                    level = 0,
                    class = "WARRIOR",
                    guild = "Wilderness Threat",
                    faction = "Monster",
                    partySize = 1,
                    damageDone = npcDmg,
                    spell = npcSpell,
                },
                victim = {
                    guid = "UNKNOWN",
                    name = vName,
                    level = vLvl,
                    class = vClass,
                    guild = vGuild,
                    faction = vFaction,
                },
                location = {
                    mapId = 0,
                    zone = zone,
                    subZone = subZone,
                    x = 0,
                    y = 0,
                },
                realm = (GetRealmName and GetRealmName()) or "",
                ruleset = (KB.Utils and KB.Utils.GetRealmRuleset and KB.Utils.GetRealmRuleset()) or "PVE",
            }
            if syncedPve.victim then syncedPve.victim.realm = syncedPve.realm end

            WoWKillboardDB.pveDeaths[deathId] = syncedPve

            -- Frontline Kill Banner UI alert for PvE casualty
            if KB.UI and KB.UI.ShowKillBanner then
                KB.UI:ShowKillBanner(syncedPve)
            end

            if KB.UI and KB.UI.RefreshIfVisible then
                KB.UI:RefreshIfVisible()
            end
        end

    elseif msgType == "BNT" and #parts >= 6 then
        local bntId = parts[2]
        WoWKillboardBounties = WoWKillboardBounties or {}
        local isNew = not WoWKillboardBounties[bntId]
        local tName = parts[3]
        local tClass = parts[4]
        local amtCopper = tonumber(parts[5]) or 0
        local pName = parts[6]
        local myRealm = (GetRealmName and GetRealmName()) or ""

        if isNew then
            WoWKillboardBounties[bntId] = {
                id = bntId,
                targetName = tName,
                targetClass = tClass,
                targetFaction = "Unknown",
                amountCopper = amtCopper,
                amountGold = math.floor(amtCopper / 10000),
                placerName = pName,
                realm = myRealm,
                status = KB.STATUS.ACTIVE,
                timestamp = time(),
            }

            local myName = UnitName("player") or ""
            if not (KB.Utils and KB.Utils.IsSelfSender and KB.Utils.IsSelfSender(pName, myName)) then
                local goldStr = (KB.Utils and KB.Utils.FormatMoney and KB.Utils.FormatMoney(amtCopper)) or (tostring(math.floor(amtCopper / 10000)) .. "g")
                SafePrint(string.format("|cffffd700[WoWKB Bounty Alert]|r |cffffffff%s|r declared a %s Mark of Spite on |cffff3333%s|r!",
                    pName, goldStr, tName))
                if KB.BountyEngine and KB.BountyEngine.ShowAlert then
                    KB.BountyEngine:ShowAlert(string.format("NEW BOUNTY: %s placed %s on %s!", pName, goldStr, tName), 1, 0.84, 0)
                end
                local s = WoWKillboardSettings or KB.DefaultSettings
                if (s.alertMode == "SOUND_AND_BANNER" or (s.alertMode ~= "BANNER_ONLY" and s.alertMode ~= "OFF" and s.soundAlerts ~= false)) then
                    if KB.SoundAlerts and KB.SoundAlerts.BOUNTY_CLAIMED then
                        PlaySound(KB.SoundAlerts.BOUNTY_CLAIMED, "Master")
                    end
                end
            end

            if KB.UI and KB.UI.RefreshIfVisible then
                KB.UI:RefreshIfVisible()
            end
        end

    elseif msgType == "SOS" and #parts >= 12 then
        local beaconData = {
            id = parts[2],
            character_name = parts[3],
            character_class = parts[4],
            character_level = tonumber(parts[5]) or 60,
            guild_name = parts[6],
            faction = parts[7],
            zone = parts[8],
            subzone = parts[9],
            coord_x = tonumber(parts[10]) or 0,
            coord_y = tonumber(parts[11]) or 0,
            hostile_count = tonumber(parts[12]) or 1,
            hostile_names = parts[13] or "Hostiles",
            timestamp = tonumber(parts[14]) or time(),
            status = "ACTIVE",
        }
        if KB.Reinforcements and KB.Reinforcements.OnIncomingDistress then
            KB.Reinforcements:OnIncomingDistress(beaconData)
        end

    elseif msgType == "SOS_RES" and #parts >= 2 then
        local charName = parts[2]
        if WoWKillboardDistress then
            for _, b in pairs(WoWKillboardDistress) do
                if b.character_name == charName and b.status == "ACTIVE" then
                    b.status = "RESOLVED"
                end
            end
        end
        if KB.UI and KB.UI.ReinforcementDialog and KB.UI.ReinforcementDialog.CurrentBeacon then
            if KB.UI.ReinforcementDialog.CurrentBeacon.character_name == charName then
                if InCombatLockdown() then
                    KB.UI.ReinforcementDialog:SetAlpha(0)
                    KB.UI.PendingHides = KB.UI.PendingHides or {}
                    table.insert(KB.UI.PendingHides, KB.UI.ReinforcementDialog)
                else
                    KB.UI.ReinforcementDialog:Hide()
                end
            end
        end

    elseif msgType == "EVT" and #parts >= 6 then
        local title = parts[3]
        local guild = parts[4]
        local creator = parts[5]
        local zone = parts[6]
        local timeStr = parts[7] or "NOW"
        if KB.Utils and KB.Utils.SafePrint then
            KB.Utils.SafePrint(string.format("|cff00ccff[GUILD EVENT]|r |cffffd100%s|r in |cffffffff%s|r announced by |cff00ff00%s|r (<%s>)! Time: %s.",
                title, zone, creator, guild, timeStr))
        elseif not InCombatLockdown() and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ccff[GUILD EVENT]|r |cffffd100%s|r in |cffffffff%s|r announced by |cff00ff00%s|r (<%s>)! Time: %s.",
                title, zone, creator, guild, timeStr))
        end

    elseif msgType == "SPT" and #parts >= 14 then
        local sighting = {
            id = parts[2],
            reporter_name = parts[3],
            reporter_guild = parts[4],
            target_name = parts[5],
            target_class = parts[6],
            target_level = tonumber(parts[7]) or 60,
            target_guild = parts[8],
            target_faction = parts[9],
            zone = parts[10],
            subzone = parts[11],
            coord_x = tonumber(parts[12]) or 0,
            coord_y = tonumber(parts[13]) or 0,
            notes = parts[14] or "Hostile spotted",
            timestamp = tonumber(parts[15]) or time(),
        }
        if KB.IntelScanner and KB.IntelScanner.OnIncomingSighting then
            KB.IntelScanner:OnIncomingSighting(sighting)
        end

    elseif msgType == "TEST_CASUALTY" and #parts >= 10 then
        local subMode = parts[2] or "PVE"
        local testId = parts[3] or ("TEST-" .. time())
        local kName = parts[4] or "Defias Pillager"
        local kClass = parts[5] or "MAGE"
        local kLvl = tonumber(parts[6]) or 0
        local kSpell = parts[7] or "Combat Strike"
        local kDmg = tonumber(parts[8]) or 0
        local vName = parts[9] or sender or "Combatant"
        local vClass = parts[10] or "WARRIOR"
        local vLvl = tonumber(parts[11]) or 0
        local vGuild = parts[12] or "None"
        local vFaction = parts[13] or "Unknown"
        local zone = parts[14] or "Wilderness"
        local subZone = parts[15] or ""

        local isPve = (subMode == "PVE")
        local testKM = {
            killId = testId,
            timestamp = time(),
            isTest = true,
            isPveDeath = isPve,
            isSolo = not isPve,
            npc = isPve and { name = kName, spell = kSpell, damage = kDmg } or nil,
            killer = {
                name = kName,
                class = kClass,
                level = kLvl,
                guild = isPve and "Wilderness Threat" or "Enemy Guild",
                faction = isPve and "Monster" or "Enemy",
                spell = kSpell,
                damage = kDmg,
            },
            victim = {
                name = vName,
                class = vClass,
                level = vLvl,
                guild = vGuild,
                faction = vFaction,
            },
            location = { zone = zone, subZone = subZone, x = 0, y = 0 },
        }
        S:OnIncomingTestCasualty(testKM, sender)

    elseif msgType == "SYS_ALERT" and #parts >= 4 then
        local alertSender = parts[2]
        local alertType = parts[3]
        local alertMsg = table.concat(parts, ":", 4)
        S:OnIncomingAdminAlert(alertSender, alertType, alertMsg)

    elseif msgType == "VER" and #parts >= 2 then
        local peerVer = parts[2]
        S:CheckPeerVersion(peerVer, sender)
    end
end

-- Process incoming standardized casualty alert from party, guild, raid, or realm channel
function S:OnIncomingChannelCasualty(text, sender)
    if not text or type(text) ~= "string" or IsSecret(text) then return end
    if not SafeFind(text, "^%[WoWKB%] Casualty:") then return end
    local myName = UnitName("player")
    local isSelf = (KB.Utils and KB.Utils.IsSelfSender and KB.Utils.IsSelfSender(sender, myName))
    if isSelf then return end

    local isTestMsg = (SafeFind(text, "%[TEST") ~= nil) or (SafeFind(text, "Simulation") ~= nil) or (SafeFind(text, "TEST SIMULATION") ~= nil)

    -- Clean trailing tags and periods
    local cleanText = text
    if SafeFind(cleanText, "%[TEST") or SafeFind(cleanText, "%[test") then
        cleanText = SafeGsub(cleanText, "%s*%[.-%]%s*$", "")
    end
    cleanText = SafeGsub(SafeGsub(cleanText, "%.$", ""), "%s+$", "")

    -- Format C: [WoWKB] Casualty: <victim> (Lvl <lvl> <class>) killed by <killer> (<spell>) in <location>
    local vName, vLvl, vClass, kName, spellName, locStr = SafeMatch(cleanText, "^%[WoWKB%] Casualty:%s*(.-)%s*%(Lvl%s*(%d+)%s*(.-)%)%s*killed by%s*(.-)%s*%((.-)%)%s*in%s*(.-)$")
    if not vName or not kName then
        vName, vLvl, vClass, kName, locStr = SafeMatch(cleanText, "^%[WoWKB%] Casualty:%s*(.-)%s*%(Lvl%s*(%d+)%s*(.-)%)%s*killed by%s*(.-)%s*in%s*(.-)$")
        spellName = "Combat Strike"
    end
    if not vName or not kName then
        vName, kName, locStr = SafeMatch(cleanText, "^%[WoWKB%] Casualty:%s*(.-)%s*killed by%s*(.-)%s*in%s*(.-)$")
        vLvl = 60
        vClass = "WARRIOR"
        spellName = "Combat Strike"
    end
    if not vName or not kName then return end

    vLvl = tonumber(vLvl) or 0
    local now = time()
    local seed = string.format("%s_%s_%s_%s", tostring(now), tostring(kName), tostring(vName), tostring(locStr or ""))
    local deathId = (isTestMsg and "TEST-CHANNEL-" or "PVE-") .. (KB.Utils and KB.Utils.Hash and KB.Utils.Hash(seed) or tostring(now))

    local channelPve = {
        deathId = deathId,
        timestamp = now,
        isTest = isTestMsg,
        isPveDeath = true,
        npc = {
            name = kName,
            id = 0,
            guid = "CREATURE",
            spell = spellName or "Combat Strike",
            damage = 0,
        },
        killer = {
            guid = "CREATURE",
            name = kName,
            level = 0,
            class = "WARRIOR",
            guild = "Wilderness Threat",
            faction = "Monster",
            partySize = 1,
            damageDone = 0,
            spell = spellName or "Combat Strike",
        },
        victim = {
            guid = "UNKNOWN",
            name = vName,
            level = vLvl,
            class = (vClass and vClass ~= "") and vClass:upper() or "WARRIOR",
            guild = "None",
            faction = "Unknown",
        },
        location = {
            mapId = 0,
            zone = locStr or "Wilderness",
            subZone = "",
            x = 0,
            y = 0,
        },
        realm = (GetRealmName and GetRealmName()) or "",
        ruleset = (KB.Utils and KB.Utils.GetRealmRuleset and KB.Utils.GetRealmRuleset()) or "PVE",
    }
    if channelPve.victim then channelPve.victim.realm = channelPve.realm end

    if isTestMsg then
        S:OnIncomingTestCasualty(channelPve, sender)
        return
    end

    WoWKillboardDB = WoWKillboardDB or { kills = {}, stats = {}, pveDeaths = {} }
    WoWKillboardDB.pveDeaths = WoWKillboardDB.pveDeaths or {}

    if not WoWKillboardDB.pveDeaths[deathId] then
        WoWKillboardDB.pveDeaths[deathId] = channelPve

        if KB.UI and KB.UI.ShowKillBanner then
            KB.UI:ShowKillBanner(channelPve)
        end

        if KB.UI and KB.UI.RefreshIfVisible then
            KB.UI:RefreshIfVisible()
        end
    end
end

-- Process incoming faction bounty alert from channel, guild, raid, or party
function S:OnIncomingChannelBounty(text, sender)
    if not text or type(text) ~= "string" or IsSecret(text) then return end
    if not SafeFind(text, "^%[WoWKB Bounty Alert%]") then return end
    local myName = UnitName("player")
    local isSelf = (KB.Utils and KB.Utils.IsSelfSender and KB.Utils.IsSelfSender(sender, myName))
    if isSelf then return end

    local pName, amtStr, tName, tClass = SafeMatch(text, "^%[WoWKB Bounty Alert%]%s*(.-)%s+placed a%s+(.-)%s+Mark of Spite on%s+(.-)%s*%(?(.-)%)?!")
    if not pName or not tName then
        pName, amtStr, tName = SafeMatch(text, "^%[WoWKB Bounty Alert%]%s*(.-)%s+placed a%s+(.-)%s+Mark of Spite on%s+(.-)%s*!$")
    end
    if not pName or not tName then return end

    local myLower = myName and SafeLower(myName) or ""
    if SafeLower(pName) == myLower then return end

    local seed = string.format("BNT_%s_%s", pName, tName)
    local bntId = "BNT-" .. (KB.Utils and KB.Utils.Hash and KB.Utils.Hash(seed) or tostring(time()))

    WoWKillboardBounties = WoWKillboardBounties or {}
    local isNew = not WoWKillboardBounties[bntId]

    local myRealm = (GetRealmName and GetRealmName()) or ""
    if not WoWKillboardBounties[bntId] then
        WoWKillboardBounties[bntId] = {
            id = bntId,
            targetName = tName,
            targetClass = (tClass and tClass ~= "") and tClass:upper() or "UNKNOWN",
            targetFaction = "Unknown",
            amountCopper = 0,
            amountGold = 0,
            placerName = pName,
            realm = myRealm,
            status = KB.STATUS.ACTIVE,
            timestamp = time(),
        }
    end

    if isNew then
        SafePrint(string.format("|cffffd700[WoWKB Bounty Alert]|r |cffffffff%s|r declared a %s Mark of Spite on |cffff3333%s|r!",
            pName, amtStr or "bounty", tName))
        if KB.BountyEngine and KB.BountyEngine.ShowAlert then
            KB.BountyEngine:ShowAlert(string.format("NEW BOUNTY: %s on %s!", amtStr or "Contract", tName), 1, 0.84, 0)
        end
        local s = WoWKillboardSettings or KB.DefaultSettings
        if (s.alertMode == "SOUND_AND_BANNER" or (s.alertMode ~= "BANNER_ONLY" and s.alertMode ~= "OFF" and s.soundAlerts ~= false)) then
            if KB.SoundAlerts and KB.SoundAlerts.BOUNTY_CLAIMED then
                PlaySound(KB.SoundAlerts.BOUNTY_CLAIMED, "Master")
            end
        end
    end

    if KB.UI and KB.UI.RefreshIfVisible then
        KB.UI:RefreshIfVisible()
    end
end

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_ADDON" or event == "CHAT_MSG_ADDON_LOGGED" then
        local prefix, message, channel, sender = ...
        pcall(function()
            S:OnAddonMessage(prefix, message, channel, sender)
        end)
    elseif event == "CHAT_MSG_CHANNEL" or event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER" or
           event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER" or event == "CHAT_MSG_GUILD" or
           event == "CHAT_MSG_OFFICER" then
        local text, sender, _, channelName, _, _, _, channelNumber, channelBase = ...
        if not text or type(text) ~= "string" or IsSecret(text) then return end

        local shouldProcess = true
        if event == "CHAT_MSG_CHANNEL" then
            local isKBChannel = false
            if channelBase and not IsSecret(channelBase) and SafeFind(SafeLower(channelBase), "wowkillboard", 1, true) then
                isKBChannel = true
            elseif channelName and not IsSecret(channelName) and SafeFind(SafeLower(channelName), "wowkillboard", 1, true) then
                isKBChannel = true
            end
            -- Allow channel processing if it's the WoWKillboard channel OR if text explicitly starts with WoWKB tags
            if not isKBChannel and not (SafeFind(text, "^%[WoWKB Alert%]") or SafeFind(text, "^%[WoWKB Update%]") or SafeFind(text, "^%[WoWKB%] Casualty:") or SafeFind(text, "^%[WoWKB Bounty Alert%]")) then
                shouldProcess = false
            end
        end

        if shouldProcess then
            if SafeFind(text, "^%[WoWKB Alert%]") or SafeFind(text, "^%[WoWKB Update%]") then
                pcall(function()
                    local alertSender, alertMsg = SafeMatch(text, "^%[WoWKB %a+%]%s*(.-):%s*(.+)$")
                    if alertMsg then
                        S:OnIncomingAdminAlert(alertSender or sender, "UPDATE", alertMsg)
                    else
                        local alertBody = SafeMatch(text, "^%[WoWKB %a+%]%s*(.+)$")
                        if alertBody then
                            S:OnIncomingAdminAlert(sender, "UPDATE", alertBody)
                        end
                    end
                end)
            elseif SafeFind(text, "^%[WoWKB%] Casualty:") then
                pcall(function()
                    S:OnIncomingChannelCasualty(text, sender)
                end)
            elseif SafeFind(text, "^%[WoWKB Bounty Alert%]") then
                pcall(function()
                    S:OnIncomingChannelBounty(text, sender)
                end)
            end
        end
    elseif event == "CHAT_MSG_CHANNEL_NOTICE" or event == "CHAT_MSG_CHANNEL_NOTICE_USER" then
        pcall(function(...)
            S:OnChannelNotice(...)
        end, ...)
    elseif event == "PLAYER_ENTERING_WORLD" then
        pcall(function()
            S:Init()
            S:ApplyChatVisibility("WoWKillboard")
            if C_Timer and C_Timer.After then
                C_Timer.After(2.0, function() S:JoinGlobalChannel() end)
                C_Timer.After(5.0, function() S:JoinGlobalChannel() end)
                C_Timer.After(7.0, function() S:BroadcastVersion() end)
            end
        end)
    elseif event == "GROUP_ROSTER_UPDATE" then
        pcall(function()
            if C_Timer and C_Timer.After then
                C_Timer.After(3.0, function() S:BroadcastVersion() end)
            end
        end)
    elseif event == "PLAYER_REGEN_ENABLED" then
        if S.pendingNewVersion and not S.hasNotifiedNewVersion then
            local peerVer = S.pendingNewVersion
            S.pendingNewVersion = nil
            S:CheckPeerVersion(peerVer, "Deferred")
        end
        if not InCombatLockdown() then
            S:JoinGlobalChannel()
        end
    end
end)

frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("CHAT_MSG_ADDON_LOGGED")
frame:RegisterEvent("CHAT_MSG_CHANNEL")
frame:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")
frame:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE_USER")
frame:RegisterEvent("CHAT_MSG_PARTY")
frame:RegisterEvent("CHAT_MSG_PARTY_LEADER")
frame:RegisterEvent("CHAT_MSG_RAID")
frame:RegisterEvent("CHAT_MSG_RAID_LEADER")
frame:RegisterEvent("CHAT_MSG_GUILD")
frame:RegisterEvent("CHAT_MSG_OFFICER")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

-- Recurring housekeeping loop: maintains channel connection and chat window purity
if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(30, function()
        if InCombatLockdown and InCombatLockdown() then return end
        local id = S:GetChannelId("WoWKillboard")
        if not id or id <= 0 then
            S:JoinGlobalChannel()
        else
            S.channelIndex = id
            S:ApplyChatVisibility("WoWKillboard")
        end
    end)
end
