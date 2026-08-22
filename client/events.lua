-- Built-in notification
-- ปลายทางจริงคือ hexa_notify (toast NUI) ถ้ามัน started ก็ส่งต่อไปให้มันวาด
-- ห้ามให้ hexa_notify มา RegisterNetEvent('HexaCore:Notify') เองเด็ดขาด —
-- event นี้มี handler อยู่ตรงนี้แล้ว ถ้าไปฟังซ้ำจะได้แจ้งเตือนสองครั้งทุกครั้ง
-- ส่วน chat:addMessage ข้างล่างคือทางถอยเมื่อไม่มี hexa_notify
local notifyColors = {
    error = { 214, 66, 66 },
    success = { 66, 214, 111 },
    info = { 66, 145, 214 },
    primary = { 66, 145, 214 },
    warning = { 214, 175, 66 }
}

local function Notify(data)
    if type(data) == 'string' then data = { description = data } end
    if type(data) ~= 'table' then return end

    if GetResourceState('hexa_notify') == 'started' then
        local ok, handled = pcall(function()
            return exports['hexa_notify']:CoreNotify(data)
        end)
        if ok and handled then return end
    end

    local text = data.title or ''
    if data.description and data.description ~= '' then
        text = text ~= '' and (text .. ': ' .. data.description) or data.description
    end
    TriggerEvent('chat:addMessage', {
        color = notifyColors[data.type] or notifyColors.info,
        multiline = true,
        args = { 'System', text }
    })
end

RegisterNetEvent('HexaCore:Notify', Notify)

-- Place Ped on ground properly
local function PlacePedOnGroundProperly(ped, coord)
    local x, y, z = table.unpack(coord)
    local found, groundz, normal = GetGroundZAndNormalFor_3dCoord(x, y, z)

    if found then
        SetEntityCoordsNoOffset(ped, x, y, groundz + normal.z, true)
    end
end

-- Player load and unload handling
-- New method for checking if logged in across all scripts (optional)
-- if LocalPlayer.state['isLoggedIn'] then
-- ปิด "เลือดฟื้นเองจากแกนสุขภาพ" ของ RDR2
-- ตั้ง 0.0 = ไม่ฟื้นเลย / 1.0 = ฟื้นตามเกมเดิม (ที่นี่ที่เดียว ไม่มีใน config)
local function DisableHealthRecharge()
    local ped = PlayerPedId()
    -- ตัวแรกรับ "player index" ไม่ใช่ ped — ส่ง ped เข้าไปเท่ากับสั่งคนละคน (ไม่ได้ปิดอะไรเลย)
    Citizen.InvokeNative(0x8899C244EBCF70DE, PlayerId(), 0.0) -- SET_PLAYER_HEALTH_RECHARGE_MULTIPLIER(player, float)
    Citizen.InvokeNative(0xDE1B1907A83A1550, ped, 0.0)        -- _SET_HEALTH_RECHARGE_MULTIPLIER(ped, int)
end

-- ค่านี้ผูกกับตัว ped ไม่ใช่ตัวผู้เล่น เกมจึงรีเซ็ตกลับเป็นค่าเริ่มต้นทุกครั้งที่
-- ped ถูกสร้าง/ฟื้นใหม่ (เกิดใหม่ · ถูกหมอชุบ · แอดมิน revive · เปลี่ยนโมเดล)
-- ตั้งครั้งเดียวตอน login จึงไม่พอ — พอตายรอบแรกเลือดก็กลับมาไต่ขึ้นเอง
-- ตอกซ้ำทุก 5 วิ (สอง native ต่อรอบ ถูกกว่าการไปดักทุกเหตุการณ์ที่สร้าง ped ใหม่)
CreateThread(function()
    while true do
        Wait(5000)
        if LocalPlayer.state.isLoggedIn then
            DisableHealthRecharge()
        end
    end
end)

RegisterNetEvent('HexaCore:Client:OnPlayerLoaded', function()
    ShutdownLoadingScreenNui()
    LocalPlayer.state:set('isLoggedIn', true, false)
    Citizen.InvokeNative(0xF808475FA571D823, true)
    SetRelationshipBetweenGroups(5, 'PLAYER', 'PLAYER')
    if Config.Player.RevealMap then
        SetMinimapHideFow(true)
    end
    Citizen.InvokeNative(0x39363DFD04E91496, PlayerId(), true) -- enable mercy kil
    DisableHealthRecharge()
end)

RegisterNetEvent('HexaCore:Client:OnPlayerUnload', function()
    LocalPlayer.state:set('isLoggedIn', false, false)
end)

-- Teleport Commands

RegisterNetEvent('HexaCore:Command:TeleportToPlayer', function(coords)
    SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z)
end)

RegisterNetEvent('HexaCore:Command:TeleportToCoords', function(x, y, z, h)
    SetEntityCoords(PlayerPedId(), x, y, z)
end)

RegisterNetEvent('HexaCore:Command:GoToMarker', function()
    local ped = PlayerPedId()
    local coords = GetWaypointCoords()
    local groundZ = GetHeightmapBottomZForPosition(coords.x, coords.y)
    local vehicle = GetVehiclePedIsIn(ped, false)
    if not IsWaypointActive() then
        Notify({ title = Lang:t("error.no_waypoint"), type = 'error', duration = 5000 })
        return
    end

    SetEntityCoords(ped, coords.x, coords.y, groundZ + 3.0)
    PlacePedOnGroundProperly(ped, coords)

    local mount = GetMount(ped)
    if mount and mount ~= 0 then
        SetEntityCoords(mount, coords.x, coords.y, groundZ + 3.0)
        PlacePedOnGroundProperly(mount, coords)
        Citizen.InvokeNative(0x028F76B6E78246EB, ped, mount, -1)
    end

    if vehicle then
        SetEntityCoords(vehicle, coords.x, coords.y, groundZ + 3.0)
        PlacePedOnGroundProperly(vehicle, coords)
        Citizen.InvokeNative(0x028F76B6E78246EB, ped, vehicle, -1)
    end

    Notify({ title = Lang:t("success.teleported_waypoint"), type = 'success', duration = 5000 })
end)

-- Noclip Command
RegisterNetEvent('HexaCore:Command:ToggleNoClip', function()
    ExecuteCommand('txAdmin:menu:noClipToggle')
end)

-- Vehicle Commands

RegisterNetEvent('HexaCore:Command:SpawnVehicle', function(vehName)
    local ped = PlayerPedId()
    local hash = joaat(vehName)
    local veh = GetVehiclePedIsUsing(ped)
    if not IsModelInCdimage(hash) then return end
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(0)
    end

    if IsPedInAnyVehicle(ped) then
        SetEntityAsMissionEntity(veh, true, true)
        DeleteVehicle(veh)
    end

    local vehicle = CreateVehicle(hash, GetEntityCoords(ped), GetEntityHeading(ped), true, false)
    TaskWarpPedIntoVehicle(ped, vehicle, -1)
    SetVehicleDirtLevel(vehicle, 0.0)
    SetModelAsNoLongerNeeded(hash)
end)

RegisterNetEvent('HexaCore:Command:DeleteVehicle', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsUsing(ped)
    if veh ~= 0 then
        SetEntityAsMissionEntity(veh, true, true)
        DeleteVehicle(veh)
    else
        local pcoords = GetEntityCoords(ped)
        local vehicles = GetGamePool('CVehicle')
        for _, v in pairs(vehicles) do
            if #(pcoords - GetEntityCoords(v)) <= 5.0 then
                SetEntityAsMissionEntity(v, true, true)
                DeleteVehicle(v)
            end
        end
    end
end)

-- Other stuff

RegisterNetEvent('HexaCore:Player:SetPlayerData', function(val)
    HexaCore.PlayerData = val
end)

RegisterNetEvent('HexaCore:Player:UpdatePlayerData', function()
    TriggerServerEvent('HexaCore:UpdatePlayer')
end)

-- This event is exploitable and should not be used. It has been deprecated, and will be removed soon.
RegisterNetEvent('HexaCore:Client:UseItem', function(item)
    Core.Warn('%s triggered the deprecated HexaCore:Client:UseItem for id %s - this event is exploitable and goes away next release, use hexa_inventory instead',
        tostring(GetInvokingResource()), GetPlayerServerId(PlayerId()))
    Core.DumpTable(item)
end)

-- Callback Events --

-- Client Callback
RegisterNetEvent('HexaCore:Client:TriggerClientCallback', function(name, ...)
    HexaCore.TriggerClientCallback(name, function(...)
        TriggerServerEvent('HexaCore:Server:TriggerClientCallback', name, ...)
    end, ...)
end)

-- Server Callback
RegisterNetEvent('HexaCore:Client:TriggerCallback', function(name, ...)
    if HexaCore.ServerCallbacks[name] then
        HexaCore.ServerCallbacks[name](...)
        HexaCore.ServerCallbacks[name] = nil
    end
end)

-- Me command
-- Thai-capable font. rb_thaifont only STREAMS ThaiFont.gfx; register + use it here
-- directly. RegisterFontId returns -1 for a few frames until the gfx streams in, so
-- poll briefly and cache. Falls back to native font 2 until ready.
local thaiFont
CreateThread(function()
    RegisterFontFile('ThaiFont')            -- streamed .gfx asset name (no extension)
    local tries = 0
    repeat
        local id = RegisterFontId('ThaiFont')   -- DefineFont family name embedded in ThaiFont.gfx
        if id and id >= 0 then thaiFont = id break end
        tries = tries + 1
        Wait(50)
    until tries > 100
end)
local function ThaiFont()
    return thaiFont or 2
end

local function Draw3DText(coords, str)
    local onScreen, worldX, worldY = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z)
    local camCoords = GetGameplayCamCoord()
    local scale = 200 / (GetGameplayCamFov() * #(camCoords - coords))

    if onScreen then
        -- Set the text color using SetTextColor (RedM version)
        SetTextColor(255, 255, 255, 255) -- White color with full opacity

        -- Set the text scale (RedM requires slight adjustment)
        SetTextScale(0.0, 0.5 * scale) -- Adjust the scale values as needed

        -- Set the font: Thai-capable font (rb_thaifont), falls back to native 2.
        SetTextFontForCurrentCommand(ThaiFont())

        -- Center the text
        SetTextCentre(true)

        -- Create the text to be displayed using a variable string
        local varString = CreateVarString(10, "LITERAL_STRING", str)

        -- Display the text at the world coordinates (converted to screen coordinates)
        DisplayText(varString, worldX, worldY)
    end
end

RegisterNetEvent('HexaCore:Command:ShowMe3D', function(senderId, msg)
    local sender = GetPlayerFromServerId(senderId)
    CreateThread(function()
        local displayTime = 10000 + GetGameTimer()
        while displayTime > GetGameTimer() do
            local targetPed = GetPlayerPed(sender)
            local tCoords = GetEntityCoords(targetPed)
            Draw3DText(tCoords, msg)
            Wait(0)
        end
    end)
end)

-- Listen to Shared being updated
RegisterNetEvent('HexaCore:Client:OnSharedUpdate', function(tableName, key, value)
    HexaCore.Shared[tableName][key] = value
    TriggerEvent('HexaCore:Client:UpdateObject')
end)

RegisterNetEvent('HexaCore:Client:OnSharedUpdateMultiple', function(tableName, values)
    for key, value in pairs(values) do
        HexaCore.Shared[tableName][key] = value
    end
    TriggerEvent('HexaCore:Client:UpdateObject')
end)

-- Shared ทั้งก้อน (Items/Jobs/...) ส่งมาตอน connecting และตอน RequestSpawn
--
-- ต้องยิง 'HexaCore:Client:UpdateObject' ต่อเสมอ: resource อื่นเก็บ core object
-- เป็น "สำเนา msgpack" จาก GetCoreObject() (ดู hexa_inventory/shared/compat.lua)
-- แล้วรอสัญญาณนี้เพื่อดึงสำเนาใหม่ ถ้าไม่ยิง สำเนาที่เขาถืออยู่จะเป็นแคตตาล็อก
-- ว่างค้างทั้ง session -> HexaCore.Shared.Items[...] พลาดหมด (อาการที่เจอ:
-- ไอเทมชนิดที่ไม่เคยมีในกระเป๋า ซื้อแล้วไม่ขึ้นจนกว่าจะ restart resource)
RegisterNetEvent('HexaCore:Client:SharedUpdate', function(shared)
    HexaCore.Shared = shared
    TriggerEvent('HexaCore:Client:UpdateObject')
end)

-- ============================================================
-- CSRF protection (NUI <-> client only)
-- ============================================================
-- ขอบเขตที่แท้จริงของกลไกนี้: กันไม่ให้หน้า NUI *อื่น* (หรือ iframe/สคริปต์ที่หลุด
-- เข้ามาในเบราว์เซอร์ของ client) ยิง callback ปลอมเข้ามาที่ Lua ฝั่ง client
--
-- ⚠️ ไม่ใช่ระบบความปลอดภัยฝั่ง server และห้ามใช้แทนกันเด็ดขาด:
-- token ถูกสร้างที่ client ส่งเข้า NUI ของ client เอง แล้ว client ตรวจเอง
-- ผู้เล่นที่ควบคุมเครื่องตัวเองอยู่แล้วเลี่ยงได้ทั้งเส้น (ไม่เรียก validateCSRF
-- ก็ได้) อำนาจตัดสินใจจริงต้องอยู่ที่ server ทุกครั้ง — ดูการเช็คสิทธิ์/ระยะ/
-- จำนวนเงินฝั่ง server ใน resource ต่าง ๆ
local csrfToken = nil

local function GenerateCSRFToken()
    local timeout = 500
    while csrfToken and timeout > 0 do
        timeout = timeout - 1
        Wait(0)
    end

    local token = tostring(math.random(100000, 999999)) .. GetGameTimer()
    csrfToken = token

    return token
end
exports('GenerateCSRFToken', GenerateCSRFToken)

RegisterNUICallback('validateCSRF', function(data, cb)
    if csrfToken and csrfToken == data.clientToken then
        csrfToken = nil
        return cb({ valid = true })
    end

    -- เดิมบรรทัดนี้คือ TriggerServerEvent('HexaCore:Server:KickCSRF') ซึ่ง server
    -- เตะทันทีตามคำสั่ง client = "client สั่งให้ server เตะตัวเอง" ไม่ใช่การตัดสินใจ
    -- ของ server เลย ตอนนี้เปลี่ยนเป็นการ "รายงาน" แล้ว server เป็นคนตัดสินเองว่า
    -- จะทำอะไรตาม Config.Security.CSRFFailurePolicy (ค่าเริ่มต้น = log เท่านั้น)
    TriggerServerEvent('HexaCore:Server:ReportCSRFFailure')
    cb({ valid = false })
end)
