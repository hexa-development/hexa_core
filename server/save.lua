-- รอบบันทึกข้อมูลผู้เล่นลงฐานข้อมูล
-- เดิมรอบเวลาเดินอยู่ที่ client (client/loops.lua ยิง HexaCore:UpdatePlayer เข้ามา) ซึ่งแปลว่าไม่ยิงก็ไม่เซฟ
-- ตอนนี้ server เป็นเจ้าของรอบเวลาทั้งหมด client ไม่มีสิทธิ์สั่งเซฟอีกแล้ว

local function saveConfig()
    return Core.Config and Core.Config.Save or nil
end

--- เก็บรายชื่อคนที่ข้อมูลเปลี่ยนจริงตั้งแต่รอบก่อน คนที่ยืนเฉย ๆ ไม่ต้องเขียนซ้ำ
local function collectDirty()
    local pending = {}
    for src, Player in pairs(Core.Players or {}) do
        if Player.Dirty then pending[#pending + 1] = src end
    end
    return pending
end

--- เซฟทุกคนที่ค้างอยู่ โดยเกลี่ยเวลาเขียนให้กระจาย ไม่ให้ 48 คนยิง MySQL พร้อมกันในติกเดียว
local function sweep()
    local cfg = saveConfig()
    local pending = collectDirty()
    local total = #pending
    if total == 0 then return end

    local spreadMs = math.max(0, (tonumber(cfg and cfg.SpreadSeconds) or 0) * 1000)
    local step = total > 1 and math.floor(spreadMs / total) or 0

    for index = 1, total do
        local src = pending[index]
        SetTimeout(step * (index - 1), function()
            -- ผู้เล่นอาจหลุดไปแล้วระหว่างรอคิว ต้องหยิบใหม่ทุกครั้งไม่ใช้ตัวที่ปิดทับไว้
            local Player = Core.Players[src]
            if Player then Player.Save() end
        end)
    end

    Hexa.Debug('autosave queued %d dirty player(s) across %dms', total, spreadMs)
end

CreateThread(function()
    while true do
        local cfg = saveConfig()
        local minutes = tonumber(cfg and cfg.Interval) or 45
        if minutes < 1 then minutes = 1 end

        Wait(minutes * 60000)
        sweep()
    end
end)

--- เซฟทุกคนเดี๋ยวนี้แบบไม่เกลี่ยเวลา ใช้ตอนกำลังจะปิด ซึ่งไม่มีเวลาให้รอคิว
function Core.SaveAllPlayers()
    local saved = 0
    for _, Player in pairs(Core.Players or {}) do
        Player.Save()
        saved = saved + 1
    end
    return saved
end

-- resource กำลังหยุดหรือเซิร์ฟกำลังปิด เขียนทุกคนลงให้ครบก่อน
-- เดิมจุดนี้เรียก Core.SavePlayer(src) ตรง ๆ ซึ่งข้าม PullStateBags ทำให้ค่าหิว กระหาย สะอาด เครียด
-- ที่ค้างอยู่ใน statebag หายทุกครั้งที่รีสตาร์ท ต้องเรียกผ่าน Player.Save() เท่านั้น
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if saveConfig() and saveConfig().OnResourceStop == false then return end
    Hexa.Log('resource stopping - saving %d player(s)', Core.SaveAllPlayers())
end)
