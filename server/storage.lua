-- ============================================================
-- hexa_core - รูปแบบการเก็บของในตัว/อาวุธ (โครง esx_core)
-- ============================================================
-- แหล่งความจริงของข้อมูลผู้เล่นแบ่งเป็น 2 คอลัมน์ในตาราง users:
--
--   users.inventory  ของทั่วไป   [{"name":"bread","amount":2,"slot":3}]
--   users.loadout    อาวุธ       [{"name":"weapon_revolver_navy","slot":1,"ammo":24,"serie":"..."}]
--
-- อาวุธ *ไม่อยู่* ใน users.inventory — แยกไป users.loadout อย่างเดียว
-- ตัวตัดสินว่าอะไรคืออาวุธคือ Shared.IsWeapon() เพียงตัวเดียว (shared/weapons.lua)
--
-- ------------------------------------------------------------
-- ทำไมต้องรวม codec ไว้ที่นี่
-- ------------------------------------------------------------
-- ของเดิม users.inventory ถูกเขียนจาก 2 ที่ที่ฟอร์แมตไม่ตรงกัน:
-- hexa_core/server/player.lua (เขียน PlayerData.items ดิบทั้งก้อน) กับ
-- hexa_inventory/server/exports.lua SaveInventory (เขียนแบบตัดฟิลด์)
-- ใครเซฟทีหลังทับของอีกฝั่ง ตอนนี้ทั้งสองที่เรียกฟังก์ชันชุดนี้ชุดเดียวกัน
-- จึงเข้ารหัสเหมือนกันเสมอ
--
-- ------------------------------------------------------------
-- ทำไมถึงไม่ใช่ {name: count} แบบ esx แล้ว
-- ------------------------------------------------------------
-- รูปแบบ esx เก็บได้แค่ "ชื่อ" กับ "จำนวนรวม" ของทุกช่องที่ชื่อเดียวกัน
-- สิ่งที่หายไปทุกครั้งที่เซฟคือ เลข slot · item.info (quality/%, ซีเรียล,
-- ข้อมูลเฉพาะชิ้น) · และอาวุธชื่อเดียวกันเหลือกระบอกเดียว
--
-- ระบบที่ใช้จริงบนเซิร์ฟนี้ต้องการทั้งสามอย่าง:
--   * ไอเทมที่มี % (หุ่นไล่กาที่ใช้ไปแล้ว ของที่เสื่อมสภาพ) ต้องอยู่คนละกอง
--     และ % ต้องไม่หายตอนล็อกอินใหม่
--   * อาวุธชนิดเดียวกันหลายกระบอก แต่ละกระบอกมีซีเรียล/กระสุนของตัวเอง
--   * ของอยู่ช่องเดิมที่ผู้เล่นจัดไว้ ไม่ถูกสับใหม่ทุกครั้งที่เข้าเกม
-- จึงเก็บเป็น array ทีละชิ้น (มี slot + info ครบ) แทน
--
-- อ่านของเก่าได้ทั้งหมด: ทั้งรูปแบบ esx ({name: count} / {name: {ammo...}})
-- และ array รุ่นก่อน — ของเก่าจะถูกเขียนกลับเป็นรูปแบบใหม่เองตอนเซฟครั้งถัดไป
-- (ไม่มี migration แบบ batch แล้ว เพราะรูปแบบใหม่ก็ขึ้นต้นด้วย '[' เหมือนกัน
--  ตัวเก่าที่ไล่แปลงทุกแถวที่ LIKE '[%' จะกินข้อมูลใหม่ทิ้งหมด)

HexaCore = HexaCore or {}
HexaCore.Storage = {}

local Storage = HexaCore.Storage

-- คีย์เรียงตามชื่อ ใช้ให้การไล่ตารางได้ลำดับคงที่
-- จำเป็นเพราะ users.inventory เป็น JSON object ซึ่ง pairs() ไล่ไม่เรียงลำดับ
-- ถ้าไม่เรียง ผู้เล่นจะเจอของสลับช่องมั่วทุกครั้งที่เข้าเกม
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

--- เรียงลิสต์ช่องให้ลำดับคงที่: ตามเลขช่อง แล้วค่อยชื่อ
--- ของที่ไม่มีเลขช่อง (มาจากแถวรูปแบบ esx เก่า) ไปต่อท้ายเสมอ
local function sortSlots(list)
    table.sort(list, function(a, b)
        local sa = a.slot or math.huge
        local sb = b.slot or math.huge
        if sa ~= sb then return sa < sb end
        return tostring(a.name) < tostring(b.name)
    end)
    return list
end

--- ช่องเก็บของในหน่วยความจำ -> รูปแบบเซฟ (array ทีละชิ้น)
--- ข้ามอาวุธ (ไปอยู่ loadout) และข้ามของจำนวน <= 0
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

--- รูปแบบเซฟ -> ลิสต์ช่อง ให้ฝั่ง inventory เอาไปจัดลงช่อง
--- อ่านได้ทั้ง array (รูปแบบปัจจุบัน) และ {name: count} (รูปแบบ esx เก่า)
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

--- ช่องเก็บของในหน่วยความจำ -> รูปแบบเซฟ loadout (array ทีละกระบอก)
---
--- เก็บทีละกระบอกจริง ๆ ไม่ได้คีย์ด้วยชื่อ — อาวุธชนิดเดียวกันจึงพกได้หลายกระบอก
--- แต่ละกระบอกถือ ซีเรียล / กระสุน / ส่วนประกอบ / สภาพ (quality) ของตัวเอง
---
--- `serie` คือ "รหัสประจำกระบอก" ที่ระบบอื่นใช้ชี้อาวุธเฉพาะกระบอก:
---   * stash_bridge ใช้เป็น uniqueKey ตอนย้ายอาวุธเข้า/ออกสแตช
---   * ปุ่ม "คัดลอกเลขทะเบียน" ในหน้ากระเป๋า
--- ตาราง player_weapons ที่เคยเก็บซ้ำถูกยกเลิกไปแล้ว เจ้าของปืนตัดสินจาก
--- loadout ของใครมีซีเรียลนั้นอยู่
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

--- รูปแบบเซฟ loadout -> ลิสต์ช่อง ให้ฝั่ง inventory เอาไปจัดลงช่อง
--- อ่านได้ทั้ง array รูปแบบปัจจุบัน, array ไอเทมรุ่นเก่า (อาวุธปนอยู่กับของทั่วไป)
--- และ {name: {ammo...}} แบบ esx
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

--- รวม users.inventory + users.loadout กลับเป็นตารางช่องแบบที่เกมใช้จริง
---
--- ในหน่วยความจำ PlayerData.items ยังเป็นตารางช่อง (slot -> item) เหมือนเดิม และ
--- *รวมอาวุธไว้ด้วย* โค้ดส่วนอื่นทั้งหมด (UI, hotbar, เทรด, สแตช, ดรอป, การใช้ไอเทม)
--- จึงทำงานได้โดยไม่ต้องแก้ ส่วนการแยกเก็บ 2 คอลัมน์เกิดขึ้นตอนเซฟเท่านั้น
--- เหมือน esx ที่รวม inventory/loadout เป็น xPlayer ก้อนเดียวตอนรันไทม์
---
--- ของที่เคยเก็บเลขช่องไว้จะได้ช่องเดิมกลับ ส่วนของที่ไม่มีเลขช่อง (แถวรูปแบบ
--- esx เก่า หรือช่องชนกันเพราะข้อมูลเพี้ยน) จะถูกเติมลงช่องว่างที่เหลือตามลำดับ
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

    -- แถวรุ่นเก่าที่ loadout เป็น NULL และอาวุธยังปนอยู่ใน inventory (array เก่า)
    -- ถ้าอ่านอาวุธจาก loadout อย่างเดียวผู้เล่นจะเสียปืนทั้งหมดทันทีที่ล็อกอิน
    -- แล้วการเซฟครั้งถัดไปจะทับให้หายถาวร — จึง fallback ไปแกะจาก inventory ให้
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
-- เปิดเป็น export จริง ไม่ให้ resource อื่นเรียกผ่าน GetCoreObject().Storage
--
-- GetCoreObject() คืนค่าข้ามขอบเขต resource ซึ่งตารางที่ติดไปเป็นสำเนาที่ถ่ายไว้
-- ตอนเรียกครั้งแรก (ทุกไฟล์ใน hexa_inventory เรียกครั้งเดียวตอนโหลด) การเข้ารหัส
-- ของในตัวต้องอ่าน Shared.Weapons ที่เป็นปัจจุบันเสมอ เรียกผ่าน export แบบนี้
-- โค้ดจะรันในรันไทม์ของ hexa_core เองทุกครั้ง จึงเห็นข้อมูลล่าสุดแน่นอน
exports('EncodeInventory', Storage.EncodeInventory)
exports('DecodeInventory', Storage.DecodeInventory)
exports('EncodeLoadout', Storage.EncodeLoadout)
exports('DecodeLoadout', Storage.DecodeLoadout)
exports('BuildSlots', Storage.BuildSlots)
exports('IsWeapon', function(name) return Shared.IsWeapon(name) end)

-- ==================== migration ====================
-- ไม่มี migration แบบไล่แก้ทุกแถวแล้ว และ *ห้ามใส่กลับมา* ในรูปแบบเดิม
--
-- ตัวเก่าไล่ SELECT ... WHERE inventory LIKE '[%' แล้วแปลงเป็น {name: count}
-- โดยถือว่า "ขึ้นต้นด้วย [ = ของเก่า" — แต่รูปแบบปัจจุบันก็เป็น JSON array
-- เหมือนกัน ถ้ายังเปิดไว้มันจะยุบ slot/info/อาวุธซ้ำชื่อของทุกคนทิ้งทุกครั้งที่บูต
--
-- ของเก่าไม่ต้องแปลงล่วงหน้าอยู่แล้ว: DecodeInventory/DecodeLoadout อ่านรูปแบบ
-- esx ({name: count}) ได้ตรง ๆ แล้วการเซฟครั้งถัดไปของตัวละครนั้นจะเขียนกลับ
-- เป็นรูปแบบใหม่ให้เอง (ทยอยแปลงตามคนที่เข้าเกม ไม่ต้องแตะ DB ทั้งตาราง)
