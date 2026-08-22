-- ตาราง Functions ถูกสร้างพร้อม metatable มิเรอร์ไว้แล้วใน main.lua
-- ประกาศซ้ำตรงนี้เท่ากับล้าง mirror ทิ้ง แล้ว bridge ที่ยกฟังก์ชันด้วย pairs() จะได้ศูนย์ตัว
HexaCore.Player_Buckets = {}
HexaCore.Entity_Buckets = {}
HexaCore.UsableItems = {}

-- Built-in notification (replaces rb_notify)
---@param source number player server id
---@param data table { title, description, type, duration }
function HexaCore.Notify(source, data)
    -- source ต้องเป็นผู้เล่นจริง (server id > 0) - ถ้ามาจาก console (0) หรือ nil
    -- จะ TriggerClientEvent ไม่ได้ (crash "Argument at index 1 was null") -> print แทน
    local src = tonumber(source)
    if not src or src <= 0 then
        local text = (data and (data.title or '')) or ''
        if data and data.description and data.description ~= '' then
            text = text ~= '' and (text .. ': ' .. data.description) or data.description
        end
        print(('[hexa_core] Notify (console): %s'):format(text))
        return
    end
    TriggerClientEvent('HexaCore:Notify', src, data)
end

-- Getters
-- Get your player first and then trigger a function on them
-- ex: local player = HexaCore.GetPlayer(source)
-- ex: local example = player.functionname(parameter)

---Gets the coordinates of an entity
---@param entity number
---@return vector4
function HexaCore.GetCoords(entity)
    local coords = GetEntityCoords(entity, false)
    local heading = GetEntityHeading(entity)
    return vector4(coords.x, coords.y, coords.z, heading)
end

---Gets player identifier of the given type
---ถ้าไม่ระบุ idtype จะใช้ Config.IdentifierType (ค่าเริ่มต้น 'steam')
---@param source any
---@param idtype string
---@return string?
function HexaCore.GetIdentifier(source, idtype)
    return GetPlayerIdentifierByType(source, idtype or HexaCore.Config.IdentifierType or 'license')
end

---Gets a players server id (source). Returns 0 if no player is found.
---@param identifier string
---@return number
function HexaCore.GetSourceByIdentifier(identifier)
    for src, _ in pairs(HexaCore.Players) do
        local idens = GetPlayerIdentifiers(src)
        for _, id in pairs(idens) do
            if identifier == id then
                return src
            end
        end
    end
    return 0
end

---Get player with given server id (source)
---@param source any
---@return table
function HexaCore.GetPlayer(source)
    if type(source) == 'number' then
        return HexaCore.Players[source]
    else
        return HexaCore.Players[HexaCore.GetSourceByIdentifier(source)]
    end
end

---Get player by citizen id
---@param citizenid string
---@return table?
function HexaCore.GetPlayerByCitizenId(citizenid)
    for src in pairs(HexaCore.Players) do
        if HexaCore.Players[src].PlayerData.citizenid == citizenid then
            return HexaCore.Players[src]
        end
    end
    return nil
end

-- GetOfflinePlayerByCitizenId / GetPlayerByLicense เคยเป็นตัวส่งต่อซ้อนอยู่ตรงนี้
-- พอแบนชั้น .Functions ทิ้ง ชื่อมันไปตรงกับตัวจริงใน server/player.lua จนกลายเป็นเรียกตัวเอง จึงลบทิ้ง

---Get player by account id
---@param account string
---@return table?
function HexaCore.GetPlayerByAccount(account)
    for src in pairs(HexaCore.Players) do
        if HexaCore.Players[src].PlayerData.charinfo.account == account then
            return HexaCore.Players[src]
        end
    end
    return nil
end

---Get player passing property and value to check exists
---@param property string
---@param value string
---@return table?
function HexaCore.GetPlayerByCharInfo(property, value)
    for src in pairs(HexaCore.Players) do
        local charinfo = HexaCore.Players[src].PlayerData.charinfo
        if charinfo[property] ~= nil and charinfo[property] == value then
            return HexaCore.Players[src]
        end
    end
    return nil
end

---Get all players. Returns the server ids of all players.
---@return table
function HexaCore.GetPlayers()
    local sources = {}
    for k in pairs(HexaCore.Players) do
        sources[#sources + 1] = k
    end
    return sources
end

---Will return an array of Hexa Player class instances
---unlike the GetPlayers() wrapper which only returns IDs
---@return table
function HexaCore.GetPlayerObjects()
    return HexaCore.Players
end

---Gets a list of all on duty players of a specified job and the number
---@param job string
---@return table, number
function HexaCore.GetPlayersOnDuty(job)
    local players = {}
    local count = 0
    for src, Player in pairs(HexaCore.Players) do
        if Player.PlayerData.job.name == job then
            if Player.PlayerData.job.onduty then
                players[#players + 1] = src
                count += 1
            end
        end
    end
    return players, count
end

---Returns only the amount of players on duty for the specified job
---@param job string
---@return number
function HexaCore.GetDutyCount(job)
    local count = 0
    for _, Player in pairs(HexaCore.Players) do
        if Player.PlayerData.job.name == job then
            if Player.PlayerData.job.onduty then
                count += 1
            end
        end
    end
    return count
end

--- @param source number source player's server ID.
--- @param coords vector The coordinates to calculate the distance from. Can be a table with x, y, z fields or a vector3. If not provided, the source player's Ped's coordinates are used.
--- @return string closestPlayer - The Player that is closest to the source player (or the provided coordinates). Returns -1 if no Players are found.
--- @return number closestDistance - The distance to the closest Player. Returns -1 if no Players are found.
function HexaCore.GetClosestPlayer(source, coords)
    local ped = GetPlayerPed(source)
    local players = GetPlayers()
    local closestDistance, closestPlayer = -1, -1
    if coords then coords = type(coords) == 'table' and vector3(coords.x, coords.y, coords.z) or coords end
    if not coords then coords = GetEntityCoords(ped) end
    for i = 1, #players do
        local playerId = players[i]
        local playerPed = GetPlayerPed(playerId)
        if playerPed ~= ped then
            local playerCoords = GetEntityCoords(playerPed)
            local distance = #(playerCoords - coords)
            if closestDistance == -1 or distance < closestDistance then
                closestPlayer = playerId
                closestDistance = distance
            end
        end
    end
    return closestPlayer, closestDistance
end

--- @param source number source player's server ID.
--- @param coords vector The coordinates to calculate the distance from. Can be a table with x, y, z fields or a vector3. If not provided, the source player's Ped's coordinates are used.
--- @return number closestObject - The Object that is closest to the source player (or the provided coordinates). Returns -1 if no Objects are found.
--- @return number closestDistance - The distance to the closest Object. Returns -1 if no Objects are found.
function HexaCore.GetClosestObject(source, coords)
    local ped = GetPlayerPed(source)
    local objects = GetAllObjects()
    local closestDistance, closestObject = -1, -1
    if coords then coords = type(coords) == 'table' and vector3(coords.x, coords.y, coords.z) or coords end
    if not coords then coords = GetEntityCoords(ped) end
    for i = 1, #objects do
        local objectCoords = GetEntityCoords(objects[i])
        local distance = #(objectCoords - coords)
        if closestDistance == -1 or closestDistance > distance then
            closestObject = objects[i]
            closestDistance = distance
        end
    end
    return closestObject, closestDistance
end

--- @param source number source player's server ID.
--- @param coords vector The coordinates to calculate the distance from. Can be a table with x, y, z fields or a vector3. If not provided, the source player's Ped's coordinates are used.
--- @return number closestVehicle - The Vehicle that is closest to the source player (or the provided coordinates). Returns -1 if no Vehicles are found.
--- @return number closestDistance - The distance to the closest Vehicle. Returns -1 if no Vehicles are found.
function HexaCore.GetClosestVehicle(source, coords)
    local ped = GetPlayerPed(source)
    local vehicles = GetAllVehicles()
    local closestDistance, closestVehicle = -1, -1
    if coords then coords = type(coords) == 'table' and vector3(coords.x, coords.y, coords.z) or coords end
    if not coords then coords = GetEntityCoords(ped) end
    for i = 1, #vehicles do
        local vehicleCoords = GetEntityCoords(vehicles[i])
        local distance = #(vehicleCoords - coords)
        if closestDistance == -1 or closestDistance > distance then
            closestVehicle = vehicles[i]
            closestDistance = distance
        end
    end
    return closestVehicle, closestDistance
end

--- @param source number source player's server ID.
--- @param coords vector The coordinates to calculate the distance from. Can be a table with x, y, z fields or a vector3. If not provided, the source player's Ped's coordinates are used.
--- @return number closestPed - The Ped that is closest to the source player (or the provided coordinates). Returns -1 if no Peds are found.
--- @return number closestDistance - The distance to the closest Ped. Returns -1 if no Peds are found.
function HexaCore.GetClosestPed(source, coords)
    local ped = GetPlayerPed(source)
    local peds = GetAllPeds()
    local closestDistance, closestPed = -1, -1
    if coords then coords = type(coords) == 'table' and vector3(coords.x, coords.y, coords.z) or coords end
    if not coords then coords = GetEntityCoords(ped) end
    for i = 1, #peds do
        if peds[i] ~= ped then
            local pedCoords = GetEntityCoords(peds[i])
            local distance = #(pedCoords - coords)
            if closestDistance == -1 or closestDistance > distance then
                closestPed = peds[i]
                closestDistance = distance
            end
        end
    end
    return closestPed, closestDistance
end

-- Routing buckets (Only touch if you know what you are doing)

---Returns the objects related to buckets, first returned value is the player buckets, second one is entity buckets
---@return table, table
function HexaCore.GetBucketObjects()
    return HexaCore.Player_Buckets, HexaCore.Entity_Buckets
end

---Will set the provided player id / source into the provided bucket id
---@param source any
---@param bucket any
---@return boolean
function HexaCore.SetPlayerBucket(source, bucket)
    if source and bucket then
        local plicense = HexaCore.GetIdentifier(source)
        Player(source).state:set('instance', bucket, true)
        SetPlayerRoutingBucket(source, bucket)
        HexaCore.Player_Buckets[plicense] = { id = source, bucket = bucket }
        return true
    else
        return false
    end
end

---Will set any entity into the provided bucket, for example peds / vehicles / props / etc.
---@param entity number
---@param bucket number
---@return boolean
function HexaCore.SetEntityBucket(entity, bucket)
    if entity and bucket then
        SetEntityRoutingBucket(entity, bucket)
        HexaCore.Entity_Buckets[entity] = { id = entity, bucket = bucket }
        return true
    else
        return false
    end
end

---Will return an array of all the player ids inside the current bucket
---@param bucket number
---@return table|boolean
function HexaCore.GetPlayersInBucket(bucket)
    local curr_bucket_pool = {}
    if HexaCore.Player_Buckets and next(HexaCore.Player_Buckets) then
        for _, v in pairs(HexaCore.Player_Buckets) do
            if v.bucket == bucket then
                curr_bucket_pool[#curr_bucket_pool + 1] = v.id
            end
        end
        return curr_bucket_pool
    else
        return false
    end
end

---Will return an array of all the entities inside the current bucket
---(not for player entities, use GetPlayersInBucket for that)
---@param bucket number
---@return table|boolean
function HexaCore.GetEntitiesInBucket(bucket)
    local curr_bucket_pool = {}
    if HexaCore.Entity_Buckets and next(HexaCore.Entity_Buckets) then
        for _, v in pairs(HexaCore.Entity_Buckets) do
            if v.bucket == bucket then
                curr_bucket_pool[#curr_bucket_pool + 1] = v.id
            end
        end
        return curr_bucket_pool
    else
        return false
    end
end

---Server side vehicle creation with optional callback
---the CreateVehicle RPC still uses the client for creation so players must be near
---@param source any
---@param model any
---@param coords vector
---@param warp boolean
---@return number
-- ทั้งสามลูปด้านล่างเดิมเป็น `while <cond> do Wait(0) end` แบบไม่มีทางออก:
-- CreateVehicle ฝั่ง server ต้องมี client อยู่ใกล้เป็นคนสร้างจริง ถ้าไม่มีใครใกล้
-- (หรือผู้เล่นหลุดออกกลางทาง) เงื่อนไขจะไม่เป็นจริงตลอดกาล -> thread นั้นวน
-- ทุก tick ของ server ไปเรื่อย ๆ กิน CPU ถาวรและ resource restart ไม่หลุด
-- ตอนนี้ทุกลูปมี deadline และหลับ 50ms ต่อรอบ (ไม่ต้องเช็คทุก tick)
local SPAWN_TIMEOUT_MS = 10000
local SPAWN_POLL_MS = 50

function HexaCore.SpawnVehicle(source, model, coords, warp)
    local ped = GetPlayerPed(source)
    model = type(model) == 'string' and joaat(model) or model
    if not coords then coords = GetEntityCoords(ped) end
    local heading = coords.w and coords.w or 0.0
    local veh = CreateVehicle(model, coords.x, coords.y, coords.z, heading, true, true)

    local deadline = GetGameTimer() + SPAWN_TIMEOUT_MS
    while not DoesEntityExist(veh) do
        if GetGameTimer() > deadline then
            print(('[hexa_core][ERROR][SPAWN_VEHICLE] Vehicle entity never existed | Source: %s | Model: %s')
                :format(tostring(source), tostring(model)))
            return 0
        end
        Wait(SPAWN_POLL_MS)
    end

    if warp then
        deadline = GetGameTimer() + SPAWN_TIMEOUT_MS
        while GetVehiclePedIsIn(ped) ~= veh do
            if GetGameTimer() > deadline then
                print(('[hexa_core][WARN][SPAWN_VEHICLE] Warp into vehicle timed out | Source: %s')
                    :format(tostring(source)))
                break
            end
            TaskWarpPedIntoVehicle(ped, veh, -1)
            Wait(SPAWN_POLL_MS)
        end
    end

    deadline = GetGameTimer() + SPAWN_TIMEOUT_MS
    while NetworkGetEntityOwner(veh) ~= source do
        if GetGameTimer() > deadline then
            print(('[hexa_core][WARN][SPAWN_VEHICLE] Ownership never migrated to source | Source: %s')
                :format(tostring(source)))
            break
        end
        Wait(SPAWN_POLL_MS)
    end
    return veh
end

--- New & more reliable server side native for creating vehicles
---comment
---@param source any
---@param model any
---@param vehtype any
-- The appropriate vehicle type for the model info.
-- Can be one of automobile, bike, boat, heli, plane, submarine, trailer, and (potentially), train.
-- This should be the same type as the type field in vehicles.meta.
---@param coords vector
---@param warp boolean
---@return number
function HexaCore.CreateVehicle(source, model, vehtype, coords, warp)
    model = type(model) == 'string' and joaat(model) or model
    vehtype = type(vehtype) == 'string' and tostring(vehtype) or vehtype
    if not coords then coords = GetEntityCoords(GetPlayerPed(source)) end
    local heading = coords.w and coords.w or 0.0
    local veh = CreateVehicleServerSetter(model, vehtype, coords, heading)
    local deadline = GetGameTimer() + SPAWN_TIMEOUT_MS
    while not DoesEntityExist(veh) do
        if GetGameTimer() > deadline then
            print(('[hexa_core][ERROR][CREATE_VEHICLE] Vehicle entity never existed | Source: %s | Model: %s')
                :format(tostring(source), tostring(model)))
            return 0
        end
        Wait(SPAWN_POLL_MS)
    end
    if warp then TaskWarpPedIntoVehicle(GetPlayerPed(source), veh, -1) end
    return veh
end

---Paychecks (standalone - don't touch)
-- ประเภทเงินที่ paycheck จะเข้า: เงินเดือนเข้าบัญชีธนาคารรวม ('bank')
-- ถ้าตัวละครยังไม่มีช่องนั้น (ข้อมูลเก่าที่ยังไม่ผ่าน MergeLegacyBankAccounts)
-- ค่อยตกไปที่เงินสด — AddMoney กับช่องที่ไม่มีจะคืน false เงียบ ๆ แล้วผู้เล่น
-- จะได้ notify ว่ารับเงินเดือนแต่เงินไม่เข้า
local PAYCHECK_ACCOUNTS = { 'bank', 'cash' }

local paycheckAccountWarned = false

--- คืนชื่อประเภทเงินที่ใช้จ่าย paycheck ได้จริงสำหรับผู้เล่นคนนี้
local function paycheckAccount(Player)
    local money = Player.PlayerData.money or {}
    for i = 1, #PAYCHECK_ACCOUNTS do
        if money[PAYCHECK_ACCOUNTS[i]] ~= nil then return PAYCHECK_ACCOUNTS[i] end
    end
    if not paycheckAccountWarned then
        paycheckAccountWarned = true
        print(('[hexa_core][WARN][PAYCHECK] No usable money account found; expected one of: %s')
            :format(table.concat(PAYCHECK_ACCOUNTS, ', ')))
    end
    return nil
end

-- ระบบบัญชีกลางของบริษัท (society) ไม่ได้อยู่ในสแตกนี้ ค่า resource/export
-- ตั้งได้จาก config เพื่อให้ต่อของภายนอกได้ภายหลังโดยไม่ต้องแก้ไฟล์นี้
local function societyResource()
    local cfg = HexaCore.Config.Money.SocietyExport
    if type(cfg) ~= 'table' then return nil end
    if type(cfg.resource) ~= 'string' or cfg.resource == '' then return nil end
    if GetResourceState(cfg.resource) ~= 'started' then return nil end
    return cfg
end

local societyWarned = false

--- ยอดคงเหลือของบัญชีบริษัท คืน nil ถ้าไม่มีระบบ society ให้ถาม
local function societyBalance(jobName)
    local cfg = societyResource()
    if not cfg then
        if not societyWarned then
            societyWarned = true
            print('[hexa_core][WARN][PAYCHECK] PayCheckSociety is enabled but no society resource is available - paying from the system instead')
        end
        return nil
    end

    local ok, balance = pcall(function()
        return exports[cfg.resource][cfg.getBalance or 'GetAccountBalance'](jobName)
    end)
    if not ok then
        print(('[hexa_core][ERROR][PAYCHECK] Society balance lookup failed | Target: %s | Export: %s | Error: %s')
            :format(cfg.resource, tostring(cfg.getBalance or 'GetAccountBalance'), tostring(balance)))
        return nil
    end
    return tonumber(balance)
end

--- หักเงินออกจากบัญชีบริษัท คืน false ถ้าทำไม่ได้
local function societyRemoveMoney(jobName, amount)
    local cfg = societyResource()
    if not cfg then return false end

    local ok, err = pcall(function()
        exports[cfg.resource][cfg.removeMoney or 'RemoveMoney'](jobName, amount, 'Employee Paycheck')
    end)
    if not ok then
        print(('[hexa_core][ERROR][PAYCHECK] Society withdrawal failed | Target: %s | Export: %s | Error: %s')
            :format(cfg.resource, tostring(cfg.removeMoney or 'RemoveMoney'), tostring(err)))
        return false
    end
    return true
end

function PaycheckInterval()
    for _, Player in pairs(HexaCore.Players) do
        -- ทุกช่วงที่อ่านต่อกันเป็นลูกโซ่ (Shared.Jobs[name].grades[level].payment)
        -- ต้องเช็คทีละชั้น: อาชีพที่ถูกลบออกจากตาราง jobs หรือ grade ที่ไม่มีอยู่
        -- เคยทำให้ทั้งลูปตายที่ผู้เล่นคนแรก แล้ว "ไม่มีใครในเซิร์ฟได้เงินเดือน"
        -- โดยไม่มี error ให้เห็นเพราะ SetTimeout ท้ายฟังก์ชันไม่เคยถูกเรียกต่อ
        local job = Player and Player.PlayerData and Player.PlayerData.job
        if job then
            local jobDef = Shared.Jobs[job.name]
            local grade = jobDef and jobDef.grades and jobDef.grades[tostring(job.grade and job.grade.level or 0)]
            local payment = tonumber(grade and grade.payment) or tonumber(job.payment) or 0

            if payment > 0 and ((jobDef and jobDef.offDutyPay) or job.onduty) then
                local account = paycheckAccount(Player)
                if account then
                    local society = HexaCore.Config.Money.PayCheckSociety and societyBalance(job.name) or nil

                    if society and society ~= 0 and society < payment then
                        -- บริษัทมีบัญชีแต่เงินไม่พอ -> ไม่จ่าย
                        HexaCore.Notify(Player.PlayerData.source, {title = Lang:t('error.company_too_poor'), type = 'error', duration = 5000 })
                    else
                        if Player.AddMoney(account, payment, 'paycheck') then
                            if society and society ~= 0 then
                                societyRemoveMoney(job.name, payment)
                            end
                            HexaCore.Notify(Player.PlayerData.source, {title = Lang:t('info.received_paycheck', { value = payment }), type = 'info', duration = 5000 })
                        end
                    end
                end
            end
        end
    end
    SetTimeout(HexaCore.Config.Money.PayCheckTimeOut * (60 * 1000), PaycheckInterval)
end

-- Callback Functions --

---Trigger Client Callback
---@param name string
---@param source any
---@param cb function
---@param ... any
function HexaCore.TriggerClientCallback(name, source, cb, ...)
    HexaCore.ClientCallbacks[name] = cb
    TriggerClientEvent('HexaCore:Client:TriggerClientCallback', source, name, ...)
end

---Create Server Callback
---@param name string
---@param cb function
function HexaCore.CreateCallback(name, cb)
    HexaCore.ServerCallbacks[name] = cb
end

---Trigger Serv er Callback
---@param name string
---@param source any
---@param cb function
---@param ... any
function HexaCore.TriggerCallback(name, source, cb, ...)
    if not HexaCore.ServerCallbacks[name] then return end
    HexaCore.ServerCallbacks[name](source, cb, ...)
end

-- Items

---Create a usable item
---@param item string
---@param data function
function HexaCore.CreateUseableItem(item, data)
    HexaCore.UsableItems[item] = data
end

---Checks if the given item is usable
---@param item string
---@return any
function HexaCore.GetUsableItem(item)
    return HexaCore.UsableItems[item]
end

---Use item
---@param source any
---@param item string
function HexaCore.UseItem(source, item)
    -- เดิมเช็ค == 'missing' ซึ่งผ่านตอน resource อยู่ในสถานะ 'stopped' /
    -- 'starting' / 'uninitialized' ด้วย แล้วการเรียก export จะ error
    -- ("attempt to index a nil value") ต้องเช็คว่า started จริงเท่านั้น
    if GetResourceState('hexa_inventory') ~= 'started' then
        print('[hexa_core][WARN][EXPORT] UseItem skipped - hexa_inventory is not started')
        return
    end
    exports['hexa_inventory']:UseItem(source, item)
end

---Kick Player
---@param source any
---@param reason string
---@param setKickReason boolean
---@param deferrals boolean
function HexaCore.Kick(source, reason, setKickReason, deferrals)
    reason = '\n' .. reason
    if setKickReason then
        setKickReason(reason)
    end
    CreateThread(function()
        if deferrals then
            deferrals.update(reason)
            Wait(2500)
        end
        if source then
            DropPlayer(source, reason)
        end
        for _ = 0, 4 do
            while true do
                if not source then break end -- [perf-fix] avoid infinite tight loop when source is nil
                if GetPlayerPing(source) >= 0 then
                    break
                end
                Wait(100) -- [perf-fix] moved out of the if-source block so the loop always yields
                DropPlayer(source, reason) -- [perf-fix] call directly instead of spawning a thread each iteration
            end
            Wait(5000)
        end
    end)
end

-- Setting & Removing Permissions

-- ประกาศให้ resource อื่นรู้ว่าสิทธิ์ของผู้เล่นคนนี้เปลี่ยน
-- ตัวที่ต้องรู้จริง ๆ คือ resource ที่เปิด/ปิดการทำงานตามสิทธิ์ล่วงหน้า เช่น
-- hexa_admin ที่เปิดลูปอ่านปุ่มลัดเฉพาะ staff (ถ้าไม่มีสัญญาณนี้ คนที่เพิ่งได้
-- สิทธิ์กลางเกมต้อง relog ก่อนปุ่มลัดจะทำงาน)
local function announcePermissionChange(source)
    TriggerEvent('HexaCore:Server:PermissionsChanged', source)
end

---Add permission for player
---@param source any
---@param permission string
function HexaCore.AddPermission(source, permission)
    if not IsPlayerAceAllowed(source, permission) then
        ExecuteCommand(('add_principal player.%s hexacore.%s'):format(source, permission))
        HexaCore.Commands.Refresh(source)
        announcePermissionChange(source)
    end
end

---Remove permission from player
---@param source any
---@param permission string
function HexaCore.RemovePermission(source, permission)
    local changed = false
    if permission then
        if IsPlayerAceAllowed(source, permission) then
            ExecuteCommand(('remove_principal player.%s hexacore.%s'):format(source, permission))
            HexaCore.Commands.Refresh(source)
            changed = true
        end
    else
        for _, v in pairs(HexaCore.Commands.Permissions) do
            if IsPlayerAceAllowed(source, v) then
                ExecuteCommand(('remove_principal player.%s hexacore.%s'):format(source, v))
                HexaCore.Commands.Refresh(source)
                changed = true
            end
        end
    end
    -- ประกาศครั้งเดียวหลังจบทุกการเปลี่ยนแปลง ไม่ใช่ทุกรอบในลูป
    if changed then announcePermissionChange(source) end
end

-- principal ผูกกับเลข server id ที่ FXServer เอากลับมาใช้ซ้ำ ไม่ถอนตอนหลุด = คนถัดไปที่ได้ id เดิมรับสิทธิ์ไปด้วย
-- ถอนดื้อ ๆ ไม่เช็ค IsPlayerAceAllowed ก่อน เพราะตอน event นี้ยิงผู้เล่นหลุดไปแล้ว การเช็คจะคืน false แล้วข้ามการถอน
-- และไม่เรียก RemovePermission เพราะปลายทางยิง event หา client ที่ไม่อยู่แล้ว
AddEventHandler('playerDropped', function()
    local src = source
    for _, permission in pairs(HexaCore.Commands.Permissions) do
        ExecuteCommand(('remove_principal player.%s hexacore.%s'):format(src, permission))
    end
end)

-- Checking for Permission Level

---Check if player has permission
---@param source any
---@param permission string
---@return boolean
function HexaCore.HasPermission(source, permission)
    if type(permission) == 'string' then
        if IsPlayerAceAllowed(source, permission) then return true end
    elseif type(permission) == 'table' then
        for _, permLevel in pairs(permission) do
            if IsPlayerAceAllowed(source, permLevel) then return true end
        end
    end

    return false
end

---Get the players permissions
---@param source any
---@return table
function HexaCore.GetPermissions(source)
    local src = source
    local perms = {}
    for _, v in pairs(HexaCore.Commands.Permissions) do
        if IsPlayerAceAllowed(src, v) then
            perms[v] = true
        end
    end
    return perms
end

---Get admin messages opt-in state for player
---@param source any
---@return boolean
function HexaCore.IsAdminAlertsEnabled(source)
    local license = HexaCore.GetIdentifier(source)
    if not license or not HexaCore.HasPermission(source, 'admin') then return false end
    -- แอดมินที่มี ace แต่ยังไม่ได้เลือกตัวละคร (หรือหลุดไปแล้ว) ไม่มีแถวใน
    -- HexaCore.Players — เดิมอ่าน Player.PlayerData ตรง ๆ แล้วพัง
    local Player = HexaCore.GetPlayer(source)
    if not Player then return false end
    return Player.PlayerData.optin
end

---Toggle opt-in to admin messages
---@param source any
function HexaCore.ToggleAdminAlerts(source)
    local license = HexaCore.GetIdentifier(source)
    if not license or not HexaCore.HasPermission(source, 'admin') then return end
    local Player = HexaCore.GetPlayer(source)
    if not Player then return end
    Player.PlayerData.optin = not Player.PlayerData.optin
    Player.SetPlayerData('optin', Player.PlayerData.optin)
end

-- Retrieves information about the database connection.
--- @return table; A table containing the database information.
function HexaCore.GetDatabaseInfo()
    local details = {
        exists = false,
        database = "",
    }
    local connectionString = GetConvar("mysql_connection_string", "")

    if connectionString == "" then
        return details
    elseif connectionString:find("mysql://") then
        connectionString = connectionString:sub(9, -1)
        details.database = connectionString:sub(connectionString:find("/") + 1, -1):gsub("[%?]+[%w%p]*$", "")
        details.exists = true
        return details
    else
        connectionString = { string.strsplit(";", connectionString) }

        for i = 1, #connectionString do
            local v = connectionString[i]
            if v:match("database") then
                details.database = v:sub(10, #v)
                details.exists = true
                return details
            end
        end
    end
end

-- Utility functions

---Check if a player has an item [deprecated]
---@param source any
---@param items table|string
---@param amount number
---@return boolean
function HexaCore.HasItem(source, items, amount)
    -- ดูเหตุผลที่ต้องเป็น ~= 'started' ที่ HexaCore.UseItem
    if GetResourceState('hexa_inventory') ~= 'started' then return false end
    return exports['hexa_inventory']:HasItem(source, items, amount)
end

---???? ... ok
---@param source any
---@param data any
---@param pattern any
---@return boolean
function HexaCore.PrepForSQL(source, data, pattern)
    data = tostring(data)
    local src = source
    local player = HexaCore.GetPlayer(src)
    local result = string.match(data, pattern)
    if not result or string.len(result) ~= string.len(data) then
        -- player อาจเป็น nil (ยังไม่เลือกตัวละคร / หลุดออกไปแล้ว) เดิมอ่าน
        -- player.PlayerData.license ตรง ๆ แล้วพังตอนที่ควรจะ "แจ้งว่าโดนโจมตี"
        local license = player and player.PlayerData and player.PlayerData.license or ('source:' .. tostring(src))
        TriggerEvent('hexa_log:server:CreateLog', 'anticheat', 'SQL Exploit Attempted', 'red', string.format('%s attempted to exploit SQL!', license))
        return false
    end
    return true
end

---Change weight to player
---@param source any
---@param weight number
---@return boolean
function HexaCore.SetMaxWeight(source, weight)
    local Player = HexaCore.GetPlayer(source)
    if not Player then return end

    Player.SetPlayerData('weight', weight)
end

---Change slots to player
---@param source any
---@param slots number
---@return boolean
function HexaCore.SetMaxSlots(source, slots)
    local Player = HexaCore.GetPlayer(source)
    if not Player then return end

    Player.SetPlayerData('slots', slots)
end

--- Checks if a player has enough weight capacity to carry a specific amount of an item
-- @param source number - The server ID of the player
-- @param item string - The name of the item
-- @param amount number - The quantity of the item to check
-- @return boolean - True if the player can carry it, false if they cannot
HexaCore.CanCarryItem = function(source, item, amount)
    local Player = HexaCore.GetPlayer(source)
    if not Player then return false end

    -- Fallback to 1 if amount isn't provided
    amount = tonumber(amount) or 1

    -- Fetch item data from the framework's shared config to get its weight
    local itemData = HexaCore.Shared.Items[item:lower()]
    if not itemData then 
        print(("^1[hexa_core] Error:^7 Item '%s' does not exist in shared items."):format(item))
        return false 
    end

    -- Calculate the total weight of the incoming items
    local itemWeight = itemData.weight or 0
    local incomingWeight = itemWeight * amount

    -- Get the player's current total inventory weight and max capacity
    -- ต้องเช็ค started เหมือน UseItem/HasItem ข้างบน ไม่งั้นตอน hexa_inventory
    -- ยังไม่สตาร์ต (หรือกำลัง restart) การเรียก export จะโยน error ทั้งที่
    -- ฟังก์ชันนี้ถูกใช้เป็น "เช็คก่อนจ่ายของ" ของหลาย resource
    if GetResourceState('hexa_inventory') ~= 'started' then return false end
    local currentWeight = exports['hexa_inventory']:GetTotalWeight(Player.PlayerData.items) or 0
    local maxWeight = Player.PlayerData.weight or 100 -- 100% weight system: fallback to full capacity if not set

    -- Check if the new total exceeds the limit
    if (currentWeight + incomingWeight) <= maxWeight then
        return true
    else
        return false
    end
end
