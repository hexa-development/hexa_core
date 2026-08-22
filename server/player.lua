HexaCore.Players = {}
HexaCore.Player = {}

-- โหลดข้อมูลผู้เล่นตอน login หรือเติมค่าเริ่มต้น แก้ตรงนี้ผิดพังทั้งระบบ (docs guide/player-object)

local resourceName = GetCurrentResourceName()

-- ตัวแปลงแถว users (สไตล์ ESX) กับ PlayerData: DB เก็บคอลัมน์แยกแต่ในเกมใช้โครงเดิม โค้ดส่วนอื่นจึงไม่ต้องแก้

-- แถว users -> PlayerData (ช่องที่ขาดจะถูกเติมโดย applyDefaults ใน CheckPlayerData)
local function UserRowToPlayerData(row)
    local metadata = (row.metadata and json.decode(row.metadata)) or {}
    return {
        citizenid = row.citizenid,
        cid = 1,
        license = row.identifier,
        money = row.accounts and json.decode(row.accounts) or nil,
        charinfo = {
            firstname = row.firstname,
            lastname = row.lastname,
            birthdate = row.dateofbirth,
            gender = (row.sex == 'f') and 1 or 0,
            -- nationality/account ไม่มีคอลัมน์ใน users จึงฝากไว้ใน metadata ตอนเซฟ
            nationality = metadata.nationality,
            account = metadata.account,
        },
        -- ส่งแค่ name + level แล้ว CheckPlayerData จะเติม label/payment จาก Shared.Jobs เอง
        job = row.job and { name = row.job, grade = { level = tonumber(row.job_grade) or 0 } } or nil,
        position = row.position and json.decode(row.position) or nil,
        metadata = metadata,
        -- DB แยก inventory/loadout แต่รันไทม์รวมเป็นก้อนเดียว ห้ามเก็บสำเนา loadout เพราะ items คือแหล่งความจริงเดียว
        items = HexaCore.Storage.BuildSlots(row.inventory, row.loadout),
    }
end

-- PlayerData -> พารามิเตอร์สำหรับ INSERT/UPDATE ตาราง users
local function BuildUserRow(PlayerData, coords)
    local metadata = {}
    for k, v in pairs(PlayerData.metadata or {}) do metadata[k] = v end
    -- ฝาก nationality/account ของ charinfo ไว้ใน metadata (users ไม่มีคอลัมน์นี้)
    if PlayerData.charinfo then
        metadata.nationality = PlayerData.charinfo.nationality
        metadata.account = PlayerData.charinfo.account
    end
    return {
        identifier = PlayerData.license,
        citizenid = PlayerData.citizenid,
        accounts = json.encode(PlayerData.money or {}),
        job = (PlayerData.job and PlayerData.job.name) or 'unemployed',
        job_grade = (PlayerData.job and PlayerData.job.grade and PlayerData.job.grade.level) or 0,
        firstname = PlayerData.charinfo and PlayerData.charinfo.firstname or nil,
        lastname = PlayerData.charinfo and PlayerData.charinfo.lastname or nil,
        dateofbirth = PlayerData.charinfo and PlayerData.charinfo.birthdate or nil,
        sex = (PlayerData.charinfo and PlayerData.charinfo.gender == 1) and 'f' or 'm',
        position = json.encode(coords or PlayerData.position or HexaCore.Config.DefaultSpawn),
        -- ต้องใช้ codec ตัวเดียวกับ hexa_inventory:SaveInventory ไม่งั้นฟอร์แมตคนละแบบ ใครเซฟทีหลังทับของอีกฝั่งทิ้ง
        inventory = json.encode(HexaCore.Storage.EncodeInventory(PlayerData.items)),
        loadout = json.encode(HexaCore.Storage.EncodeLoadout(PlayerData.items)),
        metadata = json.encode(metadata),
        -- คอลัมน์ status แบบย่อสไตล์ ESX (เผื่อเครื่องมือภายนอกอ่าน)
        status = json.encode({
            hunger = metadata.hunger,
            thirst = metadata.thirst,
            cleanliness = metadata.cleanliness,
            stress = metadata.stress,
        }),
        is_dead = metadata.isdead and 1 or 0,
    }
end

local USERS_UPSERT = 'INSERT INTO users (identifier, citizenid, accounts, job, job_grade, firstname, lastname, dateofbirth, sex, position, inventory, loadout, metadata, status, is_dead) VALUES (:identifier, :citizenid, :accounts, :job, :job_grade, :firstname, :lastname, :dateofbirth, :sex, :position, :inventory, :loadout, :metadata, :status, :is_dead) ON DUPLICATE KEY UPDATE accounts = :accounts, job = :job, job_grade = :job_grade, firstname = :firstname, lastname = :lastname, dateofbirth = :dateofbirth, sex = :sex, position = :position, inventory = :inventory, loadout = :loadout, metadata = :metadata, status = :status, is_dead = :is_dead'

function HexaCore.LoginPlayer(source, citizenid, newData)
    if source and source ~= '' then
        if citizenid then
            local license = HexaCore.GetIdentifier(source)
            local row = MySQL.prepare.await('SELECT * FROM users WHERE citizenid = ?', { citizenid })
            if row and license == row.identifier then
                HexaCore.LoadPlayer(source, UserRowToPlayerData(row))
            else
                DropPlayer(source, Lang:t('info.exploit_dropped'))
                TriggerEvent('hexa_log:server:CreateLog', 'anticheat', 'Anti-Cheat', 'white', GetPlayerName(source) .. ' Has Been Dropped For Character Joining Exploit', false)
            end
        else
            HexaCore.LoadPlayer(source, newData)
        end

        -- ล้าง isdead ที่ค้างจากรอบก่อนเสมอ แหล่งความจริงคือ ped สด ถ้าค้าง true คนอื่นเปิดกระเป๋าปล้นได้ทั้งที่ยืนอยู่
        local Player = HexaCore.Players[source]
        if Player and Player.PlayerData.metadata.isdead then
            Player.SetMetaData('isdead', false)
        end

        return true
    else
        Hexa.Error('LoginPlayer called with no source')
        return false
    end
end

function HexaCore.GetOfflinePlayerByCitizenId(citizenid)
    if citizenid then
        local row = MySQL.prepare.await('SELECT * FROM users WHERE citizenid = ?', { citizenid })
        if row then
            return HexaCore.LoadPlayer(nil, UserRowToPlayerData(row))
        end
    end
    return nil
end

function HexaCore.GetPlayerByLicense(license)
    if license then
        local source = HexaCore.GetSourceByIdentifier(license)
        if source > 0 then
            return HexaCore.Players[source]
        else
            return HexaCore.GetOfflinePlayerByLicense(license)
        end
    end
    return nil
end

function HexaCore.GetOfflinePlayerByLicense(license)
    if license then
        local row = MySQL.prepare.await('SELECT * FROM users WHERE identifier = ?', { license })
        if row then
            return HexaCore.LoadPlayer(nil, UserRowToPlayerData(row))
        end
    end
    return nil
end

-- ยุบบัญชีธนาคารสาขาเก่าเข้าช่อง bank (ไม่งั้นเงินก้อนนั้นเข้าถึงไม่ได้) ต้องทำก่อน applyDefaults ไม่งั้นยอดรวมถูกทับ
local LEGACY_BANK_ACCOUNTS = { 'valbank', 'rhobank', 'blkbank', 'armbank' }

local function MergeLegacyBankAccounts(PlayerData)
    local money = PlayerData.money
    if type(money) ~= 'table' then return end

    local merged, found = 0, false
    for i = 1, #LEGACY_BANK_ACCOUNTS do
        local key = LEGACY_BANK_ACCOUNTS[i]
        if money[key] ~= nil then
            merged = merged + (tonumber(money[key]) or 0)
            money[key] = nil
            found = true
        end
    end

    if not found then return end

    money.bank = (tonumber(money.bank) or 0) + merged
    Hexa.Log('money Merged legacy bank accounts for %s: +%s -> bank = %s', tostring(PlayerData.citizenid), tostring(merged), tostring(money.bank))
end

local function applyDefaults(playerData, defaults)
    for key, value in pairs(defaults) do
        if type(value) == 'function' then
            playerData[key] = playerData[key] or value()
        elseif type(value) == 'table' then
            playerData[key] = playerData[key] or {}
            applyDefaults(playerData[key], value)
        else
            playerData[key] = playerData[key] or value
        end
    end
end

function HexaCore.LoadPlayer(source, PlayerData)
    PlayerData = PlayerData or {}
    local Offline = not source

    if source then
        PlayerData.source = source
        PlayerData.license = PlayerData.license or HexaCore.GetIdentifier(source)
        PlayerData.name = GetPlayerName(source)
    end

    -- ตัวละครออฟไลน์ไม่เคยผ่านบล็อกบนจึงไม่มี name และ SaveOffline จะ throw หลังเขียน DB ลงไปแล้ว
    PlayerData.name = PlayerData.name or PlayerData.citizenid or 'unknown'

    local validatedJob = false
    if PlayerData.job and PlayerData.job.name ~= nil and PlayerData.job.grade and PlayerData.job.grade.level ~= nil then
        local jobInfo = HexaCore.Shared.Jobs[PlayerData.job.name]

        if jobInfo then
            local jobGradeInfo = jobInfo.grades[tostring(PlayerData.job.grade.level)]
            if jobGradeInfo then
                PlayerData.job.label = jobInfo.label
                PlayerData.job.grade.name = jobGradeInfo.name
                PlayerData.job.payment = jobGradeInfo.payment
                PlayerData.job.grade.isboss = jobGradeInfo.isboss or false
                PlayerData.job.isboss = jobGradeInfo.isboss or false
                validatedJob = true
            end
        end
    end

    if validatedJob == false then
        -- set to nil, as the default job (unemployed) will be added by 'applyDefaults'
        PlayerData.job = nil
    end

    MergeLegacyBankAccounts(PlayerData)
    applyDefaults(PlayerData, HexaCore.Config.Player.PlayerDefaults)

    if GetResourceState('hexa_inventory') == 'started' then
        -- nil กลางรายการข้าม resource จะถูกตัด citizenid เลื่อนไปช่อง source แล้ว LoadInventory คืน {} ทับกระเป๋าว่าง
        PlayerData.items = exports['hexa_inventory']:LoadInventory(PlayerData.source or 0, PlayerData.citizenid)
    end

    return HexaCore.CreatePlayer(PlayerData, Offline)
end

-- On player logout

function HexaCore.LogoutPlayer(source)
    TriggerClientEvent('HexaCore:Client:OnPlayerUnload', source)
    TriggerEvent('HexaCore:Server:OnPlayerUnload', source)
    TriggerClientEvent('HexaCore:Player:UpdatePlayerData', source)
    Wait(200)
    HexaCore.Players[source] = nil
end

-- สร้างตัวละครใหม่ แก้ตรงนี้ผิดพังทั้งระบบ (docs guide/player-object)

function HexaCore.CreatePlayer(PlayerData, Offline)
    local self = {}
    self.PlayerData = PlayerData
    self.Offline = Offline

    -- .Functions ต้องเป็นตารางจริง เพราะ wrapPlayer ของ rsg-core ยกเมธอดด้วย pairs() ถ้าเป็น proxy เปล่าสคริปต์ RSG ตายหมด
    self.Functions = {}

    -- เมธอดที่แขวนบนตัวผู้เล่นถูกมิเรอร์ลง .Functions ให้อัตโนมัติ รวมของที่ resource อื่นใส่เพิ่มตอน runtime
    setmetatable(self, {
        __newindex = function(target, key, value)
            rawset(target, key, value)
            if type(value) == 'function' then rawset(self.Functions, key, value) end
        end,
    })

    setmetatable(self.Functions, {
        __index = self,
        __newindex = function(_, key, value) self[key] = value end,
    })

    -- ธงบอกว่าข้อมูลเปลี่ยนตั้งแต่เซฟรอบล่าสุด เริ่มเป็น true เพราะคนที่เพิ่งโหลดยังไม่เคยถูกเขียนในรอบนี้
    self.Dirty = true

    function self.MarkDirty()
        self.Dirty = true
    end

    function self.SyncPlayerData()
        if self.Offline then return end

        self.Dirty = true

        if HexaCore.Config.Money.EnableMoneyItems then
            self.PlayerData = SynchronizeMoneyItems(self.PlayerData)
        end

        TriggerEvent('HexaCore:Player:SetPlayerData', self.PlayerData)
        TriggerClientEvent('HexaCore:Player:SetPlayerData', self.PlayerData.source, self.PlayerData)
    end

    function self.SetJob(job, grade)
        job = job:lower()
        grade = grade or '0'
        if not HexaCore.Shared.Jobs[job] then return false end
        self.PlayerData.job = {
            name = job,
            label = HexaCore.Shared.Jobs[job].label,
            onduty = HexaCore.Shared.Jobs[job].defaultDuty,
            type = HexaCore.Shared.Jobs[job].type or 'none',
            grade = {
                name = 'No Grades',
                level = 0,
                payment = 30,
                isboss = false
            }
        }
        local gradeKey = tostring(grade)
        local jobGradeInfo = HexaCore.Shared.Jobs[job].grades[gradeKey]
        if jobGradeInfo then
            self.PlayerData.job.grade.name = jobGradeInfo.name
            self.PlayerData.job.grade.level = tonumber(gradeKey)
            self.PlayerData.job.grade.payment = jobGradeInfo.payment
            self.PlayerData.job.grade.isboss = jobGradeInfo.isboss or false
            self.PlayerData.job.isboss = jobGradeInfo.isboss or false
        end

        if not self.Offline then
            self.SyncPlayerData()
            TriggerEvent('HexaCore:Server:OnJobUpdate', self.PlayerData.source, self.PlayerData.job)
            TriggerClientEvent('HexaCore:Client:OnJobUpdate', self.PlayerData.source, self.PlayerData.job)
        end

        return true
    end

    function self.HasItem(items, amount)
        return HexaCore.HasItem(self.PlayerData.source, items, amount)
    end

    -- เมธอดกลุ่มนี้ต้องนิยามตอนสร้าง ไม่ใช่ตอน OnPlayerLoaded เพราะ hexa_core โหลดก่อนจึงยังไม่เห็น (docs api/player-methods)
    local function inventoryReady()
        return GetResourceState('hexa_inventory') == 'started'
    end

    --- @return boolean stored, boolean dropped
    --- dropped = true means the satchel was full and the item was placed on the
    --- ground as a bag - it EXISTS, so callers must not refund for it.
    --- See hexa_inventory/server/exports.lua > Inventory.AddItem.
    function self.AddItem(item, amount, slot, info, reason)
        if not inventoryReady() then return false, false end
        -- ของในตัวเปลี่ยนก็ต้องถูกเขียนรอบหน้า เพราะเส้นทางนี้ไม่ได้ผ่าน SyncPlayerData
        self.Dirty = true
        -- ส่ง slot/info เป็น false ไม่ใช่ nil เพราะ nil กลางรายการข้าม resource จะถูกตัดจน reason เลื่อนไปนั่งช่อง slot
        return exports['hexa_inventory']:AddItem(
            self.PlayerData.source, item, amount,
            slot or false, info or false, reason or 'hexa_core:player.AddItem')
    end

    function self.RemoveItem(item, amount, slot, reason)
        if not inventoryReady() then return false end
        self.Dirty = true
        return exports['hexa_inventory']:RemoveItem(
            self.PlayerData.source, item, amount,
            slot or false, reason or 'hexa_core:player.RemoveItem')
    end

    function self.GetItemBySlot(slot)
        if not inventoryReady() then return nil end
        return exports['hexa_inventory']:GetItemBySlot(self.PlayerData.source, slot)
    end

    function self.GetItemByName(item)
        if not inventoryReady() then return nil end
        return exports['hexa_inventory']:GetItemByName(self.PlayerData.source, item)
    end

    function self.GetItemsByName(item)
        if not inventoryReady() then return {} end
        return exports['hexa_inventory']:GetItemsByName(self.PlayerData.source, item) or {}
    end

    function self.GetTotalWeight()
        if not inventoryReady() then return 0 end
        return exports['hexa_inventory']:GetTotalWeight(self.PlayerData.items) or 0
    end

    function self.SetJobDuty(onDuty)
        self.PlayerData.job.onduty = not not onDuty
        TriggerEvent('HexaCore:Server:OnJobUpdate', self.PlayerData.source, self.PlayerData.job)
        TriggerClientEvent('HexaCore:Client:OnJobUpdate', self.PlayerData.source, self.PlayerData.job)
        self.SyncPlayerData()
    end

    function self.SetPlayerData(key, val)
        if not key or type(key) ~= 'string' then return end
        self.PlayerData[key] = val
        self.SyncPlayerData()
    end

    function self.SetMetaData(meta, val)
        local function validateData(key, value)
            -- stress เคยหลุดจากลิสต์นี้ ทั้งที่เป็นค่า 0-100 เหมือนกัน ค่าจึงทะลุ 100 แล้วแถบใน hexa_status ล้นกรอบ
            if key == 'hunger' or key == 'thirst' or key == 'cleanliness' or key == 'stress' then
                value = math.min(math.max(tonumber(value) or 0, 0), 100)
            end

            return value
        end

        if type(meta) == 'table' then
            for key, value in pairs(meta) do
                self.PlayerData.metadata[key] = validateData(key, value)
            end
            self.SyncPlayerData()
            return
        end
    
        if type(meta) ~= 'string' then return end
        self.PlayerData.metadata[meta] = validateData(meta, val)
        self.SyncPlayerData()
    end

    function self.GetMetaData(meta)
        if not meta or type(meta) ~= 'string' then return end
        return self.PlayerData.metadata[meta]
    end

    -- ตัวละครเก่าไม่มีคีย์ rep ใน metadata เพราะ applyDefaults เติมเฉพาะคีย์ชั้นบนสุด อ่านตรง ๆ แล้วพังทันที
    local function repTable()
        local metadata = self.PlayerData.metadata
        if type(metadata.rep) ~= 'table' then metadata.rep = {} end
        return metadata.rep
    end

    function self.AddRep(rep, amount)
        if not rep then return end
        local addAmount = tonumber(amount)
        if not addAmount then return end
        local reps = repTable()
        reps[rep] = (tonumber(reps[rep]) or 0) + addAmount
        self.SyncPlayerData()
    end

    function self.RemoveRep(rep, amount)
        if not rep then return end
        local removeAmount = tonumber(amount)
        if not removeAmount then return end
        local reps = repTable()
        local currentRep = tonumber(reps[rep]) or 0
        reps[rep] = math.max(0, currentRep - removeAmount)
        self.SyncPlayerData()
    end

    function self.GetRep(rep)
        if not rep then return end
        return repTable()[rep] or 0
    end

    function self.AddMoney(moneytype, amount, reason)
        reason = reason or 'unknown'
        if type(moneytype) ~= 'string' then return false end
        moneytype = moneytype:lower()
        -- amount ที่แปลงเป็นตัวเลขไม่ได้เคยหลุดไปเทียบจนโยน error ตายกลาง callback (redeemcode ตัดโค้ดแล้วแต่ไม่ได้รางวัล)
        amount = tonumber(amount)
        if not amount or amount ~= amount or amount < 0 then return false end
        if not self.PlayerData.money[moneytype] then return false end
        self.PlayerData.money[moneytype] = self.PlayerData.money[moneytype] + amount

        if not self.Offline then
            self.SyncPlayerData()
            if amount > 100000 then
                TriggerEvent('hexa_log:server:CreateLog', 'playermoney', 'AddMoney', 'lightgreen', '**' .. GetPlayerName(self.PlayerData.source) .. ' (citizenid: ' .. self.PlayerData.citizenid .. ' | id: ' .. self.PlayerData.source .. ')** $' .. amount .. ' (' .. moneytype .. ') added, new ' .. moneytype .. ' balance: ' .. self.PlayerData.money[moneytype] .. ' reason: ' .. reason, true)
            else
                TriggerEvent('hexa_log:server:CreateLog', 'playermoney', 'AddMoney', 'lightgreen', '**' .. GetPlayerName(self.PlayerData.source) .. ' (citizenid: ' .. self.PlayerData.citizenid .. ' | id: ' .. self.PlayerData.source .. ')** $' .. amount .. ' (' .. moneytype .. ') added, new ' .. moneytype .. ' balance: ' .. self.PlayerData.money[moneytype] .. ' reason: ' .. reason)
            end

            if not HexaCore.Config.Money.EnableMoneyItems then
                TriggerClientEvent('hud:client:OnMoneyChange', self.PlayerData.source, moneytype, amount, false)
            end
            TriggerClientEvent('HexaCore:Client:OnMoneyChange', self.PlayerData.source, moneytype, amount, 'add', reason)
            TriggerEvent('HexaCore:Server:OnMoneyChange', self.PlayerData.source, moneytype, amount, 'add', reason)
        end

        return true
    end

    function self.RemoveMoney(moneytype, amount, reason)
        reason = reason or 'unknown'
        if type(moneytype) ~= 'string' then return false end
        moneytype = moneytype:lower()
        amount = tonumber(amount)
        if not amount or amount ~= amount or amount < 0 then return false end
        if not self.PlayerData.money[moneytype] then return false end
        local current = tonumber(self.PlayerData.money[moneytype]) or 0
        -- บีบเพดานล่างไม่ให้ต่ำกว่า 0 เสมอ เดิม bank ไม่อยู่ใน DontAllowMinus + MinusLimit ติดลบ = ซื้อของฟรีได้ถึง $5,000
        local allowMinus = true
        for _, mtype in pairs(HexaCore.Config.Money.DontAllowMinus or {}) do
            if mtype == moneytype then
                allowMinus = false
                break
            end
        end
        local floorLimit = allowMinus and math.max(0, tonumber(HexaCore.Config.Money.MinusLimit) or 0) or 0
        if (current - amount) < floorLimit then return false end
        self.PlayerData.money[moneytype] = current - amount

        if not self.Offline then
            self.SyncPlayerData()
            if amount > 100000 then
                TriggerEvent('hexa_log:server:CreateLog', 'playermoney', 'RemoveMoney', 'red', '**' .. GetPlayerName(self.PlayerData.source) .. ' (citizenid: ' .. self.PlayerData.citizenid .. ' | id: ' .. self.PlayerData.source .. ')** $' .. amount .. ' (' .. moneytype .. ') removed, new ' .. moneytype .. ' balance: ' .. self.PlayerData.money[moneytype] .. ' reason: ' .. reason, true)
            else
                TriggerEvent('hexa_log:server:CreateLog', 'playermoney', 'RemoveMoney', 'red', '**' .. GetPlayerName(self.PlayerData.source) .. ' (citizenid: ' .. self.PlayerData.citizenid .. ' | id: ' .. self.PlayerData.source .. ')** $' .. amount .. ' (' .. moneytype .. ') removed, new ' .. moneytype .. ' balance: ' .. self.PlayerData.money[moneytype] .. ' reason: ' .. reason)
            end
            if not HexaCore.Config.Money.EnableMoneyItems then
                TriggerClientEvent('hud:client:OnMoneyChange', self.PlayerData.source, moneytype, amount, true)
            end
            TriggerClientEvent('HexaCore:Client:OnMoneyChange', self.PlayerData.source, moneytype, amount, 'remove', reason)
            TriggerEvent('HexaCore:Server:OnMoneyChange', self.PlayerData.source, moneytype, amount, 'remove', reason)
        end

        return true
    end

    function self.SetMoney(moneytype, amount, reason)
        reason = reason or 'unknown'
        if type(moneytype) ~= 'string' then return false end
        moneytype = moneytype:lower()
        amount = tonumber(amount)
        if not amount or amount ~= amount or amount < 0 then return false end
        if not self.PlayerData.money[moneytype] then return false end
        local difference = amount - self.PlayerData.money[moneytype]
        self.PlayerData.money[moneytype] = amount

        if not self.Offline then
            self.SyncPlayerData()
            TriggerEvent('hexa_log:server:CreateLog', 'playermoney', 'SetMoney', 'green', '**' .. GetPlayerName(self.PlayerData.source) .. ' (citizenid: ' .. self.PlayerData.citizenid .. ' | id: ' .. self.PlayerData.source .. ')** $' .. amount .. ' (' .. moneytype .. ') set, new ' .. moneytype .. ' balance: ' .. self.PlayerData.money[moneytype] .. ' reason: ' .. reason)
            if not HexaCore.Config.Money.EnableMoneyItems then
                TriggerClientEvent('hud:client:OnMoneyChange', self.PlayerData.source, moneytype, math.abs(difference), difference < 0)
            end
            TriggerClientEvent('HexaCore:Client:OnMoneyChange', self.PlayerData.source, moneytype, amount, 'set', reason)
            TriggerEvent('HexaCore:Server:OnMoneyChange', self.PlayerData.source, moneytype, amount, 'set', reason)
        end

        return true
    end

    function self.GetMoney(moneytype)
        if type(moneytype) ~= 'string' then return false end
        moneytype = moneytype:lower()
        return self.PlayerData.money[moneytype]
    end

    function self.Save()
        if self.Offline then
            HexaCore.SaveOfflinePlayer(self.PlayerData)
        else
            self.PullStateBags()
            HexaCore.SavePlayer(self.PlayerData.source)
        end
    end

    function self.Logout()
        if self.Offline then return end
        HexaCore.LogoutPlayer(self.PlayerData.source)
    end

    -- AddMethod กับ AddField เขียนลงช่องเดียวกันแล้ว จึงยุบเหลือ SetField ตัวเดียวที่เขียนทับเสมอ
    local RESERVED_FIELDS = { PlayerData = true, Functions = true, Offline = true }

    function self.SetField(name, value)
        if type(name) ~= 'string' or name == '' then return false, 'field name must be a non-empty string' end
        -- กันสคริปต์ภายนอกทับโครงของตัวผู้เล่นด้วยชื่อที่ส่งมาเป็นสตริง
        if RESERVED_FIELDS[name] then return false, ('cannot overwrite reserved field %s'):format(name) end
        self[name] = value
        return true
    end

    self.AddMethod = self.SetField
    self.AddField = self.SetField

    -- bridge ของ rsg เรียกตัวนี้ เซิร์ฟนี้ไม่มีระบบแก๊งจึงคืน false เสมอแทนที่จะปล่อยให้เป็น nil
    function self.SetGang()
        return false
    end

    -- hexa_redeemcode เดาชื่อนี้แล้วไม่เจอจนต้องเขียนทางอ้อมเอง ต่อสายให้ตรงกับ Core ที่มีอยู่แล้ว
    function self.CanCarryItem(item, amount)
        return HexaCore.CanCarryItem(self.PlayerData.source, item, amount)
    end

    function self.PullStateBags()
        local metadata = {}
        local keys = { "hunger", "thirst", "cleanliness", "stress", "health" }
    
        local state = Player(self.PlayerData.source).state
        for _, key in ipairs(keys) do
            if state[key] ~= nil then
                metadata[key] = state[key]
            end
        end
    
        if next(metadata) then
            self.SetMetaData(metadata)
        end
    end

    function self.PushStateBags()
        local metadata = self.PlayerData.metadata
        local keys = { "hunger", "thirst", "cleanliness", "stress", "health" }
    
        local state = Player(self.PlayerData.source).state
        for _, key in ipairs(keys) do
            if metadata[key] ~= nil then
                state[key] = metadata[key]
            end
        end
    end

    if self.Offline then
        return self
    else
        self.PushStateBags()
        HexaCore.Players[self.PlayerData.source] = self
        HexaCore.SavePlayer(self.PlayerData.source)
        TriggerEvent('HexaCore:Server:PlayerLoaded', self)
        self.SyncPlayerData()
    end
end

-- แขวนเมธอดเพิ่มบนตัวผู้เล่นจาก resource อื่น ตัวอย่างการใช้ดู docs api/player-methods

function HexaCore.SetPlayerField(ids, methodName, handler)
    local idType = type(ids)
    if idType == 'number' then
        if ids == -1 then
            for _, v in pairs(HexaCore.Players) do
                v.SetField(methodName, handler)
            end
        else
            if not HexaCore.Players[ids] then return end

            HexaCore.Players[ids].SetField(methodName, handler)
        end
    elseif idType == 'table' and table.type(ids) == 'array' then
        for i = 1, #ids do
            HexaCore.SetPlayerField(ids[i], methodName, handler)
        end
    end
end

-- ใส่ฟิลด์ข้อมูลเพิ่มบนตัวผู้เล่น ตัวอย่างการใช้ดู docs api/player-methods

function HexaCore.SetPlayerField(ids, fieldName, data)
    local idType = type(ids)
    if idType == 'number' then
        if ids == -1 then
            for _, v in pairs(HexaCore.Players) do
                v.SetField(fieldName, data)
            end
        else
            if not HexaCore.Players[ids] then return end

            HexaCore.Players[ids].SetField(fieldName, data)
        end
    elseif idType == 'table' and table.type(ids) == 'array' then
        for i = 1, #ids do
            HexaCore.SetPlayerField(ids[i], fieldName, data)
        end
    end
end

-- Save player info to database (ตาราง users สไตล์ ESX คีย์ด้วย identifier)

function HexaCore.SavePlayer(source)
    -- ต้องเช็คก่อน index ไม่งั้นเซฟที่ค้างคิวหลังผู้เล่นหลุดจะโยน nil และ else ข้างล่างกลายเป็นโค้ดตาย
    local Player = HexaCore.Players[source]
    local PlayerData = Player and Player.PlayerData
    if PlayerData then
        local ped = GetPlayerPed(source)
        -- ped อาจยังไม่มีตอนคิวเซฟทำงาน แล้ว GetEntityCoords คืน 0,0,0 = ส่งตัวละครไปโผล่กลางทะเล จึงใช้ตำแหน่งเดิมแทน
        local pcoords = DoesEntityExist(ped) and GetEntityCoords(ped) or nil

        -- ธงถูกปิดก่อนเขียน ไม่ใช่หลังเขียน เพราะการเขียนเป็นแบบไม่รอผล ถ้าปิดทีหลังจะไปลบธงที่เพิ่งถูกปักใหม่ระหว่างรอ
        Player.Dirty = false

        MySQL.insert(USERS_UPSERT, BuildUserRow(PlayerData, pcoords), function(insertId)
            -- เดิมพิมพ์ว่าสำเร็จตั้งแต่ยังไม่ได้เขียน และพิมพ์เหมือนกันหมดไม่ว่าจะสำเร็จหรือไม่
            if insertId == nil then
                Player.Dirty = true
                return Hexa.Error('failed to save %s (%s) - will retry on the next sweep',
                    tostring(PlayerData.name), tostring(PlayerData.citizenid))
            end
            Hexa.Debug('saved %s (%s)', tostring(PlayerData.name), tostring(PlayerData.citizenid))
        end)

        if GetResourceState('hexa_inventory') == 'started' then exports['hexa_inventory']:SaveInventory(source) end
    else
        Hexa.Error('SavePlayer called for id %s but no player data is loaded', tostring(source))
    end
end

function HexaCore.SaveOfflinePlayer(PlayerData)
    if PlayerData then
        MySQL.insert(USERS_UPSERT, BuildUserRow(PlayerData))
        if GetResourceState('hexa_inventory') == 'started' then exports['hexa_inventory']:SaveInventory(PlayerData, true) end
        -- log บรรทัดนี้ throw ได้ทั้งที่ MySQL.insert ข้างบนลงไปแล้ว ผู้เรียกเลยเห็นว่าล้มเหลวทั้งที่เงินเข้าจริง
        Hexa.Debug('saved offline character %s', tostring(PlayerData.name or PlayerData.citizenid))
    else
        Hexa.Error('SaveOfflinePlayer called with no player data')
    end
end


-- Delete character

local playertables = { -- เพิ่มตารางที่อ้างอิง citizenid ได้ แต่ต้องมีจริงใน DB ไม่งั้น transaction ลบตัวละคร fail ทั้งชุด
    { table = 'users'},
}

function HexaCore.DeleteCharacter(source, citizenid)
    local license = HexaCore.GetIdentifier(source)
    local result = MySQL.scalar.await('SELECT identifier FROM users WHERE citizenid = ?', { citizenid })
    if license == result then
        local query = 'DELETE FROM %s WHERE citizenid = ?'
        local tableCount = #playertables
        local queries = table.create(tableCount, 0)

        for i = 1, tableCount do
            local v = playertables[i]
            queries[i] = { query = query:format(v.table), values = { citizenid } }
        end

        MySQL.transaction(queries, function(result2)
            if result2 then
                TriggerEvent('hexa_log:server:CreateLog', 'joinleave', 'Character Deleted', 'red', '**' .. GetPlayerName(source) .. '** ' .. license .. ' deleted **' .. citizenid .. '**..')
            end
        end)
    else
        DropPlayer(source, Lang:t('info.exploit_dropped'))
        TriggerEvent('hexa_log:server:CreateLog', 'anticheat', 'Anti-Cheat', 'white', GetPlayerName(source) .. ' Has Been Dropped For Character Deletion Exploit', true)
    end
end

function HexaCore.ForceDeleteCharacter(citizenid)
    local result = MySQL.scalar.await('SELECT identifier FROM users WHERE citizenid = ?', { citizenid })
    if result then
        local query = 'DELETE FROM %s WHERE citizenid = ?'
        local tableCount = #playertables
        local queries = table.create(tableCount, 0)
        local Player = HexaCore.GetPlayerByCitizenId(citizenid)

        if Player then
            DropPlayer(Player.PlayerData.source, 'An admin deleted the character which you are currently using')
        end
        for i = 1, tableCount do
            local v = playertables[i]
            queries[i] = { query = query:format(v.table), values = { citizenid } }
        end

        MySQL.transaction(queries, function(result2)
            if result2 then
                TriggerEvent('hexa_log:server:CreateLog', 'joinleave', 'Character Force Deleted', 'red', 'Character **' .. citizenid .. '** got deleted')
            end
        end)
    end
end

-- Inventory Backwards Compatibility

function HexaCore.SaveInventory(source)
    if GetResourceState('hexa_inventory') ~= 'started' then return end
    exports['hexa_inventory']:SaveInventory(source, false)
end

function HexaCore.SaveOfflineInventory(PlayerData)
    if GetResourceState('hexa_inventory') ~= 'started' then return end
    exports['hexa_inventory']:SaveInventory(PlayerData, true)
end

function HexaCore.GetTotalWeight(items)
    if GetResourceState('hexa_inventory') ~= 'started' then return end
    return exports['hexa_inventory']:GetTotalWeight(items)
end

function HexaCore.GetSlotsByItem(items, itemName)
    if GetResourceState('hexa_inventory') ~= 'started' then return end
    return exports['hexa_inventory']:GetSlotsByItem(items, itemName)
end

function HexaCore.GetFirstSlotByItem(items, itemName)
    if GetResourceState('hexa_inventory') ~= 'started' then return end
    return exports['hexa_inventory']:GetFirstSlotByItem(items, itemName)
end

-- Util Functions

-- citizen id = CitizenIdPrefix + สุ่ม CitizenIdDigits หลักเติมศูนย์ ข้าม LockedIds และเช็คไม่ให้ซ้ำกับตาราง users

local CITIZEN_ID_TRIES = 50 -- draws per digit length before widening the pool
local CITIZEN_ID_MAX_EXTRA_DIGITS = 4 -- how far the pool may widen when it is full

local lockedIdSet = nil
local function IsCitizenIdLocked(id)
    if not lockedIdSet then
        lockedIdSet = {}
        for _, v in pairs(HexaCore.Config.Player.LockedIds or {}) do
            lockedIdSet[tonumber(v)] = true
        end
    end
    return lockedIdSet[id] == true
end

--- จำนวนหลักของเลขสุ่ม บีบไว้ไม่ให้หลุดช่วง integer ของ Lua
local function CitizenIdDigits()
    local digits = math.floor(tonumber(HexaCore.Config.Player.CitizenIdDigits) or 4)
    if digits < 1 then return 1 end
    if digits > 12 then return 12 end
    return digits
end

--- สุ่ม id ว่างที่มี digits หลักพอดี คืน nil ถ้าทุกครั้งชนเลขที่ล็อกไว้หรือถูกใช้แล้ว
local function DrawCitizenId(prefix, digits)
    local pool = 1
    for _ = 1, digits do pool = pool * 10 end

    local format = '%0' .. digits .. 'd'
    for _ = 1, CITIZEN_ID_TRIES do
        local number = math.random(0, pool - 1)
        if not IsCitizenIdLocked(number) then
            local citizenId = prefix .. string.format(format, number)
            local taken = MySQL.prepare.await('SELECT EXISTS(SELECT 1 FROM users WHERE citizenid = ?) AS uniqueCheck', { citizenId })
            if taken == 0 then return citizenId end
        end
    end

    return nil
end

function HexaCore.CreateCitizenId()
    local prefix = tostring(HexaCore.Config.Player.CitizenIdPrefix or '')
    local digits = CitizenIdDigits()

    for extra = 0, CITIZEN_ID_MAX_EXTRA_DIGITS do
        local citizenId = DrawCitizenId(prefix, digits + extra)
        if citizenId then
            if extra > 0 then
                Hexa.Log('citizen id pool of %d digits looks full, issued a %d digit id (%s) — raise Config.Player.CitizenIdDigits', digits, digits + extra, citizenId)
            end
            return citizenId
        end
    end

    -- practically unreachable: every pool up to digits+4 came back full
    local fallback = prefix .. tostring(os.time())
    Hexa.Log('could not draw a free citizen id, falling back to %s — raise Config.Player.CitizenIdDigits', fallback)
    return fallback
end

function HexaCore.CreateAccountNumber()
    local AccountNumber = 'US0' .. math.random(1, 9) .. 'HexaCore' .. math.random(1111, 9999) .. math.random(1111, 9999) .. math.random(11, 99)
    -- account ถูกฝากไว้ใน metadata (ตาราง users ไม่มีคอลัมน์ charinfo)
    local result = MySQL.prepare.await('SELECT EXISTS(SELECT 1 FROM users WHERE JSON_UNQUOTE(JSON_EXTRACT(metadata, "$.account")) = ?) AS uniqueCheck', { AccountNumber })
    if result == 0 then return AccountNumber end
    return HexaCore.CreateAccountNumber()
end

function HexaCore.CreateFingerprint()
    local FingerId = tostring(HexaCore.Shared.RandomStr(2) .. HexaCore.Shared.RandomInt(3) .. HexaCore.Shared.RandomStr(1) .. HexaCore.Shared.RandomInt(2) .. HexaCore.Shared.RandomStr(3) .. HexaCore.Shared.RandomInt(4))
    local result = MySQL.prepare.await('SELECT EXISTS(SELECT 1 FROM users WHERE JSON_UNQUOTE(JSON_EXTRACT(metadata, "$.fingerprint")) = ?) AS uniqueCheck', { FingerId })
    if result == 0 then return FingerId end
    return HexaCore.CreateFingerprint()
end

function HexaCore.CreateWalletId()
    local WalletId = 'Hexa-' .. math.random(11111111, 99999999)
    local result = MySQL.prepare.await('SELECT EXISTS(SELECT 1 FROM users WHERE JSON_UNQUOTE(JSON_EXTRACT(metadata, "$.walletid")) = ?) AS uniqueCheck', { WalletId })
    if result == 0 then return WalletId end
    return HexaCore.CreateWalletId()
end

function HexaCore.CreatePhoneSerial()
    local SerialNumber = math.random(11111111, 99999999)
    local result = MySQL.prepare.await('SELECT EXISTS(SELECT 1 FROM users WHERE JSON_UNQUOTE(JSON_EXTRACT(metadata, "$.phonedata.SerialNumber")) = ?) AS uniqueCheck', { SerialNumber })
    if result == 0 then return SerialNumber end
    return HexaCore.CreatePhoneSerial()
end

PaycheckInterval() -- This starts the paycheck system
