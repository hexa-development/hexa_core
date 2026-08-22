-- ลูปนับเวลาเซฟย้ายไป server/save.lua แล้ว ถ้า client นับเอง ไม่ยิงก็ไม่เซฟ และเปิดทางเขียน DB รัว ๆ (docs guide/persistence)

-- ปิดปุ่ม/prompt ของเกมที่ไม่ต้องการ ต้องเรียกทุกเฟรมเพราะ DisableControlAction มีผลแค่เฟรมเดียว
CreateThread(function()
    while true do
        Wait(0)
        DisableControlAction(0, 0xCF8A4ECA, true) -- ปิด HUD ปุ่ม Left Alt (กดรัวๆ)
        DisableControlAction(0, 0x9CC7A1A4, true) -- ปิด prompt Ability Loadout
    end
end)