-- ตาราง items ใน DB คือแหล่งไอเทมแหล่งเดียว (Shared.Items เริ่มว่าง) แก้แล้วต้อง restart ดู docs guide/items-jobs

-- ไอเทมเงินต้องมีใน Shared.Items ไม่งั้น moneyitems.lua เรียก AddItem('dollar') ไม่ผ่าน แล้วเงินสดหายตอนล็อกอิน
local MONEY_ITEMS = {
    dollar           = { label = 'Dollar',           weight = 0 },
    cent             = { label = 'Cent',             weight = 0 },
    money_clip       = { label = 'Money Clip',       weight = 0 },
    blood_dollar     = { label = 'Blood Dollar',     weight = 0 },
    blood_cent       = { label = 'Blood Cent',       weight = 0 },
    blood_money_clip = { label = 'Blood Money Clip', weight = 0 },
}

-- ต้องรวมอาวุธเข้าที่นี่ เพราะตาราง items โครง esx ไม่มีคอลัมน์ type ทุกแถวจึงเป็น 'item' แล้ว hexa_inventory มองไม่เห็นอาวุธ
local function buildCatalogue(rows)
    local items = {}

    -- 1. ไอเทมจากฐานข้อมูล: โครง esx_core 100% ฟิลด์ที่ ESX ไม่มีแต่ inventory ใช้ ต้องเติม default ตรงนี้
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

    -- 2. อาวุธ: แถวใน DB ชนะเรื่อง label/weight แต่ type/unique ต้องบังคับเสมอ เพราะ DB บอกไม่ได้ว่าแถวไหนเป็นอาวุธ
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
    local ok, rows = pcall(Db.Query, 'SELECT * FROM items')
    if not ok then
        Hexa.Error('could not read the items table - only weapons will be registered, so unknown items get dropped from inventories. %s', tostring(rows))
        rows = nil
    end
    if not rows or #rows == 0 then
        -- ห้าม return: ตาราง items ว่างก็ยังต้องลงทะเบียนอาวุธให้ครบ ไม่งั้น LoadInventory ตัดอาวุธทิ้งทั้งกระเป๋า
        Hexa.Warn('the items table is empty - only weapons will be registered. check that install.sql seeded correctly')
        rows = {}
    end

    local items = buildCatalogue(rows)

    -- Shared เป็น reference เดียวกับ Core.Shared จึงอัปเดตทั้งคู่พร้อมกัน
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

Db.Ready(function()
    -- รอ installer สร้าง/seed ตาราง items ให้เสร็จก่อนค่อยโหลด
    if AwaitSchemaReady then AwaitSchemaReady(15000) end
    loadItemsFromDatabase()
end)
