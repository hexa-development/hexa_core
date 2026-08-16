-- ============================================================
-- ควบคุมความหนาแน่น NPC / สัตว์ / ยานพาหนะ (Config.Density)
-- ============================================================
-- natives ชุดนี้เป็นแบบ "ThisFrame" โดยดีไซน์ของเอนจิน RDR3:
-- ค่ามีผลแค่เฟรมเดียวแล้วรีเซ็ตกลับ 1.0 เสมอ จึงจำเป็นต้องเรียกทุกเฟรม
-- (เลี่ยง loop ไม่ได้) แต่ optimize ให้เบาที่สุด:
--   1. ค่า 1.0 = ค่า default ของเอนจิน -> ข้ามไม่เรียกเลย
--   2. ถ้าทุกค่าเป็น 1.0 -> ไม่สร้าง thread เลยแม้แต่ตัวเดียว
--   3. precompute รายการ native ที่ต้องเรียกไว้ล่วงหน้า loop ใน thread แค่ไล่ยิง

local densityNatives = {
    [1] = 0xC0258742B034DFAF, -- SetAmbientAnimalDensityMultiplierThisFrame
    [2] = 0xDB48E99F8E064E56, -- SetScenarioAnimalDensityMultiplierThisFrame
    [3] = 0xBA0980B5C0A11924, -- SetAmbientHumanDensityMultiplierThisFrame
    [4] = 0x28CB6391ACEDD9DB, -- SetScenarioHumanDensityMultiplierThisFrame
    [5] = 0xAB0D553FE20A6E25, -- SetAmbientPedDensityMultiplierThisFrame
    [6] = 0x7A556143A1C03898, -- SetScenarioPedDensityMultiplierThisFrame
    [7] = 0xFEDFA97638D61D4A, -- SetParkedVehicleDensityMultiplierThisFrame
    [8] = 0x1F91D44490E1EA0C, -- SetRandomVehicleDensityMultiplierThisFrame
    [9] = 0x606374EBFC27B133, -- SetVehicleDensityMultiplierThisFrame
}

-- precompute เฉพาะรายการที่ค่าไม่ใช่ 1.0 (ต่างจาก default ถึงจะต้องเรียก)
local active = {}
for index, hash in pairs(densityNatives) do
    local value = Config.Density and Config.Density[index]
    if value and value ~= 1.0 then
        active[#active + 1] = { hash = hash, value = value + 0.0 }
    end
end

-- ทุกค่าเป็น 1.0 (ค่าปกติของเกมทั้งหมด) -> ไม่ต้องมี loop เลย
if #active > 0 then
    CreateThread(function()
        while true do
            Wait(0)
            for i = 1, #active do
                Citizen.InvokeNative(active[i].hash, active[i].value)
            end
        end
    end)
end
