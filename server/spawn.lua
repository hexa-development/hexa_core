-- login + spawn อัตโนมัติ ไม่มีหน้าจอเลือกตัวละคร ไม่เจอตัวละครก็สร้างใหม่ให้เลย ดู docs guide/player-object

local spawning = {} -- กันการยิง RequestSpawn ซ้ำระหว่างที่กำลัง login อยู่

-- ส่งข้อมูล spawn ของผู้เล่นที่ login แล้วกลับไปให้ client
local function sendSpawn(src, Player)
    local pos = Player.PlayerData.position or Core.Config.DefaultSpawn
    local health = (Player.PlayerData.metadata and Player.PlayerData.metadata.health) or 600
    -- ส่งเพศไปด้วย เพื่อให้ client เลือกโมเดล mp_male/mp_female ให้ตรงกับที่เลือกไว้
    local gender = (Player.PlayerData.charinfo and Player.PlayerData.charinfo.gender) or 0
    TriggerClientEvent('HexaCore:Client:SpawnPlayer', src, pos, health, gender)
end

-- ตัวละครเดียวกันอาจยังค้างอยู่คนละ source ถ้า reconnect เร็วกว่า playerDropped ต้องปลดตัวเก่าก่อนสร้างตัวใหม่
local function releaseStaleSession(citizenid, src)
    if not citizenid then return end

    local stale = Core.GetPlayerByCitizenId(citizenid)
    if not stale then return end

    local oldSrc = stale.PlayerData.source
    if not oldSrc or oldSrc == src then return end

    -- ต้องเซฟก่อนถอด เพราะ SavePlayer หยิบตัวผู้เล่นจาก Core.Players ถอดก่อนแล้วความคืบหน้าของ session เก่าหายทั้งก้อน
    local ok, err = pcall(stale.Save)
    if not ok then
        Hexa.Error('failed to save stale session of %s on id %s: %s', tostring(citizenid), tostring(oldSrc), tostring(err))
    end

    -- ต้องถอดออกเสมอแม้เซฟพัง ไม่งั้น playerDropped ของ source เก่าจะเซฟข้อมูลก่อน reconnect ทับ session ใหม่ทีหลัง
    Core.Players[oldSrc] = nil
    Hexa.Log('character %s reconnected on id %s - released stale session on id %s', tostring(citizenid), tostring(src), tostring(oldSrc))

    -- รอให้คิวเขียนของตัวเก่าลง DB ก่อน ไม่งั้น Login อ่านแถวเดิมกลับมาแล้วเขียนทับสิ่งที่เพิ่งเซฟไป
    Wait(500)
end

RegisterNetEvent('HexaCore:Server:RequestSpawn', function()
    local src = source

    -- login ไปแล้วแต่ client ขอซ้ำ ต้องตอบข้อมูลเดิมกลับ ห้าม return เงียบ ไม่งั้น client ค้างรอตลอด
    if Core.Players[src] then
        return sendSpawn(src, Core.Players[src])
    end

    -- เปิดหน้าเลือกตัวละครอยู่ = หน้านั้นเป็นคนสั่ง login เอง ประตูนี้ต้องปิดฝั่ง server ด้วย ไม่งั้น client ยิง event เองเพื่อข้ามหน้าเลือกได้
    if Core.Config.MultiCharacter then return end

    if spawning[src] then return end -- กำลัง login อยู่ รอรอบนี้จบก่อน
    spawning[src] = true

    -- รอ installer สร้างตาราง players ให้เสร็จก่อน (กันแข่งกันตอน DB ใหม่)
    if AwaitSchemaReady then AwaitSchemaReady(15000) end

    local license = Core.GetIdentifier(src)
    if not license then
        spawning[src] = nil
        return DropPlayer(src, Lang:t('error.no_valid_license'))
    end

    -- ต้องครอบ pcall ให้ spawning ถูกเคลียร์เสมอ ไม่งั้น error ครั้งเดียว = ผู้เล่นขอ spawn ใหม่ไม่ได้อีกเลย
    local ok, err = pcall(function()
        -- หาตัวละครของ license นี้ (ตาราง users: identifier = license)
        local citizenid = Db.Scalar('SELECT citizenid FROM users WHERE identifier = ? ORDER BY last_seen DESC LIMIT 1', { license })
        -- ต้องปลดตัวเก่าก่อน Login ไม่งั้นตัวละครเดียวกันมีสอง Player object แล้วตัวเก่าเซฟทับตอน playerDropped ยิงตามมา
        releaseStaleSession(citizenid, src)
        -- citizenid = nil ได้ -> Login จะสร้างตัวละครใหม่จาก PlayerDefaults ให้เอง
        Core.LoginPlayer(src, citizenid)
    end)
    spawning[src] = nil

    if not ok then
        Hexa.Log('RequestSpawn failed for id %s: %s', src, err)
        return -- client จะ retry เองใน 10 วิ
    end

    local Player = Core.Players[src]
    if not Player then return end

    -- ส่ง Shared ล่าสุดให้ client ก่อน spawn (อาชีพจาก DB อาจโหลดหลัง client ต่อเข้ามา)
    TriggerClientEvent('HexaCore:Client:SharedUpdate', src, Core.Shared)
    sendSpawn(src, Player)
end)

AddEventHandler('playerDropped', function()
    spawning[source] = nil
end)

-- เซฟตอน resource หยุดอยู่ที่ server/save.lua แล้ว เพราะ SavePlayer ตรงๆ ข้าม PullStateBags ค่าสถานะเลยหายทุกรีสตาร์ท
