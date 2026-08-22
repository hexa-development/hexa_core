-- print ทุกตัวผ่านที่เดียว ข้อความ log เป็นอังกฤษล้วน ใช้โค้ดสี ^N ของ FiveM ไม่ใช่ ANSI เพราะคอนโซล FXServer แสดงไม่เหมือนกัน

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

-- ต้องตัดความลึกเพราะการพิมพ์บล็อกเธรดหลัก ตารางที่วนหาตัวเองจะลากคอนโซลค้างทั้งเซิร์ฟ
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

-- เดิมสองตัวนี้มีแค่ฝั่ง server และใช้ ANSI ยกมาไว้ชุดเดียวกันให้มีครบสองฝั่งและคำนำหน้า/สีไม่แตกแถว
function Hexa.ShowError(resource, msg)
    print(('^1[%s:ERROR]^7 %s'):format(tostring(resource), tostring(msg)))
end

function Hexa.ShowSuccess(resource, msg)
    print(('^2[%s:SUCCESS]^7 %s'):format(tostring(resource), tostring(msg)))
end
