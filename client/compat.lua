-- ชั้นรองรับชื่อเก่า ฝั่ง client
-- โหลดท้ายสุดใน fxmanifest เพราะต้องเห็นฟังก์ชันจริงครบทุกตัวก่อนถึงจะผูก alias ได้
-- ทุกตัวที่นี่จะถูกถอดออกเมื่อกวาดแก้ resource ภายนอกครบแล้ว

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

-- Debug เดิมทำคนละหน้าที่กันสองฝั่ง ฝั่งนี้รับ (resource, obj, depth) ฝั่ง server รับ (tbl, indent)
-- ตัวใหม่แยกเป็น PrintDebug (พิมพ์บรรทัด) กับ DumpTable (พิมพ์ตาราง) alias จึงต้องเดาให้ถูกจากชนิดของอาร์กิวเมนต์
if rawget(Core, 'Debug') == nil then
    Core.Debug = function(first, second, ...)
        Hexa.WarnOnce('Debug', 'Core.Debug was split into Core.PrintDebug (one line) and Core.DumpTable (a table) - pick one')
        if type(first) == 'table' then return Core.DumpTable(first, second) end
        if type(second) == 'table' then return Core.DumpTable(second, ...) end
        return Core.PrintDebug('%s', tostring(first))
    end
end
