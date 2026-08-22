-- spawn อัตโนมัติ ไม่มีหน้าจอเลือกจุดเกิด: ขอตำแหน่งจาก server (ตัวใหม่ = Config.DefaultSpawn), docs guide/persistence

local spawned = false
local resuming = false

-- ต้องรีเซ็ตธง spawned ตอน unload ไม่งั้น guard `if spawned then return` บล็อก SpawnPlayer รอบถัดไปทิ้ง
RegisterNetEvent('HexaCore:Client:OnPlayerUnload', function()
    spawned = false
end)

-- mp_male/female เป็น metaped เปล่า ต้อง enable ชิ้นส่วนร่างกายเอง ไม่งั้นล่องหน (hash = ตัวแรกของหมวดใน rb_appearance)
local BASE_COMPONENTS = {
    male = {
        0xF6496128, -- BODIES_UPPER  (ลำตัวท่อนบน)
        0x0A615E02, -- BODIES_LOWER  (ลำตัวท่อนล่าง)
        0xF0FB1DF0, -- heads         (หัว)
        0x6F1CFE41, -- eyes          (ตา)
        0x2A7712A2, -- teeth         (ฟัน)
    },
    female = {
        0x928DAD43, -- BODIES_UPPER
        0xF0CD92EC, -- BODIES_LOWER
        0x9D251F06, -- heads
        0x375030AD, -- eyes
        0x39340BFF, -- teeth
    },
}

-- แปลงเพศ -> ชื่อโมเดล (gender: 0/'m' = ชาย, 1/'f' = หญิง)
function HexaGenderToModel(gender)
    if gender == 1 or gender == '1' or gender == 'f' or gender == 'female' then
        return 'mp_female', 'female'
    end
    return 'mp_male', 'male'
end

-- native wrappers (คัดจาก rb_appearance)
local function updatePedVariation(ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
end

local function setPedComponentEnabled(ped, componentHash)
    -- 0xD3A7B003ED343FD9 = SetPedComponentEnabled(ped, hash, immediately=false, isMp=true, ?=true)
    Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, componentHash, false, true, true)
    updatePedVariation(ped)
end

---@param ped number
---@param sex string 'male' | 'female' (ค่าเริ่มต้น male)
function applyNakedBase(ped, sex)
    local parts = BASE_COMPONENTS[sex] or BASE_COMPONENTS.male
    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, ped, 7, false) -- SetMetaPedType (7 = player metaped)
    updatePedVariation(ped)

    -- enable ทีละหมวดแล้ววน retry จน component โหลดครบ (0xA0BC8FAED8CFEB3C = HasPedComponentLoaded)
    for attempt = 1, 10 do
        for i = 1, #parts do
            setPedComponentEnabled(ped, parts[i])
        end
        Citizen.InvokeNative(0xAAB86462966168CE, ped, true) -- refresh ให้วาดผลทันที
        if Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) then break end
        Wait(100)
    end
end

CreateThread(function()
    -- เปิด MultiCharacter อยู่ = ปิด auto-login ให้ multichar เป็นคนสั่ง spawn เอง (handler ด้านล่างยังทำงานให้)
    if HexaCore.Config.MultiCharacter then return end

    resuming = NetworkIsSessionStarted()

    -- จอดำระหว่างรอโหลดข้อมูล (ทั้งเข้าครั้งแรกและ restart)
    DoScreenFadeOut(0)

    if not resuming then
        while not NetworkIsSessionStarted() do Wait(100) end
    end

    -- RedM สร้าง ped ให้เองหลัง session เริ่ม แค่รอ ไม่ต้องเรียก spawnmanager — เกิน 10 วิยังไม่มาค่อยใช้เป็น fallback
    local ped = PlayerPedId()
    local pedDeadline = GetGameTimer() + 10000
    local forcedSpawn = false
    while not DoesEntityExist(ped) do
        if not forcedSpawn and GetGameTimer() > pedDeadline then
            forcedSpawn = true
            exports.spawnmanager:setAutoSpawn(false)
            exports.spawnmanager:spawnPlayer({
                x = Config.DefaultSpawn.x,
                y = Config.DefaultSpawn.y,
                z = Config.DefaultSpawn.z,
                heading = Config.DefaultSpawn.w or 0.0,
                skipFade = true,
            })
        end
        Wait(100)
        ped = PlayerPedId()
    end

    -- freeze + ซ่อนตัวไว้ระหว่างรอข้อมูลจากฐานข้อมูล
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)

    -- ขอ spawn จาก server แล้วรอ ถ้าไม่ตอบใน 10 วิ ขอใหม่ (กันแพ็กเก็ตหลุด)
    while not spawned do
        TriggerServerEvent('HexaCore:Server:RequestSpawn')
        local waited = 0
        while not spawned and waited < 10000 do
            Wait(100)
            waited = waited + 100
        end
    end
end)

---@param pos table ตำแหน่ง spawn
---@param health number เลือด
---@param gender any เพศของตัวละคร (0/'m' = ชาย, 1/'f' = หญิง) - server ส่งมาจาก DB
RegisterNetEvent('HexaCore:Client:SpawnPlayer', function(pos, health, gender)
    if spawned then return end
    spawned = true

    local ped = PlayerPedId()
    DoScreenFadeOut(0)

    -- เลือกโมเดลตามเพศที่ผู้เล่นเลือกไว้ตอนสร้างตัวละคร (ไม่ใช่ mp_male ตายตัว)
    local modelName, sex = HexaGenderToModel(gender)
    local model = joaat(modelName)
    RequestModel(model)
    local modelDeadline = GetGameTimer() + 10000
    while not HasModelLoaded(model) and GetGameTimer() < modelDeadline do Wait(10) end

    if HasModelLoaded(model) then
        Citizen.InvokeNative(0xED40380076A31506, PlayerId(), model, false) -- SetPlayerModel
        -- รอ engine สลับ ped ให้เสร็จ (ได้ ped ตัวใหม่) ก่อนทำขั้นตอนถัดไป
        local swapDeadline = GetGameTimer() + 3000
        repeat
            Wait(0)
            ped = PlayerPedId()
        until GetEntityModel(ped) == model or GetGameTimer() > swapDeadline
        SetModelAsNoLongerNeeded(model)
    end

    FreezeEntityPosition(ped, true)

    -- วาร์ปไปตำแหน่งล่าสุดจาก DB (ตอน restart = จุดที่ยืนล่าสุด เพราะ server เซฟก่อนหยุดเสมอ)
    SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false)
    SetEntityHeading(ped, pos.w or 0.0)

    -- รอ collision รอบตัวโหลดเสร็จหลังจอดำ (เพดาน 8 วิ กันค้างถาวร)
    local deadline = GetGameTimer() + 8000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < deadline do
        RequestCollisionAtCoord(pos.x, pos.y, pos.z)
        Wait(50)
    end

    -- วางลงพื้นพอดี ไม่ลอย/ไม่จมดิน
    local found, groundZ = GetGroundZAndNormalFor_3dCoord(pos.x, pos.y, pos.z + 0.5)
    if found then
        SetEntityCoordsNoOffset(ped, pos.x, pos.y, groundZ + 0.1, false, false, false)
    end

    -- ตั้งร่างเปล่า *หลัง* วาร์ป+collision โหลดเสร็จ ทำก่อนหน้านั้น component mesh จะสตรีมไม่เข้า = ล่องหน
    ped = PlayerPedId()
    applyNakedBase(ped, sex)

    -- คืนสภาพตัวละคร + ตั้งเลือดตามที่เซฟไว้
    SetEntityCollision(ped, true, true)
    SetEntityVisible(ped, true, false)
    SetEntityAlpha(ped, 255, false) -- reset alpha เผื่อค้างจากตอนซ่อน
    ResetEntityAlpha(ped)
    SetEntityInvincible(ped, false)
    FreezeEntityPosition(ped, false)
    -- คืน player control เผื่อ spawnmanager freeze ค้างไว้ (SetPlayerControl)
    Citizen.InvokeNative(0x8D32347D6D4C40A2, PlayerId(), true, 0, false)
    if health and health > 0 then
        SetEntityHealth(ped, health)
    end

    -- ปิดหน้าโหลดแล้วเข้าเกมทันที
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    DoScreenFadeIn(500)

    -- แจ้งทั้ง server และ client ว่าผู้เล่นเข้าเกมสมบูรณ์แล้ว
    TriggerServerEvent('HexaCore:Server:OnPlayerLoaded')
    TriggerEvent('HexaCore:Client:OnPlayerLoaded')
end)
