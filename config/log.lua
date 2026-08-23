-- hexa_core / config: ปลายทางของ log

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
