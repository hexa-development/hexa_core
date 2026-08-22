-- ทุก print ของ hexa_core ผ่านสี่ตัวนี้ที่เดียว เพื่อให้ปิด/เปิดจากคอนฟิกได้จุดเดียวและคำนำหน้าคงรูปแบบเดียวกัน
-- ข้อความ log เป็นอังกฤษล้วนทั้งระบบ คอนโซลเซิร์ฟเวอร์บางตัวแสดงตัวไทยเพี้ยนและคนไล่ log ต้องกวาดตาเร็ว
-- (คอมเมนต์ในโค้ดกับข้อความที่ผู้เล่นเห็นยังเป็นไทยตามเดิม)
-- ใช้โค้ดสีของ FiveM (^N) ล้วน ไม่ใช้ ANSI escape เพราะคอนโซล FXServer แสดงผลไม่เหมือนกัน

Hexa = Hexa or {}

local PREFIX = '^5[hexa_core]^7'

local function stamp(level)
    if not level then return PREFIX end
    return ('%s %s'):format(PREFIX, level)
end

local function compose(level, fmt, ...)
    local body = select('#', ...) > 0 and fmt:format(...) or tostring(fmt)
    return ('%s %s'):format(stamp(level), body)
end

function Hexa.Log(fmt, ...)
    print(compose(nil, fmt, ...))
end

function Hexa.Warn(fmt, ...)
    print(compose('^3[WARN]^7', fmt, ...))
end

function Hexa.Error(fmt, ...)
    print(compose('^1[ERROR]^7', fmt, ...))
end

-- Debug ถูกเรียกถี่กว่าเพื่อน จึงเช็กสวิตช์ก่อนแล้วค่อยฟอร์แมตสตริง ไม่งั้นจ่ายค่าสร้างสตริงทิ้งทุกครั้งแม้ปิดอยู่
function Hexa.Debug(fmt, ...)
    if not (Config and Config.Debug) then return end
    print(compose('^6[DEBUG]^7', fmt, ...))
end

-- เตือนเรื่องเดิมซ้ำ ๆ ไม่มีประโยชน์ ตัวนี้พิมพ์ครั้งเดียวต่อคีย์แล้วเงียบไปตลอดอายุ resource
local warnedOnce = {}

function Hexa.WarnOnce(key, fmt, ...)
    if warnedOnce[key] then return end
    warnedOnce[key] = true
    Hexa.Warn(fmt, ...)
end

-- พิมพ์ตารางลงคอนโซล แยกจาก Debug เพราะเดิมชื่อ Debug ทำสองหน้าที่คนละอย่างในสองฝั่ง
-- ตัดความลึกไว้เพราะการพิมพ์บล็อกเธรดหลัก ตารางที่วนหาตัวเองจะลากคอนโซลค้างทั้งเซิร์ฟ
local MAX_DEPTH = 6

function Hexa.DumpTable(value, indent)
    indent = indent or 0
    local pad = string.rep('  ', indent)

    if type(value) ~= 'table' then
        return print(('%s^0%s'):format(pad, tostring(value)))
    end

    if indent > MAX_DEPTH then
        return print(pad .. '...')
    end

    for key, item in pairs(value) do
        local label = ('%s^3%s:^0'):format(pad, tostring(key))
        local kind = type(item)
        if kind == 'table' then
            print(label)
            Hexa.DumpTable(item, indent + 1)
        elseif kind == 'string' then
            print(("%s ^2'%s'^0"):format(label, item))
        elseif kind == 'number' then
            print(('%s ^5%s^0'):format(label, item))
        elseif kind == 'boolean' then
            print(('%s ^1%s^0'):format(label, tostring(item)))
        else
            print(('%s ^9%s^0'):format(label, tostring(item)))
        end
    end
end

-- สองตัวนี้เป็นรูปแบบเดิมที่โค้ดในเซิร์ฟใช้อยู่ ยกมาไว้บนตัวพิมพ์ชุดเดียวกันเพื่อให้คำนำหน้าไม่แตกแถว
-- เดิมมีเฉพาะฝั่ง server และใช้ ANSI escape ตอนนี้มีครบสองฝั่งและใช้โค้ดสีของ FiveM เหมือนที่อื่น
function Hexa.ShowError(resource, msg)
    print(('^1[%s:ERROR]^7 %s'):format(tostring(resource), tostring(msg)))
end

function Hexa.ShowSuccess(resource, msg)
    print(('^2[%s:SUCCESS]^7 %s'):format(tostring(resource), tostring(msg)))
end
