CreateThread(function()
    local interval = (1000 * 60) * HexaCore.Config.UpdateInterval

    while true do
        Wait(interval)
        if LocalPlayer.state.isLoggedIn then
            TriggerServerEvent("HexaCore:UpdatePlayer")
        end
    end
end)

-- ปิดปุ่ม/prompt ของเกมที่ไม่ต้องการ
-- (DisableControlAction มีผลแค่เฟรมเดียว จำเป็นต้องเรียกทุกเฟรม)
CreateThread(function()
    while true do
        Wait(0)
        DisableControlAction(0, 0xCF8A4ECA, true) -- ปิด HUD ปุ่ม Left Alt (กดรัวๆ)
        DisableControlAction(0, 0x9CC7A1A4, true) -- ปิด prompt Ability Loadout
    end
end)