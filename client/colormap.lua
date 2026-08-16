-- ============================================================
-- hexa_core — Colormap (ระบายสีอาณาเขตบนแผนที่)
-- ============================================================
-- ผูก hash ของโซน (state / district / region) เข้ากับ blip style
-- แล้วเกมจะวาดเส้นขอบ + สีพื้นให้เองทั้งบนมินิแมพและแผนที่ใหญ่
-- ตั้งค่าทั้งหมดอยู่ที่ Config.Colormap ใน config.lua
--
-- ไม่มี loop / ไม่มี thread — ทาสีครั้งเดียวตอน resource start แล้วจบ
-- สีที่ทาไว้ค้างอยู่กับ client จนกว่าจะถูกล้าง จึงต้องล้างคืนตอน resource stop
-- ไม่งั้น restart hexa_core แล้วสีเก่าจะค้างบนแผนที่ของคนที่อยู่ในเซิร์ฟ
--
-- ที่ดึงไปใช้:
--   exports['hexa_core']:SetZoneColor(zoneHash, color)  -- ทาสีโซนเดียว (ระหว่างเกม)
--   exports['hexa_core']:ResetZoneColor(zoneHash)       -- ล้างสีโซนเดียว
--   exports['hexa_core']:RefreshZoneColors()            -- ทาใหม่ทั้งหมดตาม Config
--   exports['hexa_core']:ClearZoneColors()              -- ล้างทุกโซนที่สคริปต์นี้ทาไว้

local APPLY_WANTED_REGION_STYLE  = 0x563FCB6620523917
local REMOVE_WANTED_REGION_STYLE = 0x6786D7AFAC3162B3

--- โซนที่ทาสีค้างไว้อยู่ตอนนี้ — ใช้เป็นรายการล้างตอน stop/refresh
--- (คีย์ = hash ของโซน) เก็บเฉพาะโซนที่สคริปต์นี้ทาเอง จะได้ไม่ไปล้างของ resource อื่น
local activeZones = {}

local function colormapConfig()
    return HexaCore.Config and HexaCore.Config.Colormap or nil
end

local function debugPrint(message)
    local cfg = colormapConfig()
    if cfg and cfg.Debug then
        print(('[hexa_core] [colormap] %s'):format(message))
    end
end

--- แปลงค่าที่รับมาให้เป็น hash 32 บิต — รับได้ทั้งตัวเลข (0x3B8DD21A) และสตริง ('BLIP_STYLE_...')
local function resolveHash(value)
    if type(value) == 'number' then
        return value & 0xFFFFFFFF
    end

    if type(value) == 'string' and value ~= '' then
        return GetHashKey(value) & 0xFFFFFFFF
    end

    return nil
end

--- แปลงค่า color ในคอนฟิกให้เป็น hash ของ blip style
--- รับได้ทั้งชื่อสีจาก Config.Colormap.Colors ('red') และชื่อ style ตรงๆ ('BLIP_STYLE_...')
local function resolveColor(color)
    local cfg = colormapConfig()
    local palette = cfg and cfg.Colors or nil

    if palette and type(color) == 'string' and palette[color] then
        return resolveHash(palette[color])
    end

    return resolveHash(color)
end

--- ล้างสีของโซนเดียว
local function resetZoneColor(zone)
    local zoneHash = resolveHash(zone)
    if not zoneHash then return false end

    Citizen.InvokeNative(REMOVE_WANTED_REGION_STYLE, zoneHash)
    activeZones[zoneHash] = nil
    debugPrint(('cleared zone 0x%08X'):format(zoneHash))

    return true
end

--- ทาสีโซนเดียว — color เป็นชื่อสีในพาเลตต์ หรือชื่อ/hash ของ blip style ก็ได้
local function setZoneColor(zone, color)
    local zoneHash = resolveHash(zone)
    local styleHash = resolveColor(color)

    if not zoneHash or not styleHash then
        print(('[hexa_core] [colormap] skipped zone: invalid hash or color (zone=%s color=%s)')
            :format(tostring(zone), tostring(color)))
        return false
    end

    -- ล้างของเดิมก่อนเสมอ เผื่อโซนนี้เคยถูกทาสีอื่นไว้ (เช่นตอน refresh หลังแก้คอนฟิก)
    if activeZones[zoneHash] then
        Citizen.InvokeNative(REMOVE_WANTED_REGION_STYLE, zoneHash)
    end

    Citizen.InvokeNative(APPLY_WANTED_REGION_STYLE, zoneHash, styleHash)
    activeZones[zoneHash] = true
    debugPrint(('painted zone 0x%08X with style 0x%08X'):format(zoneHash, styleHash))

    return true
end

--- ล้างทุกโซนที่สคริปต์นี้ทาไว้
local function clearZoneColors()
    local hashes = {}
    for zoneHash in pairs(activeZones) do
        hashes[#hashes + 1] = zoneHash
    end

    for i = 1, #hashes do
        resetZoneColor(hashes[i])
    end
end

--- ล้างของเดิมทั้งหมดแล้วทาใหม่ตาม Config.Colormap.Zones — คืนจำนวนโซนที่ทาสำเร็จ
local function refreshZoneColors()
    clearZoneColors()

    local cfg = colormapConfig()
    if not cfg or cfg.Enabled == false then
        debugPrint('disabled (Config.Colormap.Enabled = false)')
        return 0
    end

    if type(cfg.Zones) ~= 'table' then
        print('[hexa_core] [colormap] Config.Colormap.Zones must be a table')
        return 0
    end

    local applied = 0
    for i = 1, #cfg.Zones do
        local zone = cfg.Zones[i]
        if type(zone) ~= 'table' then
            print(('[hexa_core] [colormap] skipped Zones[%d]: not a table'):format(i))
        elseif setZoneColor(zone.hash, zone.color or zone.style) then
            applied = applied + 1
        end
    end

    debugPrint(('painted %d zones'):format(applied))
    return applied
end

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    refreshZoneColors()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    clearZoneColors()
end)

-- ============================================================
-- debug commands (Config.Colormap.Debug = true)
-- ============================================================
-- English only on purpose: these are throwaway dev tools, the strings are
-- meant to be pasted straight into Config.Colormap.Zones.

local GET_MAP_ZONE_AT_COORDS = 0x43AD8FC02B429D33

if colormapConfig() and colormapConfig().Debug then
    -- /zonehash — dump every map zone hash at the player's position.
    -- Stand where you want to paint, run it, copy the hex into Config.Colormap.Zones.
    -- Zone types are nested: the low ones are the small areas (region / district),
    -- the high ones are the big containers (state). Types with no zone are skipped.
    RegisterCommand('zonehash', function()
        local coords = GetEntityCoords(PlayerPedId())
        print(('[hexa_core] [colormap] zones at %.2f %.2f %.2f'):format(coords.x, coords.y, coords.z))

        local found = 0
        for zoneType = 0, 15 do
            local hash = Citizen.InvokeNative(GET_MAP_ZONE_AT_COORDS, coords.x, coords.y, coords.z, zoneType)
            if hash and hash ~= 0 then
                found = found + 1
                print(('  type %-2d  0x%08X'):format(zoneType, hash & 0xFFFFFFFF))
            end
        end

        if found == 0 then
            print('  no zone here (open water / out of bounds)')
        end
    end, false)

    -- /zonestyle <zone> <style> — paint one zone right now, without a restart.
    --   zone  = 0x3B8DD21A, or a zone name such as state_lemoyne
    --   style = a palette name from Config.Colormap.Colors ('red'), or a raw
    --           BLIP_STYLE_* name to preview a shade that is not in the palette
    -- The paint is client-side and lives until restart, so it is safe to spam.
    RegisterCommand('zonestyle', function(_, args)
        local zone, style = args[1], args[2]
        if not zone or not style then
            print('[hexa_core] [colormap] usage: /zonestyle <hash|name> <color|BLIP_STYLE_*>')
            return
        end

        if setZoneColor(tonumber(zone) or zone, style) then
            print(('[hexa_core] [colormap] painted %s with %s — open the map to check')
                :format(zone, style))
        end
    end, false)

    -- /zonereset [zone] — clear one zone, or with no argument repaint everything
    -- from Config.Colormap.Zones (undoes whatever /zonestyle left behind).
    RegisterCommand('zonereset', function(_, args)
        local zone = args[1]
        if zone then
            resetZoneColor(tonumber(zone) or zone)
            return
        end

        print(('[hexa_core] [colormap] repainted %d zones from config'):format(refreshZoneColors()))
    end, false)
end

-- ============================================================
-- exports
-- ============================================================

exports('SetZoneColor', setZoneColor)
exports('ResetZoneColor', resetZoneColor)
exports('RefreshZoneColors', refreshZoneColors)
exports('ClearZoneColors', clearZoneColors)
