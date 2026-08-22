-- ============================================================
-- hexa_core — ระบบสถานะร่างกาย (ฝั่ง server)
-- ============================================================
-- หิว (hunger) / กระหาย (thirst) / สะอาด (cleanliness) / เครียด (stress)
-- ทุกค่าเป็น 0-100 เก็บอยู่ใน PlayerData.metadata และเซฟลงฐานข้อมูลตามรอบปกติ
--
-- ทำไมรอบลดค่าถึงอยู่ฝั่งนี้:
-- ต้นฉบับให้ client นับเวลาแล้วยิง SetMetaData กลับมาเอง ซึ่งแปลว่าใครไม่ยิงก็ไม่หิว
-- (แค่หยุด thread เดียวใน client ก็อมตะ) ที่นี่จึงนับเวลาเองทั้งหมด client ได้แค่
-- รับค่าที่คำนวณเสร็จแล้วไปวาด — ดู hexa_status
--
-- export ที่สคริปต์อื่นเรียกได้ (อาหาร/น้ำ/สบู่/ยา ใช้ชุดนี้):
--   exports['hexa_core']:AddStatus(src, 'hunger', 20)
--   exports['hexa_core']:RemoveStatus(src, 'thirst', 10)
--   exports['hexa_core']:SetStatus(src, 'cleanliness', 100)
--   exports['hexa_core']:GetStatus(src)            -> ตารางครบทุกค่า
--   exports['hexa_core']:GetStatus(src, 'hunger')  -> ตัวเลขเดียว

local StatusKeys = { 'hunger', 'thirst', 'cleanliness', 'stress' }

--- คีย์ที่ระบบนี้ดูแล — กันไม่ให้ export ถูกใช้ไปเขียน metadata ช่องอื่น
--- (injail / rep / criminalrecord ต้องผ่าน SetMetaData ตรงๆ เท่านั้น)
local IsStatusKey = {}
for _, key in ipairs(StatusKeys) do IsStatusKey[key] = true end

local function statusConfig()
    return HexaCore.Config and HexaCore.Config.Status or nil
end

local function clamp(value)
    return math.min(math.max(tonumber(value) or 0, 0), 100)
end

--- อ่านค่าสถานะทั้งหมดของผู้เล่นคนหนึ่ง (nil = ไม่มีตัวละครโหลดอยู่)
local function readStatus(src)
    -- ตั้งชื่อ ply ไม่ใช่ Player เพราะ Player(...) เป็นฟังก์ชัน global ของ FiveM
    -- ที่ไฟล์นี้ต้องใช้อ่าน statebag — ตั้งชื่อชนกันเมื่อไหร่ statebag พังเงียบทันที
    local ply = HexaCore.GetPlayer(src)
    if not ply then return nil end

    local metadata = ply.PlayerData.metadata or {}
    local out = {}
    for _, key in ipairs(StatusKeys) do
        out[key] = clamp(metadata[key])
    end
    return out
end

--- เขียนค่าหลายช่องพร้อมกันแล้วบอก client รอบเดียว
--- values = { hunger = 80, thirst = 55, ... } (ช่องที่ไม่รู้จักถูกทิ้ง)
local function writeStatus(src, values)
    local ply = HexaCore.GetPlayer(src)
    if not ply then return nil end

    local applied = {}
    for key, value in pairs(values) do
        if IsStatusKey[key] then
            applied[key] = clamp(value)
        end
    end
    if not next(applied) then return nil end

    -- SetMetaData แบบตารางเรียก UpdatePlayerData ให้ครั้งเดียว (ไม่ใช่ครั้งต่อคีย์)
    ply.SetMetaData(applied)

    -- statebag ของผู้เล่น: สคริปต์อื่นอ่าน Player(src).state.hunger ได้โดยไม่ต้องขอ core object
    -- และ InitializeStateBags/PersistStateBags ใน player.lua ใช้ช่องเดียวกันนี้อยู่แล้ว
    local state = Player(src).state
    for key, value in pairs(applied) do
        state:set(key, value, true)
    end

    TriggerClientEvent('HexaCore:Client:UpdateNeeds', src, readStatus(src))
    return applied
end

-- ============================================================
-- รอบลดค่าตามเวลา
-- ============================================================

CreateThread(function()
    while true do
        local cfg = statusConfig()
        local minutes = cfg and tonumber(cfg.TickInterval) or 5
        if minutes < 1 then minutes = 1 end

        Wait(minutes * 60000)

        cfg = statusConfig()
        if cfg and cfg.Enabled and type(cfg.Drain) == 'table' then
            for _, ply in pairs(HexaCore.Players or {}) do
                local src = ply.PlayerData.source
                local metadata = ply.PlayerData.metadata or {}

                -- คนที่นอนตายอยู่ไม่ควรหิวเพิ่ม — ไม่งั้นฟื้นมาเลือดหมดซ้ำทันที
                if not metadata.isdead then
                    local next_ = {}
                    for _, key in ipairs(StatusKeys) do
                        local rate = tonumber(cfg.Drain[key])
                        if rate and rate ~= 0 then
                            next_[key] = clamp((tonumber(metadata[key]) or 100) - rate)
                        end
                    end
                    if next(next_) then writeStatus(src, next_) end
                end
            end
        end
    end
end)

-- ============================================================
-- ส่งค่าให้ client ตอนเพิ่งโหลดตัวละครเสร็จ
-- ============================================================
-- hexa_status เปิดหน้าจอตอนไหนก็ได้ แต่ค่าแรกต้องมาจากที่นี่เสมอ
-- (PlayerLoaded ยิงก่อน NUI ของ hexa_status พร้อม ตัว client จึงขอซ้ำได้ด้วย
--  HexaCore:Server:RequestStatus ข้างล่าง)
AddEventHandler('HexaCore:Server:PlayerLoaded', function(ply)
    local src = ply.PlayerData.source
    local status = readStatus(src)
    if status then
        TriggerClientEvent('HexaCore:Client:UpdateNeeds', src, status)
    end
end)

RegisterNetEvent('HexaCore:Server:RequestStatus', function()
    local src = source
    local status = readStatus(src)
    if status then
        TriggerClientEvent('HexaCore:Client:UpdateNeeds', src, status)
    end
end)

-- ============================================================
-- exports
-- ============================================================

exports('GetStatus', function(src, key)
    local status = readStatus(src)
    if not status then return nil end
    if key then return status[key] end
    return status
end)

exports('SetStatus', function(src, key, value)
    if type(key) == 'table' then return writeStatus(src, key) end
    if not IsStatusKey[key] then return nil end
    return writeStatus(src, { [key] = value })
end)

exports('AddStatus', function(src, key, amount)
    local status = readStatus(src)
    if not status or not IsStatusKey[key] then return nil end
    return writeStatus(src, { [key] = status[key] + (tonumber(amount) or 0) })
end)

exports('RemoveStatus', function(src, key, amount)
    local status = readStatus(src)
    if not status or not IsStatusKey[key] then return nil end
    return writeStatus(src, { [key] = status[key] - (tonumber(amount) or 0) })
end)

-- ============================================================
-- คำสั่งแอดมิน
-- ============================================================

HexaCore.Commands.Add('setstatus', 'ตั้งค่าสถานะร่างกายของผู้เล่น', {
    { name = 'id',    help = 'ไอดีผู้เล่น' },
    { name = 'key',   help = 'hunger / thirst / cleanliness / stress' },
    { name = 'value', help = 'ค่า 0-100' },
}, true, function(source, args)
    local target = tonumber(args[1])
    local key = tostring(args[2] or ''):lower()
    local value = tonumber(args[3])

    if not target or not IsStatusKey[key] or not value then
        return HexaCore.Notify(source, { title = 'ใช้: /setstatus [id] [hunger|thirst|cleanliness|stress] [0-100]', type = 'error', duration = 5000 })
    end

    if not writeStatus(target, { [key] = value }) then
        return HexaCore.Notify(source, { title = 'ไม่พบผู้เล่นไอดีนี้', type = 'error', duration = 5000 })
    end

    HexaCore.Notify(source, { title = ('ตั้ง %s ของไอดี %s เป็น %s แล้ว'):format(key, target, clamp(value)), type = 'success', duration = 5000 })
end, 'admin')
