-- Notify: ส่งต่อ hexa_notify (ไม่มีก็ถอยไป chat) — ห้าม hexa_notify ฟัง HexaCore:Notify เอง ไม่งั้นแจ้งเตือนซ้ำสองครั้ง
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

-- โหลด/ออกตัวละคร — สคริปต์อื่นเช็คสถานะได้ด้วย: if LocalPlayer.state['isLoggedIn'] then (ดู docs guide/player-object)

-- ปิดเลือดฟื้นเองจากแกนสุขภาพของ RDR2 — 0.0 = ไม่ฟื้น, 1.0 = ตามเกมเดิม (ตั้งตายตัวที่นี่ ไม่มีใน config)
local function DisableHealthRecharge()
    local ped = PlayerPedId()
    -- ตัวแรกรับ "player index" ไม่ใช่ ped — ส่ง ped เข้าไปเท่ากับสั่งคนละคน (ไม่ได้ปิดอะไรเลย)
    Citizen.InvokeNative(0x8899C244EBCF70DE, PlayerId(), 0.0) -- SET_PLAYER_HEALTH_RECHARGE_MULTIPLIER(player, float)
    Citizen.InvokeNative(0xDE1B1907A83A1550, ped, 0.0)        -- _SET_HEALTH_RECHARGE_MULTIPLIER(ped, int)
end

-- ค่านี้ผูกกับ ped เกมรีเซ็ตทุกครั้งที่ ped ใหม่ (เกิด/ชุบ/เปลี่ยนโมเดล) ตั้งตอน login ครั้งเดียวไม่พอ ต้องตอกซ้ำ
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

    -- GetVehiclePedIsIn คืน 0 ตอนไม่ได้อยู่ในพาหนะ และ 0 ใน Lua เป็นค่าจริง ต้องเทียบ ~= 0 เองเหมือนด่าน mount ข้างบน
    if vehicle and vehicle ~= 0 then
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
    Core.PlayerData = val
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
RegisterNetEvent('HexaCore:Client:TriggerClientCallback', function(name, id, ...)
    -- ต้องส่ง id กลับไปด้วย ฝั่ง server ใช้คู่ (src, id) หาคิวที่รออยู่ ถ้าส่งแต่ชื่อจะไปกินคิวของคนอื่นได้
    Core.TriggerClientCallback(name, function(...)
        TriggerServerEvent('HexaCore:Server:TriggerClientCallback', name, id, ...)
    end, ...)
end)

-- Server Callback
RegisterNetEvent('HexaCore:Client:TriggerCallback', function(name, id, ...)
    -- หยิบด้วย id ของการเรียกครั้งนั้น ไม่ใช่ชื่อ ไม่งั้นสองคำขอชื่อเดียวกันจะสลับคำตอบกัน
    local cb = Core.ServerCallbacks[id]
    if not cb then return end
    Core.ServerCallbacks[id] = nil
    cb(...)
end)

-- คำสั่ง me: rb_thaifont แค่สตรีม ThaiFont.gfx ต้อง register เอง และ RegisterFontId คืน -1 ช่วงแรก จึง poll+cache
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
    Core.Shared[tableName][key] = value
    TriggerEvent('HexaCore:Client:UpdateObject')
end)

RegisterNetEvent('HexaCore:Client:OnSharedUpdateMultiple', function(tableName, values)
    for key, value in pairs(values) do
        Core.Shared[tableName][key] = value
    end
    TriggerEvent('HexaCore:Client:UpdateObject')
end)

-- Shared (Items/Jobs): ต้องยิง UpdateObject ต่อ ไม่งั้นสำเนา core object ของ resource อื่นค้างว่างทั้ง session
RegisterNetEvent('HexaCore:Client:SharedUpdate', function(shared)
    Core.Shared = shared
    TriggerEvent('HexaCore:Client:UpdateObject')
end)

-- CSRF (NUI<->client เท่านั้น): กัน NUI อื่นยิง callback ปลอม ไม่ใช่ความปลอดภัยฝั่ง server ที่ต้องตัดสินใจเองเสมอ
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

    -- รายงานเฉยๆ ไม่สั่งเตะ (เดิม client สั่ง server เตะตัวเอง) — server ตัดสินตาม Config.Security.CSRFFailurePolicy
    TriggerServerEvent('HexaCore:Server:ReportCSRFFailure')
    cb({ valid = false })
end)
