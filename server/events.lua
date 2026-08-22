-- Event Handler

AddEventHandler('chatMessage', function(_, _, message)
    if string.sub(message, 1, 1) == '/' then
        CancelEvent()
        return
    end
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    if not HexaCore.Players[src] then return end
    local Player = HexaCore.Players[src]
    TriggerEvent('hexa_log:server:CreateLog', 'joinleave', 'Dropped', 'red', '**' .. GetPlayerName(src) .. '** (' .. Player.PlayerData.license .. ') left..' .. '\n **Reason:** ' .. reason)
    TriggerEvent('HexaCore:Server:PlayerDropped', Player)
    Player.Save()
    HexaCore.Player_Buckets[Player.PlayerData.license] = nil
    HexaCore.Players[src] = nil
end)

local readyFunction = MySQL.ready
local databaseConnected = readyFunction == nil
if readyFunction ~= nil then
    MySQL.ready(function()
        -- รอ installer สร้างตาราง users ก่อน (weight/slots ไม่ได้เก็บใน DB แล้ว ใช้ค่าจาก Config.Player.PlayerDefaults)
        if AwaitSchemaReady then AwaitSchemaReady(15000) end
        databaseConnected = true
    end)
end

-- Player Connecting
local function onPlayerConnecting(name, _, deferrals)
    local src = source
    deferrals.defer()

    if not databaseConnected then
        return deferrals.done(Lang:t('error.connecting_database_error'))
    end

    Wait(0)
    deferrals.update(string.format('Hello %s. กำลังตรวจสอบตัวตนผู้เล่น...', name))
    local identifier = HexaCore.GetIdentifier(src)

    -- ไม่มี identifier ตามที่ตั้งค่าไว้ (เช่นบังคับ steam แต่ไม่ได้เปิดผ่าน Steam) ต้องตัดจบตั้งแต่หน้าเชื่อมต่อ
    if not identifier then
        if (HexaCore.Config.IdentifierType or 'license') == 'steam' then
            return deferrals.done('เซิร์ฟเวอร์นี้ต้องเปิดเกมผ่าน Steam (ไม่พบ Steam ID) กรุณาเปิด Steam ให้ล็อกอินอยู่ แล้วเปิด RDR2 ผ่าน Steam อีกครั้ง')
        end
        return deferrals.done(Lang:t('error.no_valid_license'))
    end

    Wait(0)
    deferrals.update(string.format(Lang:t('info.join_server'), name))
    deferrals.done()

    TriggerClientEvent('HexaCore:Client:SharedUpdate', src, HexaCore.Shared)
end

AddEventHandler('playerConnecting', onPlayerConnecting)

-- Callback Events --

-- Client Callback
RegisterNetEvent('HexaCore:Server:TriggerClientCallback', function(name, ...)
    if HexaCore.ClientCallbacks[name] then
        HexaCore.ClientCallbacks[name](...)
        HexaCore.ClientCallbacks[name] = nil
    end
end)

-- Server Callback
RegisterNetEvent('HexaCore:Server:TriggerCallback', function(name, ...)
    local src = source
    HexaCore.TriggerCallback(name, src, function(...)
        TriggerClientEvent('HexaCore:Client:TriggerCallback', src, name, ...)
    end, ...)
end)

-- Player

-- Save() เขียนแถว users ทั้งแถว + SaveInventory ปล่อยให้ client ยิงรัวเมื่อไหร่ MySQL ถล่มทั้งเซิร์ฟ ดู docs guide/persistence
local lastSave = {}
local SAVE_COOLDOWN_MS = 30000

AddEventHandler('playerDropped', function() lastSave[source] = nil end)

-- ต้องเป็น AddEventHandler ไม่ใช่ RegisterNetEvent ไม่งั้น client สั่งเขียน DB เองได้ตรงๆ
AddEventHandler('HexaCore:UpdatePlayer', function()
    local src = source
    local now = GetGameTimer()
    if lastSave[src] and (now - lastSave[src]) < SAVE_COOLDOWN_MS then return end
    lastSave[src] = now
    local Player = HexaCore.GetPlayer(src)
    if not Player then return end
    Player.Save()
end)

-- ไวต์ลิสต์เท่านั้น คีย์อื่น (injail / rep / criminalrecord ฯลฯ) ถ้าเปิดให้ client เขียน = เคลียร์คุก/ปั้ม rep เองได้
local CLIENT_SETTABLE_META = {
    hunger = true, thirst = true, cleanliness = true, stress = true,
}

RegisterNetEvent('HexaCore:Server:SetMetaData', function(meta, data)
    local src = source
    if type(meta) ~= 'string' or not CLIENT_SETTABLE_META[meta] then
        return Hexa.Log('security id %s tried to set metadata key %s', src, tostring(meta))
    end
    if type(data) ~= 'number' and type(data) ~= 'boolean' then return end
    local Player = HexaCore.GetPlayer(src)
    if not Player then return end
    Player.SetMetaData(meta, data)
end)

RegisterNetEvent('HexaCore:ToggleDuty', function()
    local src = source
    local Player = HexaCore.GetPlayer(src)
    if not Player then return end
    if Player.PlayerData.job.onduty then
        Player.SetJobDuty(false)
        HexaCore.Notify(src, {title = Lang:t('info.off_duty'), type = 'info', duration = 5000 })
    else
        Player.SetJobDuty(true)
        HexaCore.Notify(src, {title = Lang:t('info.on_duty'), type = 'info', duration = 5000 })
    end

    TriggerEvent('HexaCore:Server:SetDuty', src, Player.PlayerData.job.onduty)
    TriggerClientEvent('HexaCore:Client:SetDuty', src, Player.PlayerData.job.onduty)
end)

-- Items

-- This event is exploitable and should not be used. It has been deprecated, and will be removed soon.
RegisterNetEvent('HexaCore:Server:UseItem', function(item)
    Core.Warn('%s triggered the deprecated HexaCore:Server:UseItem for id %s - this event is exploitable and goes away next release, use hexa_inventory instead',
        tostring(GetInvokingResource()), source)
    Core.DumpTable(item)
end)

-- This event is exploitable and should not be used. It has been deprecated, and will be removed soon. function(itemName, amount, slot)
RegisterNetEvent('HexaCore:Server:RemoveItem', function(itemName, amount)
    local src = source
    Hexa.Warn('%s triggered the deprecated HexaCore:Server:RemoveItem for id %s (%s x%s) - do this server side with Player.RemoveItem instead',
        tostring(GetInvokingResource()), src, tostring(itemName), tostring(amount))
end)

-- This event is exploitable and should not be used. It has been deprecated, and will be removed soon. function(itemName, amount, slot, info)
RegisterNetEvent('HexaCore:Server:AddItem', function(itemName, amount)
    local src = source
    Hexa.Warn('%s triggered the deprecated HexaCore:Server:AddItem for id %s (%s x%s) - do this server side with Player.AddItem instead',
        tostring(GetInvokingResource()), src, tostring(itemName), tostring(amount))
end)

-- Non-Chat Command Calling (ex: Hexa-adminmenu)

RegisterNetEvent('HexaCore:CallCommand', function(command, args)
    local src = source
    if not HexaCore.Commands.List[command] then return end
    local Player = HexaCore.GetPlayer(src)
    if not Player then return end
    local hasPerm = HexaCore.HasPermission(src, 'command.' .. HexaCore.Commands.List[command].name)
    if hasPerm then
        if HexaCore.Commands.List[command].argsrequired and #HexaCore.Commands.List[command].arguments ~= 0 and not args[#HexaCore.Commands.List[command].arguments] then
            HexaCore.Notify(src, {title = Lang:t('error.missing_args2'), type = 'error', duration = 5000 })
        else
            HexaCore.Commands.List[command].callback(src, args)
        end
    else
        HexaCore.Notify(src, {title = Lang:t('error.no_access'), type = 'error', duration = 5000 })
    end
end)

-- คืน netId ไม่ใช่ตัวรถ (client ต้อง NetworkGetEntityFromNetworkId แล้ว NetToVeh เอง) และสามด่านนี้กันยิงถมเซิร์ฟด้วยรถ
local lastVehicleSpawn = {}
local VEHICLE_SPAWN_COOLDOWN_MS = 3000

AddEventHandler('playerDropped', function() lastVehicleSpawn[source] = nil end)

HexaCore.CreateCallback('HexaCore:Server:SpawnVehicle', function(source, cb, model, coords, warp)
    if not HexaCore.GetPlayer(source) then return cb(nil) end

    if type(model) ~= 'string' and type(model) ~= 'number' then
        Hexa.Warn('id %s asked to spawn a vehicle with a %s model argument', tostring(source), type(model))
        return cb(nil)
    end

    local now = GetGameTimer()
    if lastVehicleSpawn[source] and (now - lastVehicleSpawn[source]) < VEHICLE_SPAWN_COOLDOWN_MS then
        return cb(nil)
    end
    lastVehicleSpawn[source] = now

    local veh = HexaCore.SpawnVehicle(source, model, coords, warp)
    if not veh or not DoesEntityExist(veh) then return cb(nil) end
    cb(NetworkGetNetworkIdFromEntity(veh))
end)

-- รายงาน CSRF เท่านั้น: token ตรวจฝั่ง client ล้วน server ยืนยันไม่ได้ จึงตัดสินตาม Config.Security.CSRFFailurePolicy
local CSRF_WINDOW_MS = 10000

local csrfReports = {}   -- [src] = { count = n, windowStart = ms }

AddEventHandler('playerDropped', function()
    csrfReports[source] = nil
end)

RegisterNetEvent('HexaCore:Server:ReportCSRFFailure', function()
    local src = source
    if not src or src <= 0 then return end

    local policy = (HexaCore.Config.Security and HexaCore.Config.Security.CSRFFailurePolicy) or 'log'
    local threshold = (HexaCore.Config.Security and HexaCore.Config.Security.CSRFFailureThreshold) or 5

    local now = GetGameTimer()
    local entry = csrfReports[src]
    if not entry or (now - entry.windowStart) >= CSRF_WINDOW_MS then
        entry = { count = 0, windowStart = now }
        csrfReports[src] = entry
    end
    entry.count = entry.count + 1

    -- log ครั้งแรกของ window เท่านั้น กันไม่ให้การยิงรัวกลายเป็นการถล่ม console
    if entry.count == 1 then
        Hexa.Warn('security NUI CSRF token mismatch reported by client | Source: %s | Name: %s | Policy: %s', tostring(src), tostring(GetPlayerName(src)), policy)
        TriggerEvent('hexa_log:server:CreateLog', 'anticheat', 'CSRF Mismatch Reported', 'orange',
            ('**%s** (id: %s) reported an NUI CSRF token mismatch'):format(tostring(GetPlayerName(src)), tostring(src)))
    end

    if policy == 'kick' and entry.count >= threshold then
        csrfReports[src] = nil
        Hexa.Warn('security Dropping player after repeated CSRF mismatches | Source: %s | Count: %d', tostring(src), entry.count)
        DropPlayer(src, 'CSRF validation failed')
    end
end)