Config = {}

-- การตั้งค่าทั่วไปของเซิร์ฟเวอร์

Config.MaxPlayers = GetConvarInt('sv_maxclients', 48) -- จำนวนผู้เล่นสูงสุด ดึงค่ามาจาก convar "sv_maxclients" ใน server.cfg อัตโนมัติ (ถ้าไม่ได้ตั้งไว้จะใช้ค่าเริ่มต้น 48)
Config.IdentifierType = 'steam' -- คอลัมน์ identifier ใน users: 'steam' ต้องเปิดเกมผ่าน Steam ไม่งั้นถูกเตะตอน connect, 'license' ทุกคนมี ปลอดภัยกว่า
Config.MultiCharacter = true -- true = ใช้หน้าเลือกตัวละคร hexa_multicharacter (ปิด auto-login) / false = auto-login ตัวละครล่าสุดให้อัตโนมัติ ไม่มีหน้าเลือก
Config.DefaultSpawn = vector4(-2784.2534, -3058.2639, -12.3404, 333.5929) -- จุดเกิดเริ่มต้นของตัวละครใหม่ (x, y, z, ทิศทางที่หันหน้า) ใช้เมื่อผู้เล่นยังไม่มีตำแหน่งบันทึกไว้
Config.Debug = false -- true = เปิดข้อความ [DEBUG] ทั้งระบบ (ปิดอยู่จะไม่เสียเวลาสร้างสตริงเลย)

-- การบันทึกข้อมูลผู้เล่นลงฐานข้อมูล

-- รอบกวาดเซฟเดินฝั่ง server เท่านั้น (client ไม่ยิงก็ไม่มีวันเซฟ) และเขียนเฉพาะคนที่ข้อมูลเปลี่ยนจริง ดู docs guide/persistence
Config.Save = {}

Config.Save.Interval = 45 -- ทุกกี่นาทีถึงจะกวาดเซฟหนึ่งรอบ (ต่ำสุด 1) แนะนำ 30-60
Config.Save.SpreadSeconds = 60 -- เกลี่ยการเขียนของแต่ละคนให้กระจายภายในกี่วินาที กัน 48 คนยิง MySQL พร้อมกัน
Config.Save.OnDrop = true -- เซฟทันทีตอนผู้เล่นหลุด (ควรเปิดไว้ ไม่งั้นเสียความคืบหน้าตั้งแต่รอบกวาดล่าสุด)
Config.Save.OnResourceStop = true -- เซฟทุกคนก่อน resource หยุดหรือเซิร์ฟปิด

-- ชื่อเดิมของ Config.Save.Interval ยังอ่านได้อยู่เพื่อไม่ให้คอนฟิกเก่าพัง
Config.UpdateInterval = Config.Save.Interval

-- ปลายทางของ log

-- hexa_core รับ hexa_log:server:CreateLog เอง (เดิมไม่มี resource ปลายทาง log หายหมด) ลงคอนโซลเสมอ + Discord ถ้าใส่ URL ดู docs guide/logging
Config.Log = {}

Config.Log.Enabled = true -- false = ไม่พิมพ์และไม่ส่งอะไรเลย

-- ใส่ URL ของ Discord webhook แยกตามหมวดได้ ปล่อยว่าง = ไม่ส่ง ใช้ default เป็นตัวรับที่เหลือ
Config.Log.Webhooks = {
    default   = '',
    joinleave = '',
    anticheat = '',
}

-- การตั้งค่าระบบเงิน

Config.Money = {}

-- ประเภทเงินทั้งหมดในเซิร์ฟเวอร์ คีย์ = ชื่อประเภทเงิน, ค่า = จำนวนเงินตั้งต้นที่ตัวละครใหม่ได้รับ
Config.Money.MoneyTypes = {
    cash = 50,    -- เงินสด (พกติดตัว) เริ่มต้นให้ 50
    bank = 0,     -- เงินฝากธนาคาร — บัญชีเดียวใช้ร่วมกันทุกสาขา (ฝากที่เมืองไหนก็ถอนได้ทุกเมือง)
    gold = 0      -- ทองคำ (สกุลเงินพิเศษ)
}
-- เดิมธนาคารแยกช่องตามเมือง (valbank/rhobank/...) ตอนนี้ยุบเหลือ 'bank' เดียว ยอดเก่ารวมให้ตอนโหลด (MergeLegacyBankAccounts ใน server/player.lua)
Config.Money.DontAllowMinus = {'cash', 'gold', 'bank', 'bloodmoney'} -- รายชื่อประเภทเงินที่ "ห้ามติดลบ" เด็ดขาด (หักแล้วเหลือต่ำกว่า 0 ไม่ได้)
Config.Money.MinusLimit = 0 -- ยอดติดลบสูงสุดที่อนุญาต สำหรับประเภทเงินที่ไม่ได้อยู่ในลิสต์ข้างบน
-- เดิม bank ไม่อยู่ในลิสต์ + MinusLimit ติดลบ ทำให้ RemoveMoney คืน true ทั้งที่เงินไม่พอ = แจกของฟรี ตอนนี้ server/player.lua บีบเพดานล่างที่ 0 เสมอ
Config.Money.PayCheckTimeOut = 10 -- รอบเวลาการจ่ายเงินเดือน (paycheck) ให้ผู้เล่นตามค่า payment ของอาชีพ (หน่วยเป็นนาที)
Config.Money.PayCheckSociety = false -- true = เงินเดือนจะถูกหักจากบัญชีกลางของบริษัท/หน่วยงาน (society) ที่ผู้เล่นสังกัด ต้องตั้ง Config.Money.SocietyExport ด้านล่างให้ชี้ไป resource ที่มีระบบบัญชีบริษัทจริง / false = เงินเดือนเสกให้ฟรีจากระบบ
-- รูปแบบ export ของ society ดู docs guide/configuration — nil = จ่ายจากระบบ (เดิม hardcode 'Hexa-banking' ที่ไม่มีจริง เปิดแล้วเงินเดือนพัง)
Config.Money.SocietyExport = nil
Config.Money.EnableMoneyItems = false -- true = เงินสดและทองจะเป็น "ไอเทม" ในกระเป๋าแทนตัวเลขเฉยๆ (หมายเหตุ: ไอเทมเงินถูกลบออกจาก shared/items.lua ไปแล้ว) / false = เป็นตัวเลขปกติ

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

-- ความหนาแน่นของ NPC / สัตว์ / ยานพาหนะในโลก

-- 0.0 = ปิดสนิท, 1.0 = ค่าปกติของเกม (1.0 ถูกข้ามไม่เรียก native เลย เพราะเป็น default ของเอนจินอยู่แล้ว ประหยัดงานต่อเฟรม)
Config.Density = {
    [1] = 1.0, -- สัตว์ ambient (เปิดไว้ให้ล่าสัตว์ได้)
    [2] = 1.0, -- สัตว์ scenario (เปิดไว้ให้ล่าสัตว์ได้)
    [3] = 0.0, -- ปิด NPC มนุษย์ ambient
    [4] = 0.0, -- ปิด NPC มนุษย์ scenario
    [5] = 0.0, -- ปิด ped ทั่วไป ambient
    [6] = 0.0, -- ปิด ped ทั่วไป scenario
    [7] = 0.0, -- ปิดรถม้าจอดข้างทาง
    [8] = 0.0, -- ปิดรถม้าสุ่มวิ่งบนถนน
    [9] = 0.0, -- ปิดยานพาหนะทั่วไป
}

-- ระบบสถานะร่างกาย (หิว / กระหาย / สะอาด / เครียด)

-- ค่าทั้งสี่อยู่ใน metadata (0-100, เครียดยิ่งต่ำยิ่งดี) รอบลดค่าเดินฝั่ง server เพราะ client ไม่ยิงก็ไม่มีวันหิว client เหลือแค่หักเลือดที่ ped จริง
Config.Status = {}

Config.Status.Enabled = true -- false = ปิดระบบทั้งหมด (ค่าใน metadata ค้างไว้เฉยๆ ไม่ลดเอง ไม่หักเลือด)

-- รายชื่อสถานะทั้งหมดของเซิร์ฟ เพิ่มชื่อลงลิสต์นี้แล้วทั้งเส้นทางรู้จักเอง: เซฟลง DB, statebag, ไวต์ลิสต์ที่ client เขียนได้,
-- คำสั่ง /setstatus, exports GetStatus/SetStatus/AddStatus/RemoveStatus และ HUD ฝั่ง client
-- เพิ่มคีย์ใหม่แล้วต้องทำอีกสองที่: ตั้งค่าเริ่มต้นใน Config.Player.PlayerDefaults.metadata (ไม่งั้นตัวละครใหม่เริ่มที่ 100)
-- และใส่อัตราลดใน Config.Status.Drain ข้างล่าง (ไม่ใส่ = ไม่ลดเอง ให้สคริปต์อื่นเป็นคนขยับ)
Config.Status.Keys = { 'hunger', 'thirst', 'cleanliness', 'stress' }

-- ทุกกี่นาทีถึงจะลดค่าหนึ่งรอบ
Config.Status.TickInterval = 5

-- ลดกี่หน่วยต่อรอบ (ติดลบ = เพิ่มกลับ) ค่าเริ่มต้นหิว/กระหายหมดใน ~4 / ~2.8 ชม. ส่วนเครียด -1 = คลายเอง (ตัวเพิ่มเป็นหน้าที่ของสคริปต์อื่น)
Config.Status.Drain = {
    hunger      = 2.0,
    thirst      = 3.0,
    cleanliness = 1.0,
    stress      = -1.0,
}

-- หักเลือดเมื่อหิวจัด/กระหายจัด (ค่าแตะ 0)
Config.Status.Damage = {
    enabled   = true,
    keys      = { 'hunger', 'thirst' }, -- สถานะที่แตะพื้นแล้วหักเลือด (ต้องเป็นชื่อที่มีใน Config.Status.Keys)
    threshold = 0,     -- ค่าที่ถือว่า "จัด" (0 = ต้องหมดเกลี้ยงก่อนถึงจะเริ่มหัก)
    interval  = 10000, -- ทุกกี่มิลลิวินาทีถึงจะหักหนึ่งครั้ง
    amount    = 5,     -- หักครั้งละกี่หน่วยเลือด
    minHealth = 100,   -- หักลงไม่ต่ำกว่านี้ (กันตายคาที่จากความหิวล้วนๆ ตั้ง 0 ถ้าอยากให้ตายได้)
}

--- แกนทองไหลลงแล้วหลอดนอกเติมกลับไม่เต็มอีก เซิร์ฟมีระบบหิว/กระหายเองจึงกดแกนให้เต็มค้างไว้ (client/status.lua)
Config.Status.Cores = {
    enabled = true, -- false = ปล่อยให้เกมจัดการแกนเอง (แกนจะไหลลงเองตามเวลาแบบ RDR2 ปกติ)

    -- ค่าแกนที่จะกดค้างไว้ (0-100) ตั้ง nil = ไม่ยุ่งกับแกนนั้น
    health  = 100, -- แกนสุขภาพ
    stamina = 100, -- แกนสเตมินา
    deadeye = 100, -- แกนเดดอาย

    -- เติมหลอดสเตมินานอกเฉพาะตอนเปลี่ยน ped (ped ใหม่ไม่สืบค่าเดิม) ห้ามเติมทุกรอบ ไม่งั้นวิ่งเท่าไหร่ก็ไม่มีวันเหนื่อย
    staminaOnSpawn = 100,

    interval = 5000, -- ตอกซ้ำทุกกี่มิลลิวินาที (ต่ำสุด 1000)
}

-- เลือดฟื้นเองของ RDR2 ถูกปิดที่ hexa_core/client/events.lua อยากให้ฟื้นตามเกมเดิมแก้ 0.0 เป็น 1.0 ตรงนั้น ไม่ใช่ที่ไฟล์นี้

-- การตั้งค่าอื่นๆ

-- ความปลอดภัย
Config.Security = {}

-- CSRF token ตรวจฝั่ง client ล้วน server ยืนยันไม่ได้ จึงเป็นแค่สัญญาณเตือน: 'log' (แนะนำ) / 'kick' เมื่อครบ threshold ใน 10 วิ อาจโดน NUI โหลดช้า
Config.Security.CSRFFailurePolicy = 'log'
Config.Security.CSRFFailureThreshold = 5

Config.PromptDistance = 1.0 -- ระยะห่าง (เมตร) ที่ prompt ปุ่มกดโต้ตอบ (เช่น กด E เพื่อคุย) กดได้ (near)
Config.PromptVisible  = 3.0 -- ระยะห่าง (เมตร) ที่หมุดหกเหลี่ยมเริ่มโผล่ให้เห็น (far)
Config.Player.RevealMap = true -- true = เปิดแผนที่ทั้งหมดให้เห็นตั้งแต่แรก (ไม่มีหมอกบังแผนที่) / false = ต้องเดินสำรวจเองถึงจะเห็น

-- Eagle Eye (โหมดตาอินทรี - มองเห็นรอยเท้า/กลิ่น/สัตว์)

-- everyone.enabled = false แล้วจะเปิดเฉพาะอาชีพที่ตั้ง enabled = true (เพิ่มชื่อ job ตามตาราง jobs ได้ เช่น hunter = { enabled = true })
Config.EagleEye = {
    everyone = {
        enabled = true, -- true = เปิดให้ผู้เล่นทุกคนใช้ได้ / false = เปิดเฉพาะอาชีพที่ระบุด้านล่าง
    },
    vallaw = {
        enabled = false, -- ตำรวจ Valentine
    },
    rholaw = {
        enabled = false, -- ตำรวจ Rhodes
    },
}

-- Colormap — ระบายสีอาณาเขตบนแผนที่

-- ผูก hash โซนเข้ากับ blip style ด้วย native ชุด wanted region เกมวาดขอบ+สีให้เอง งานฝั่ง client ล้วน (client/colormap.lua)

-- รายชื่อ hash โซน / blip style > github.com/femga/rdr3_discoveries ที่ graphics/minimap/wanted_regions และ useful_info_from_rpfs/blip_styles

Config.Colormap = {}

Config.Colormap.Enabled = true -- false = ไม่ระบายสีโซนใดเลย (แผนที่กลับไปเป็นสีปกติของเกม)
Config.Colormap.Debug = false -- true = พิมพ์ hash ของโซนที่ทาสี/ล้างสีลง console ฝั่ง client
-- Debug = true เปิดคำสั่งช่วยหา hash ใน F8: /zonehash, /zonestyle <zone> <style>, /zonereset [zone] — ดู docs api/commands

-- ชื่อสีทางซ้ายเป็นแค่ชื่อเรียกที่ Zones อ้างถึง เฉดจริงมาจาก blip style ทางขวา เปลี่ยน/เพิ่มสีได้อิสระ ไม่ได้จำกัดที่ 6
Config.Colormap.Colors = {
    red    = 'BLIP_STYLE_WANTED_REGION',       -- แดง — โซนอันตราย / เขตหวงห้าม
    orange = 'BLIP_STYLE_MP_MISSION_GIVER',    -- ส้ม
    yellow = 'BLIP_STYLE_DEBUG_YELLOW',        -- เหลือง
    green  = 'BLIP_STYLE_DEBUG_GREEN',         -- เขียว — โซนปลอดภัย
    blue   = 'BLIP_STYLE_DEBUG_BLUE',          -- ฟ้า
    purple = 'BLIP_STYLE_FM_EVENT',            -- ม่วง
}

-- โซนที่จะทาสี — color ใส่ได้ทั้งชื่อสีจากตารางข้างบน หรือชื่อ blip style ตรงๆ ('BLIP_STYLE_TURRET_WEAPON')
Config.Colormap.Zones = {
    -- ===== AMBARINO =====
    { hash = 0x3B8DD21A, color = 'red' }, -- STATE

    -- ===== NEW AUSTIN =====
    { hash = 0x41759831, color = 'orange' }, -- STATE

    -- ===== WEST ELIZABETH =====
    { hash = 0xD69B5B49, color = 'yellow' }, -- STATE

    -- ===== NEW HANOVER =====
    { hash = 0x41332496, color = 'green' }, -- STATE

    -- ===== LEMOYNE =====
    { hash = 0x945395DF, color = 'purple' }, -- STATE

    -- ===== GUARMA =====
    { hash = 0xDC87C0C8, color = 'purple' }, -- STATE

    -- ===== ROANOKE RIDGE (ฝั่งตะวันออกของ NEW HANOVER: Annesburg + Van Horn + Roanoke) =====
    { hash = 0x30FAE29B, color = 'blue' }, -- DISTRICT: ROANOKE RIDGE
}
