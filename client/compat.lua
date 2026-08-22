-- ชั้นรองรับชื่อเก่าฝั่ง client (ชั่วคราว) ต้องโหลดท้ายสุดใน fxmanifest เพราะต้องเห็นฟังก์ชันจริงครบก่อนถึงผูก alias ได้

local RENAMED = {
    CreateClientCallback        = 'CreateCallback',
    LookAtEntity                = 'TurnPedToFaceEntity',
    GetPlayers                  = 'GetLocalPlayers',
    GetPlayersFromCoords        = 'GetLocalPlayersInRadius',
    GetClosestPlayer            = 'GetClosestLocalPlayer',
    RequestAnimDict             = 'LoadAnimDict',
    AttachProp                  = 'CreateAttachedProp',
    SpawnClear                  = 'IsAreaClearOfVehicles',
    LoadParticleDictionary      = 'LoadPtfxAsset',
    GetStreetNametAtCoords      = 'GetStreetNamesAtCoords',
    GetCurrentTime              = 'GetInGameTime',
    GetGroundZCoord             = 'GetGroundCoords',
    GetGroundHash               = 'GetGroundMaterial',
}

for oldName, newName in pairs(RENAMED) do
    if rawget(Core, oldName) == nil then
        Core[oldName] = function(...)
            local caller = GetInvokingResource() or 'unknown resource'
            Hexa.WarnOnce(oldName, '%s calls Core.%s which was renamed to Core.%s - update the call, the old name goes away next release',
                caller, oldName, newName)
            local fn = Core[newName]
            if type(fn) ~= 'function' then
                return Hexa.Error('Core.%s is missing, so the alias Core.%s cannot forward', newName, oldName)
            end
            return fn(...)
        end
    end
end

-- Debug เดิมคนละ signature สองฝั่ง alias จึงต้องเดาจากชนิดอาร์กิวเมนต์ว่าจะส่งไป PrintDebug หรือ DumpTable
if rawget(Core, 'Debug') == nil then
    Core.Debug = function(first, second, ...)
        Hexa.WarnOnce('Debug', 'Core.Debug was split into Core.PrintDebug (one line) and Core.DumpTable (a table) - pick one')
        if type(first) == 'table' then return Core.DumpTable(first, second) end
        if type(second) == 'table' then return Core.DumpTable(second, ...) end
        return Core.PrintDebug('%s', tostring(first))
    end
end
