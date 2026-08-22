-- ============================================================
-- โหลดไอเทมจากฐานข้อมูล (ตาราง items สไตล์ ESX)
-- ============================================================
-- ฐานข้อมูลเป็นแหล่งข้อมูลไอเทมเพียงแหล่งเดียว (Shared.Items เริ่มต้นว่าง)
-- install.sql จะสร้าง + seed ไอเทมเริ่มต้นให้อัตโนมัติตอนบูตครั้งแรก
-- แก้ไข/เพิ่มไอเทม: แก้ข้อมูลใน DB โดยตรง แล้ว restart hexa_core

-- ไอเทมเงิน (ใช้เมื่อ Config.Money.EnableMoneyItems = true)
-- ต้องมีใน Shared.Items ไม่งั้น server/moneyitems.lua เรียก AddItem('dollar', ...)
-- แล้ว hexa_inventory ปฏิเสธเพราะหาไอเทมไม่เจอ (เงินสดจะหายทันทีที่ล็อกอิน)
local MONEY_ITEMS = {
    dollar           = { label = 'Dollar',           weight = 0 },
    cent             = { label = 'Cent',             weight = 0 },
    money_clip       = { label = 'Money Clip',       weight = 0 },
    blood_dollar     = { label = 'Blood Dollar',     weight = 0 },
    blood_cent       = { label = 'Blood Cent',       weight = 0 },
    blood_money_clip = { label = 'Blood Money Clip', weight = 0 },
}

-- ============================================================
-- แคตตาล็อกไอเทมรวมศูนย์
-- ============================================================
-- Shared.Items คือแหล่งข้อมูล "ไอเทมทุกชนิด" ที่เดียวของทั้งเซิร์ฟเวอร์
-- รวม 3 แหล่งเข้าด้วยกัน:
--   1. ตาราง items ในฐานข้อมูล (โครง esx: ของกิน ของใช้ วัตถุดิบ)
--   2. Shared.Weapons (shared/weapons.lua)  -> ใส่ให้เป็น type = 'weapon'
--   3. ไอเทมเงิน (เมื่อเปิด EnableMoneyItems)
--
-- ข้อ 2 สำคัญมาก: ตาราง items เป็นโครง esx ซึ่ง *ไม่มีคอลัมน์ type* ทุกแถวจึงถูก
-- ใส่ type = 'item' เสมอ ผลคือเงื่อนไข `Shared.Items[name].type == 'weapon'` ที่มี
-- กระจายอยู่ทั่ว hexa_inventory (ตอนใช้ไอเทม, เทรด, สแตช, ดรอป, UI) เป็นเท็จตลอด
-- และอาวุธก็ไม่เคยมีแถวใน items ด้วย -> hexa_inventory มองไม่เห็นอาวุธเลย
-- รวมไว้ตรงนี้ทีเดียว โค้ดฝั่ง inventory จึงไม่ต้องมีทางหนีทีไล่ของตัวเอง
local function buildCatalogue(rows)
    local items = {}

    -- 1. ไอเทมจากฐานข้อมูล
    -- ตาราง items เป็นโครง esx_core 100% (name, label, weight, rare, can_remove)
    -- ฟิลด์ที่ ESX ไม่มีแต่ระบบภายใน/inventory ใช้ จะเติมเป็นค่า default ตรงนี้
    for _, row in ipairs(rows or {}) do
        items[row.name] = {
            name = row.name,
            label = row.label,
            weight = tonumber(row.weight) or 1,
            rare = row.rare == 1,
            canRemove = row.can_remove == 1,
            -- ค่า default สำหรับฟิลด์นอกเหนือ ESX
            type = 'item',
            image = row.name .. '.png', -- ตามธรรมเนียมรูปไอเทมชื่อเดียวกับ item name
            unique = false,
            useable = true, -- ใช้ได้จริงหรือไม่ตัดสินที่การลงทะเบียน CreateUseableItem เหมือน ESX.RegisterUsableItem
            shouldClose = true,
        }
    end

    -- 2. อาวุธ
    -- แถวใน DB (ถ้ามี) ชนะเรื่อง label/weight แต่ type/unique ถูกบังคับเป็นอาวุธเสมอ
    -- เพราะ DB ไม่มีทางบอกได้ว่าแถวไหนเป็นอาวุธ
    for name, weapon in pairs(Shared.Weapons or {}) do
        local existing = items[name]
        items[name] = {
            name = name,
            label = (existing and existing.label) or weapon.label or name,
            weight = (existing and existing.weight) or tonumber(weapon.weight) or 1,
            rare = existing and existing.rare or false,
            canRemove = existing == nil or existing.canRemove,
            type = 'weapon',
            image = name .. '.png',
            unique = true,      -- อาวุธไม่กองรวมช่อง: 1 กระบอก 1 ช่อง
            useable = true,     -- "ใช้" = ถือ/เก็บอาวุธ (client/weapons.lua)
            shouldClose = true,
        }
    end

    -- 3. ไอเทมเงิน (เฉพาะตอนเปิดใช้)
    if Config.Money and Config.Money.EnableMoneyItems then
        for name, money in pairs(MONEY_ITEMS) do
            if not items[name] then
                items[name] = {
                    name = name,
                    label = money.label,
                    weight = money.weight,
                    rare = false,
                    canRemove = true,
                    type = 'item',
                    image = name .. '.png',
                    unique = false,
                    useable = false,   -- เงินไม่ได้ "ใช้" กดใช้ไม่ได้
                    shouldClose = false,
                }
            end
        end
    end

    return items
end

local function loadItemsFromDatabase()
    -- เหตุผลเดียวกับ jobs: คิวรีล้มแล้วเงียบ = ผู้เล่นเสียของทั้งกระเป๋าเพราะ LoadInventory ตัดของที่ไม่รู้จักทิ้ง
    local ok, rows = pcall(MySQL.query.await, 'SELECT * FROM items')
    if not ok then
        Hexa.Error('could not read the items table - only weapons will be registered, so unknown items get dropped from inventories. %s', tostring(rows))
        rows = nil
    end
    if not rows or #rows == 0 then
        -- ไม่ return แล้ว: ต่อให้ตาราง items ว่าง อาวุธก็ยังต้องลงทะเบียนให้ครบ
        -- ไม่งั้นผู้เล่นเสียอาวุธทั้งหมดตอนโหลด (LoadInventory ตัดของที่ไม่รู้จักทิ้ง)
        Hexa.Warn('the items table is empty - only weapons will be registered. check that install.sql seeded correctly')
        rows = {}
    end

    local items = buildCatalogue(rows)

    -- Shared เป็น reference เดียวกับ HexaCore.Shared จึงอัปเดตทั้งคู่พร้อมกัน
    Shared.Items = items

    local count, weapons = 0, 0
    for _, item in pairs(items) do
        count = count + 1
        if item.type == 'weapon' then weapons = weapons + 1 end
    end
    Hexa.Log('item catalogue ready: %d entries (%d weapons, %d general)', count, weapons, count - weapons)

    -- sync ให้ client ที่ออนไลน์อยู่ (กรณี restart กลางเกม) + refresh core object
    TriggerClientEvent('HexaCore:Client:OnSharedUpdateMultiple', -1, 'Items', items)
    TriggerEvent('HexaCore:Server:UpdateObject')
end

MySQL.ready(function()
    -- รอ installer สร้าง/seed ตาราง items ให้เสร็จก่อนค่อยโหลด
    if AwaitSchemaReady then AwaitSchemaReady(15000) end
    loadItemsFromDatabase()
end)
