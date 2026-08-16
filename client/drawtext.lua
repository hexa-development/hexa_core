local positions = {
    left = 'left-center',
    right = 'right-center',
    top = 'top-center'
}

local positionCoords = {
    ['left-center'] = { x = 0.08, y = 0.5 },
    ['right-center'] = { x = 0.92, y = 0.5 },
    ['top-center'] = { x = 0.5, y = 0.05 }
}

local currentText = nil
local currentPosition = 'right-center'
local drawing = false

local function resolvePos(pos)
    return positions[pos] or pos or 'right-center'
end

local function startDrawLoop()
    if drawing then return end
    drawing = true
    CreateThread(function()
        while currentText do
            local pos = positionCoords[currentPosition] or positionCoords['right-center']
            local str = CreateVarString(10, 'LITERAL_STRING', currentText)
            SetTextScale(0.4, 0.4)
            SetTextColor(255, 255, 255, 255)
            SetTextCentre(true)
            SetTextDropshadow(1, 0, 0, 0, 200)
            DisplayText(str, pos.x, pos.y)
            Wait(0)
        end
        drawing = false
    end)
end

local function showText(text, pos)
    currentText = text
    currentPosition = resolvePos(pos)
    startDrawLoop()
end

local function updateText(text, pos)
    showText(text, pos)
end

local function hideText()
    currentText = nil
end

local function keyPressed()
    currentText = nil
end

RegisterNetEvent('hexa_core:client:DrawText', function(text, pos)
    showText(text, pos)
end)

RegisterNetEvent('hexa_core:client:ChangeText', function(text, pos)
    updateText(text, pos)
end)

RegisterNetEvent('hexa_core:client:HideText', function()
    hideText()
end)

RegisterNetEvent('hexa_core:client:KeyPressed', function()
    keyPressed()
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        currentText = nil
    end
end)

exports('DrawText', showText)
exports('ChangeText', updateText)
exports('HideText', hideText)
exports('KeyPressed', keyPressed)
