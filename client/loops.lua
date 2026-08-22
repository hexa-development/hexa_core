-- ลูปนับเวลาเซฟเคยอยู่ตรงนี้ ย้ายไป server/save.lua แล้ว
-- client เป็นคนนับเวลาแปลว่าไม่ยิงก็ไม่มีวันเซฟ และเปิดทางให้สั่งเขียน DB รัว ๆ ได้ด้วย

-- ปิดปุ่ม/prompt ของเกมที่ไม่ต้องการ
-- (DisableControlAction มีผลแค่เฟรมเดียว จำเป็นต้องเรียกทุกเฟรม)
CreateThread(function()
    while true do
        Wait(0)
        DisableControlAction(0, 0xCF8A4ECA, true) -- ปิด HUD ปุ่ม Left Alt (กดรัวๆ)
        DisableControlAction(0, 0x9CC7A1A4, true) -- ปิด prompt Ability Loadout
    end
end)