-- ชั้น alias ชื่อเก่า ต้องโหลดท้ายสุดใน fxmanifest เพราะต้องเห็นฟังก์ชันจริงครบก่อนถึงผูกได้ ดู docs guide/upgrading

-- ชื่อเดิม -> ชื่อใหม่ เรียกได้ปกติแต่เตือนครั้งเดียวต่อชื่อ พร้อมบอกว่า resource ไหนเป็นคนเรียก
local RENAMED = {
    GetSource                   = 'GetSourceByIdentifier',
    GetHexaPlayers              = 'GetPlayerObjects',
    CanUseItem                  = 'GetUsableItem',
    GetPermission               = 'GetPermissions',
    IsOptin                     = 'IsAdminAlertsEnabled',
    ToggleOptin                 = 'ToggleAdminAlerts',
    ChangeWeight                = 'SetMaxWeight',
    ChangeSlots                 = 'SetMaxSlots',
    AddPlayerMethod             = 'SetPlayerField',
    AddPlayerField              = 'SetPlayerField',
    SetMethod                   = 'SetField',
    AddJob                      = 'RegisterJob',
    AddJobs                     = 'RegisterJobs',
    RemoveJob                   = 'UnregisterJob',
    UpdateJob                   = 'UpdateJobDefinition',
    AddItem                     = 'RegisterItem',
    AddItems                    = 'RegisterItems',
    UpdateItem                  = 'UpdateItemDefinition',
    RemoveItem                  = 'UnregisterItem',
    CreateFingerId              = 'CreateFingerprint',
    CreateSerialNumber          = 'CreatePhoneSerial',
}

-- ชื่อเดิมที่เคยอยู่ใต้ Core.Player.* ตอนนี้ยุบขึ้นมาอยู่บน Core แล้ว ต้องเติมนามให้ไม่ชนกับเมธอดของตัวผู้เล่น
local RENAMED_LIFECYCLE = {
    Login                       = 'LoginPlayer',
    Logout                      = 'LogoutPlayer',
    Save                        = 'SavePlayer',
    SaveOffline                 = 'SaveOfflinePlayer',
    CheckPlayerData             = 'LoadPlayer',
    GetOfflinePlayer            = 'GetOfflinePlayerByCitizenId',
}

local function deprecate(oldName, newName, target)
    if rawget(Core, oldName) ~= nil then return end
    Core[oldName] = function(...)
        local caller = GetInvokingResource() or 'unknown resource'
        Hexa.WarnOnce(oldName, '%s calls Core.%s which was renamed to Core.%s - update the call, the old name goes away next release',
            caller, oldName, newName)
        local fn = target or Core[newName]
        if type(fn) ~= 'function' then
            return Hexa.Error('Core.%s is missing, so the alias Core.%s cannot forward', newName, oldName)
        end
        return fn(...)
    end
end

for oldName, newName in pairs(RENAMED) do
    deprecate(oldName, newName)
end

-- เนมสเปซปลอมแทน Core.Player.* ที่ยุบทิ้ง __index ต้องจับทุกชื่อ ไม่ใช่แค่ตัวที่เปลี่ยนชื่อ เพราะย้ายขึ้น Core หมด
Core.Player = setmetatable({}, {
    __index = function(_, key)
        local target = RENAMED_LIFECYCLE[key] or key
        local fn = Core[target]
        if type(fn) ~= 'function' then return nil end
        return function(...)
            local caller = GetInvokingResource() or 'unknown resource'
            Hexa.WarnOnce('Player.' .. key, '%s calls Core.Player.%s - the Player namespace was dissolved, use Core.%s instead',
                caller, key, target)
            return fn(...)
        end
    end,
})

-- ระบบชื่อเสียงถูกถอดแล้ว แต่ต้องคง stub ไว้เตือนสคริปต์ qb/rsg ก่อนหนึ่งรอบ และคืนค่าว่างไม่ใช่ค่าปลอม
local REMOVED_PLAYER_METHODS = {
    AddRep    = function() return false end,
    RemoveRep = function() return false end,
    GetRep    = function() return 0 end,
}

AddEventHandler('HexaCore:Server:PlayerLoaded', function(Player)
    if not Player then return end
    for name, stub in pairs(REMOVED_PLAYER_METHODS) do
        if rawget(Player, name) == nil then
            Player[name] = function(...)
                Hexa.WarnOnce('rep:' .. name, 'Player.%s was removed - this server has no reputation system', name)
                return stub(...)
            end
        end
    end
end)
