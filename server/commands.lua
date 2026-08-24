Core.Commands = {}
Core.Commands.List = {}
Core.Commands.IgnoreList = { -- ระดับที่ไม่ต้องสร้าง ace รายคำสั่ง
    ['admin'] = true,          -- admin ใช้ได้ทุกคำสั่งอยู่แล้ว (add_ace hexacore.admin command allow ใน permissions.cfg)
    ['user'] = true            -- user = builtin.everyone (ทุกคน)
}

Core.Commands.Permissions = {'admin', 'staff'} -- ระดับสิทธิ์ในเซิร์ฟเวอร์ (ต้องตรงกับ permissions.cfg) — admin = สูงสุด, staff = ทีมงาน

-- คำสั่งแอดมินอ้างผู้เล่นด้วย citizen id ถาวร ไม่ใช่ session id ที่เปลี่ยนทุกครั้งที่เข้าเกม ดู docs api/commands
local function GetPlayerByCid(id)
    if not id then return nil end
    return Core.GetPlayerByCitizenId(tostring(id))
end

CreateThread(function() -- Add ace to node for perm checking
    local permissions = Core.Commands.Permissions
    for i = 1, #permissions do
        local permission = permissions[i]
        ExecuteCommand(('add_ace hexacore.%s %s allow'):format(permission, permission))
    end
end)

-- Register & Refresh Commands

function Core.Commands.Add(name, help, arguments, argsrequired, callback, permission, ...)
    local restricted = true                                  -- Default to restricted for all commands
    if not permission then permission = 'user' end           -- some commands don't pass permission level
    if permission == 'user' then restricted = false end      -- allow all users to use command

    RegisterCommand(name, function(source, args, rawCommand) -- Register command with the server
        if argsrequired and #args < #arguments then
            return Core.Notify(source, {
                title = 'System',
                description = Lang:t('error.missing_args2'),
                type = 'error'
            })
        end
        callback(source, args, rawCommand)
    end, restricted)

    local extraPerms = ... and table.pack(...) or nil
    if extraPerms then
        extraPerms[extraPerms.n + 1] = permission -- The 'n' field is the number of arguments in the packed table
        extraPerms.n += 1
        permission = extraPerms
        for i = 1, permission.n do
            if not Core.Commands.IgnoreList[permission[i]] then -- only create aces for extra perm levels
                ExecuteCommand(('add_ace hexacore.%s command.%s allow'):format(permission[i], name))
            end
        end
        permission.n = nil
    else
        permission = tostring(permission:lower())
        if not Core.Commands.IgnoreList[permission] then -- only create aces for extra perm levels
            ExecuteCommand(('add_ace hexacore.%s command.%s allow'):format(permission, name))
        end
    end

    Core.Commands.List[name:lower()] = {
        name = name:lower(),
        permission = permission,
        help = help,
        arguments = arguments,
        argsrequired = argsrequired,
        callback = callback
    }
end

function Core.Commands.Refresh(source)
    local src = source
    local Player = Core.GetPlayer(src)
    local suggestions = {}
    if Player then
        for command, info in pairs(Core.Commands.List) do
            local hasPerm = IsPlayerAceAllowed(tostring(src), 'command.' .. command)
            if hasPerm then
                suggestions[#suggestions + 1] = {
                    name = '/' .. command,
                    help = info.help,
                    params = info.arguments
                }
            else
                TriggerClientEvent('chat:removeSuggestion', src, '/' .. command)
            end
        end
        TriggerClientEvent('chat:addSuggestions', src, suggestions)
    end
end

-- Teleport
Core.Commands.Add('tp', Lang:t('command.tp.help'), { { name = Lang:t('command.tp.params.x.name'), help = Lang:t('command.tp.params.x.help') }, { name = Lang:t('command.tp.params.y.name'), help = Lang:t('command.tp.params.y.help') }, { name = Lang:t('command.tp.params.z.name'), help = Lang:t('command.tp.params.z.help') } }, false, function(source, args)
    if args[1] and not args[2] and not args[3] then
        if tonumber(args[1]) then
            local Target = GetPlayerByCid(args[1])
            if Target then
                local coords = GetEntityCoords(GetPlayerPed(Target.PlayerData.source))
                TriggerClientEvent('HexaCore:Command:TeleportToPlayer', source, coords)
            else
                Core.Notify(source, {title = Lang:t('error.not_online'), type = 'error', duration = 5000 })
            end
        else
            Core.Notify(source, {title = Lang:t('error.wrong_format'), type = 'error', duration = 5000 })
        end
    else
        if args[1] and args[2] and args[3] then
            -- ต้องแปลงแล้วเช็ค nil ก่อนบวก .0 ไม่งั้นพิมพ์ผิดตัวเดียวได้ Lua error และผู้เล่นไม่เห็นอะไรเลย (เดิมเช็ค ~= 0 ซึ่งตัดแกนที่เป็น 0 พอดีทิ้งด้วย)
            local x = tonumber((args[1]:gsub(',', '')))
            local y = tonumber((args[2]:gsub(',', '')))
            local z = tonumber((args[3]:gsub(',', '')))
            if x and y and z then
                TriggerClientEvent('HexaCore:Command:TeleportToCoords', source, x + .0, y + .0, z + .0)
            else
                Core.Notify(source, {title = Lang:t('error.wrong_format'), type = 'error', duration = 5000 })
            end
        else
            Core.Notify(source, {title = Lang:t('error.missing_args'), type = 'error', duration = 5000 })
        end
    end
end, 'admin')

Core.Commands.Add('tpm', Lang:t('command.tpm.help'), {}, false, function(source)
    TriggerClientEvent('HexaCore:Command:GoToMarker', source)
end, 'admin')

-- admin noclip
Core.Commands.Add('noclip', Lang:t("command.noclip.help"), {}, false, function(source)
    TriggerClientEvent('HexaCore:Command:ToggleNoClip', source)
end, 'admin')

-- Permissions

Core.Commands.Add('addpermission', Lang:t('command.addpermission.help'), { { name = Lang:t('command.addpermission.params.id.name'), help = Lang:t('command.addpermission.params.id.help') }, { name = Lang:t('command.addpermission.params.permission.name'), help = Lang:t('command.addpermission.params.permission.help') } }, true, function(source, args)
    local Player = GetPlayerByCid(args[1])
    local permission = tostring(args[2]):lower()
    if Player then
        Core.AddPermission(Player.PlayerData.source, permission)
    else
        Core.Notify(source, {title = Lang:t('error.not_online'), type = 'error', duration = 5000 })
    end
end, 'admin')

Core.Commands.Add('removepermission', Lang:t('command.removepermission.help'), { { name = Lang:t('command.removepermission.params.id.name'), help = Lang:t('command.removepermission.params.id.help') }, { name = Lang:t('command.removepermission.params.permission.name'), help = Lang:t('command.removepermission.params.permission.help') } }, true, function(source, args)
    local Player = GetPlayerByCid(args[1])
    local permission = tostring(args[2]):lower()
    if Player then
        Core.RemovePermission(Player.PlayerData.source, permission)
    else
        Core.Notify(source, {title = Lang:t('error.not_online'), type = 'error', duration = 5000 })
    end
end, 'admin')

-- Vehicle

Core.Commands.Add('vehicle', Lang:t('command.car.help'), { { name = Lang:t('command.car.params.model.name'), help = Lang:t('command.car.params.model.help') } }, true, function(source, args)
    TriggerClientEvent('HexaCore:Command:SpawnVehicle', source, args[1])
end, 'admin')

Core.Commands.Add('dv', Lang:t('command.dv.help'), {}, false, function(source)
    TriggerClientEvent('HexaCore:Command:DeleteVehicle', source)
end, 'admin')

Core.Commands.Add('dvall', Lang:t('command.dvall.help'), {}, false, function()
    local vehicles = GetAllVehicles()
    for _, vehicle in ipairs(vehicles) do
        DeleteEntity(vehicle)
    end
end, 'admin')

-- Peds

Core.Commands.Add('dvp', Lang:t('command.dvp.help'), {}, false, function()
    local peds = GetAllPeds()
    for _, ped in ipairs(peds) do
        DeleteEntity(ped)
    end
end, 'admin')

-- Objects

Core.Commands.Add('dvo', Lang:t('command.dvo.help'), {}, false, function()
    local objects = GetAllObjects()
    for _, object in ipairs(objects) do
        DeleteEntity(object)
    end
end, 'admin')

-- Money

Core.Commands.Add('givemoney', Lang:t('command.givemoney.help'), { { name = Lang:t('command.givemoney.params.id.name'), help = Lang:t('command.givemoney.params.id.help') }, { name = Lang:t('command.givemoney.params.moneytype.name'), help = Lang:t('command.givemoney.params.moneytype.help') }, { name = Lang:t('command.givemoney.params.amount.name'), help = Lang:t('command.givemoney.params.amount.help') } }, true, function(source, args)
    local Player = GetPlayerByCid(args[1])
    if Player then
        Player.AddMoney(tostring(args[2]), tonumber(args[3]), 'Admin give money')
    else
        Core.Notify(source, {title = Lang:t('error.not_online'), type = 'error', duration = 5000 })
    end
end, 'admin')

Core.Commands.Add('setmoney', Lang:t('command.setmoney.help'), { { name = Lang:t('command.setmoney.params.id.name'), help = Lang:t('command.setmoney.params.id.help') }, { name = Lang:t('command.setmoney.params.moneytype.name'), help = Lang:t('command.setmoney.params.moneytype.help') }, { name = Lang:t('command.setmoney.params.amount.name'), help = Lang:t('command.setmoney.params.amount.help') } }, true, function(source, args)
    local Player = GetPlayerByCid(args[1])
    if Player then
        Player.SetMoney(tostring(args[2]), tonumber(args[3]))
    else
        Core.Notify(source, {title = Lang:t('error.not_online'), type = 'error', duration = 5000 })
    end
end, 'admin')

-- Items

Core.Commands.Add('giveitem', 'Give an item to a player by citizen id (Admin Only)', { { name = 'id', help = 'Citizen id' }, { name = 'item', help = 'Item name' }, { name = 'amount', help = 'Amount (default 1)' } }, true, function(source, args)
    local Player = GetPlayerByCid(args[1])
    if not Player then
        return Core.Notify(source, {title = Lang:t('error.not_online'), type = 'error', duration = 5000 })
    end
    local item = tostring(args[2]):lower()
    local amount = tonumber(args[3]) or 1
    if not Core.Shared.Items[item] then
        return Core.Notify(source, {title = 'Item does not exist', type = 'error', duration = 5000 })
    end
    if GetResourceState('hexa_inventory') ~= 'started' then
        return Core.Notify(source, {title = 'Inventory resource not running', type = 'error', duration = 5000 })
    end
    exports['hexa_inventory']:AddItem(Player.PlayerData.source, item, amount)
    Core.Notify(source, {title = ('Gave %sx %s to id %s'):format(amount, item, args[1]), type = 'success', duration = 5000 })
end, 'admin')

-- Job

Core.Commands.Add('job', Lang:t('command.job.help'), {}, false, function(source)
    -- ต้องเช็ค nil ก่อน GetPlayer คืน nil ได้เมื่อยังไม่โหลดตัวละครหรือพิมพ์จาก console ที่ source = 0
    local Player = Core.GetPlayer(source)
    local PlayerJob = Player and Player.PlayerData and Player.PlayerData.job
    if not PlayerJob then
        return Core.Notify(source, {title = Lang:t('error.not_online'), type = 'error', duration = 5000 })
    end
    Core.Notify(source, {title = Lang:t('info.job_info', { value = PlayerJob.label, value2 = PlayerJob.grade.name, value3 = PlayerJob.onduty }), type = 'info', duration = 5000 })
end, 'user')

Core.Commands.Add('setjob', Lang:t('command.setjob.help'), { { name = Lang:t('command.setjob.params.id.name'), help = Lang:t('command.setjob.params.id.help') }, { name = Lang:t('command.setjob.params.job.name'), help = Lang:t('command.setjob.params.job.help') }, { name = Lang:t('command.setjob.params.grade.name'), help = Lang:t('command.setjob.params.grade.help') } }, true, function(source, args)
    local Player = GetPlayerByCid(args[1])
    if Player then
        local job = tostring(args[2])
        local grade = tonumber(args[3])
        if not Core.Shared.Jobs[job] then
            Core.Notify(source, {title = Lang:t('error.job_not_exist'), type = 'error', duration = 5000 })
            return
        end
        if GetResourceState('Hexa-multijob') == 'started' then
            exports['Hexa-multijob']:AddJobToPlayer(Player.PlayerData.citizenid, job, grade)
        end
        Player.SetJob(job, grade)
        Core.Notify(source, {title = Lang:t('success.job_set'), type = 'success', duration = 5000 })
    else
        Core.Notify(source, {title = Lang:t('error.not_online'), type = 'error', duration = 5000 })
    end
end, 'admin')

-- Me command

Core.Commands.Add('me', Lang:t('command.me.help'), { { name = Lang:t('command.me.params.message.name'), help = Lang:t('command.me.params.message.help') } }, false, function(source, args)
    if #args < 1 then
        Core.Notify(source, {title = Lang:t('error.missing_args2'), type = 'error', duration = 5000 })
        return
    end
    local ped = GetPlayerPed(source)
    local pCoords = GetEntityCoords(ped)
    local msg = table.concat(args, ' '):gsub('[~<].-[>~]', '')
    local Players = Core.GetPlayers()
    for i = 1, #Players do
        local Player = Players[i]
        local target = GetPlayerPed(Player)
        local tCoords = GetEntityCoords(target)
        if target == ped or #(pCoords - tCoords) < 20 then
            TriggerClientEvent('HexaCore:Command:ShowMe3D', Player, source, msg)
        end
    end
end, 'user')

-- ids
Core.Commands.Add('id', 'Check Your Citizen ID #', {}, false, function(source)
    local Player = Core.GetPlayer(source)
    Core.Notify(source, {title = 'ID: '..Player.PlayerData.citizenid, type = 'info', duration = 5000 })
end, 'user')
