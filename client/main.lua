-- อ็อบเจกต์หลักฝั่ง client แขวนชั้นเดียว ใช้ `or {}` ไม่ใช่ `= {}` กันไฟล์ที่โหลดก่อนถูกล้างถ้าลำดับใน fxmanifest ขยับ
Core = Core or {}

-- ชื่อเดิมชี้ตารางเดียวกัน โค้ดเก่าที่เขียน Core.X ยังทำงานได้ไม่ต้องแก้
HexaCore = Core

Core.PlayerData = {}
Core.Config = Config
Core.Shared = Shared
Core.ClientCallbacks = {}
Core.ServerCallbacks = {}

-- ต้องเป็นตารางจริงที่มีสมาชิกจริง เพราะ [bridge]/rsg-core ยกฟังก์ชันด้วย pairs() ถ้าเป็น proxy __index จะ mirror ได้ศูนย์ตัว
Core.Functions = {}

-- ทุกครั้งที่มีใครแขวนฟังก์ชันใหม่บน Core ให้มิเรอร์ลง Core.Functions ทันที
setmetatable(Core, {
    __newindex = function(target, key, value)
        rawset(target, key, value)
        if type(value) == 'function' then rawset(Core.Functions, key, value) end
    end,
})

-- __index รับของที่เพิ่มตอน runtime ส่วน __newindex ส่งการเขียนกลับขึ้น Core ให้เป็นแหล่งเดียว
setmetatable(Core.Functions, {
    __index = Core,
    __newindex = function(_, key, value) Core[key] = value end,
})

-- ตัวพิมพ์ log ทั้งชุดนิยามไว้ที่ shared/log.lua เพื่อให้ signature เหมือนกันเป๊ะทั้งสองฝั่ง
Core.Log = Hexa.Log
Core.Warn = Hexa.Warn
Core.Error = Hexa.Error
Core.PrintDebug = Hexa.Debug
Core.DumpTable = Hexa.DumpTable
Core.ShowError = Hexa.ShowError
Core.ShowSuccess = Hexa.ShowSuccess

exports('GetCoreObject', function()
    return Core
end)

-- ดึงไปใช้ใน resource อื่น: local Core = exports['hexa_core']:GetCoreObject()
