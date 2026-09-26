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
    if canaccessvalue and not canaccessvalue(val) then return false end
    if issecretvalue and issecretvalue(val) then return false end
    return true
end

function U.SafeString(val, fallback)
    if not U.CanAccess(val) then return fallback or "Unknown" end
    local str = tostring(val)
    if not U.CanAccess(str) then return fallback or "Unknown" end
    return str
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

    local flavorName = "WoW Forever"
    local flavorColor = "00e5ff" -- Tactical Cyan for Forever Beta

    if isBeta or isClassicBeta or (tocversion >= 11500 and tocversion < 11600) then
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

    return string.format("|cffffffffWoW Killboard|r |cff%s[%s • %s]|r", flavorColor, flavorName, realm)
end

-- Retrieve active player specialization (Cross-Client Parity)
function U.GetPlayerSpec()
    if type(GetSpecialization) == "function" and type(GetSpecializationInfo) == "function" then
        local specIndex = GetSpecialization()
        if specIndex then
            local _, specName = GetSpecializationInfo(specIndex)
            if specName and specName ~= "" then return specName end
        end
    end
    -- Classic Era / Vanilla / Forever talent points inspection
    if type(GetTalentTabInfo) == "function" and type(GetNumTalentTabs) == "function" then
        local maxPoints = -1
        local dominantSpec = nil
        local numTabs = GetNumTalentTabs() or 3
        for i = 1, numTabs do
            local name, _, pointsSpent = GetTalentTabInfo(i)
            if pointsSpent and pointsSpent > maxPoints then
                maxPoints = pointsSpent
                dominantSpec = name
            end
        end
        if dominantSpec and maxPoints > 0 then
            return dominantSpec
        end
    end
    return nil
end
