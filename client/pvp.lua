local HexaCore = exports['hexa_core']:GetCoreObject()

CreateThread(function()
    local active = false
    local timer = 0
    local lastPeaceful = nil -- [perf-fix] track last-applied relationship/friendly-fire state
    while true do
        Wait(0) -- [perf-fix] keep frame polling only for the keybind reads

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

        if IsControlJustPressed(0, HexaCore.Shared.Keybinds['E']) then
            timer = 0
            active = true
            while timer < 200 do
                Wait(0)
                timer = timer + 1
                SetRelationshipBetweenGroups(1, 'PLAYER', 'PLAYER')
            end
            active = false
            lastPeaceful = false -- [perf-fix] force re-apply after forced relationship writes
        end

        if IsControlJustPressed(0, HexaCore.Shared.Keybinds['F']) then
            Wait(500)
            SetRelationshipBetweenGroups(1, 'PLAYER', 'PLAYER')
            active = false
            timer = 0
            lastPeaceful = false -- [perf-fix] force re-apply after forced relationship write
        end
    end
end)
