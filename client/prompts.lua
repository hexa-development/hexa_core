-- ชั้นภาพย้ายไป hexa_interaction แล้ว แต่ export/signature เดิมคงไว้ครบ ระยะและกดค้าง 1000ms เท่าเดิม (docs api/exports)

local Prompts = {}
local PromptGroups = {}

local function executeOptions(options)
    if options == nil then return end
    if options.type == 'client' then
        if options.args == nil then
            TriggerEvent(options.event)
        else
            TriggerEvent(options.event, table.unpack(options.args))
        end
    else
        if options.args == nil then
            TriggerServerEvent(options.event)
        else
            TriggerServerEvent(options.event, table.unpack(options.args))
        end
    end
end

-- ทั้งสแตกกดค้าง ENTER 1000ms เสมอ (key ที่ส่งมาถูกมองข้าม) กลุ่มก็ใช้ปุ่มเดียวกัน กดครั้งเดียวยิง onComplete ทุกตัวในกลุ่ม
local PROMPT_KEY  = 'ENTER'
local PROMPT_HOLD = 1000

local function createPrompt(name, coords, key, text, options)
    Prompts[name] = { name = name, coords = coords, key = key, text = text, options = options }
    exports['hexa_interaction']:RegisterPrompt({
        id       = name,
        coords   = coords,
        key      = PROMPT_KEY,
        label    = text,
        -- ป้ายในเกมเป็นอังกฤษเสมอ ส่ง options.promptLabel มาทับได้ ไม่ส่ง hexa_interaction จะตกกลับไปใช้ text
        promptLabel = options and options.promptLabel or nil,
        distance = Config.PromptDistance,
        visibleDistance = Config.PromptVisible,
        hold     = true,
        holdTime = PROMPT_HOLD,
        onComplete = function() executeOptions(options) end,
    })
end

local function createPromptGroup(group, label, coords, prompts)
    PromptGroups[group] = { group = group, label = label, coords = coords, prompts = prompts }
    local list = {}
    for _, v in pairs(prompts) do
        list[#list + 1] = {
            id       = tostring(group) .. ':' .. tostring(v.name or v.key),
            key      = PROMPT_KEY,
            label    = v.text,
            promptLabel = v.promptLabel,
            hold     = true,
            holdTime = PROMPT_HOLD,
            onComplete = function() executeOptions(v.options) end,
        }
    end
    exports['hexa_interaction']:RegisterGroup({
        id       = group,
        label    = label,
        coords   = coords,
        distance = Config.PromptDistance,
        visibleDistance = Config.PromptVisible,
        prompts  = list,
    })
end

local function getPrompt()
    return Prompts
end

local function getPromptGroup()
    return PromptGroups
end

local function deletePrompt(name)
    if Prompts[name] then Prompts[name] = nil end
    exports['hexa_interaction']:RemovePrompt(name)
end

local function deletePromptGroup(name)
    if PromptGroups[name] then PromptGroups[name] = nil end
    exports['hexa_interaction']:RemoveGroup(name)
end

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    for name in pairs(Prompts) do
        exports['hexa_interaction']:RemovePrompt(name)
    end
    Prompts = {}

    for name in pairs(PromptGroups) do
        exports['hexa_interaction']:RemoveGroup(name)
    end
    PromptGroups = {}
end)

exports('createPrompt', createPrompt)
exports('createPromptGroup', createPromptGroup)
exports('getPrompt', getPrompt)
exports('getPromptGroup', getPromptGroup)
exports('deletePrompt', deletePrompt)
exports('deletePromptGroup', deletePromptGroup)
