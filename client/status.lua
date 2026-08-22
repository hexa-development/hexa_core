-- hexa_core — สถานะร่างกาย (client): server นับเวลา/คำนวณให้ ที่นี่แค่หักเลือดตอนหิวจัด (ต้องแตะ ped) และแคชค่าให้ HUD

local StatusKeys = { 'hunger', 'thirst', 'cleanliness', 'stress' }

--- ค่าล่าสุดจาก server — เริ่มที่ 100 ไว้ก่อน กัน HUD วาดแถบว่างช่วงก่อน UpdateNeeds ก้อนแรกมาถึง
local status = { hunger = 100, thirst = 100, cleanliness = 100, stress = 0 }

local function clamp(value)
    return math.min(math.max(tonumber(value) or 0, 0), 100)
end

local function statusConfig()
    return HexaCore.Config and HexaCore.Config.Status or nil
end

-- รับค่าจาก server

RegisterNetEvent('HexaCore:Client:UpdateNeeds', function(incoming)
    if type(incoming) ~= 'table' then return end
    for _, key in ipairs(StatusKeys) do
        if incoming[key] ~= nil then status[key] = clamp(incoming[key]) end
    end
end)

-- ต้องรับ SetPlayerData ด้วย ไม่ใช่แค่ UpdateNeeds ไม่งั้นสคริปต์ที่เรียก SetMetaData ตรงๆ จะทำให้ HUD ค้างค่าเก่า
RegisterNetEvent('HexaCore:Player:SetPlayerData', function(playerData)
    local metadata = playerData and playerData.metadata
    if type(metadata) ~= 'table' then return end
    for _, key in ipairs(StatusKeys) do
        if metadata[key] ~= nil then status[key] = clamp(metadata[key]) end
    end
end)

-- ขอค่าชุดแรกซ้ำเอง เพราะ resource ที่ restart กลางเกม (เช่น hexa_status) ไม่ได้เห็น PlayerLoaded รอบแรก
RegisterNetEvent('HexaCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('HexaCore:Server:RequestStatus')
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if LocalPlayer.state.isLoggedIn then
        TriggerServerEvent('HexaCore:Server:RequestStatus')
    end
end)

-- หักเลือดตอนหิวจัด / กระหายจัด

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

-- แกนทอง/สเตมินา: ค่าผูกกับ ped ไม่ใช่ผู้เล่น ped ใหม่จึงไม่สืบค่าเดิม — กดแกนเต็มค้าง หลอดนอกเติมเฉพาะตอน ped เปลี่ยน

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

--- เติมแกน (+ หลอดสเตมินาถ้าสั่ง) เฉพาะแกนที่ยังไม่ถึงเป้า — เขียนทับทุกรอบไอคอนแกนจะกะพริบทุก 5 วิ
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

-- เทียบ handle ped + ธงตาย = รู้ว่าเพิ่งเกิด/เปลี่ยนโมเดล/ถูกชุบ (ชุบแล้ว ped เดิมกลับมาแต่สเตมินาว่าง) จึงเติมหลอดนอก
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

-- exports — รายละเอียดพารามิเตอร์/ค่าที่คืน ดู docs api/exports

exports('GetStatus', function(key)
    if key then return status[key] end
    return {
        hunger      = status.hunger,
        thirst      = status.thirst,
        cleanliness = status.cleanliness,
        stress      = status.stress,
    }
end)

--- เติมแกน+หลอดสเตมินาเดี๋ยวนี้ (ส่ง false = เฉพาะแกน) สำหรับสคริปต์อื่นเรียกหลังชุบ/เปลี่ยนโมเดล
exports('RefillCores', function(fullStamina)
    refillCores(fullStamina ~= false)
end)
