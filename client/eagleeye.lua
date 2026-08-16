local HexaCore = exports['hexa_core']:GetCoreObject()

-- เปิด/ปิดความสามารถ Eagle Eye (Dead Eye ของสัตว์ - มองเห็นรอยเท้า/กลิ่น)
local function EnableEagleEye(enable)
    Citizen.InvokeNative(0xA63FCAD3A6FEC6D2, PlayerId(), enable)
end

-- ตรวจว่าอาชีพนี้ใช้ Eagle Eye ได้หรือไม่
local function ShouldEnableEagleEye(job)
    if Config.EagleEye.everyone.enabled then
        return true
    end

    return (job and Config.EagleEye[job] and Config.EagleEye[job].enabled) == true
end

local function HandleEagleEyeAccess()
    local playerData = HexaCore.Functions.GetPlayerData()
    local playerJob = playerData and playerData.job and playerData.job.name
    EnableEagleEye(ShouldEnableEagleEye(playerJob))
end

RegisterNetEvent('HexaCore:Client:OnPlayerLoaded', function()
    HandleEagleEyeAccess()
end)

RegisterNetEvent('HexaCore:Client:OnJobUpdate', function()
    HandleEagleEyeAccess()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    HandleEagleEyeAccess()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    EnableEagleEye(false)
end)
