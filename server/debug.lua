-- ตัวพิมพ์จริงย้ายไปอยู่ shared/log.lua หมดแล้ว ไฟล์นี้เหลือแค่ปลายทางของ log ที่ resource อื่นยิงเข้ามา

-- ทั้งเซิร์ฟยิง hexa_log:server:CreateLog อยู่ 23 จุดใน 4 resource แต่ไม่เคยมี resource ชื่อ hexa_log อยู่จริง
-- และไม่มีใครลงทะเบียนรับ event นี้เลย log ทั้งหมดจึงหายเงียบ ทั้งคนเข้าออก ลบตัวละคร และแจ้งเตือน anticheat
-- รับเองตรงนี้เพื่อให้ 23 จุดเดิมเห็นผลทันทีโดยไม่ต้องแก้อะไร และส่งต่อ webhook ได้ถ้าตั้งค่าไว้
local LOG_COLOURS = {
    red = '^1', green = '^2', yellow = '^3', blue = '^4', white = '^7', default = '^7',
}

local function logConfig()
    return Core.Config and Core.Config.Log or nil
end

local function postToDiscord(category, title, message)
    local cfg = logConfig()
    local url = cfg and cfg.Webhooks and (cfg.Webhooks[category] or cfg.Webhooks.default)
    if type(url) ~= 'string' or url == '' then return end

    local payload = json.encode({
        username = 'hexa_core',
        embeds = { { title = title, description = message, color = 0xB45309 } },
    })
    PerformHttpRequest(url, function(status)
        -- ยิงไม่ผ่านห้ามเงียบ ไม่งั้นกลับไปเป็นปัญหาเดิมที่ log หายโดยไม่มีใครรู้
        if status ~= 200 and status ~= 204 then
            Hexa.WarnOnce('webhook:' .. category, 'discord webhook for %s returned %s', category, tostring(status))
        end
    end, 'POST', payload, { ['Content-Type'] = 'application/json' })
end

AddEventHandler('hexa_log:server:CreateLog', function(category, title, colour, message)
    local cfg = logConfig()
    if cfg and cfg.Enabled == false then return end

    category = tostring(category or 'general')
    title = tostring(title or '')
    message = tostring(message or '')

    local tint = LOG_COLOURS[colour] or LOG_COLOURS.default
    print(('%s [%s]^7 %s%s^7 %s'):format('^5[hexa_core]', category:upper(), tint, title, message))

    postToDiscord(category, title, message)
end)

-- เดิมมี HexaCore:DebugSomething เป็นทางอ้อมให้ Debug เรียกผ่าน ตอนนี้ Core.DumpTable พิมพ์ตรงได้เลย
-- คงตัวรับไว้เพราะยังมีโค้ดเก่ายิงเข้ามา และคงกันไม่ให้เป็น net event เหมือนเดิมเพื่อไม่ให้ client ยิงถล่มคอนโซล
AddEventHandler('HexaCore:DebugSomething', function(tbl, indent, resource)
    Hexa.Log('^6[DUMP]^7 %s', tostring(resource or GetInvokingResource() or 'unknown resource'))
    Core.DumpTable(tbl, indent)
end)
