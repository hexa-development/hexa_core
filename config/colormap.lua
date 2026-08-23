-- hexa_core / config: Colormap

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
