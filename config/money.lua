-- hexa_core / config: ระบบเงิน

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
