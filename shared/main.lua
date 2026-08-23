Shared = Shared or {}

-- ว่างตอนโหลดไฟล์เป็นเรื่องปกติ server อ่านอาชีพ/ไอเทมจาก DB ตอนบูตแล้ว sync ให้ client (docs guide/items-jobs)
Shared.Jobs = {}
Shared.Items = {}

-- รายชื่อสถานะร่างกายมาจาก Config.Status.Keys ที่เดียว ทุกไฟล์อ่านสองตัวนี้แทนการถือลิสต์ฮาร์ดโค้ดของตัวเอง
-- สร้างตอนโหลดได้เพราะไฟล์ใน config/ เป็น shared_script ชุดแรกใน fxmanifest จึงมาก่อนไฟล์นี้เสมอ
Shared.StatusKeys = {}   -- เรียงตามลำดับในคอนฟิก ใช้ตอนต้องวนให้ครบ
Shared.IsStatusKey = {}  -- ไวต์ลิสต์ ใช้ตอนต้องเช็คว่าคีย์ที่รับมาเป็นสถานะจริงไหม

do
    local configured = Config and Config.Status and Config.Status.Keys
    -- คอนฟิกเก่าที่ยังไม่มีคีย์นี้ต้องได้สี่ตัวเดิมไป ไม่ใช่ลิสต์ว่างที่ทำให้ระบบสถานะเงียบไปทั้งระบบ
    if type(configured) ~= 'table' or #configured == 0 then
        configured = { 'hunger', 'thirst', 'cleanliness', 'stress' }
    end

    for _, key in ipairs(configured) do
        key = tostring(key):lower()
        -- ชื่อซ้ำในลิสต์จะทำให้ทุกลูปวนคีย์นั้นสองรอบ ตัดทิ้งตั้งแต่ตอนสร้าง
        if key ~= '' and not Shared.IsStatusKey[key] then
            Shared.IsStatusKey[key] = true
            Shared.StatusKeys[#Shared.StatusKeys + 1] = key
        end
    end
end

--- ค่าเริ่มต้นของสถานะหนึ่งช่อง อ่านจาก PlayerDefaults ที่เดียว คีย์ใหม่ที่ลืมตั้งค่าจะได้ไม่เริ่มที่ 0 แล้วหิวตายทันที
---@param key string
---@return number
function Shared.StatusDefault(key)
    local defaults = Config and Config.Player and Config.Player.PlayerDefaults and Config.Player.PlayerDefaults.metadata
    return (defaults and tonumber(defaults[key])) or 100
end

local StringCharset = {}
local NumberCharset = {}

Shared.StarterItems = {
    bread = { amount = 5, item = 'bread' },
    water = { amount = 5, item = 'water' },
}

for i = 48, 57 do NumberCharset[#NumberCharset + 1] = string.char(i) end
for i = 65, 90 do StringCharset[#StringCharset + 1] = string.char(i) end
for i = 97, 122 do StringCharset[#StringCharset + 1] = string.char(i) end

function Shared.RandomStr(length)
    if length <= 0 then return '' end
    return Shared.RandomStr(length - 1) .. StringCharset[math.random(1, #StringCharset)]
end

function Shared.RandomInt(length)
    if length <= 0 then return '' end
    return Shared.RandomInt(length - 1) .. NumberCharset[math.random(1, #NumberCharset)]
end

function Shared.SplitStr(str, delimiter)
    local result = {}
    local from = 1
    local delim_from, delim_to = string.find(str, delimiter, from)
    while delim_from do
        result[#result + 1] = string.sub(str, from, delim_from - 1)
        from = delim_to + 1
        delim_from, delim_to = string.find(str, delimiter, from)
    end
    result[#result + 1] = string.sub(str, from)
    return result
end

function Shared.Trim(value)
    if not value then return nil end
    return (string.gsub(value, '^%s*(.-)%s*$', '%1'))
end

function Shared.FirstToUpper(value)
    if not value then return nil end
    return (value:gsub("^%l", string.upper))
end

function Shared.Round(value, numDecimalPlaces)
    if not numDecimalPlaces then return math.floor(value + 0.5) end
    local power = 10 ^ numDecimalPlaces
    return math.floor((value * power) + 0.5) / (power)
end

function Shared.ChangeVehicleExtra(vehicle, extra, enable)
    if DoesExtraExist(vehicle, extra) then
        if enable then
            SetVehicleExtra(vehicle, extra, false)
            if not IsVehicleExtraTurnedOn(vehicle, extra) then
                Shared.ChangeVehicleExtra(vehicle, extra, enable)
            end
        else
            SetVehicleExtra(vehicle, extra, true)
            if IsVehicleExtraTurnedOn(vehicle, extra) then
                Shared.ChangeVehicleExtra(vehicle, extra, enable)
            end
        end
    end
end

function Shared.SetDefaultVehicleExtras(vehicle, config)
    -- Clear Extras
    for i = 1, 20 do
        if DoesExtraExist(vehicle, i) then
            SetVehicleExtra(vehicle, i, 1)
        end
    end

    for id, enabled in pairs(config) do
        Shared.ChangeVehicleExtra(vehicle, tonumber(id), type(enabled) == 'boolean' and enabled or true)
    end
end

Shared.MaleNoGloves = {
    [0] = true,
    [1] = true,
    [2] = true,
    [3] = true,
    [4] = true,
    [5] = true,
    [6] = true,
    [7] = true,
    [8] = true,
    [9] = true,
    [10] = true,
    [11] = true,
    [12] = true,
    [13] = true,
    [14] = true,
    [15] = true,
    [18] = true,
    [26] = true,
    [52] = true,
    [53] = true,
    [54] = true,
    [55] = true,
    [56] = true,
    [57] = true,
    [58] = true,
    [59] = true,
    [60] = true,
    [61] = true,
    [62] = true,
    [112] = true,
    [113] = true,
    [114] = true,
    [118] = true,
    [125] = true,
    [132] = true
}

Shared.FemaleNoGloves = {
    [0] = true,
    [1] = true,
    [2] = true,
    [3] = true,
    [4] = true,
    [5] = true,
    [6] = true,
    [7] = true,
    [8] = true,
    [9] = true,
    [10] = true,
    [11] = true,
    [12] = true,
    [13] = true,
    [14] = true,
    [15] = true,
    [19] = true,
    [59] = true,
    [60] = true,
    [61] = true,
    [62] = true,
    [63] = true,
    [64] = true,
    [65] = true,
    [66] = true,
    [67] = true,
    [68] = true,
    [69] = true,
    [70] = true,
    [71] = true,
    [129] = true,
    [130] = true,
    [131] = true,
    [135] = true,
    [142] = true,
    [149] = true,
    [153] = true,
    [157] = true,
    [161] = true,
    [165] = true
}

exports('GetWeapons', function()
    return Shared.Weapons
end)
