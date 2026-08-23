local Core = exports['hexa_core']:GetCoreObject()

CreateThread(function()
    local active = false
    local timer = 0
    local cancelAt = nil -- เก็บเวลาที่ปุ่ม F จะมีผล แทนการ Wait ค้างกลางลูปซึ่งทำให้หยุดอ่านปุ่มอื่น
    local lastPeaceful = nil -- [perf-fix] track last-applied relationship/friendly-fire state
    while true do
        Wait(0) -- [perf-fix] keep frame polling only for the keybind reads

        -- นับถอยหลังหน้าต่างบังคับศัตรูในลูปหลัก ลูปซ้อนเดิมยึด coroutine ไว้จนอ่านปุ่มอื่นและสถานะขี่ม้าไม่ได้ทั้งช่วง
        if active and timer > 0 then
            timer = timer - 1
            if timer == 0 then active = false end
        end

        -- ดีเลย์ของปุ่ม F ต้องเดินด้วยนาฬิกา ไม่ใช่ Wait(500) ที่หยุดอ่านปุ่มทั้งครึ่งวินาที
        if cancelAt and GetGameTimer() >= cancelAt then
            cancelAt = nil
            active = false
            timer = 0
        end

        local ped = PlayerPedId()
        local peaceful = (active == false and not IsPedOnMount(ped) and not IsPedInAnyVehicle(ped)) -- [perf-fix]
        if peaceful ~= lastPeaceful then -- [perf-fix] only write relationship + friendly-fire natives on state change
            if peaceful then
                SetRelationshipBetweenGroups(3, 'PLAYER', 'PLAYER')
            else
                SetRelationshipBetweenGroups(1, 'PLAYER', 'PLAYER')
            end
            Citizen.InvokeNative(0xF808475FA571D823, true) -- [perf-fix] moved out of per-frame path
            NetworkSetFriendlyFireOption(true) -- [perf-fix] moved out of per-frame path
            lastPeaceful = peaceful
        end

        if IsControlJustPressed(0, Core.Shared.Keybinds['E']) then
            -- ตั้งเป็นจำนวนเฟรมเท่าลูปซ้อนเดิม (200) แล้วปล่อยให้ guard ด้านบนเขียน relationship ครั้งเดียวตอนสถานะเปลี่ยน
            timer = 200
            active = true
            cancelAt = nil -- กด E ระหว่างที่ F กำลังนับดีเลย์อยู่ ถือว่าผู้เล่นสั่งลุยต่อ
        end

        if IsControlJustPressed(0, Core.Shared.Keybinds['F']) then
            cancelAt = GetGameTimer() + 500 -- คงดีเลย์เดิม 500ms ไว้ แต่ไม่บล็อกลูป
        end
    end
end)
