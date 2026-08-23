-- ชั้น alias ชื่อเก่า ต้องโหลดท้ายสุดใน fxmanifest เพราะต้องเห็นฟังก์ชันจริงครบก่อนถึงผูกได้ ดู docs guide/upgrading

-- ชื่อเดิม -> ชื่อใหม่ เรียกได้ปกติแต่เตือนครั้งเดียวต่อชื่อ พร้อมบอกว่า resource ไหนเป็นคนเรียก
local RENAMED = {
    GetSource                   = 'GetSourceByIdentifier',
    -- ชื่อฝั่ง client ที่มีสคริปต์เรียกผิดฝั่งมาที่ server ตัวเทียบเท่าคือ GetPlayers ซึ่งคืนลิสต์ source เหมือนกัน
    GetLocalPlayers             = 'GetPlayers',
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

-- เนมสเปซแทน Core.Player.* ที่ยุบทิ้ง ต้องจับทุกชื่อ ไม่ใช่แค่ตัวที่เปลี่ยนชื่อ เพราะย้ายขึ้น Core หมด
-- และต้องเป็นตารางจริงที่มีสมาชิกจริง ไม่ใช่ proxy __index เพราะ bridge/rsg-core ยกของด้วย pairs()
-- (mirrorPlayerNamespace ใน rsg-core/server/main.lua) proxy จะให้ศูนย์ตัว แล้ว RSGCore.Player.Login กลายเป็น nil
-- เป็นกับดักตัวเดียวกับที่ Core.Functions เคยเจอ ดูคอมเมนต์ใน server/main.lua
local PlayerNamespace = {}

local function bindLegacy(oldName, newName)
    if type(Core[newName]) ~= 'function' then return end
    PlayerNamespace[oldName] = function(...)
        local caller = GetInvokingResource() or 'unknown resource'
        Hexa.WarnOnce('Player.' .. oldName, '%s calls Core.Player.%s - the Player namespace was dissolved, use Core.%s instead',
            caller, oldName, newName)
        -- อ่านสดทุกครั้ง ไม่ปิดทับตัวฟังก์ชันไว้ เผื่อมีใครสลับของบน Core ทีหลัง
        local fn = Core[newName]
        if type(fn) ~= 'function' then
            return Hexa.Error('Core.%s is missing, so Core.Player.%s cannot forward', newName, oldName)
        end
        return fn(...)
    end
end

-- ทุกฟังก์ชันที่อยู่บน Core ยกขึ้นมาด้วยชื่อเดิมก่อน แล้วค่อยทับด้วยคู่ชื่อเก่า -> ชื่อใหม่
-- ต้องเก็บชื่อไว้ก่อนค่อยผูก เพราะ bindLegacy เขียนลง PlayerNamespace ไม่ใช่ Core ที่กำลังวนอยู่
local coreFunctionNames = {}
for key, value in pairs(Core) do
    if type(value) == 'function' then coreFunctionNames[#coreFunctionNames + 1] = key end
end
for _, key in ipairs(coreFunctionNames) do bindLegacy(key, key) end

for oldName, newName in pairs(RENAMED_LIFECYCLE) do
    bindLegacy(oldName, newName)
    -- ชื่อในลิสต์นี้ต้องมีจริงบน Core เสมอ ผูกไม่ได้แปลว่าไฟล์ที่นิยามมันโหลดไม่ขึ้น ต้องดังตั้งแต่ตอนบูต
    -- ไม่ใช่ปล่อยให้ไปโผล่เป็น "attempt to call a nil value" ในสคริปต์อื่นตอนผู้เล่นเข้าเกม
    if PlayerNamespace[oldName] == nil then
        Hexa.Error('Core.%s is missing at boot - Core.Player.%s will be nil (did server/player.lua fail to load?)', newName, oldName)
    end
end

-- ผูกไว้ล่วงหน้าเพื่อให้ pairs() เห็นของจริง ส่วน __index ไว้รับฟังก์ชันที่ถูกเพิ่มบน Core ทีหลัง (เช่นผ่าน Core.SetField)
setmetatable(PlayerNamespace, {
    __index = function(_, key)
        local target = RENAMED_LIFECYCLE[key] or key
        if type(Core[target]) ~= 'function' then return nil end
        bindLegacy(key, target)
        return rawget(PlayerNamespace, key)
    end,
})

Core.Player = PlayerNamespace

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
