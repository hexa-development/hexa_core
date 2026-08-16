-- ============================================================
-- Automatic database installer
-- ============================================================
-- Runs install.sql once the DB connection is ready, so the framework's base
-- tables (users, jobs, job_grades, items) are
-- created without a manual import step.
--
-- Safe to run on every boot: install.sql only contains idempotent DDL
-- (CREATE TABLE IF NOT EXISTS) plus ALTER statements whose "already exists"
-- errors are treated as benign and skipped.
--
-- A statement that fails for any other reason is logged and the installer
-- continues with the remaining statements, so one bad statement cannot leave
-- the rest of the schema uncreated.
--
-- Other server scripts in this resource can call AwaitSchemaReady(timeoutMs)
-- to block until the schema has been applied (used by server/events.lua so
-- its players-column check does not race table creation on a fresh database).

local resourceName = GetCurrentResourceName()
local schemaReady = false

-- Blocks the calling thread until install.sql has been applied (or the
-- timeout elapses). Returns true once the schema is ready.
function AwaitSchemaReady(timeoutMs)
    local waited = 0
    local timeout = timeoutMs or 15000
    while not schemaReady and waited < timeout do
        Wait(50)
        waited = waited + 50
    end
    return schemaReady
end

-- Same wait, for other resources. install.sql here is the ONLY schema in the
-- stack (hexa_inventory has no installer of its own), so anything that queries
-- users_vault / item_drops / users must call this first, or its first SELECT can
-- race the CREATE TABLE on a fresh database.
--
--   exports['hexa_core']:AwaitSchemaReady(15000)
--
-- Blocks the calling thread, so call it inside a CreateThread.
exports('AwaitSchemaReady', AwaitSchemaReady)

local function printLog(kind, message)
    local color = (kind == 'success' and '^2') or (kind == 'warning' and '^3') or '^1'
    print(('[%s]%s %s^7'):format(resourceName, color, message))
end

-- Errors that just mean "this migration already ran". Matched case-insensitively
-- against the driver message so it works on both MySQL 8 and MariaDB.
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

-- Drop whole-line '--' comments. This MUST happen before splitting on ';',
-- not after: a semicolon inside a comment would otherwise end a statement
-- early, and the prose following it on the same line has no leading '--' of
-- its own, so it would survive the strip and be prepended to the next
-- statement as garbage.
local function stripComments(sql)
    local kept = {}
    for line in (sql .. '\n'):gmatch('(.-)\n') do
        if not line:match('^%s*%-%-') then
            kept[#kept + 1] = line
        end
    end
    return table.concat(kept, '\n')
end

-- Split a SQL script into individual statements on ';' boundaries,
-- discarding blank statements.
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

    local failed = 0
    for _, statement in ipairs(statements) do
        local ok, err = pcall(function()
            MySQL.query.await(statement)
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

MySQL.ready(function()
    runInstall()
    -- Always release waiters, even if some statements failed - a stuck flag
    -- would block player connections forever, which is worse than one more
    -- logged SQL error.
    schemaReady = true
end)
