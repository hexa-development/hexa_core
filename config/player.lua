-- hexa_core / config: ผู้เล่น / ตัวละคร

-- การตั้งค่าผู้เล่น / ตัวละคร

Config.Player = {}
Config.Player.DefaultModel = 'mp_male' -- โมเดลตัวละครพื้นฐานตอน spawn (ก่อนระบบเสื้อผ้า/หน้าตามาทับ)
-- รูปแบบ citizen id = คำนำหน้า + เลขสุ่ม เช่น 'RB' + 4 หลัก -> RB1234, RB0087
Config.Player.CitizenIdPrefix = 'RB' -- คำนำหน้า citizen id (ใส่ '' = ไม่มีคำนำหน้า เหลือแต่เลข)
Config.Player.CitizenIdDigits = 4 -- จำนวนหลัก (เติม 0 ให้ครบเสมอ) 4 หลัก = 10,000 เลข เต็มแล้วระบบเพิ่มหลักให้เองชั่วคราวแล้วเตือนใน console
Config.Player.LockedIds = {
    -- 1 หลัก
    1, 2, 3, 4, 5, 6, 7, 8, 9,

    -- 2 หลัก
    11, 22, 33, 44, 55, 66, 77, 88, 99,

    -- 3 หลัก
    111, 222, 333, 444, 555, 666, 777, 888, 999,

    -- 4 หลัก
    1111, 2222, 3333, 4444, 5555, 6666, 7777, 8888, 9999,

    -- 5 หลัก
    11111, 22222, 33333, 44444, 55555, 66666, 77777, 88888, 99999,

    -- 6 หลัก
    111111, 222222, 333333, 444444, 555555, 666666, 777777, 888888, 999999,
} -- รายการเลข ID ที่ระบบจะข้าม ไม่แจกให้ผู้เล่น

-- ค่าเริ่มต้นของตัวละครใหม่ ช่องที่เป็น function() จะถูกเรียกตอนสร้างจริงเพื่อสุ่มค่าใหม่ทุกครั้ง ดู docs guide/player-object
Config.Player.PlayerDefaults = {
    citizenid = function() -- citizen id ประจำตัวละคร (คำนำหน้า + เลขสุ่ม ตาม Config.Player.CitizenIdPrefix/Digits)
        return Core.CreateCitizenId()
    end,
    cid = 1, -- ลำดับช่องตัวละคร (character slot) ของบัญชีนั้นๆ
    money = function() -- เงินตั้งต้นทุกประเภท ดึงมาจาก Config.Money.MoneyTypes ด้านบนโดยอัตโนมัติ
        local moneyDefaults = {}
        for moneytype, startamount in pairs(Config.Money.MoneyTypes) do
            moneyDefaults[moneytype] = startamount
        end
        return moneyDefaults
    end,
    optin = true, -- สถานะรับการแจ้งเตือนสำหรับ admin (เกี่ยวกับระบบ report/แจ้งเตือนต่างๆ)

    -- ข้อมูลส่วนตัวของตัวละคร
    charinfo = {
        firstname = 'Firstname', -- ชื่อจริงเริ่มต้น (จะถูกแทนที่ตอนสร้างตัวละคร)
        lastname = 'Lastname',   -- นามสกุลเริ่มต้น (จะถูกแทนที่ตอนสร้างตัวละคร)
        birthdate = '00-00-0000', -- วันเกิดเริ่มต้น
        gender = 0,              -- เพศ (0 = ชาย, 1 = หญิง)
        nationality = 'USA',     -- สัญชาติเริ่มต้น
        account = function()     -- เลขบัญชีธนาคาร สร้างใหม่แบบสุ่มไม่ซ้ำทุกตัวละคร
            return Core.CreateAccountNumber()
        end
    },

    -- อาชีพเริ่มต้นของตัวละครใหม่
    job = {
        name = 'unemployed',  -- ชื่ออาชีพ (คีย์อ้างอิงในระบบ ต้องตรงกับตาราง jobs ในฐานข้อมูล)
        label = 'Civilian',   -- ชื่ออาชีพที่แสดงให้ผู้เล่นเห็น
        payment = 10,         -- เงินเดือนต่อรอบ paycheck
        type = 'none',        -- ประเภทอาชีพ (เช่น leo = ตำรวจ, medical = หมอ, none = ไม่มีหมวด)
        onduty = false,       -- สถานะเข้าเวรเริ่มต้น (false = ยังไม่เข้าเวร)
        isboss = false,       -- เป็นหัวหน้าอาชีพหรือไม่
        grade = {
            name = 'Freelancer', -- ชื่อตำแหน่ง/ขั้นของอาชีพ
            level = 0            -- ระดับขั้น (ยิ่งสูงยิ่งมีสิทธิ์มาก)
        }
    },

    -- ข้อมูลสถานะต่างๆ ของตัวละคร (metadata)
    metadata = {
        health = 600,        -- พลังชีวิตเริ่มต้น
        hunger = 100,        -- ความอิ่ม (0-100, 100 = อิ่มเต็มที่)
        thirst = 100,        -- ความชุ่มคอ (0-100, 100 = ไม่กระหายน้ำ)
        cleanliness = 100,   -- ความสะอาดของร่างกาย (0-100)
        stress = 0,          -- ความเครียด (0 = ไม่เครียดเลย)
        isdead = false,      -- สถานะการตาย (true = ตายอยู่)
        armor = 0,           -- เกราะเริ่มต้น
        ishandcuffed = false, -- สถานะถูกใส่กุญแจมือ
        injail = 0,          -- เวลาที่เหลือในคุก (0 = ไม่ได้ติดคุก)
        jailitems = {},      -- ไอเทมที่ถูกยึดไว้ตอนเข้าคุก (คืนตอนพ้นโทษ)
        status = {},         -- สถานะพิเศษอื่นๆ (เช่น อาการบาดเจ็บ, โรค)
        rep = {},            -- ค่าชื่อเสียง (reputation) ในระบบต่างๆ
        callsign = 'NO CALLSIGN', -- รหัสเรียกขาน (ใช้กับอาชีพตำรวจ/หน่วยงาน)
        fingerprint = function() -- รหัสลายนิ้วมือ สร้างแบบสุ่มไม่ซ้ำทุกตัวละคร
            return Core.CreateFingerprint()
        end,
        walletid = function() -- รหัสกระเป๋าเงิน สร้างแบบสุ่มไม่ซ้ำทุกตัวละคร
            return Core.CreateWalletId()
        end,
        criminalrecord = {   -- ประวัติอาชญากรรม
            hasRecord = false, -- มีประวัติหรือไม่
            date = nil         -- วันที่บันทึกประวัติล่าสุด
        }
    },
    position = Config.DefaultSpawn, -- ตำแหน่งเกิดเริ่มต้น (อ้างอิงจาก Config.DefaultSpawn ด้านบน)
    items = {},  -- ไอเทมติดตัวเริ่มต้น (ว่าง = ไม่มีไอเทม)
    weight = 100, -- น้ำหนักสูงสุดที่แบกได้ ระบบคิดเป็นเปอร์เซ็นต์: แบกได้เต็มที่ 100 และน้ำหนักไอเทมคือ % ต่อชิ้น
    slots = 25   -- จำนวนช่องเก็บของในกระเป๋า
}

Config.Player.RevealMap = true -- true = เปิดแผนที่ทั้งหมดให้เห็นตั้งแต่แรก (ไม่มีหมอกบังแผนที่) / false = ต้องเดินสำรวจเองถึงจะเห็น
