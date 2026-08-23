-- Automatic database installer

-- รันตอนบูตทุกครั้งได้เพราะ DDL เป็น idempotent, error "already exists" ถูกข้าม, ตัวที่ล้มเหตุอื่นถูก log แล้วเดินต่อจนครบ

local resourceName = GetCurrentResourceName()
local schemaReady = false

-- บล็อกเธรดที่เรียกจนกว่า install.sql จะถูกใช้เสร็จหรือหมดเวลา คืน true เมื่อ schema พร้อม
function AwaitSchemaReady(timeoutMs)
    local waited = 0
    local timeout = timeoutMs or 15000
    while not schemaReady and waited < timeout do
        Wait(50)
        waited = waited + 50
    end
    return schemaReady
end

-- resource อื่นต้องเรียกก่อน SELECT ตารางใด ๆ (install.sql คือ schema เดียวของสแตก) และเรียกใน CreateThread เพราะบล็อก
exports('AwaitSchemaReady', AwaitSchemaReady)

local function printLog(kind, message)
    local color = (kind == 'success' and '^2') or (kind == 'warning' and '^3') or '^1'
    print(('[%s]%s %s^7'):format(resourceName, color, message))
end

-- error ที่แปลว่า "migration นี้รันไปแล้ว" เทียบแบบไม่สนตัวพิมพ์ใหญ่เล็ก ให้ครอบทั้ง MySQL 8 และ MariaDB
local benignPatterns = {
    'duplicate column name',    -- 1060: ADD COLUMN that is already there
    'duplicate key name',       -- 1061: ADD INDEX / ADD UNIQUE KEY already there
    'already exists',           -- 1050 table, 1061 index (MariaDB wording)
    'check that column/key exists', -- 1091: DROP COLUMN/KEY ของที่ไม่มีแล้ว (ข้อความแบบเก่า)
    'check that it exists',     -- 1091: DROP INDEX ของที่ไม่มีแล้ว (ข้อความจริงของ MySQL 8)
    "can't drop",               -- ครอบคลุมทุกกรณี DROP ของที่ไม่มีอยู่ (index/key/column)
    'needs to be dropped',      -- ลบ index ที่ถูกใช้เป็น foreign key อยู่ - ข้ามไปได้
}

local function isBenign(err)
    local message = tostring(err):lower()
    for _, pattern in ipairs(benignPatterns) do
        if message:find(pattern, 1, true) then
            return true
        end
    end
    return false
end

-- ต้องตัดคอมเมนต์ก่อนแยกด้วย ';' ไม่งั้น ';' ในคอมเมนต์จะตัดคำสั่งกลางคัน แล้วข้อความที่เหลือจะติดไปกับคำสั่งถัดไป
local function stripComments(sql)
    local kept = {}
    for line in (sql .. '\n'):gmatch('(.-)\n') do
        if not line:match('^%s*%-%-') then
            kept[#kept + 1] = line
        end
    end
    return table.concat(kept, '\n')
end

-- แยกสคริปต์ SQL เป็นคำสั่งทีละอันที่ ';' และทิ้งคำสั่งว่าง
local function splitStatements(sql)
    local statements = {}
    for statement in (stripComments(sql) .. ';'):gmatch('(.-);') do
        local trimmed = statement:gsub('^%s+', ''):gsub('%s+$', '')
        if trimmed ~= '' then
            statements[#statements + 1] = trimmed
        end
    end
    return statements
end

-- เดิมอยู่ใน install.sql แล้วถูกรันทุกบูต ซึ่ง MySQL ไม่ error แต่ rebuild ตาราง users ทั้งใบทุกครั้ง เวลาบูตจึงโตตามจำนวนตัวละครและกินโควตา AwaitSchemaReady
local USERS_PK_MIGRATION = 'ALTER TABLE `users` DROP PRIMARY KEY, ADD PRIMARY KEY (`citizenid`)'

-- ถามสคีมาว่า PK ของ users เป็น citizenid คอลัมน์เดียวหรือยัง จะได้ข้าม ALTER ที่ไม่มีอะไรให้ทำ
local function usersPrimaryKeyIsCitizenId()
    local rows = Db.Query(
        "SELECT `COLUMN_NAME` AS `col` FROM `information_schema`.`STATISTICS`" ..
        " WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'users' AND `INDEX_NAME` = 'PRIMARY'" ..
        " ORDER BY `SEQ_IN_INDEX`"
    ) or {}
    -- ไม่มีแถวเลย = ยังไม่มีตาราง users (หรือไม่มี PK) ปล่อยให้ CREATE TABLE ใน install.sql สร้าง PK ที่ถูกต้องเอง อย่าไป DROP ของที่ไม่มีอยู่
    if #rows == 0 then return true end
    return #rows == 1 and tostring(rows[1].col):lower() == 'citizenid'
end

-- คืนจำนวน statement ที่ล้มเหลว เพื่อให้นับรวมกับลูปหลักได้
local function migrateUsersPrimaryKey()
    local ok, isMigrated = pcall(usersPrimaryKeyIsCitizenId)
    if not ok then
        -- อ่านสคีมาไม่ได้ก็ข้ามไปเลย ดีกว่าเดาแล้วไป rebuild ตารางทิ้ง
        printLog('warning', ('Could not read the users primary key - skipping the citizenid migration: %s'):format(isMigrated))
        return 0
    end
    if isMigrated then return 0 end

    printLog('warning', 'Migrating the users primary key to citizenid - this rebuilds the table once and may take a while.')
    local done, err = pcall(function()
        Db.Query(USERS_PK_MIGRATION)
    end)
    if not done and not isBenign(err) then
        printLog('error', ('Auto-install statement failed: %s'):format(err))
        printLog('error', ('  statement: %s'):format(USERS_PK_MIGRATION))
        return 1
    end
    return 0
end

local function runInstall()
    local sql = LoadResourceFile(resourceName, 'install.sql')
    if not sql or sql == '' then
        printLog('error', 'install.sql not found or empty - skipping auto-install.')
        return
    end

    local statements = splitStatements(sql)
    if #statements == 0 then
        printLog('warning', 'install.sql contained no runnable statements.')
        return
    end

    -- ต้องมาก่อนลูป เพื่อให้ลำดับเทียบเท่าตอนที่ ALTER ตัวนี้ยังเป็น statement ที่ 2 ของ install.sql
    local failed = migrateUsersPrimaryKey()
    for _, statement in ipairs(statements) do
        local ok, err = pcall(function()
            Db.Query(statement)
        end)
        if not ok and not isBenign(err) then
            failed = failed + 1
            printLog('error', ('Auto-install statement failed: %s'):format(err))
            printLog('error', ('  statement: %s'):format(statement:gsub('%s+', ' ')))
        end
    end

    if failed > 0 then
        printLog('warning', ('Database auto-install finished with %d failed statement(s).'):format(failed))
    else
        printLog('success', 'Database schema verified/installed.')
    end
end

Db.Ready(function()
    runInstall()
    -- ปล่อยคนที่รออยู่เสมอแม้บางคำสั่งพัง เพราะแฟล็กค้างจะบล็อกการเข้าเซิร์ฟเวอร์ตลอดไป
    schemaReady = true
end)
