-- ห้ามประกาศตาราง Functions ซ้ำที่นี่ จะล้าง metatable มิเรอร์ของ main.lua ทิ้ง จน bridge ที่ยกด้วย pairs() ได้ศูนย์ตัว

-- Asset loading helpers (native replacements for ox_lib)

local function requestModel(model, timeout)
    model = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(model) then return end
    RequestModel(model)
    local deadline = GetGameTimer() + (timeout or 10000)
    while not HasModelLoaded(model) do
        if GetGameTimer() > deadline then return end
        Wait(0)
    end
    return model
end

local function requestAnimDict(animDict, timeout)
    if not DoesAnimDictExist(animDict) then return end
    RequestAnimDict(animDict)
    local deadline = GetGameTimer() + (timeout or 10000)
    while not HasAnimDictLoaded(animDict) do
        if GetGameTimer() > deadline then return end
        Wait(0)
    end
    return animDict
end

local function requestAnimSet(animSet, timeout)
    RequestAnimSet(animSet)
    local deadline = GetGameTimer() + (timeout or 10000)
    while not HasAnimSetLoaded(animSet) do
        if GetGameTimer() > deadline then return end
        Wait(0)
    end
    return animSet
end

local function requestNamedPtfxAsset(ptFxName, timeout)
    RequestNamedPtfxAsset(ptFxName)
    local deadline = GetGameTimer() + (timeout or 10000)
    while not HasNamedPtfxAssetLoaded(ptFxName) do
        if GetGameTimer() > deadline then return end
        Wait(0)
    end
    return ptFxName
end

-- Callbacks

function Core.CreateCallback(name, cb)
    Core.ClientCallbacks[name] = cb
end

function Core.TriggerClientCallback(name, cb, ...)
    if not Core.ClientCallbacks[name] then return end
    Core.ClientCallbacks[name](cb, ...)
end

-- ตั๋วประจำการเรียกแต่ละครั้ง เก็บ cb ตามชื่ออย่างเดียวทำให้ยิงชื่อเดียวกันซ้อนกันแล้วคำตอบไขว้กันหรือหายไปเลย
local requestId = 0

function Core.TriggerCallback(name, cb, ...)
    requestId = requestId + 1
    Core.ServerCallbacks[requestId] = cb
    TriggerServerEvent('HexaCore:Server:TriggerCallback', name, requestId, ...)
end

-- ใช้ Core.PrintDebug/Core.DumpTable ที่ shared/log.lua แทน Core.Debug เดิมที่ชน signature ฝั่ง server (docs guide/logging)

-- Player

function Core.GetPlayerData(cb)
    if not cb then return Core.PlayerData end
    cb(Core.PlayerData)
end

function Core.GetCoords(entity)
    local coords = GetEntityCoords(entity)
    return vector4(coords.x, coords.y, coords.z, GetEntityHeading(entity))
end

function Core.HasItem(items, amount)
    -- เช็ค started เหมือนฝั่ง server: ถามตอน hexa_inventory ยังไม่ขึ้น ต้องได้ false ไม่ใช่ error
    if GetResourceState('hexa_inventory') ~= 'started' then return false end
    return exports['hexa_inventory']:HasItem(items, amount)
end

---@param entity number - The entity to look at
---@param timeout number - The time in milliseconds before the function times out
---@param speed number - The speed at which the entity should turn
---@return number - The time at which the entity was looked at
function Core.TurnPedToFaceEntity(entity, timeout, speed)
    -- ต้องเช็คชนิดก่อน: DoesEntityExist ที่รับ string/table จะ error ทันที guard บรรทัดถัดไปไม่มีโอกาสทำงาน
    if type(entity) ~= 'number' then return end
    if not DoesEntityExist(entity) then return end
    if speed and type(speed) ~= 'number' then return end
    if speed and speed > 5.0 then speed = 5.0 end
    if not timeout or timeout > 5000 then timeout = 5000 end
    local ped = PlayerPedId()
    local playerPos = GetEntityCoords(ped)
    local targetPos = GetEntityCoords(entity)
    local dx = targetPos.x - playerPos.x
    local dy = targetPos.y - playerPos.y
    local targetHeading = GetHeadingFromVector_2d(dx, dy)
    local turnSpeed = speed
    local startTimeout = GetGameTimer()
    while true do
        local currentHeading = GetEntityHeading(ped)
        local diff = targetHeading - currentHeading
        if math.abs(diff) < 2 then
            break
        end
        if diff < -180 then
            diff = diff + 360
        elseif diff > 180 then
            diff = diff - 360
        end
        turnSpeed = speed + (2.5 - speed) * (1 - math.abs(diff) / 180)
        if diff > 0 then
            currentHeading = currentHeading + turnSpeed
        else
            currentHeading = currentHeading - turnSpeed
        end
        SetEntityHeading(ped, currentHeading)
        Wait(0)
        if (startTimeout + timeout) < GetGameTimer() then break end
    end
    SetEntityHeading(ped, targetHeading)
end

-- Function to run an animation
--- @param animDic string: The name of the animation dictionary
--- @param animName string - The name of the animation within the dictionary
--- @param duration number - The duration of the animation in milliseconds. -1 will play the animation indefinitely
--- @param upperbodyOnly boolean - If true, the animation will only affect the upper body of the ped
--- @return number - The timestamp indicating when the animation concluded. For animations set to loop indefinitely, this will still return the maximum duration of the animation.
function Core.PlayAnim(animDict, animName, upperbodyOnly, duration)
    local flags = upperbodyOnly and 16 or 0
    local runTime = duration or -1
    requestAnimDict(animDict)
    TaskPlayAnim(PlayerPedId(), animDict, animName, 8.0, 3.0, runTime, flags, 0.0, false, false, true)
    RemoveAnimDict(animDict)
end

-- ต้องคีย์ด้วย hash เพราะ GetEntityModel คืนตัวเลข เทียบกับชื่อ string ตรง ๆ ได้ false เสมอ ชายจะตกไปใช้ FemaleNoGloves
local MALE_MODELS = {
    [joaat('mp_male')] = true,
    [joaat('mp_m_freemode_01')] = true,
}

function Core.IsWearingGloves()
    local ped = PlayerPedId()
    local armIndex = GetPedDrawableVariation(ped, 3)
    local model = GetEntityModel(ped)
    if MALE_MODELS[model] then
        if Core.Shared.MaleNoGloves[armIndex] then
            return false
        end
    else
        if Core.Shared.FemaleNoGloves[armIndex] then
            return false
        end
    end
    return true
end

-- World Getters

function Core.GetVehicles()
    return GetGamePool('CVehicle')
end

function Core.GetObjects()
    return GetGamePool('CObject')
end

function Core.GetLocalPlayers()
    return GetActivePlayers()
end

function Core.GetLocalPlayersInRadius(coords, distance)
    local players = GetActivePlayers()
    local ped = PlayerPedId()
    if coords then
        coords = type(coords) == 'table' and vec3(coords.x, coords.y, coords.z) or coords
    else
        coords = GetEntityCoords(ped)
    end
    distance = distance or 5
    local closePlayers = {}
    for _, player in ipairs(players) do
        local targetCoords = GetEntityCoords(GetPlayerPed(player))
        local targetdistance = #(targetCoords - coords)
        if targetdistance <= distance then
            closePlayers[#closePlayers + 1] = player
        end
    end
    return closePlayers
end

function Core.GetClosestLocalPlayer(coords)
    local ped = PlayerPedId()
    if coords then
        coords = type(coords) == 'table' and vec3(coords.x, coords.y, coords.z) or coords
    else
        coords = GetEntityCoords(ped)
    end
    local closestPlayers = Core.GetLocalPlayersInRadius(coords)
    local closestDistance = -1
    local closestPlayer = -1
    for i = 1, #closestPlayers, 1 do
        if closestPlayers[i] ~= PlayerId() and closestPlayers[i] ~= -1 then
            local pos = GetEntityCoords(GetPlayerPed(closestPlayers[i]))
            local distance = #(pos - coords)

            if closestDistance == -1 or closestDistance > distance then
                closestPlayer = closestPlayers[i]
                closestDistance = distance
            end
        end
    end
    return closestPlayer, closestDistance
end

function Core.GetPeds(ignoreList)
    local pedPool = GetGamePool('CPed')
    local peds = {}
    local ignoreTable = {}
    ignoreList = ignoreList or {}
    for i = 1, #ignoreList do
        ignoreTable[ignoreList[i]] = true
    end
    for i = 1, #pedPool do
        if not ignoreTable[pedPool[i]] then
            peds[#peds + 1] = pedPool[i]
        end
    end
    return peds
end

function Core.GetClosestPed(coords, ignoreList)
    local ped = PlayerPedId()
    if coords then
        coords = type(coords) == 'table' and vec3(coords.x, coords.y, coords.z) or coords
    else
        coords = GetEntityCoords(ped)
    end
    ignoreList = ignoreList or {}
    local peds = Core.GetPeds(ignoreList)
    local closestDistance = -1
    local closestPed = -1
    for i = 1, #peds, 1 do
        local pedCoords = GetEntityCoords(peds[i])
        local distance = #(pedCoords - coords)

        if closestDistance == -1 or closestDistance > distance then
            closestPed = peds[i]
            closestDistance = distance
        end
    end
    return closestPed, closestDistance
end

function Core.GetClosestVehicle(coords)
    local ped = PlayerPedId()
    local vehicles = GetGamePool('CVehicle')
    local closestDistance = -1
    local closestVehicle = -1
    if coords then
        coords = type(coords) == 'table' and vec3(coords.x, coords.y, coords.z) or coords
    else
        coords = GetEntityCoords(ped)
    end
    for i = 1, #vehicles, 1 do
        local vehicleCoords = GetEntityCoords(vehicles[i])
        local distance = #(vehicleCoords - coords)

        if closestDistance == -1 or closestDistance > distance then
            closestVehicle = vehicles[i]
            closestDistance = distance
        end
    end
    return closestVehicle, closestDistance
end

function Core.GetClosestObject(coords)
    local ped = PlayerPedId()
    local objects = GetGamePool('CObject')
    local closestDistance = -1
    local closestObject = -1
    if coords then
        coords = type(coords) == 'table' and vec3(coords.x, coords.y, coords.z) or coords
    else
        coords = GetEntityCoords(ped)
    end
    for i = 1, #objects, 1 do
        local objectCoords = GetEntityCoords(objects[i])
        local distance = #(objectCoords - coords)
        if closestDistance == -1 or closestDistance > distance then
            closestObject = objects[i]
            closestDistance = distance
        end
    end
    return closestObject, closestDistance
end

-- Vehicle

Core.LoadModel = requestModel

---@param model string|number
---@param cb? fun(vehicle: number)
---@param coords? vector4 player position if not specified
---@param isnetworked? boolean defaults to true
---@param teleportInto boolean teleport player to driver seat if true
function Core.SpawnVehicle(model, cb, coords, isnetworked, teleportInto)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local combinedCoords = vec4(playerCoords.x, playerCoords.y, playerCoords.z, GetEntityHeading(playerPed))
    coords = type(coords) == 'table' and vec4(coords.x, coords.y, coords.z, coords.w or combinedCoords.w) or coords or combinedCoords
    model = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(model) then return end

    isnetworked = isnetworked == nil or isnetworked
    requestModel(model)
    local veh = CreateVehicle(model, coords.x, coords.y, coords.z, coords.w, isnetworked, false)
    local netid = NetworkGetNetworkIdFromEntity(veh)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetNetworkIdCanMigrate(netid, true)
    SetModelAsNoLongerNeeded(model)
    if teleportInto then TaskWarpPedIntoVehicle(playerPed, veh, -1) end
    if cb then cb(veh) end
end

function Core.DeleteVehicle(vehicle)
    SetEntityAsMissionEntity(vehicle, true, true)
    DeleteVehicle(vehicle)
end

function Core.GetPlate(vehicle)
    if vehicle == 0 then return end
    return Core.Shared.Trim(GetVehicleNumberPlateText(vehicle))
end

function Core.GetVehicleLabel(vehicle)
    if vehicle == nil or vehicle == 0 then return end
    return GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)))
end

function Core.GetVehicleProperties(vehicle)
    if DoesEntityExist(vehicle) then
        local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)

        local colorPrimary, colorSecondary = GetVehicleColours(vehicle)
        if GetIsVehiclePrimaryColourCustom(vehicle) then
            local r, g, b = GetVehicleCustomPrimaryColour(vehicle)
            colorPrimary = { r, g, b }
        end

        if GetIsVehicleSecondaryColourCustom(vehicle) then
            local r, g, b = GetVehicleCustomSecondaryColour(vehicle)
            colorSecondary = { r, g, b }
        end

        local extras = {}
        for extraId = 0, 12 do
            if DoesExtraExist(vehicle, extraId) then
                local state = IsVehicleExtraTurnedOn(vehicle, extraId) == 1
                extras[tostring(extraId)] = state
            end
        end

        local tireHealth = {}
        for i = 0, 3 do
            tireHealth[i] = GetVehicleWheelHealth(vehicle, i)
        end

        local tireBurstState = {}
        for i = 0, 5 do
            tireBurstState[i] = IsVehicleTyreBurst(vehicle, i, false)
        end

        local tireBurstCompletely = {}
        for i = 0, 5 do
            tireBurstCompletely[i] = IsVehicleTyreBurst(vehicle, i, true)
        end

        local windowStatus = {}
        for i = 0, 7 do
            windowStatus[i] = IsVehicleWindowIntact(vehicle, i) == 1
        end

        local doorStatus = {}
        for i = 0, 5 do
            doorStatus[i] = IsVehicleDoorDamaged(vehicle, i) == 1
        end

        return {
            model = GetEntityModel(vehicle),
            plate = Core.GetPlate(vehicle),
            plateIndex = GetVehicleNumberPlateTextIndex(vehicle),
            bodyHealth = Core.Shared.Round(GetVehicleBodyHealth(vehicle), 0.1),
            engineHealth = Core.Shared.Round(GetVehicleEngineHealth(vehicle), 0.1),
            tankHealth = Core.Shared.Round(GetVehiclePetrolTankHealth(vehicle), 0.1),
            fuelLevel = Core.Shared.Round(GetVehicleFuelLevel(vehicle), 0.1),
            dirtLevel = Core.Shared.Round(GetVehicleDirtLevel(vehicle), 0.1),
            oilLevel = Core.Shared.Round(GetVehicleOilLevel(vehicle), 0.1),
            color1 = colorPrimary,
            color2 = colorSecondary,
            pearlescentColor = pearlescentColor,
            dashboardColor = GetVehicleDashboardColour(vehicle),
            wheelColor = wheelColor,
            wheels = GetVehicleWheelType(vehicle),
            wheelSize = GetVehicleWheelSize(vehicle),
            wheelWidth = GetVehicleWheelWidth(vehicle),
            tireHealth = tireHealth,
            tireBurstState = tireBurstState,
            tireBurstCompletely = tireBurstCompletely,
            windowTint = GetVehicleWindowTint(vehicle),
            windowStatus = windowStatus,
            doorStatus = doorStatus,
        }
    else
        return
    end
end

function Core.SetVehicleProperties(vehicle, props)
    if DoesEntityExist(vehicle) then
        if props.extras then
            for id, enabled in pairs(props.extras) do
                if enabled then
                    SetVehicleExtra(vehicle, tonumber(id), 0)
                else
                    SetVehicleExtra(vehicle, tonumber(id), 1)
                end
            end
        end

        local colorPrimary, colorSecondary = GetVehicleColours(vehicle)
        local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)
        SetVehicleModKit(vehicle, 0)
        if props.plate then
            SetVehicleNumberPlateText(vehicle, props.plate)
        end
        if props.plateIndex then
            SetVehicleNumberPlateTextIndex(vehicle, props.plateIndex)
        end
        if props.bodyHealth then
            SetVehicleBodyHealth(vehicle, props.bodyHealth + 0.0)
        end
        if props.engineHealth then
            SetVehicleEngineHealth(vehicle, props.engineHealth + 0.0)
        end
        if props.tankHealth then
            SetVehiclePetrolTankHealth(vehicle, props.tankHealth)
        end
        if props.fuelLevel then
            SetVehicleFuelLevel(vehicle, props.fuelLevel + 0.0)
        end
        if props.dirtLevel then
            SetVehicleDirtLevel(vehicle, props.dirtLevel + 0.0)
        end
        if props.oilLevel then
            SetVehicleOilLevel(vehicle, props.oilLevel)
        end
        if props.color1 then
            if type(props.color1) == 'number' then
                ClearVehicleCustomPrimaryColour(vehicle)
                SetVehicleColours(vehicle, props.color1, colorSecondary)
            else
                SetVehicleCustomPrimaryColour(vehicle, props.color1[1], props.color1[2], props.color1[3])
            end
        end
        if props.color2 then
            if type(props.color2) == 'number' then
                ClearVehicleCustomSecondaryColour(vehicle)
                SetVehicleColours(vehicle, props.color1 or colorPrimary, props.color2)
            else
                SetVehicleCustomSecondaryColour(vehicle, props.color2[1], props.color2[2], props.color2[3])
            end
        end
        if props.wheelColor then
            SetVehicleExtraColours(vehicle, props.pearlescentColor or pearlescentColor, props.wheelColor)
        end
        if props.wheels then
            SetVehicleWheelType(vehicle, props.wheels)
        end
        if props.tireHealth then
            for wheelIndex, health in pairs(props.tireHealth) do
                SetVehicleWheelHealth(vehicle, wheelIndex, health)
            end
        end
        if props.tireBurstState then
            for wheelIndex, burstState in pairs(props.tireBurstState) do
                if burstState then
                    SetVehicleTyreBurst(vehicle, tonumber(wheelIndex), false, 1000.0)
                end
            end
        end
        if props.tireBurstCompletely then
            for wheelIndex, burstState in pairs(props.tireBurstCompletely) do
                if burstState then
                    SetVehicleTyreBurst(vehicle, tonumber(wheelIndex), true, 1000.0)
                end
            end
        end
        if props.windowTint then
            SetVehicleWindowTint(vehicle, props.windowTint)
        end
        if props.windowStatus then
            for windowIndex, smashWindow in pairs(props.windowStatus) do
                if not smashWindow then SmashVehicleWindow(vehicle, windowIndex) end
            end
        end
        if props.doorStatus then
            for doorIndex, breakDoor in pairs(props.doorStatus) do
                if breakDoor then
                    SetVehicleDoorBroken(vehicle, tonumber(doorIndex), true)
                end
            end
        end
    end
end

-- Unused

-- ชุด SetTextFont/BeginTextCommandDisplayText/AddTextComponentSubstringPlayerName เป็นของ GTA V ไม่มีใน RDR3 เรียกแล้วตายที่บรรทัดแรก ต้องใช้สาย CreateVarString+DisplayText แบบ client/drawtext.lua
function Core.DrawText(x, y, width, height, scale, r, g, b, a, text)
    -- Use local function instead
    SetTextScale(scale, scale)
    SetTextColor(r, g, b, a)
    DisplayText(CreateVarString(10, 'LITERAL_STRING', text), x - width / 2, y - height / 2 + 0.005)
end

function Core.DrawText3D(x, y, z, text)
    -- Use local function instead
    SetDrawOrigin(x, y, z, 0)
    -- พื้นหลังต้องวาดก่อนตัวอักษร ไม่งั้นแผ่นดำทับข้อความที่เพิ่งวาดไป
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0 + 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 75)
    SetTextScale(0.35, 0.35)
    SetTextColor(255, 255, 255, 215)
    SetTextCentre(true)
    DisplayText(CreateVarString(10, 'LITERAL_STRING', text), 0.0, 0.0)
    ClearDrawOrigin()
end

Core.LoadAnimDict = requestAnimDict

function Core.GetClosestBone(entity, list)
    local playerCoords, bone, coords, distance = GetEntityCoords(PlayerPedId())
    for _, element in pairs(list) do
        local boneCoords = GetWorldPositionOfEntityBone(entity, element.id or element)
        local boneDistance = #(playerCoords - boneCoords)
        if not coords then
            bone, coords, distance = element, boneCoords, boneDistance
        elseif distance > boneDistance then
            bone, coords, distance = element, boneCoords, boneDistance
        end
    end
    if not bone then
        bone = { id = GetEntityBoneIndexByName(entity, 'bodyshell'), type = 'remains', name = 'bodyshell' }
        coords = GetWorldPositionOfEntityBone(entity, bone.id)
        distance = #(coords - playerCoords)
    end
    return bone, coords, distance
end

function Core.GetBoneDistance(entity, boneType, boneIndex)
    local bone
    if boneType == 1 then
        bone = GetPedBoneIndex(entity, boneIndex)
    else
        bone = GetEntityBoneIndexByName(entity, boneIndex)
    end
    local boneCoords = GetWorldPositionOfEntityBone(entity, bone)
    local playerCoords = GetEntityCoords(PlayerPedId())
    return #(boneCoords - playerCoords)
end

function Core.CreateAttachedProp(ped, model, boneId, x, y, z, xR, yR, zR, vertex)
    local modelHash = type(model) == 'string' and joaat(model) or model
    local bone = GetPedBoneIndex(ped, boneId)
    Core.LoadModel(modelHash)
    local prop = CreateObject(modelHash, 1.0, 1.0, 1.0, 1, 1, 0)
    AttachEntityToEntity(prop, ped, bone, x, y, z, xR, yR, zR, 1, 1, 0, 1, not vertex and 2 or 0, 1)
    SetModelAsNoLongerNeeded(modelHash)
    return prop
end

function Core.IsAreaClearOfVehicles(coords, radius)
    if coords then
        coords = type(coords) == 'table' and vec3(coords.x, coords.y, coords.z) or coords
    else
        coords = GetEntityCoords(PlayerPedId())
    end
    local vehicles = GetGamePool('CVehicle')
    local closeVeh = {}
    for i = 1, #vehicles, 1 do
        local vehicleCoords = GetEntityCoords(vehicles[i])
        local distance = #(vehicleCoords - coords)
        if distance <= radius then
            closeVeh[#closeVeh + 1] = vehicles[i]
        end
    end
    if #closeVeh > 0 then return false end
    return true
end

Core.LoadAnimSet = requestAnimSet

Core.LoadPtfxAsset = requestNamedPtfxAsset

---@deprecated use ParticleFx natives directly
function Core.StartParticleAtCoord(dict, ptName, looped, coords, rot, scale, alpha, color, duration)    coords = type(coords) == 'table' and vec3(coords.x, coords.y, coords.z) or coords or GetEntityCoords(PlayerPedId())

    requestNamedPtfxAsset(dict)
    UseParticleFxAssetNextCall(dict)
    SetPtfxAssetNextCall(dict)
    local particleHandle
    if looped then
        particleHandle = StartParticleFxLoopedAtCoord(ptName, coords.x, coords.y, coords.z, rot.x, rot.y, rot.z, scale or 1.0, false, false, false, false)
        if color then
            SetParticleFxLoopedColour(particleHandle, color.r, color.g, color.b, false)
        end
        SetParticleFxLoopedAlpha(particleHandle, alpha or 10.0)
        if duration then
            Wait(duration)
            StopParticleFxLooped(particleHandle, false)
        end
    else
        SetParticleFxNonLoopedAlpha(alpha or 1.0)
        if color then
            SetParticleFxNonLoopedColour(color.r, color.g, color.b)
        end
        StartParticleFxNonLoopedAtCoord(ptName, coords.x, coords.y, coords.z, rot.x, rot.y, rot.z, scale or 1.0, false, false, false)
    end
    return particleHandle
end

---@deprecated use ParticleFx natives directly
function Core.StartParticleOnEntity(dict, ptName, looped, entity, bone, offset, rot, scale, alpha, color, evolution, duration)
    requestNamedPtfxAsset(dict)
    UseParticleFxAssetNextCall(dict)
    local particleHandle = nil
    ---@cast bone number
    local pedBoneIndex = bone and GetPedBoneIndex(entity, bone) or 0
    ---@cast bone string
    local nameBoneIndex = bone and GetEntityBoneIndexByName(entity, bone) or 0
    local entityType = GetEntityType(entity)
    local boneID = entityType == 1 and (pedBoneIndex ~= 0 and pedBoneIndex) or (looped and nameBoneIndex ~= 0 and nameBoneIndex)
    if looped then
        if boneID then
            particleHandle = StartParticleFxLoopedOnEntityBone(ptName, entity, offset.x, offset.y, offset.z, rot.x, rot.y, rot.z, boneID, scale or 1.0, false, false, false)
        else
            particleHandle = StartParticleFxLoopedOnEntity(ptName, entity, offset.x, offset.y, offset.z, rot.x, rot.y, rot.z, scale or 1.0, false, false, false)
        end
        if evolution then
            SetParticleFxLoopedEvolution(particleHandle, evolution.name, evolution.amount, false)
        end
        if color then
            SetParticleFxLoopedColour(particleHandle, color.r, color.g, color.b, false)
        end
        SetParticleFxLoopedAlpha(particleHandle, alpha or 1.0)
        if duration then
            Wait(duration)
            StopParticleFxLooped(particleHandle, false)
        end
    else
        SetParticleFxNonLoopedAlpha(alpha or 1.0)
        if color then
            SetParticleFxNonLoopedColour(color.r, color.g, color.b)
        end
        if boneID then
            StartParticleFxNonLoopedOnPedBone(ptName, entity, offset.x, offset.y, offset.z, rot.x, rot.y, rot.z, boneID, scale or 1.0, false, false, false)
        else
            StartParticleFxNonLoopedOnEntity(ptName, entity, offset.x, offset.y, offset.z, rot.x, rot.y, rot.z, scale or 1.0, false, false, false)
        end
    end
    return particleHandle
end

function Core.GetStreetNamesAtCoords(coords)
    local streetname1, streetname2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    return { main = GetStreetNameFromHashKey(streetname1), cross = GetStreetNameFromHashKey(streetname2) }
end

function Core.GetZoneAtCoords(coords)
    return GetLabelText(GetNameOfZone(coords))
end

function Core.GetCardinalDirection(entity)
    entity = DoesEntityExist(entity) and entity or PlayerPedId()
    if DoesEntityExist(entity) then
        local heading = GetEntityHeading(entity)
        if ((heading >= 0 and heading < 45) or (heading >= 315 and heading < 360)) then
            return 'North'
        elseif (heading >= 45 and heading < 135) then
            return 'East'
        elseif (heading >= 135 and heading < 225) then
            return 'South'
        elseif (heading >= 225 and heading < 315) then
            return 'West'
        end
    else
        return 'Cardinal Direction Error'
    end
end

function Core.GetInGameTime()
    local obj = {}
    obj.min = GetClockMinutes()
    obj.hour = GetClockHours()
    if obj.hour <= 12 then
        obj.ampm = 'AM'
    elseif obj.hour >= 13 then
        obj.ampm = 'PM'
        obj.formattedHour = obj.hour - 12
    end
    if obj.min <= 9 then
        obj.formattedMin = '0' .. obj.min
    end
    return obj
end

function Core.GetGroundCoords(coords)
    if not coords then return end

    local retval, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z, 0)
    if retval then
        return vector3(coords.x, coords.y, groundZ)
    else
        return coords
    end
end

-- เลือก native อ่านผล shapetest ตอนโหลด บิลด์นี้ไม่มี GetShapeTestResultEx และห้าม rawget(_G) เพราะ native ผูกผ่าน metatable
local shapeTestResult
do
    local withMaterial = GetShapeTestResultIncludingMaterial
    if type(withMaterial) ~= 'function' then withMaterial = GetShapeTestResultEx end
    local plain = GetShapeTestResult

    if type(withMaterial) == 'function' then
        shapeTestResult = withMaterial
    elseif type(plain) == 'function' then
        -- ตัวธรรมดาไม่คืน material -> แทรก 0 เข้าไปให้ลำดับค่าที่คืนเหมือนกัน
        shapeTestResult = function(handle)
            local retval, hit, endCoords, normal, entity = plain(handle)
            return retval, hit, endCoords, normal, 0, entity
        end
    else
        shapeTestResult = function() return 0, false, nil, nil, 0, 0 end
    end
end

function Core.GetGroundMaterial(entity)
    local coords = GetEntityCoords(entity)
    local num = StartShapeTestCapsule(coords.x, coords.y, coords.z + 4, coords.x, coords.y, coords.z - 2.0, 1, 1, entity, 7)
    local retval, success, endCoords, surfaceNormal, materialHash, entityHit = shapeTestResult(num)
    return materialHash, entityHit, surfaceNormal, endCoords, success, retval
end
