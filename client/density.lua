-- ควบคุมความหนาแน่น NPC / สัตว์ / ยานพาหนะ (Config.Density)

-- natives ชุดนี้เป็น ThisFrame รีเซ็ตเป็น 1.0 ทุกเฟรม จึงต้องยิงทุกเฟรม แต่ข้ามค่า 1.0 และไม่สร้าง thread ถ้าไม่มีค่าไหนต่าง

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
