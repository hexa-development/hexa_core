-- login + spawn อัตโนมัติ ไม่มีหน้าจอเลือกตัวละคร ไม่เจอตัวละครก็สร้างใหม่ให้เลย ดู docs guide/player-object

local spawning = {} -- กันการยิง RequestSpawn ซ้ำระหว่างที่กำลัง login อยู่

-- ส่งข้อมูล spawn ของผู้เล่นที่ login แล้วกลับไปให้ client
local function sendSpawn(src, Player)
    local pos = Player.PlayerData.position or HexaCore.Config.DefaultSpawn
    local health = (Player.PlayerData.metadata and Player.PlayerData.metadata.health) or 600
    -- ส่งเพศไปด้วย เพื่อให้ client เลือกโมเดล mp_male/mp_female ให้ตรงกับที่เลือกไว้
    local gender = (Player.PlayerData.charinfo and Player.PlayerData.charinfo.gender) or 0
    TriggerClientEvent('HexaCore:Client:SpawnPlayer', src, pos, health, gender)
end

RegisterNetEvent('HexaCore:Server:RequestSpawn', function()
    local src = source

    -- login ไปแล้วแต่ client ขอซ้ำ ต้องตอบข้อมูลเดิมกลับ ห้าม return เงียบ ไม่งั้น client ค้างรอตลอด
    if HexaCore.Players[src] then
        return sendSpawn(src, HexaCore.Players[src])
    end
    if spawning[src] then return end -- กำลัง login อยู่ รอรอบนี้จบก่อน
    spawning[src] = true

    -- รอ installer สร้างตาราง players ให้เสร็จก่อน (กันแข่งกันตอน DB ใหม่)
    if AwaitSchemaReady then AwaitSchemaReady(15000) end

    local license = HexaCore.GetIdentifier(src)
    if not license then
        spawning[src] = nil
        return DropPlayer(src, Lang:t('error.no_valid_license'))
    end

    -- ต้องครอบ pcall ให้ spawning ถูกเคลียร์เสมอ ไม่งั้น error ครั้งเดียว = ผู้เล่นขอ spawn ใหม่ไม่ได้อีกเลย
    local ok, err = pcall(function()
        -- หาตัวละครของ license นี้ (ตาราง users สไตล์ ESX: identifier = license)
        local citizenid = MySQL.scalar.await('SELECT citizenid FROM users WHERE identifier = ? ORDER BY last_seen DESC LIMIT 1', { license })
        -- citizenid = nil ได้ -> Login จะสร้างตัวละครใหม่จาก PlayerDefaults ให้เอง
        HexaCore.LoginPlayer(src, citizenid)
    end)
    spawning[src] = nil

    if not ok then
        Hexa.Log('RequestSpawn failed for id %s: %s', src, err)
        return -- client จะ retry เองใน 10 วิ
    end

    local Player = HexaCore.Players[src]
    if not Player then return end

    -- ส่ง Shared ล่าสุดให้ client ก่อน spawn (อาชีพจาก DB อาจโหลดหลัง client ต่อเข้ามา)
    TriggerClientEvent('HexaCore:Client:SharedUpdate', src, HexaCore.Shared)
    sendSpawn(src, Player)
end)

AddEventHandler('playerDropped', function()
    spawning[source] = nil
end)

-- เซฟตอน resource หยุดอยู่ที่ server/save.lua แล้ว เพราะ SavePlayer ตรงๆ ข้าม PullStateBags ค่าสถานะเลยหายทุกรีสตาร์ท
