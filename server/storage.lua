-- hexa_core - รูปแบบการเก็บของในตัว/อาวุธ (โครง esx_core)

-- อาวุธแยกไป users.loadout ไม่ปนใน users.inventory ตัดสินด้วย Shared.IsWeapon ตัวเดียว - ดู docs guide/persistence

HexaCore = HexaCore or {}
HexaCore.Storage = {}

local Storage = HexaCore.Storage

-- เรียงคีย์ตามชื่อ เพราะ pairs() ไล่ JSON object ไม่คงลำดับ ไม่เรียงแล้วของจะสลับช่องทุกครั้งที่เข้าเกม
local function sortedKeys(map)
    local keys = {}
    for k in pairs(map or {}) do keys[#keys + 1] = k end
    table.sort(keys)
    return keys
end

local function decodeJson(raw)
    if type(raw) == 'table' then return raw end
    if type(raw) ~= 'string' or raw == '' then return nil end
    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= 'table' then return nil end
    return decoded
end

-- ==================== inventory (ของทั่วไป) ====================

--- เรียงตามเลขช่องแล้วค่อยชื่อ ของที่ไม่มีเลขช่อง (แถวรูปแบบ esx เก่า) ไปต่อท้ายเสมอ
local function sortSlots(list)
    table.sort(list, function(a, b)
        local sa = a.slot or math.huge
        local sb = b.slot or math.huge
        if sa ~= sb then return sa < sb end
        return tostring(a.name) < tostring(b.name)
    end)
    return list
end

--- ช่องเก็บของในหน่วยความจำ -> รูปแบบเซฟ (array ทีละชิ้น) ข้ามอาวุธที่ไปอยู่ loadout และของจำนวน <= 0
--- @param items table ตารางไอเทมแบบมี slot (PlayerData.items)
--- @return table ลิสต์ { {name=, amount=, slot=, info=}, ... }
function Storage.EncodeInventory(items)
    local out = {}
    for _, item in pairs(items or {}) do
        local name = item and item.name
        local amount = tonumber(item and item.amount) or 0
        if name and amount > 0 and not Shared.IsWeapon(name) then
            -- info ว่างไม่ต้องเก็บ ให้ JSON ไม่บวมโดยเปล่าประโยชน์
            local info = type(item.info) == 'table' and next(item.info) ~= nil and item.info or nil
            out[#out + 1] = {
                name = name:lower(),
                amount = amount,
                slot = tonumber(item.slot),
                info = info,
            }
        end
    end
    return sortSlots(out)
end

--- รูปแบบเซฟ -> ลิสต์ช่อง อ่านได้ทั้ง array รูปแบบปัจจุบัน และ {name: count} แบบ esx เก่า
--- @param raw string|table ค่าจากคอลัมน์ users.inventory
--- @return table ลิสต์ { {name=, amount=, slot=, info=}, ... }
function Storage.DecodeInventory(raw)
    local decoded = decodeJson(raw)
    if not decoded then return {} end

    local out = {}

    -- รูปแบบปัจจุบัน: [{name=, amount=, slot=, info=}, ...]
    if decoded[1] ~= nil and type(decoded[1]) == 'table' then
        for _, item in ipairs(decoded) do
            if item and item.name and not Shared.IsWeapon(item.name) then
                out[#out + 1] = {
                    name = tostring(item.name):lower(),
                    amount = tonumber(item.amount) or 1,
                    slot = tonumber(item.slot),
                    info = type(item.info) == 'table' and item.info or {},
                }
            end
        end
        return sortSlots(out)
    end

    -- รูปแบบ esx เก่า: {name = count} — ไม่มี slot/info ให้กู้ ได้แค่ชื่อกับจำนวน
    for _, name in ipairs(sortedKeys(decoded)) do
        local count = tonumber(decoded[name]) or 0
        if count > 0 and not Shared.IsWeapon(name) then
            out[#out + 1] = { name = tostring(name):lower(), amount = count, info = {} }
        end
    end
    return out
end

-- ==================== loadout (อาวุธ) ====================

--- เซฟ loadout ทีละกระบอก serie คือรหัสประจำกระบอกที่ใช้ชี้เจ้าของแทน player_weapons ที่เลิกใช้ - ดู docs guide/persistence
--- @param items table ตารางไอเทมแบบมี slot (PlayerData.items)
--- @return table ลิสต์ { {name=, slot=, ammo=, components=, tintIndex=, serie=, quality=}, ... }
function Storage.EncodeLoadout(items)
    local out = {}
    for _, item in pairs(items or {}) do
        local name = item and item.name
        if name and Shared.IsWeapon(name) then
            local info = type(item.info) == 'table' and item.info or {}
            out[#out + 1] = {
                name = name:lower(),
                slot = tonumber(item.slot),
                ammo = tonumber(info.ammo) or 0,
                components = type(info.components) == 'table' and info.components or {},
                tintIndex = tonumber(info.tintIndex) or 0,
                serie = info.serie,
                quality = tonumber(info.quality),
            }
        end
    end
    return sortSlots(out)
end

--- รูปแบบเซฟ loadout -> ลิสต์ช่อง อ่านได้ทั้ง array ปัจจุบัน, array ไอเทมรุ่นเก่า และ {name: {ammo...}} แบบ esx
--- @param raw string|table ค่าจากคอลัมน์ users.loadout
--- @return table ลิสต์ { {name=, slot=, ammo=, components=, tintIndex=, serie=, quality=}, ... }
function Storage.DecodeLoadout(raw)
    local decoded = decodeJson(raw)
    if not decoded then return {} end

    local out = {}

    if decoded[1] ~= nil and type(decoded[1]) == 'table' then
        for _, entry in ipairs(decoded) do
            if entry and entry.name and Shared.IsWeapon(entry.name) then
                -- รูปแบบปัจจุบันเก็บค่าไว้ที่ตัวมันเอง ส่วน array ไอเทมรุ่นเก่าเก็บไว้ใน .info
                local info = type(entry.info) == 'table' and entry.info or entry
                out[#out + 1] = {
                    name = tostring(entry.name):lower(),
                    slot = tonumber(entry.slot),
                    ammo = tonumber(info.ammo) or 0,
                    components = type(info.components) == 'table' and info.components or {},
                    tintIndex = tonumber(info.tintIndex) or 0,
                    serie = info.serie,
                    quality = tonumber(info.quality),
                }
            end
        end
        return sortSlots(out)
    end

    -- รูปแบบ esx เก่า: {name = {ammo=, components=, tintIndex=}} — ชื่อละกระบอก
    for _, name in ipairs(sortedKeys(decoded)) do
        local w = decoded[name]
        if type(w) == 'table' then
            out[#out + 1] = {
                name = tostring(name):lower(),
                ammo = tonumber(w.ammo) or 0,
                components = type(w.components) == 'table' and w.components or {},
                tintIndex = tonumber(w.tintIndex) or 0,
                serie = w.serie,
                quality = tonumber(w.quality),
            }
        end
    end
    return out
end

-- ==================== ประกอบกลับเป็นช่องเก็บของ ====================

--- รวม 2 คอลัมน์กลับเป็นตารางช่องที่มีอาวุธปนอยู่ด้วย การแยกเก็บเกิดตอนเซฟเท่านั้น ของที่ไม่มีเลขช่องถูกเติมลงช่องว่างที่เหลือ
--- @param inventoryRaw string|table ค่าคอลัมน์ users.inventory
--- @param loadoutRaw string|table ค่าคอลัมน์ users.loadout
--- @return table ลิสต์เรียงตามช่อง { {name=, amount=, slot=, info=}, ... }
function Storage.BuildSlots(inventoryRaw, loadoutRaw)
    local out, used, pending = {}, {}, {}

    --- ได้ช่องตามที่เก็บไว้ไหม ถ้าช่องนั้นถูกจองแล้วให้ไปต่อคิวเติมช่องว่างทีหลัง
    local function place(entry)
        local slot = tonumber(entry.slot)
        if slot and slot > 0 and not used[slot] then
            used[slot] = true
            entry.slot = slot
            out[#out + 1] = entry
        else
            entry.slot = nil
            pending[#pending + 1] = entry
        end
    end

    -- แถวรุ่นเก่า loadout เป็น NULL อาวุธยังปนใน inventory ถ้าไม่ fallback ผู้เล่นเสียปืนหมดและเซฟครั้งถัดไปทับหายถาวร
    local weapons = Storage.DecodeLoadout(loadoutRaw)
    if #weapons == 0 then
        weapons = Storage.DecodeLoadout(inventoryRaw)
    end

    for _, w in ipairs(weapons) do
        place({
            name = w.name,
            amount = 1,   -- หนึ่งแถวคือหนึ่งกระบอกเสมอ
            slot = w.slot,
            info = {
                ammo = w.ammo,
                components = w.components,
                tintIndex = w.tintIndex,
                serie = w.serie,
                quality = w.quality,
            },
        })
    end

    for _, item in ipairs(Storage.DecodeInventory(inventoryRaw)) do
        place({
            name = item.name,
            amount = item.amount,
            slot = item.slot,
            info = type(item.info) == 'table' and item.info or {},
        })
    end

    local free = 1
    for _, entry in ipairs(pending) do
        while used[free] do free = free + 1 end
        used[free] = true
        entry.slot = free
        out[#out + 1] = entry
    end

    return sortSlots(out)
end

-- ==================== exports ====================

-- ห้ามเรียกผ่าน GetCoreObject() เพราะตารางข้ามขอบเขต resource เป็นสำเนาเก่า แต่ codec ต้องอ่าน Shared.Weapons ปัจจุบันเสมอ
exports('EncodeInventory', Storage.EncodeInventory)
exports('DecodeInventory', Storage.DecodeInventory)
exports('EncodeLoadout', Storage.EncodeLoadout)
exports('DecodeLoadout', Storage.DecodeLoadout)
exports('BuildSlots', Storage.BuildSlots)
exports('IsWeapon', function(name) return Shared.IsWeapon(name) end)

-- ==================== migration ====================

-- ห้ามใส่ migration ที่ไล่แถว LIKE '[%' กลับมา รูปแบบปัจจุบันก็เป็น array จะยุบ slot/info ทิ้ง ของเก่าแปลงเองตอนเซฟอยู่แล้ว
