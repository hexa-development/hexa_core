HexaCore.Commands = {}
HexaCore.Commands.List = {}
HexaCore.Commands.IgnoreList = { -- ระดับที่ไม่ต้องสร้าง ace รายคำสั่ง
    ['admin'] = true,          -- admin ใช้ได้ทุกคำสั่งอยู่แล้ว (add_ace hexacore.admin command allow ใน permissions.cfg)
    ['user'] = true            -- user = builtin.everyone (ทุกคน)
}

HexaCore.Commands.Permissions = {'admin', 'staff'} -- ระดับสิทธิ์ในเซิร์ฟเวอร์ (ต้องตรงกับ permissions.cfg) — admin = สูงสุด, staff = ทีมงาน

-- คำสั่งแอดมินอ้างผู้เล่นด้วย citizen id ถาวร ไม่ใช่ session id ที่เปลี่ยนทุกครั้งที่เข้าเกม ดู docs api/commands
local function GetPlayerByCid(id)
    if not id then return nil end
    return HexaCore.GetPlayerByCitizenId(tostring(id))
end

CreateThread(function() -- Add ace to node for perm checking
    local permissions = HexaCore.Commands.Permissions
    for i = 1, #permissions do
        local permission = permissions[i]
        ExecuteCommand(('add_ace hexacore.%s %s allow'):format(permission, permission))
    end
end)

-- Register & Refresh Commands

function HexaCore.Commands.Add(name, help, arguments, argsrequired, callback, permission, ...)
    local restricted = true                                  -- Default to restricted for all commands
    if not permission then permission = 'user' end           -- some commands don't pass permission level
    if permission == 'user' then restricted = false end      -- allow all users to use command

    RegisterCommand(name, function(source, args, rawCommand) -- Register command within fivem
        if argsrequired and #args < #arguments then
            return HexaCore.Notify(source, {
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
            if not HexaCore.Commands.IgnoreList[permission[i]] then -- only create aces for extra perm levels
                ExecuteCommand(('add_ace hexacore.%s command.%s allow'):format(permission[i], name))
            end
        end
        permission.n = nil
    else
        permission = tostring(permission:lower())
        if not HexaCore.Commands.IgnoreList[permission] then -- only create aces for extra perm levels
            ExecuteCommand(('add_ace hexacore.%s command.%s allow'):format(permission, name))
        end
    end

    HexaCore.Commands.List[name:lower()] = {
        name = name:lower(),
        permission = permission,
        help = help,
        arguments = arguments,
        argsrequired = argsrequired,
        callback = callback
    }
end

function HexaCore.Commands.Refresh(source)
    local src = source
    local Player = HexaCore.GetPlayer(src)
    local suggestions = {}
    if Player then
        for command, info in pairs(HexaCore.Commands.List) do
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
HexaCore.Commands.Add('tp', Lang:t('command.tp.help'), { { name = Lang:t('command.tp.params.x.name'), help = Lang:t('command.tp.params.x.help') }, { name = Lang:t('command.tp.params.y.name'), help = Lang:t('command.tp.params.y.help') }, { name = Lang:t('command.tp.params.z.name'), help = Lang:t('command.tp.params.z.help') } }, false, function(source, args)
    if args[1] and not args[2] and not args[3] then
        if tonumber(args[1]) then
            local Target = GetPlayerByCid(args[1])
            if Target then
                local coords = GetEntityCoords(GetPlayerPed(Target.PlayerData.source))
                TriggerClientEvent('HexaCore:Command:TeleportToPlayer', source, coords)
            else
                HexaCore.Notify(source, {title = Lang:t('error.not_online'), type = 'error', duration = 5000 })
            end
        else
            HexaCore.Notify(source, {title = Lang:t('error.wrong_format'), type = 'error', duration = 5000 })
        end
    else
        if args[1] and args[2] and args[3] then
            local x = tonumber((args[1]:gsub(',', ''))) + .0
            local y = tonumber((args[2]:gsub(',', ''))) + .0
            local z = tonumber((args[3]:gsub(',', ''))) + .0
            if x ~= 0 and y ~= 0 and z ~= 0 then
                TriggerClientEvent('HexaCore:Command:TeleportToCoords', source, x, y, z)
            else
                HexaCore.Notify(source, {title = Lang:t('error.wrong_format'), type = 'error', duration = 5000 })
            end
        else
            HexaCore.Notify(source, {title = Lang:t('error.missing_args'), type = 'error', duration = 5000 })
        end
    end
end, 'admin')

HexaCore.Commands.Add('tpm', Lang:t('command.tpm.help'), {}, false, function(source)
    TriggerClientEvent('HexaCore:Command:GoToMarker', source)
end, 'admin')

-- admin noclip
HexaCore.Commands.Add('noclip', Lang:t("command.noclip.help"), {}, false, function(source)
    TriggerClientEvent('HexaCore:Command:ToggleNoClip', source)
end, 'admin')

-- Permissions

HexaCore.Commands.Add('addpermission', Lang:t('command.addpermission.help'), { { name = Lang:t('command.addpermission.params.id.name'), help = Lang:t('command.addpermission.params.id.help') }, { name = Lang:t('command.addpermission.params.permission.name'), help = Lang:t('command.addpermission.params.permission.help') } }, true, function(source, args)
    local Player = GetPlayerByCid(args[1])
    local permission = tostring(args[2]):lower()
    if Player then
        HexaCore.AddPermission(Player.PlayerData.source, permission)
    else
        HexaCore.Notify(source, {title = Lang:t('error.not_online'), type = 'error', duration = 5000 })
    end
end, 'admin')

HexaCore.Commands.Add('removepermission', Lang:t('command.removepermission.help'), { { name = Lang:t('command.removepermission.params.id.name'), help = Lang:t('command.removepermission.params.id.help') }, { name = Lang:t('command.removepermission.params.permission.name'), help = Lang:t('command.removepermission.params.permission.help') } }, true, function(source, args)
    local Player = GetPlayerByCid(args[1])
    local permission = tostring(args[2]):lower()
    if Player then
        HexaCore.RemovePermission(Player.PlayerData.source, permission)
    else
        HexaCore.Notify(source, {title = Lang:t('error.not_online'), type = 'error', duration = 5000 })
    end
end, 'admin')

-- Vehicle

HexaCore.Commands.Add('vehicle', Lang:t('command.car.help'), { { name = Lang:t('command.car.params.model.name'), help = Lang:t('command.car.params.model.help') } }, true, function(source, args)
    TriggerClientEvent('HexaCore:Command:SpawnVehicle', source, args[1])
end, 'admin')

HexaCore.Commands.Add('dv', Lang:t('command.dv.help'), {}, false, function(source)
    TriggerClientEvent('HexaCore:Command:DeleteVehicle', source)
end, 'admin')

HexaCore.Commands.Add('dvall', Lang:t('command.dvall.help'), {}, false, function()
    local vehicles = GetAllVehicles()
    for _, vehicle in ipairs(vehicles) do
        DeleteEntity(vehicle)
    end
end, 'admin')

-- Peds

HexaCore.Commands.Add('dvp', Lang:t('command.dvp.help'), {}, false, function()
    local peds = GetAllPeds()
    for _, ped in ipairs(peds) do
        DeleteEntity(ped)
    end
end, 'admin')

-- Objects

HexaCore.Commands.Add('dvo', Lang:t('command.dvo.help'), {}, false, function()
    local objects = GetAllObjects()
    for _, object in ipairs(objects) do
        DeleteEntity(object)
    end
end, 'admin')

-- Money

HexaCore.Commands.Add('givemoney', Lang:t('command.givemoney.help'), { { name = Lang:t('command.givemoney.params.id.name'), help = Lang:t('command.givemoney.params.id.help') }, { name = Lang:t('command.givemoney.params.moneytype.name'), help = Lang:t('command.givemoney.params.moneytype.help') }, { name = Lang:t('command.givemoney.params.amount.name'), help = Lang:t('command.givemoney.params.amount.help') } }, true, function(source, args)
    local Player = GetPlayerByCid(args[1])
    if Player then
        Player.AddMoney(tostring(args[2]), tonumber(args[3]), 'Admin give money')
    else
        HexaCore.Notify(source, {title = Lang:t('error.not_online'), type = 'error', duration = 5000 })
    end
end, 'admin')

HexaCore.Commands.Add('setmoney', Lang:t('command.setmoney.help'), { { name = Lang:t('command.setmoney.params.id.name'), help = Lang:t('command.setmoney.params.id.help') }, { name = Lang:t('command.setmoney.params.moneytype.name'), help = Lang:t('command.setmoney.params.moneytype.help') }, { name = Lang:t('command.setmoney.params.amount.name'), help = Lang:t('command.setmoney.params.amount.help') } }, true, function(source, args)
    local Player = GetPlayerByCid(args[1])
    if Player then
        Player.SetMoney(tostring(args[2]), tonumber(args[3]))
    else
        HexaCore.Notify(source, {title = Lang:t('error.not_online'), type = 'error', duration = 5000 })
    end
end, 'admin')

-- Items

HexaCore.Commands.Add('giveitem', 'Give an item to a player by citizen id (Admin Only)', { { name = 'id', help = 'Citizen id' }, { name = 'item', help = 'Item name' }, { name = 'amount', help = 'Amount (default 1)' } }, true, function(source, args)
    local Player = GetPlayerByCid(args[1])
    if not Player then
        return HexaCore.Notify(source, {title = Lang:t('error.not_online'), type = 'error', duration = 5000 })
    end
    local item = tostring(args[2]):lower()
    local amount = tonumber(args[3]) or 1
    if not HexaCore.Shared.Items[item] then
        return HexaCore.Notify(source, {title = 'Item does not exist', type = 'error', duration = 5000 })
    end
    if GetResourceState('hexa_inventory') ~= 'started' then
        return HexaCore.Notify(source, {title = 'Inventory resource not running', type = 'error', duration = 5000 })
    end
    exports['hexa_inventory']:AddItem(Player.PlayerData.source, item, amount)
    HexaCore.Notify(source, {title = ('Gave %sx %s to id %s'):format(amount, item, args[1]), type = 'success', duration = 5000 })
end, 'admin')

-- Job

HexaCore.Commands.Add('job', Lang:t('command.job.help'), {}, false, function(source)
    -- ต้องเช็ค nil ก่อน GetPlayer คืน nil ได้เมื่อยังไม่โหลดตัวละครหรือพิมพ์จาก console ที่ source = 0
    local Player = HexaCore.GetPlayer(source)
    local PlayerJob = Player and Player.PlayerData and Player.PlayerData.job
    if not PlayerJob then
        return HexaCore.Notify(source, {title = Lang:t('error.not_online'), type = 'error', duration = 5000 })
    end
    HexaCore.Notify(source, {title = Lang:t('info.job_info', { value = PlayerJob.label, value2 = PlayerJob.grade.name, value3 = PlayerJob.onduty }), type = 'info', duration = 5000 })
end, 'user')

HexaCore.Commands.Add('setjob', Lang:t('command.setjob.help'), { { name = Lang:t('command.setjob.params.id.name'), help = Lang:t('command.setjob.params.id.help') }, { name = Lang:t('command.setjob.params.job.name'), help = Lang:t('command.setjob.params.job.help') }, { name = Lang:t('command.setjob.params.grade.name'), help = Lang:t('command.setjob.params.grade.help') } }, true, function(source, args)
    local Player = GetPlayerByCid(args[1])
    if Player then
        local job = tostring(args[2])
        local grade = tonumber(args[3])
        if not HexaCore.Shared.Jobs[job] then
            HexaCore.Notify(source, {title = Lang:t('error.job_not_exist'), type = 'error', duration = 5000 })
            return
        end
        if GetResourceState('Hexa-multijob') == 'started' then
            exports['Hexa-multijob']:AddJobToPlayer(Player.PlayerData.citizenid, job, grade)
        end
        Player.SetJob(job, grade)
        HexaCore.Notify(source, {title = Lang:t('success.job_set'), type = 'success', duration = 5000 })
    else
        HexaCore.Notify(source, {title = Lang:t('error.not_online'), type = 'error', duration = 5000 })
    end
end, 'admin')

-- Me command

HexaCore.Commands.Add('me', Lang:t('command.me.help'), { { name = Lang:t('command.me.params.message.name'), help = Lang:t('command.me.params.message.help') } }, false, function(source, args)
    if #args < 1 then
        HexaCore.Notify(source, {title = Lang:t('error.missing_args2'), type = 'error', duration = 5000 })
        return
    end
    local ped = GetPlayerPed(source)
    local pCoords = GetEntityCoords(ped)
    local msg = table.concat(args, ' '):gsub('[~<].-[>~]', '')
    local Players = HexaCore.GetPlayers()
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
HexaCore.Commands.Add('id', 'Check Your Citizen ID #', {}, false, function(source)
    local Player = HexaCore.GetPlayer(source)
    HexaCore.Notify(source, {title = 'ID: '..Player.PlayerData.citizenid, type = 'info', duration = 5000 })
end, 'user')
