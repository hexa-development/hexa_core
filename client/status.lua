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
