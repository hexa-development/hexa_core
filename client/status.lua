-- ============================================================
-- hexa_core — ระบบสถานะร่างกาย (ฝั่ง client)
-- ============================================================
-- ฝั่งนี้ไม่ได้เป็นคนลดค่า — server/status.lua เป็นคนนับเวลาและคำนวณให้ทั้งหมด
-- หน้าที่ของไฟล์นี้มีสองอย่างเท่านั้น:
--   1. หักเลือดตอนหิวจัด/กระหายจัด (แตะ ped จริง ทำที่ server ไม่ได้)
--   2. เก็บค่าล่าสุดไว้ให้ hexa_status (หรือ resource อื่น) ดึงไปวาด
--
-- ที่ดึงค่าไปใช้:
--   exports['hexa_core']:GetStatus()          -> { hunger=, thirst=, cleanliness=, stress= }
--   exports['hexa_core']:GetStatus('hunger')  -> ตัวเลขเดียว
--   AddEventHandler('HexaCore:Client:UpdateNeeds', function(status) ... end)

local StatusKeys = { 'hunger', 'thirst', 'cleanliness', 'stress' }

--- ค่าล่าสุดที่ server ส่งมา — เริ่มที่ 100 ไว้ก่อนเพื่อไม่ให้ HUD วาดแถบว่างเปล่า
--- ในช่วงไม่กี่เฟรมก่อน UpdateNeeds ก้อนแรกจะมาถึง
local status = { hunger = 100, thirst = 100, cleanliness = 100, stress = 0 }

local function clamp(value)
    return math.min(math.max(tonumber(value) or 0, 0), 100)
end

local function statusConfig()
    return HexaCore.Config and HexaCore.Config.Status or nil
end

-- ============================================================
-- รับค่าจาก server
-- ============================================================

RegisterNetEvent('HexaCore:Client:UpdateNeeds', function(incoming)
    if type(incoming) ~= 'table' then return end
    for _, key in ipairs(StatusKeys) do
        if incoming[key] ~= nil then status[key] = clamp(incoming[key]) end
    end
end)

-- metadata เดินทางมาสองทาง: UpdateNeeds (ทางตรง ยิงเฉพาะตอนค่าสถานะขยับ) กับ
-- SetPlayerData ก้อนใหญ่ (ยิงทุกครั้งที่ playerdata ช่องไหนก็ได้เปลี่ยน)
-- ต้องรับทั้งคู่ ไม่งั้นสคริปต์ที่เรียก SetMetaData ตรงๆ โดยไม่ผ่าน export ของเรา
-- จะทำให้ HUD ค้างค่าเก่าไว้จนถึงรอบลดค่าถัดไป
RegisterNetEvent('HexaCore:Player:SetPlayerData', function(playerData)
    local metadata = playerData and playerData.metadata
    if type(metadata) ~= 'table' then return end
    for _, key in ipairs(StatusKeys) do
        if metadata[key] ~= nil then status[key] = clamp(metadata[key]) end
    end
end)

-- ขอค่าชุดแรกเมื่อโหลดตัวละครเสร็จ — PlayerLoaded ฝั่ง server ก็ยิงมาให้อยู่แล้ว
-- แต่ resource ที่ restart กลางเกม (เช่น hexa_status) ไม่ได้เห็นเหตุการณ์นั้น
RegisterNetEvent('HexaCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('HexaCore:Server:RequestStatus')
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if LocalPlayer.state.isLoggedIn then
        TriggerServerEvent('HexaCore:Server:RequestStatus')
    end
end)

-- ============================================================
-- หักเลือดตอนหิวจัด / กระหายจัด
-- ============================================================

CreateThread(function()
    while true do
        local cfg = statusConfig()
        local damage = cfg and cfg.Damage or nil
        local interval = damage and tonumber(damage.interval) or 10000
        if interval < 1000 then interval = 1000 end

        Wait(interval)

        cfg = statusConfig()
        damage = cfg and cfg.Damage or nil

        if cfg and cfg.Enabled and damage and damage.enabled and LocalPlayer.state.isLoggedIn then
            local threshold = tonumber(damage.threshold) or 0
            local starving = status.hunger <= threshold or status.thirst <= threshold

            if starving then
                local ped = PlayerPedId()
                if not IsEntityDead(ped) then
                    local health = GetEntityHealth(ped)
                    local floor = tonumber(damage.minHealth) or 0
                    local amount = tonumber(damage.amount) or 5

                    if health > floor then
                        SetEntityHealth(ped, math.max(floor, health - amount))
                    end
                end
            end
        end
    end
end)

-- ============================================================
-- แกนทอง (cores) + หลอดสเตมินา
-- ============================================================
-- RDR2 แยกค่าเป็นสองชั้น: "แกนทอง" (วงในที่ไหลลงเองตามเวลา) กับ "หลอดนอก" (ค่าจริงที่ใช้วิ่ง/ยิง)
-- แกนทองไหลลงเมื่อไหร่ หลอดนอกก็เติมกลับได้ไม่เต็มอีกต่อไป — และค่าพวกนี้ผูกกับ "ตัว ped"
-- ไม่ใช่ตัวผู้เล่น ped ตัวใหม่ (เกิดใหม่ / เปลี่ยนโมเดลตอนสร้างตัวละคร/เปลี่ยนชุด) จึงไม่ได้
-- สืบค่าเดิมมาเลย ผลคือเพิ่งเข้าเกมก็ได้สเตมินามาไม่เต็มหลอดทั้งที่ยังไม่ได้วิ่ง
--
-- เซิร์ฟนี้นับหิว/กระหายเองอยู่แล้ว (ด้านบน) แกนของเกมจึงถูกกดเต็มค้างไว้แทน
-- ส่วนหลอดนอกเติมให้เฉพาะตอน ped เปลี่ยนตัวเท่านั้น ไม่งั้นวิ่งเท่าไหร่ก็ไม่มีวันเหนื่อย

--- coreIndex ของ _SET_ATTRIBUTE_CORE_VALUE: 0 = สุขภาพ, 1 = สเตมินา, 2 = เดดอาย
local Cores = {
    { key = 'health',  index = 0 },
    { key = 'stamina', index = 1 },
    { key = 'deadeye', index = 2 },
}

local function coresConfig()
    local cfg = statusConfig()
    return cfg and cfg.Cores or nil
end

local function getCoreValue(ped, index)
    -- _GET_ATTRIBUTE_CORE_VALUE(ped, coreIndex) -> 0-100
    return tonumber(Citizen.InvokeNative(0x36731AC041289BB1, ped, index, Citizen.ResultAsInteger())) or 0
end

--- เติมแกนให้ถึงค่าที่ตั้งไว้ + (ถ้าสั่ง) เติมหลอดสเตมินาด้านนอกจนเต็ม
--- เขียนเฉพาะแกนที่ยังไม่ถึงค่าเป้าหมาย — เขียนทับทุกรอบไอคอนแกนจะกะพริบให้เห็นทุก 5 วิ
local function refillCores(fullStamina)
    local cfg = coresConfig()
    if not cfg or not cfg.enabled then return end

    local ped = PlayerPedId()
    if not DoesEntityExist(ped) or IsEntityDead(ped) then return end

    for _, core in ipairs(Cores) do
        local target = tonumber(cfg[core.key])
        if target then
            target = math.floor(clamp(target))
            if getCoreValue(ped, core.index) < target then
                -- _SET_ATTRIBUTE_CORE_VALUE(ped, coreIndex, value)
                Citizen.InvokeNative(0xC6258F41D86676E0, ped, core.index, target)
            end
        end
    end

    if fullStamina then
        local target = tonumber(cfg.staminaOnSpawn)
        if target then
            -- _RESTORE_PED_STAMINA(ped, 0.0-100.0)
            Citizen.InvokeNative(0x675680D089BFA21F, ped, clamp(target) + 0.0)
        end
    end
end

-- ped เปลี่ยนตัวเมื่อไหร่ = ถือว่าเพิ่งเกิด/เพิ่งเปลี่ยนโมเดล ให้เติมหลอดนอกให้ด้วยหนึ่งครั้ง
-- (ดักด้วยการเทียบ handle ถูกกว่าการไปไล่ดักทุกเหตุการณ์ที่สร้าง ped ใหม่)
-- ฟื้นจากตายนับด้วย: หมอชุบ/แอดมิน revive ได้ ped ตัวเดิมกลับมาแต่หลอดสเตมินาว่างเปล่า
CreateThread(function()
    local lastPed = 0
    local wasDead = false

    while true do
        local cfg = coresConfig()
        local interval = cfg and tonumber(cfg.interval) or 5000
        if interval < 1000 then interval = 1000 end

        Wait(interval)

        if LocalPlayer.state.isLoggedIn then
            local ped = PlayerPedId()
            local dead = IsEntityDead(ped)
            local reborn = ped ~= lastPed or (wasDead and not dead)

            lastPed = ped
            wasDead = dead

            refillCores(reborn)
        end
    end
end)

AddEventHandler('HexaCore:Client:OnPlayerLoaded', function()
    refillCores(true)
end)

-- ============================================================
-- exports
-- ============================================================

exports('GetStatus', function(key)
    if key then return status[key] end
    return {
        hunger      = status.hunger,
        thirst      = status.thirst,
        cleanliness = status.cleanliness,
        stress      = status.stress,
    }
end)

--- เติมแกน (และหลอดสเตมินา) ให้เต็มเดี๋ยวนี้ — สคริปต์อื่นเรียกได้หลังชุบ/หลังเปลี่ยนโมเดล
--- exports['hexa_core']:RefillCores()      -- เติมแกน + หลอดสเตมินา
--- exports['hexa_core']:RefillCores(false) -- เติมเฉพาะแกน ไม่ยุ่งกับหลอดสเตมินา
exports('RefillCores', function(fullStamina)
    refillCores(fullStamina ~= false)
end)
