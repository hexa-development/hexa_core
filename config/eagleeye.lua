-- hexa_core / config: Eagle Eye

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
