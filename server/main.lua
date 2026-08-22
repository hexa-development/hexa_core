-- อ็อบเจกต์หลักของเฟรมเวิร์ก ฟังก์ชันทุกตัวแขวนตรงนี้ชั้นเดียว ไม่มี .Functions คั่นอีกแล้ว
-- ใช้ `or {}` ไม่ใช่ `= {}` เพื่อไม่ให้ไฟล์ที่โหลดก่อนหน้าถูกล้างทิ้งถ้าลำดับใน fxmanifest ขยับ
Core = Core or {}

-- ชื่อเดิมชี้ตารางเดียวกัน โค้ดเก่าที่เขียน HexaCore.X ยังทำงานได้ไม่ต้องแก้
HexaCore = Core

Core.Config = Config
Core.Shared = Shared
Core.ClientCallbacks = {}
Core.ServerCallbacks = {}

-- ชั้น .Functions เดิมยังเรียกได้ตลอดช่วงเปลี่ยนผ่าน และต้องเป็น "ตารางจริงที่มีสมาชิกอยู่จริง"
-- เพราะ [bridge]/rsg-core ยกฟังก์ชันไปทำ RSG API ด้วย pairs() ไม่ใช่การ index ทีละตัว
-- proxy ที่มีแค่ __index จะทำให้ bridge mirror ได้ศูนย์ตัวแล้วสคริปต์ RSG พังเงียบทั้งเซิร์ฟ
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
