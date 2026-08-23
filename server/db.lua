-- ชั้นคุยฐานข้อมูลของ hexa_core เรียก oxmysql ผ่าน exports ตรง ๆ ไม่ include @oxmysql/lib/MySQL.lua แล้ว
-- ต้องเป็นไฟล์แรกของ server_scripts เพราะ installer.lua ใช้ตั้งแต่บูต และห้ามพึ่ง Core ที่ main.lua ยังไม่ได้สร้างตอนนี้

Db = Db or {}

local resourceName = GetCurrentResourceName()
local oxmysql = exports.oxmysql
local Await = Citizen.Await
local CreateThreadNow = Citizen.CreateThreadNow

-- บอก oxmysql ให้ส่ง error กลับทาง callback ตัวที่สอง แทนการโยนข้ามเธรดที่ไม่มีใครรับ
local RETURN_ERRORS = true

-- export ของ oxmysql รับ self เป็นอาร์กิวเมนต์แรกเสมอ ส่ง nil ไปเหมือนที่ lib ของมันเองทำ
local function fire(method, query, parameters, cb)
    return oxmysql[method](nil, query, parameters, cb, resourceName, RETURN_ERRORS)
end

-- ไม่มี export ตัวไหนคืนค่าตรงให้ Lua ต้องห่อ callback เป็น promise แล้ว Await เอง เหมือนที่ lib ทำ
local function wait(method, query, parameters)
    local p = promise.new()
    fire(method, query, parameters, function(result, err)
        if err then return p:reject(err) end
        p:resolve(result)
    end)
    return Await(p)
end

-- ==================== แบบรอคำตอบ ====================
-- เรียกได้เฉพาะในเธรดที่ Wait ได้ error จาก DB จะถูกโยนออกมา ผู้เรียกที่ยอมพังไม่ได้ต้องครอบ pcall เอง

function Db.Query(query, parameters) return wait('query', query, parameters) end
function Db.Single(query, parameters) return wait('single', query, parameters) end
function Db.Scalar(query, parameters) return wait('scalar', query, parameters) end
function Db.Prepare(query, parameters) return wait('prepare', query, parameters) end
function Db.Insert(query, parameters) return wait('insert', query, parameters) end
function Db.Update(query, parameters) return wait('update', query, parameters) end
function Db.Transaction(queries) return wait('transaction', queries, nil) end

-- ==================== แบบยิงแล้วเดินต่อ ====================
-- cb รับ (result, error) ตามที่ oxmysql ส่งมา ใช้กับคิวเซฟที่ห้ามหยุดเธรดรอ DB

function Db.QueryAsync(query, parameters, cb) return fire('query', query, parameters, cb) end
function Db.InsertAsync(query, parameters, cb) return fire('insert', query, parameters, cb) end
function Db.UpdateAsync(query, parameters, cb) return fire('update', query, parameters, cb) end
function Db.TransactionAsync(queries, cb) return fire('transaction', queries, nil, cb) end

-- ==================== ตัวรอให้ DB พร้อม ====================

-- บล็อกจน oxmysql เริ่มและต่อฐานข้อมูลติด ต้องเรียกในเธรดที่ Wait ได้
function Db.AwaitReady()
    while GetResourceState('oxmysql') ~= 'started' do Wait(50) end
    oxmysql.awaitConnection()
    return true
end

-- เปิดเธรดใหม่ให้เอง ผู้เรียกจึงไม่ถูกบล็อกตอนโหลดไฟล์ (แทน MySQL.ready เดิม)
function Db.Ready(cb)
    CreateThreadNow(function()
        Db.AwaitReady()
        if cb then cb() end
    end)
end
