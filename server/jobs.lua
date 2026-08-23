-- ตาราง jobs + job_grades ใน DB คือแหล่งอาชีพแหล่งเดียว (Shared.Jobs เริ่มว่าง) แก้แล้วต้อง restart ดู docs guide/items-jobs

local function loadJobsFromDatabase()
    -- ต้องห่อ pcall คิวรีล้มแล้วเธรดตายเงียบ = Shared.Jobs ค้างว่าง ทุกคนตกงานโดยไม่มีอะไรฟ้อง
    local ok, jobRows = pcall(MySQL.query.await, 'SELECT * FROM jobs')
    if not ok then
        Hexa.Error('could not read the jobs table - every player will load as unemployed. %s', tostring(jobRows))
        return
    end
    if not jobRows or #jobRows == 0 then
        Hexa.Warn('the jobs table is empty - no jobs are registered. check that install.sql seeded correctly')
        return
    end

    local gradesOk, gradeRows = pcall(MySQL.query.await, 'SELECT * FROM job_grades')
    if not gradesOk then
        Hexa.Error('could not read job_grades - every job will load with no grades. %s', tostring(gradeRows))
        gradeRows = {}
    end
    gradeRows = gradeRows or {}

    -- สร้างโครงสร้างเดียวกับ Shared.Jobs เดิม โค้ดส่วนอื่นไม่ต้องแก้
    local jobs = {}
    for _, row in ipairs(jobRows) do
        jobs[row.name] = {
            name = row.name,
            label = row.label or row.name,
            type = row.type,
            defaultDuty = row.default_duty == 1,
            offDutyPay = row.offduty_pay == 1,
            whitelisted = row.whitelisted == 1,
            grades = {},
        }
    end

    for _, row in ipairs(gradeRows) do
        local job = jobs[row.job_name]
        if job then
            job.grades[tostring(row.grade)] = {
                name = row.name or row.label or tostring(row.grade),
                payment = tonumber(row.salary) or 0,
                isboss = row.isboss == 1,
            }
        end
    end

    -- อาชีพที่ไม่มี grade เลย ใส่ grade 0 กันโค้ดส่วนอื่นพัง
    for _, job in pairs(jobs) do
        if not next(job.grades) then
            job.grades['0'] = { name = job.label, payment = 0 }
        end
    end

    -- Shared เป็น reference เดียวกับ Core.Shared จึงอัปเดตทั้งคู่พร้อมกัน
    Shared.Jobs = jobs

    local count = 0
    for _ in pairs(jobs) do count = count + 1 end
    Hexa.Log('loaded %d job(s) from the database', count)

    -- sync ให้ client ที่ออนไลน์อยู่ (กรณี restart กลางเกม) + refresh core object
    TriggerClientEvent('HexaCore:Client:OnSharedUpdateMultiple', -1, 'Jobs', jobs)
    TriggerEvent('HexaCore:Server:UpdateObject')
end

MySQL.ready(function()
    -- รอ installer สร้าง/seed ตาราง jobs ให้เสร็จก่อนค่อยโหลด
    if AwaitSchemaReady then AwaitSchemaReady(15000) end
    loadJobsFromDatabase()
end)
