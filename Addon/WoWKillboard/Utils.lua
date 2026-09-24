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

-- Class colorizer
function U.ColorizeByClass(text, class)
    if not class then return text end
    class = string.upper(class)
    local colorHex = KB.ClassColors[class] or "FFFFFF"
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
