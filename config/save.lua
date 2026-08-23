-- hexa_core / config: รอบกวาดเซฟลงฐานข้อมูล

-- การบันทึกข้อมูลผู้เล่นลงฐานข้อมูล

-- รอบกวาดเซฟเดินฝั่ง server เท่านั้น (client ไม่ยิงก็ไม่มีวันเซฟ) และเขียนเฉพาะคนที่ข้อมูลเปลี่ยนจริง ดู docs guide/persistence
Config.Save = {}

Config.Save.Interval = 45 -- ทุกกี่นาทีถึงจะกวาดเซฟหนึ่งรอบ (ต่ำสุด 1) แนะนำ 30-60
Config.Save.SpreadSeconds = 60 -- เกลี่ยการเขียนของแต่ละคนให้กระจายภายในกี่วินาที กัน 48 คนยิง MySQL พร้อมกัน
Config.Save.OnDrop = true -- เซฟทันทีตอนผู้เล่นหลุด (ควรเปิดไว้ ไม่งั้นเสียความคืบหน้าตั้งแต่รอบกวาดล่าสุด)
Config.Save.OnResourceStop = true -- เซฟทุกคนก่อน resource หยุดหรือเซิร์ฟปิด

-- ชื่อเดิมของ Config.Save.Interval ยังอ่านได้อยู่เพื่อไม่ให้คอนฟิกเก่าพัง
Config.UpdateInterval = Config.Save.Interval
