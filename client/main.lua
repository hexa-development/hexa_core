HexaCore = {}
HexaCore.PlayerData = {}
HexaCore.Config = Config
HexaCore.Shared = Shared
HexaCore.ClientCallbacks = {}
HexaCore.ServerCallbacks = {}

exports('GetCoreObject', function()
    return HexaCore
end)

-- To use this export in a script instead of manifest method
-- Just put this line of code below at the very top of the script
-- local HexaCore = exports['hexa_core']:GetCoreObject()
