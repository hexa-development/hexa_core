local function tPrint(tbl, indent)
    indent = indent or 0
    -- กันตารางซ้อนลึกไม่จำกัด: พิมพ์ทีละบรรทัดลงคอนโซลบล็อกเธรดหลัก
    if indent > 6 then return print(string.rep('  ', indent) .. '...') end
    if type(tbl) == 'table' then
        for k, v in pairs(tbl) do
            local tblType = type(v)
            local formatting = ('%s ^3%s:^0'):format(string.rep('  ', indent), k)

            if tblType == 'table' then
                print(formatting)
                tPrint(v, indent + 1)
            elseif tblType == 'boolean' then
                print(('%s^1 %s ^0'):format(formatting, v))
            elseif tblType == 'function' then
                print(('%s^9 %s ^0'):format(formatting, v))
            elseif tblType == 'number' then
                print(('%s^5 %s ^0'):format(formatting, v))
            elseif tblType == 'string' then
                print(("%s ^2'%s' ^0"):format(formatting, v))
            else
                print(('%s^2 %s ^0'):format(formatting, v))
            end
        end
    else
        print(('%s ^0%s'):format(string.rep('  ', indent), tbl))
    end
end

-- AddEventHandler ไม่ใช่ RegisterServerEvent: client ยิงเข้ามาไม่ได้อีกแล้ว
-- (เดิมใครก็ยิงตารางซ้อนลึกๆ รัวๆ มาบล็อกเธรดหลัก + ปลอมชื่อ resource ในล็อกได้)
-- HexaCore.Debug ด้านล่างเรียกด้วย TriggerEvent ในเซิร์ฟเวอร์ ไม่ต้องจด net event
AddEventHandler('HexaCore:DebugSomething', function(tbl, indent, resource)
    print(('\x1b[4m\x1b[36m[ %s : DEBUG]\x1b[0m'):format(resource))
    tPrint(tbl, indent)
    print('\x1b[4m\x1b[36m[ END DEBUG ]\x1b[0m')
end)

function HexaCore.Debug(tbl, indent)
    TriggerEvent('HexaCore:DebugSomething', tbl, indent, GetInvokingResource() or 'qb-core')
end

function HexaCore.ShowError(resource, msg)
    print('\x1b[31m[' .. resource .. ':ERROR]\x1b[0m ' .. msg)
end

function HexaCore.ShowSuccess(resource, msg)
    print('\x1b[32m[' .. resource .. ':LOG]\x1b[0m ' .. msg)
end
