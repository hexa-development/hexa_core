-- Add or change (a) method(s) in the Core.Functions table
local function SetMethod(methodName, handler)
    if type(methodName) ~= 'string' then
        return false, 'invalid_method_name'
    end

    Core.Functions[methodName] = handler

    TriggerEvent('HexaCore:Server:UpdateObject')

    return true, 'success'
end

Core.SetField = SetMethod
exports('SetMethod', SetMethod)

-- Add or change (a) field(s) in the Core table
local function SetField(fieldName, data)
    if type(fieldName) ~= 'string' then
        return false, 'invalid_field_name'
    end

    Core[fieldName] = data

    TriggerEvent('HexaCore:Server:UpdateObject')

    return true, 'success'
end

Core.SetField = SetField
exports('SetField', SetField)

-- Single add job function which should only be used if you planning on adding a single job
local function AddJob(jobName, job)
    if type(jobName) ~= 'string' then
        return false, 'invalid_job_name'
    end

    if Core.Shared.Jobs[jobName] then
        return false, 'job_exists'
    end

    Core.Shared.Jobs[jobName] = job

    TriggerClientEvent('HexaCore:Client:OnSharedUpdate', -1, 'Jobs', jobName, job)
    TriggerEvent('HexaCore:Server:UpdateObject')
    return true, 'success'
end

Core.RegisterJob = AddJob
exports('AddJob', AddJob)

-- Multiple Add Jobs
local function AddJobs(jobs)
    local shouldContinue = true
    local message = 'success'
    local errorItem = nil

    for key, value in pairs(jobs) do
        if type(key) ~= 'string' then
            message = 'invalid_job_name'
            shouldContinue = false
            errorItem = jobs[key]
            break
        end

        if Core.Shared.Jobs[key] then
            message = 'job_exists'
            shouldContinue = false
            errorItem = jobs[key]
            break
        end

        Core.Shared.Jobs[key] = value
    end

    if not shouldContinue then return false, message, errorItem end
    TriggerClientEvent('HexaCore:Client:OnSharedUpdateMultiple', -1, 'Jobs', jobs)
    TriggerEvent('HexaCore:Server:UpdateObject')
    return true, message, nil
end

Core.RegisterJobs = AddJobs
exports('AddJobs', AddJobs)

-- Single Remove Job
local function RemoveJob(jobName)
    if type(jobName) ~= 'string' then
        return false, 'invalid_job_name'
    end

    if not Core.Shared.Jobs[jobName] then
        return false, 'job_not_exists'
    end

    Core.Shared.Jobs[jobName] = nil

    TriggerClientEvent('HexaCore:Client:OnSharedUpdate', -1, 'Jobs', jobName, nil)
    TriggerEvent('HexaCore:Server:UpdateObject')
    return true, 'success'
end

Core.UnregisterJob = RemoveJob
exports('RemoveJob', RemoveJob)

-- Single Update Job
local function UpdateJob(jobName, job)
    if type(jobName) ~= 'string' then
        return false, 'invalid_job_name'
    end

    if not Core.Shared.Jobs[jobName] then
        return false, 'job_not_exists'
    end

    Core.Shared.Jobs[jobName] = job

    TriggerClientEvent('HexaCore:Client:OnSharedUpdate', -1, 'Jobs', jobName, job)
    TriggerEvent('HexaCore:Server:UpdateObject')
    return true, 'success'
end

Core.UpdateJobDefinition = UpdateJob
exports('UpdateJob', UpdateJob)

-- Single add item
local function AddItem(itemName, item)
    if type(itemName) ~= 'string' then
        return false, 'invalid_item_name'
    end

    if Core.Shared.Items[itemName] then
        return false, 'item_exists'
    end

    Core.Shared.Items[itemName] = item

    TriggerClientEvent('HexaCore:Client:OnSharedUpdate', -1, 'Items', itemName, item)
    TriggerEvent('HexaCore:Server:UpdateObject')
    return true, 'success'
end

Core.RegisterItem = AddItem
exports('AddItem', AddItem)

-- Single update item
local function UpdateItem(itemName, item)
    if type(itemName) ~= 'string' then
        return false, 'invalid_item_name'
    end
    if not Core.Shared.Items[itemName] then
        return false, 'item_not_exists'
    end
    Core.Shared.Items[itemName] = item
    TriggerClientEvent('HexaCore:Client:OnSharedUpdate', -1, 'Items', itemName, item)
    TriggerEvent('HexaCore:Server:UpdateObject')
    return true, 'success'
end

Core.UpdateItemDefinition = UpdateItem
exports('UpdateItem', UpdateItem)

-- Multiple Add Items
local function AddItems(items)
    local shouldContinue = true
    local message = 'success'
    local errorItem = nil

    for key, value in pairs(items) do
        if type(key) ~= 'string' then
            message = 'invalid_item_name'
            shouldContinue = false
            errorItem = items[key]
            break
        end

        if Core.Shared.Items[key] then
            message = 'item_exists'
            shouldContinue = false
            errorItem = items[key]
            break
        end

        Core.Shared.Items[key] = value
    end

    if not shouldContinue then return false, message, errorItem end
    TriggerClientEvent('HexaCore:Client:OnSharedUpdateMultiple', -1, 'Items', items)
    TriggerEvent('HexaCore:Server:UpdateObject')
    return true, message, nil
end

Core.RegisterItems = AddItems
exports('AddItems', AddItems)

-- Single Remove Item
local function RemoveItem(itemName)
    if type(itemName) ~= 'string' then
        return false, 'invalid_item_name'
    end

    if not Core.Shared.Items[itemName] then
        return false, 'item_not_exists'
    end

    Core.Shared.Items[itemName] = nil

    TriggerClientEvent('HexaCore:Client:OnSharedUpdate', -1, 'Items', itemName, nil)
    TriggerEvent('HexaCore:Server:UpdateObject')
    return true, 'success'
end

Core.UnregisterItem = RemoveItem
exports('RemoveItem', RemoveItem)

local resourceName = GetCurrentResourceName()
local function GetCoreVersion(InvokingResource)
    local resourceVersion = GetResourceMetadata(resourceName, 'version')
    if InvokingResource and InvokingResource ~= '' then
        Hexa.Debug('%s asked for the core version: %s', tostring(InvokingResource or 'unknown resource'), tostring(resourceVersion))
    end
    return resourceVersion
end

Core.GetCoreVersion = GetCoreVersion
exports('GetCoreVersion', GetCoreVersion)

local function ExploitBan(playerId, origin)
    local name = GetPlayerName(playerId)
    DropPlayer(playerId, Lang:t('info.exploit_dropped'))
    TriggerEvent('hexa_log:server:CreateLog', 'anticheat', 'Anti-Cheat', 'red', name .. ' has been kicked for exploiting ' .. origin, true)
end

exports('ExploitBan', ExploitBan)
