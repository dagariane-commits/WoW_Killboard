--[[
    WoWKillboard - Utils.lua
    Cryptographic hash generator, formatting, coordinate math, and unit helpers.
]]

WoWKillboard = WoWKillboard or {}
local KB = WoWKillboard
KB.Utils = {}
local U = KB.Utils

-- Secret Values Guard (The War Within / 11.0+ / Modern Classic Architecture)
function U.CanAccess(val)
    if val == nil then return false end
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, val)
        if ok and secret then return false end
    end
    if type(issecrettable) == "function" then
        local ok, secretTable = pcall(issecrettable, val)
        if ok and secretTable then return false end
    end
    if type(canaccessvalue) == "function" then
        local ok, canAccess = pcall(canaccessvalue, val)
        if ok and not canAccess then return false end
    end
    -- Ultimate runtime check: if comparing val with itself or empty string errors, it is a secret value
    local ok1 = pcall(function() return val == val end)
    if not ok1 then return false end
    local ok2 = pcall(function() return val ~= "" end)
    if not ok2 then return false end
    return true
end

function U.SafeString(val, fallback)
    if not U.CanAccess(val) then return fallback or "Unknown" end
    local str = tostring(val)
    if not U.CanAccess(str) then return fallback or "Unknown" end
    return str
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

-- Clean combatant name: strip realm, rank prefixes, punctuation, and trim
function U.CleanCombatantName(name)
    if not name or not U.CanAccess(name) or type(name) ~= "string" then return name end
    local clean = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")
    local base = clean:match("^([^-]+)") or clean
    for _, prefix in ipairs(PVP_RANK_PREFIXES) do
        base = base:gsub("^" .. prefix, "")
    end
    base = base:gsub("[%.,!%?:;]", "")
    return base:match("^%s*(.-)%s*$") or name
end

-- Normalize combatant name for canonical dictionary lookup
function U.NormalizeCombatantName(name)
    local clean = U.CleanCombatantName(name)
    if clean and clean ~= "" then
        return clean:lower()
    end
    return nil
end

-- Count entries in a hash table
function U.TableLength(t)
    if not t or type(t) ~= "table" then return 0 end
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

-- Simple FNV-1a 32-bit Hash for deterministic Kill IDs
function U.Hash(str)
    local hash = 2166136261
    for i = 1, #str do
        local byte = string.byte(str, i)
        hash = bit.bxor(hash, byte)
        hash = (hash * 16777619) % 4294967296
    end
    return string.format("%08x", hash)
end

-- Generate a unique, deterministic Kill ID
function U.GenerateKillId(timestamp, killerGUID, victimGUID, mapId)
    local seed = string.format("%s_%s_%s_%s", tostring(timestamp or 0), tostring(killerGUID or ""), tostring(victimGUID or ""), tostring(mapId or 0))
    return "KB-" .. U.Hash(seed)
end

-- Format large numbers (e.g. 142500 -> "142.5k", 2500000 -> "2.50M")
function U.FormatNumber(val)
    val = tonumber(val) or 0
    if val >= 1000000 then
        return string.format("%.2fM", val / 1000000)
    elseif val >= 1000 then
        return string.format("%.1fk", val / 1000)
    else
        return tostring(math.floor(val))
    end
end

-- Format gold in WoW copper
function U.FormatMoney(copper)
    copper = tonumber(copper) or 0
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop = copper % 100
    if gold > 0 then
        return string.format("|cffffd700%dg|r |cffc7c7cf%ds|r", gold, silver)
    elseif silver > 0 then
        return string.format("|cffc7c7cf%ds|r |cffeda55f%dc|r", silver, cop)
    else
        return string.format("|cffeda55f%dc|r", cop)
    end
end

-- Relative time formatting
function U.FormatTimeAgo(epoch)
    local now = time()
    local diff = math.max(0, now - (tonumber(epoch) or now))
    if diff < 60 then
        return string.format("%ds ago", diff)
    elseif diff < 3600 then
        return string.format("%dm ago", math.floor(diff / 60))
    elseif diff < 86400 then
        return string.format("%dh ago", math.floor(diff / 3600))
    else
        return string.format("%dd ago", math.floor(diff / 86400))
    end
end

-- Class colorizer (Guaranteed Blizzard & Custom Class Colors parity)
function U.ColorizeByClass(text, class)
    if not text then return "" end
    if not class or class == "" then return text end
    class = string.upper(class)
    if class == "UNKNOWN" then
        return string.format("|cffc7c7cf%s|r", text)
    end

    local colorHex = nil
    if RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        if c.colorStr then
            colorHex = c.colorStr:gsub("^ff", ""):gsub("^FF", "")
        elseif c.r and c.g and c.b then
            colorHex = string.format("%02x%02x%02x", math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255))
        end
    end
    if not colorHex or colorHex == "" then
        colorHex = KB.ClassColors[class] or "C7C7CF"
    end
    return string.format("|cff%s%s|r", colorHex, text)
end

-- Faction colorizer
function U.ColorizeByFaction(text, faction)
    local colorHex = KB.FactionColors[faction] or "FFFFFF"
    return string.format("|cff%s%s|r", colorHex, text)
end

-- Convert Hex color string ("RRGGBB" or "AARRGGBB") to RGB (0.0 - 1.0)
function U.HexToRGB(hex)
    if not hex or type(hex) ~= "string" then return 1.0, 0.82, 0.0 end
    hex = hex:gsub("#", ""):gsub("^ff", ""):gsub("^FF", "")
    if #hex < 6 then return 1.0, 0.82, 0.0 end
    local r = tonumber(hex:sub(1, 2), 16) or 255
    local g = tonumber(hex:sub(3, 4), 16) or 210
    local b = tonumber(hex:sub(5, 6), 16) or 0
    return r / 255, g / 255, b / 255
end

-- Dynamic Accent & Highlight Color Engine (User Configurable: Gold, Class Color, Custom)
function U.GetAccentColor()
    local s = WoWKillboardSettings or (KB and KB.DefaultSettings) or {}
    local mode = s.accentColorMode or "gold"
    if mode == "class" then
        local _, pClass = UnitClass("player")
        if pClass then
            pClass = pClass:upper()
            if RAID_CLASS_COLORS and RAID_CLASS_COLORS[pClass] then
                local c = RAID_CLASS_COLORS[pClass]
                local r, g, b = c.r or 1.0, c.g or 0.82, c.b or 0.0
                local hex = string.format("%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
                return r, g, b, hex
            elseif KB.ClassColors and KB.ClassColors[pClass] then
                local hex = KB.ClassColors[pClass]
                local r, g, b = U.HexToRGB(hex)
                return r, g, b, hex
            end
        end
    elseif mode == "custom" and s.customAccentColor then
        local c = s.customAccentColor
        local r, g, b = c[1] or 1.0, c[2] or 0.82, c[3] or 0.0
        local hex = string.format("%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
        return r, g, b, hex
    end
    -- Default: Classic Gold #FFD100
    return 1.0, 0.82, 0.0, "ffd100"
end

function U.GetAccentHex()
    local _, _, _, hex = U.GetAccentColor()
    return hex or "ffd100"
end

function U.GetAccentCode()
    local _, _, _, hex = U.GetAccentColor()
    return "|cff" .. (hex or "ffd100")
end

KB.GetAccentColor = U.GetAccentColor
KB.GetAccentHex = U.GetAccentHex
KB.GetAccentCode = U.GetAccentCode
WoWKB = WoWKillboard
WoWKB.AccentColor = U.GetAccentColor

local CLASS_TITLE_MAP = {
    ["WARRIOR"]     = "Warrior",
    ["PALADIN"]     = "Paladin",
    ["HUNTER"]      = "Hunter",
    ["ROGUE"]       = "Rogue",
    ["PRIEST"]      = "Priest",
    ["DEATHKNIGHT"] = "Death Knight",
    ["SHAMAN"]      = "Shaman",
    ["MAGE"]        = "Mage",
    ["WARLOCK"]     = "Warlock",
    ["MONK"]        = "Monk",
    ["DRUID"]       = "Druid",
    ["DEMONHUNTER"] = "Demon Hunter",
    ["EVOKER"]      = "Evoker",
}

-- Return standardized title-cased class name for telemetry
function U.GetClassTitle(class)
    if not class or not U.CanAccess(class) or class == "" or class == "UNKNOWN" then
        return "Adventurer"
    end
    local raw = tostring(class):upper():gsub("%s+", "")
    if CLASS_TITLE_MAP[raw] then
        return CLASS_TITLE_MAP[raw]
    end
    local s = tostring(class)
    return s:sub(1, 1):upper() .. s:sub(2):lower()
end

-- Retrieve normalized map coordinates and zone names safely
function U.GetPlayerLocation()
    local mapId = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local x, y = 0, 0
    if mapId and U.CanAccess(mapId) then
        local pos = C_Map.GetPlayerMapPosition(mapId, "player")
        if pos and U.CanAccess(pos) and pos.GetXY then
            local px, py = pos:GetXY()
            if U.CanAccess(px) and U.CanAccess(py) then
                x, y = px, py
            end
        end
    end

    local zoneName = GetZoneText()
    zoneName = U.CanAccess(zoneName) and zoneName or "Unknown Zone"
    local subZone = GetSubZoneText()
    subZone = U.CanAccess(subZone) and subZone or ""

    return {
        mapId = (mapId and U.CanAccess(mapId)) and mapId or 0,
        zone = zoneName,
        subZone = subZone,
        x = math.floor((x or 0) * 10000) / 100,  -- percentage with 2 decimals
        y = math.floor((y or 0) * 10000) / 100,
    }
end

-- Convenient unpack helper for GPS coordinates
function U.GetGPSCoordinates()
    local loc = U.GetPlayerLocation()
    return loc.mapId, loc.zone, loc.subZone, loc.x, loc.y
end

-- Serialize a table to a Lua string (for export/sync)
function U.Serialize(t)
    if type(t) ~= "table" then
        if type(t) == "string" then return string.format("%q", t) end
        return tostring(t)
    end
    local s = "{"
    for k, v in pairs(t) do
        local keyStr
        if type(k) == "string" and k:match("^[%a_][%w_]*$") then
            keyStr = k
        else
            keyStr = "[" .. U.Serialize(k) .. "]"
        end
        s = s .. keyStr .. "=" .. U.Serialize(v) .. ","
    end
    return s .. "}"
end

-- Retrieve active WoW client flavor and build
function U.GetClientFlavor()
    local version, build, date, tocversion
    if GetBuildInfo then
        version, build, date, tocversion = GetBuildInfo()
    end
    tocversion = tonumber(tocversion) or 11500
    if tocversion < 20000 then
        return "CLASSIC_ERA", version, tocversion
    elseif tocversion < 30000 then
        return "TBC", version, tocversion
    elseif tocversion < 40000 then
        return "WOTLK", version, tocversion
    elseif tocversion < 50000 then
        return "CATA", version, tocversion
    elseif tocversion < 60000 then
        return "MOP", version, tocversion
    elseif tocversion < 70000 then
        return "WOD", version, tocversion
    elseif tocversion < 80000 then
        return "LEGION", version, tocversion
    elseif tocversion < 90000 then
        return "BFA", version, tocversion
    elseif tocversion < 100000 then
        return "SHADOWLANDS", version, tocversion
    elseif tocversion < 110000 then
        return "DRAGONFLIGHT", version, tocversion
    else
        return "RETAIL", version, tocversion
    end
end

-- Retrieve active WoW client flavor and realm label for UI Header
function U.GetClientFlavorTitle()
    local realm = (GetRealmName and GetRealmName()) or "PvP"
    local version, build, date, tocversion
    if GetBuildInfo then
        version, build, date, tocversion = GetBuildInfo()
    end
    tocversion = tonumber(tocversion) or 11500

    local isBeta = (type(IsTestBuild) == "function" and IsTestBuild())
    local isClassicBeta = (version and (version:lower():find("beta") or version:lower():find("ptr")))
    local isForeverRealm = (realm and realm:lower():find("forever"))

    local flavorName = "Classic Era"
    local flavorColor = "d97706" -- Amber for Classic Era

    if isBeta or isClassicBeta or isForeverRealm then
        flavorName = "WoW Forever"
        flavorColor = "00e5ff"
    elseif tocversion >= 110000 then
        flavorName = "Modern Retail"
        flavorColor = "a855f7"
    elseif tocversion >= 20000 then
        flavorName = "Classic Progression"
        flavorColor = "eab308"
    else
        flavorName = "Classic Era"
        flavorColor = "d97706"
    end

    return string.format("|cffffffffWoW Killboard|r |cff%s[%s - %s]|r", flavorColor, flavorName, realm)
end

-- Retrieve active realm ruleset: "PVE", "PVP", "HARDCORE", or "RP"
function U.GetRealmRuleset()
    local realm = (GetRealmName and GetRealmName()) or ""
    -- Check per-realm user override first (prevents cross-realm preference stomping)
    if WoWKillboardDB and WoWKillboardDB.realmRulesets and realm ~= "" and WoWKillboardDB.realmRulesets[realm] then
        local r = tostring(WoWKillboardDB.realmRulesets[realm]):upper()
        if r == "PVE" or r == "PVP" or r == "HARDCORE" or r == "RP" then
            return r
        end
    end

    -- Auto-detect from realm name and known realm classifications
    local rLower = realm:lower():gsub("%s+", "")
    if rLower:find("hardcore") or rLower:find("hc") or rLower:find("defiaspillager") or rLower:find("skullrock") or rLower:find("stitches") or rLower:find("nekrosh") or rLower:find("soulseeker") or rLower:find("doomhowl") then
        return "HARDCORE"
    elseif rLower:find("pve") or rLower:find("normal") or rLower:find("wildgrowth") or rLower:find("mankrik") or rLower:find("pagle") or rLower:find("atiesh") or rLower:find("ashkandi") or rLower:find("westfall") or rLower:find("mirageraceway") or rLower:find("pyrewood") or rLower:find("nethergarde") or rLower:find("auberdine") or rLower:find("everlook") or rLower:find("chromie") then
        return "PVE"
    elseif rLower:find("roleplay") or rLower:find("lavalash") or rLower:find("bloodsail") or rLower:find("celebras") or rLower:find("hydraxian") then
        return "RP"
    elseif rLower:find("pvp") or rLower:find("crusaderstrike") or rLower:find("lonewolf") or rLower:find("livingflame") or rLower:find("chaosbolt") or rLower:find("whitemane") or rLower:find("faerlina") or rLower:find("benediction") or rLower:find("grobbulus") or rLower:find("firemaw") or rLower:find("gehennas") then
        return "PVP"
    end

    if WoWKillboardDB and WoWKillboardDB.campaignRuleset then
        local r = tostring(WoWKillboardDB.campaignRuleset):upper()
        if r == "PVE" or r == "PVP" or r == "HARDCORE" or r == "RP" then
            return r
        end
    end
    return "PVP"
end

-- Check if active ruleset is PvE / Hardcore
function U.IsPveRuleset()
    local r = U.GetRealmRuleset()
    return (r == "PVE" or r == "HARDCORE")
end

-- Retrieve standardized client flavor subtitle for UI Header (Cross-Client Parity)
-- Format: WoW / Game Version (Forever) / Realm (PVP) / Ruleset [PvE] / Status (Live / Beta) / Version
function U.GetClientFlavorSubtitle()
    local realm = (GetRealmName and GetRealmName()) or "PvP"
    local version, build, date, tocversion
    if GetBuildInfo then
        version, build, date, tocversion = GetBuildInfo()
    end
    tocversion = tonumber(tocversion) or 11500

    local isBeta = (type(IsTestBuild) == "function" and IsTestBuild())
    local isClassicBeta = (version and (version:lower():find("beta") or version:lower():find("ptr")))
    local isForeverRealm = (realm and realm:lower():find("forever"))

    local gameVersion = "Classic Era"
    local status = "Live"
    local gameColor = "d97706" -- Amber
    local statusColor = "60a5fa" -- Blue

    if isBeta or isClassicBeta or isForeverRealm then
        gameVersion = "Forever"
        status = "Beta"
        gameColor = "00e5ff"
        statusColor = "00ff88"
    elseif tocversion >= 110000 then
        gameVersion = "Retail"
        status = isBeta and "Beta" or "Live"
        gameColor = "a855f7"
        statusColor = isBeta and "00ff88" or "60a5fa"
    elseif tocversion >= 20000 then
        gameVersion = "Progression"
        status = isBeta and "Beta" or "Live"
        gameColor = "eab308"
        statusColor = isBeta and "00ff88" or "60a5fa"
    else
        gameVersion = "Classic Era"
        status = isBeta and "Beta" or "Live"
        gameColor = "d97706"
        statusColor = isBeta and "00ff88" or "60a5fa"
    end

    local ruleset = U.GetRealmRuleset()
    local rulesetTag = "|cffef4444[PvP]|r"
    if ruleset == "PVE" then
        rulesetTag = "|cff10b981[PvE]|r"
    elseif ruleset == "HARDCORE" then
        rulesetTag = "|cfff59e0b[Hardcore]|r"
    elseif ruleset == "RP" then
        rulesetTag = "|cffc084fc[RP]|r"
    end

    local verStr = KB.Version or "1.0.0"
    return string.format(
        "|cffffd100WoW|r / |cff%s%s|r / |cffc7b28c%s|r / %s / |cff%s%s|r / |cff888888v%s|r",
        gameColor, gameVersion, realm, rulesetTag, statusColor, status, verStr
    )
end

-- Retrieve active player specialization (Cross-Client Parity)
function U.GetPlayerSpec()
    -- Modern Retail / Cataclysm / MoP talent system
    if type(GetSpecialization) == "function" and type(GetSpecializationInfo) == "function" then
        local ok, specIndex = pcall(GetSpecialization)
        if ok and specIndex and type(specIndex) == "number" then
            local ok2, _, specName = pcall(GetSpecializationInfo, specIndex)
            if ok2 and specName and type(specName) == "string" and specName ~= "" then
                return specName
            end
        end
    end

    -- Classic Era / Vanilla / Forever / Wrath talent points inspection
    if type(GetTalentTabInfo) == "function" and type(GetNumTalentTabs) == "function" then
        local maxPoints = -1
        local dominantSpec = nil
        local okNum, numTabs = pcall(GetNumTalentTabs)
        numTabs = (okNum and type(numTabs) == "number") and numTabs or 3

        for i = 1, numTabs do
            local okTab, ret1, ret2, ret3, ret4, ret5 = pcall(GetTalentTabInfo, i)
            if okTab then
                local tabName, pointsSpent
                -- Modern Classic Era / Retail engine signature:
                -- (id, name, description, iconTexture, pointsSpent, background, ...)
                if type(ret2) == "string" and (type(ret5) == "number" or tonumber(ret5)) then
                    tabName = ret2
                    pointsSpent = tonumber(ret5)
                -- Legacy 1.12 Vanilla signature:
                -- (name, iconTexture, pointsSpent, fileName)
                elseif type(ret1) == "string" and (type(ret3) == "number" or tonumber(ret3)) then
                    tabName = ret1
                    pointsSpent = tonumber(ret3)
                else
                    tabName = (type(ret2) == "string" and ret2 ~= "") and ret2 or (type(ret1) == "string" and ret1 or nil)
                    pointsSpent = tonumber(ret5) or tonumber(ret3) or 0
                end

                pointsSpent = tonumber(pointsSpent) or 0
                if pointsSpent > maxPoints then
                    maxPoints = pointsSpent
                    dominantSpec = tabName
                end
            end
        end

        if dominantSpec and type(dominantSpec) == "string" and dominantSpec ~= "" and maxPoints > 0 then
            return dominantSpec
        end
    end

    return nil
end

-- Taint-Safe Chat Output Layer (Guardrail 1: Zero Blizzard UI Taint)
-- Circumvents Blizzard_PrintHandler / SecureTypes.lua taint by queuing combat prints until out of combat
KB.PrintQueue = KB.PrintQueue or {}

function U.SafePrint(...)
    local n = select("#", ...)
    if n == 0 then return end
    local pieces = {}
    for i = 1, n do
        local v = select(i, ...)
        table.insert(pieces, tostring(v))
    end
    local msg = table.concat(pieces, " ")
    if not U.CanAccess(msg) then return end

    if InCombatLockdown() then
        table.insert(KB.PrintQueue, msg)
        return
    end

    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(msg)
    end
end

function U.FlushPrintQueue()
    if InCombatLockdown() then return end
    if not KB.PrintQueue or #KB.PrintQueue == 0 then return end
    local queue = KB.PrintQueue
    KB.PrintQueue = {}
    for _, msg in ipairs(queue) do
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(msg)
        end
    end
end

-- Cross-Client Group and Raid Runtime Feature Detection (Guardrail 2: Cross-Client Parity)
function U.IsInRaid()
    if IsInRaid and IsInRaid() then return true end
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then return true end
    return false
end

function U.IsInGroup()
    if IsInGroup and IsInGroup() then return true end
    if GetNumGroupMembers and GetNumGroupMembers() > 0 then return true end
    if GetNumPartyMembers and GetNumPartyMembers() > 0 then return true end
    if U.IsInRaid() then return true end
    return false
end

-- Cross-Client Taint-Safe Addon Message Dispatcher
function U.SendAddonMessage(prefix, message, chatType, target)
    if not prefix or not message or not chatType then return end
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        pcall(C_ChatInfo.SendAddonMessage, prefix, message, chatType, target)
        return
    end
    if SendAddonMessage then
        pcall(SendAddonMessage, prefix, message, chatType, target)
        return
    end
end

-- Safe Self-Sender Check Immune to Lua Regex/Dash Magic Characters in Character or Realm Names
function U.IsSelfSender(sender, myName)
    if not sender or not myName then return false end
    if sender:lower() == myName:lower() then return true end
    local sLen = #myName
    if #sender > sLen and sender:sub(1, sLen):lower() == myName:lower() and sender:sub(sLen + 1, sLen + 1) == "-" then
        return true
    end
    local baseSender = sender:match("^([^-]+)") or sender
    local baseMyName = myName:match("^([^-]+)") or myName
    if baseSender:lower() == baseMyName:lower() then
        return true
    end
    return false
end


