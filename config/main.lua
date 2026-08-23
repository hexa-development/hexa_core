-- hexa_core / config: ทั่วไป + ระยะ prompt + ความปลอดภัย

Config = Config or {}

-- การตั้งค่าทั่วไปของเซิร์ฟเวอร์

Config.MaxPlayers = GetConvarInt('sv_maxclients', 48) -- จำนวนผู้เล่นสูงสุด ดึงค่ามาจาก convar "sv_maxclients" ใน server.cfg อัตโนมัติ (ถ้าไม่ได้ตั้งไว้จะใช้ค่าเริ่มต้น 48)
Config.IdentifierType = 'steam' -- คอลัมน์ identifier ใน users: 'steam' ต้องเปิดเกมผ่าน Steam ไม่งั้นถูกเตะตอน connect, 'license' ทุกคนมี ปลอดภัยกว่า
Config.MultiCharacter = true -- true = ใช้หน้าเลือกตัวละคร hexa_multicharacter (ปิด auto-login) / false = auto-login ตัวละครล่าสุดให้อัตโนมัติ ไม่มีหน้าเลือก
Config.DefaultSpawn = vector4(-2784.2534, -3058.2639, -12.3404, 333.5929) -- จุดเกิดเริ่มต้นของตัวละครใหม่ (x, y, z, ทิศทางที่หันหน้า) ใช้เมื่อผู้เล่นยังไม่มีตำแหน่งบันทึกไว้
Config.Debug = false -- true = เปิดข้อความ [DEBUG] ทั้งระบบ (ปิดอยู่จะไม่เสียเวลาสร้างสตริงเลย)

-- การตั้งค่าอื่นๆ

-- ความปลอดภัย
Config.Security = {}

-- CSRF token ตรวจฝั่ง client ล้วน server ยืนยันไม่ได้ จึงเป็นแค่สัญญาณเตือน: 'log' (แนะนำ) / 'kick' เมื่อครบ threshold ใน 10 วิ อาจโดน NUI โหลดช้า
Config.Security.CSRFFailurePolicy = 'log'
Config.Security.CSRFFailureThreshold = 5

Config.PromptDistance = 1.0 -- ระยะห่าง (เมตร) ที่ prompt ปุ่มกดโต้ตอบ (เช่น กด E เพื่อคุย) กดได้ (near)
Config.PromptVisible  = 3.0 -- ระยะห่าง (เมตร) ที่หมุดหกเหลี่ยมเริ่มโผล่ให้เห็น (far)
