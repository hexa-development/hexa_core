-- ============================================================
-- hexa_core - โครงสร้างฐานข้อมูลหลัก (ติดตั้งอัตโนมัติตอน resource start)
-- ============================================================
-- ติดตั้งอัตโนมัติโดย server/installer.lua ไม่ต้อง import เอง
--
-- ตาราง users คีย์ด้วย identifier (license)
-- คอลัมน์แยกกันชัดเจน (accounts, job, job_grade, firstname, ...)
-- เพิ่ม citizenid ไว้เป็นเลขประจำตัวแบบเรียงลำดับ (ใช้กับคำสั่ง admin
-- และตารางของ resource อื่นที่อ้างอิงตัวละครด้วย citizenid)
--
-- ทุก statement เป็น idempotent (CREATE TABLE IF NOT EXISTS)
-- รันซ้ำทุกครั้งที่บูตได้อย่างปลอดภัย

-- ------------------------------------------------------------
-- users
-- ------------------------------------------------------------
-- identifier = steam hex / license ของผู้เล่น (1 คน มีได้หลายตัวละคร -> ไม่ใช่ PRIMARY KEY)
-- citizenid  = เลขประจำตัวละคร = PRIMARY KEY (1 แถว = 1 ตัวละคร)
--              *สำคัญ* ถ้าตั้ง PK เป็น identifier จะได้แค่ 1 ตัวละครต่อคน
--              และการ INSERT ... ON DUPLICATE KEY UPDATE จะไปทับตัวละครเดิมทิ้ง
-- accounts   = json เงินทุกประเภท {cash, bank, gold} (bank = บัญชีธนาคารรวมทุกสาขา)
-- inventory  = json ของทั่วไป {"bread":2,"water":1} (*ไม่รวมอาวุธ*)
-- loadout    = json อาวุธ {"weapon_revolver_navy":{"ammo":24,"components":[],"tintIndex":0}}
--              อาวุธแยกออกจาก inventory เด็ดขาด ตัวตัดสินคือ Shared.IsWeapon()
--              แถวเก่าที่อาวุธยังปนอยู่ใน inventory จะถูกแปลงให้อัตโนมัติโดย server/storage.lua
-- metadata   = json สถานะทั้งหมด (hunger, thirst, isdead, fingerprint, ...)
-- status     = json สถานะแบบย่อ {hunger, thirst, cleanliness, stress}
CREATE TABLE IF NOT EXISTS `users` (
    `identifier` VARCHAR(60) NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `accounts` LONGTEXT DEFAULT NULL,
    `group` VARCHAR(50) DEFAULT 'user',
    `job` VARCHAR(50) DEFAULT 'unemployed',
    `job_grade` INT(11) DEFAULT 0,
    `firstname` VARCHAR(50) DEFAULT NULL,
    `lastname` VARCHAR(50) DEFAULT NULL,
    `dateofbirth` VARCHAR(25) DEFAULT NULL,
    `sex` VARCHAR(10) DEFAULT 'm',
    `position` LONGTEXT DEFAULT NULL,
    `skin` LONGTEXT DEFAULT NULL,
    `inventory` LONGTEXT DEFAULT NULL,
    `loadout` LONGTEXT DEFAULT NULL,
    `metadata` LONGTEXT DEFAULT NULL,
    `status` LONGTEXT DEFAULT NULL,
    `is_dead` TINYINT(1) DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `last_seen` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`),
    KEY `idx_users_identifier` (`identifier`),
    KEY `idx_users_last_seen` (`last_seen`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------
-- migration: ตาราง users เวอร์ชันแรกตั้ง PRIMARY KEY เป็น identifier
-- ทำให้ 1 คนมีได้ตัวละครเดียว + สร้างตัวใหม่ไปทับตัวเก่า
-- ย้าย PK มาที่ citizenid ทำใน server/installer.lua (migrateUsersPrimaryKey) ไม่ใช่ตรงนี้ เพราะ DROP PRIMARY KEY + ADD PRIMARY KEY ไม่ error บน DB ที่ย้ายแล้ว แต่สั่ง rebuild ตาราง users ทั้งใบซ้ำทุกครั้งที่บูต
-- ------------------------------------------------------------
ALTER TABLE `users` DROP INDEX `idx_users_citizenid`;
ALTER TABLE `users` ADD INDEX `idx_users_identifier` (`identifier`);

-- ------------------------------------------------------------
-- migration: คอลัมน์ inventory / loadout
-- ------------------------------------------------------------
-- DB ที่สร้างก่อนมีคอลัมน์พวกนี้ต้องเติมเข้าไป (DB ใหม่จะ fail แบบ benign แล้วข้ามไป)
-- การย้ายข้อมูลอาวุธจาก inventory เดิมไป loadout ทำใน server/storage.lua
-- เพราะต้องแกะ JSON ทีละแถว ทำใน SQL ล้วนไม่ได้
ALTER TABLE `users` ADD COLUMN `inventory` LONGTEXT DEFAULT NULL;
ALTER TABLE `users` ADD COLUMN `loadout` LONGTEXT DEFAULT NULL;

-- ------------------------------------------------------------
-- jobs + job_grades
-- ------------------------------------------------------------
-- อาชีพทั้งหมดโหลดจาก 2 ตารางนี้ตอน server บูต (server/jobs.lua)
-- shared/jobs.lua เป็นแค่ค่า fallback ถ้าตารางว่าง
-- คอลัมน์เสริมของ hexa: type, default_duty, offduty_pay, isboss
CREATE TABLE IF NOT EXISTS `jobs` (
    `name` VARCHAR(50) NOT NULL,
    `label` VARCHAR(100) DEFAULT NULL,
    `type` VARCHAR(50) DEFAULT NULL,
    `default_duty` TINYINT(1) DEFAULT 0,
    `offduty_pay` TINYINT(1) DEFAULT 0,
    `whitelisted` TINYINT(1) DEFAULT 0,
    PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `job_grades` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `job_name` VARCHAR(50) NOT NULL,
    `grade` INT(11) NOT NULL,
    `name` VARCHAR(50) DEFAULT NULL,
    `label` VARCHAR(50) DEFAULT NULL,
    `salary` INT(11) DEFAULT 0,
    `isboss` TINYINT(1) DEFAULT 0,
    `skin_male` LONGTEXT DEFAULT NULL,
    `skin_female` LONGTEXT DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `idx_job_grades` (`job_name`, `grade`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- seed อาชีพเริ่มต้น (ตรงกับ shared/jobs.lua) - INSERT IGNORE จึงรันซ้ำได้
-- แก้ไข/เพิ่มอาชีพภายหลังให้แก้ใน DB โดยตรง แล้ว restart hexa_core
INSERT IGNORE INTO `jobs` (`name`, `label`, `type`, `default_duty`, `offduty_pay`, `whitelisted`) VALUES
    ('unemployed', 'Civilian', NULL, 1, 0, 0),
    ('vallaw', 'Valentine Law Enforcement', 'leo', 0, 0, 1),
    ('rholaw', 'Rhodes Law Enforcement', 'leo', 0, 0, 1),
    ('blklaw', 'Blackwater Law Enforcement', 'leo', 0, 0, 1),
    ('strlaw', 'Strawberry Law Enforcement', 'leo', 0, 0, 1),
    ('stdenlaw', 'Saint Denis Law Enforcement', 'leo', 0, 0, 1),
    ('medic', 'Medic', 'medic', 0, 0, 1);

INSERT IGNORE INTO `job_grades` (`job_name`, `grade`, `name`, `label`, `salary`, `isboss`) VALUES
    ('unemployed', 0, 'Freelancer', 'Freelancer', 3, 0),
    ('vallaw', 0, 'Recruit', 'Recruit', 10, 0),
    ('vallaw', 1, 'Deputy', 'Deputy', 25, 0),
    ('vallaw', 2, 'Sheriff', 'Sheriff', 50, 1),
    ('rholaw', 0, 'Recruit', 'Recruit', 10, 0),
    ('rholaw', 1, 'Deputy', 'Deputy', 25, 0),
    ('rholaw', 2, 'Sheriff', 'Sheriff', 50, 1),
    ('blklaw', 0, 'Recruit', 'Recruit', 10, 0),
    ('blklaw', 1, 'Deputy', 'Deputy', 25, 0),
    ('blklaw', 2, 'Sheriff', 'Sheriff', 50, 1),
    ('strlaw', 0, 'Recruit', 'Recruit', 10, 0),
    ('strlaw', 1, 'Deputy', 'Deputy', 25, 0),
    ('strlaw', 2, 'Sheriff', 'Sheriff', 50, 1),
    ('stdenlaw', 0, 'Recruit', 'Recruit', 10, 0),
    ('stdenlaw', 1, 'Deputy', 'Deputy', 25, 0),
    ('stdenlaw', 2, 'Sheriff', 'Sheriff', 50, 1),
    ('medic', 0, 'Recruit', 'Recruit', 5, 0),
    ('medic', 1, 'Trainee', 'Trainee', 25, 0),
    ('medic', 2, 'Doctor', 'Doctor', 50, 0),
    ('medic', 3, 'Surgeon', 'Surgeon', 75, 0),
    ('medic', 4, 'Manager', 'Manager', 100, 1);

-- ------------------------------------------------------------
-- items
-- ------------------------------------------------------------
-- ไอเทมทั้งหมดโหลดจากตารางนี้ตอน server บูต (server/items.lua)
CREATE TABLE IF NOT EXISTS `items` (
    `name` VARCHAR(50) NOT NULL,
    `label` VARCHAR(100) NOT NULL,
    `weight` INT(11) NOT NULL DEFAULT 1,
    `rare` TINYINT(1) NOT NULL DEFAULT 0,
    `can_remove` TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- seed ไอเทมเริ่มต้น - INSERT IGNORE จึงรันซ้ำได้
-- เพิ่ม/แก้ไอเทมภายหลังให้แก้ใน DB โดยตรง แล้ว restart hexa_core
--
-- ★ อาวุธ *ไม่ต้อง* มีแถวที่นี่ — server/items.lua รวม Shared.Weapons
--   (shared/weapons.lua) เข้าแคตตาล็อกให้เองตอนบูต
-- ★ 'birdpost' กับ 'paper' ก็ไม่อยู่ที่นี่ — hexa_telegram แทรกเองตอนบูต
--   (ดู hexa_telegram/sql/install.sql)
--
-- น้ำหนักคิดเป็น "% ของที่แบกได้" ผู้เล่นแบกได้ 100 (hexa_core Config.Player
-- PlayerDefaults.weight) ของกินของใช้จึงตั้งไว้ 1 = แบกได้อย่างละ 100 ชิ้น
INSERT IGNORE INTO `items` (`name`, `label`, `weight`) VALUES
    -- อาหาร
    ('bread',        'ขนมปัง',        1),
    ('biscuit',      'บิสกิต',        1),
    ('canned_beans', 'ถั่วกระป๋อง',    1),
    ('salted_meat',  'เนื้อเค็ม',      1),
    ('cheese',       'ชีส',           1),
    ('apple',        'แอปเปิล',       1),
    -- เครื่องดื่ม
    ('water',        'น้ำดื่ม',        1),
    ('coffee',       'กาแฟ',          1),
    ('beer',         'เบียร์',         1),
    ('whiskey',      'วิสกี้',         1),
    ('wine',         'ไวน์',          1),
    -- ยารักษา
    ('bandage',      'ผ้าพันแผล',      1),
    ('firstaid',     'ชุดปฐมพยาบาล',   2),
    ('health_tonic', 'ยาบำรุงกำลัง',   1),
    ('medicine',     'ยา',            1),
    -- ------------------------------------------------------------
    -- ไอเทมของระบบ (ห้ามเอาไปขายในร้าน)
    -- ------------------------------------------------------------
    -- ทั้งสองตัวใช้ได้ก็ต่อเมื่อมี info ติดมากับชิ้นนั้น ('clothes' ต้องมี
    -- info.outfit_id / 'toilet' ต้องมี info.presetid) ร้านค้าใส่ info ไม่ได้
    -- ซื้อเปล่า ๆ ไปก็กดใช้แล้วไม่เกิดอะไร — murphy_* เป็นคนแจกตอนซื้อชุด/ทรง
    --
    -- แต่ *ต้องมีแถวตรงนี้* ไม่งั้น hexa_inventory:AddItem คืน false ทันที
    -- (server/exports.lua: `if not itemInfo then return false end`)
    -- แล้วผู้เล่นจ่ายเงินซื้อชุดแต่ไม่ได้ไอเทมกลับมาแบบเงียบ ๆ
    --
    -- ★ ห้ามเขียนคอมเมนต์ไว้ "ท้ายบรรทัดเดียวกับ SQL" ในไฟล์นี้
    --   server/installer.lua ตัดเฉพาะบรรทัดที่ขึ้นต้นด้วย -- ทั้งบรรทัด
    --   (stripComments) คอมเมนต์ท้ายบรรทัดจะรอดมาแล้วไปเกาะหัว statement ถัดไป
    --   clothes = murphy_clothing Config.OutfitItem
    --   toilet  = murphy_barber   Config.OverlayItem
    ('clothes',      'ชุดเสื้อผ้า',     2),
    ('toilet',       'ชุดแต่งหน้า',     1);

-- ฐานข้อมูลที่สร้างไว้ก่อนหน้านี้จะมี 'bread'/'water' เป็นชื่ออังกฤษอยู่ เพราะ
-- INSERT IGNORE ไม่แตะแถวที่มีแล้ว อยากให้เป็นไทยเหมือนตัวอื่นก็รันครั้งเดียว:
--   UPDATE `items` SET `label` = 'ขนมปัง' WHERE `name` = 'bread';
--   UPDATE `items` SET `label` = 'น้ำดื่ม' WHERE `name` = 'water';

-- ============================================================
-- ตารางของระบบกระเป๋า (hexa_inventory)
-- ============================================================
-- hexa_inventory ไม่มี install.sql / installer ของตัวเองแล้ว โครงสร้างฐานข้อมูล
-- ทั้งหมดของสแต็กอยู่ในไฟล์นี้ไฟล์เดียว เพื่อไม่ให้มี installer สองตัวแข่งกันสร้าง
-- ตารางเดียวกัน (แข่งกันแล้วมีสิทธิ์เจอ deadlock/แถวซ้ำ) และเพื่อให้มีลำดับที่แน่นอน
-- เสมอ: hexa_core บูตก่อน hexa_inventory จึงมั่นใจได้ว่าตารางพร้อมก่อนถูกใช้
--
-- hexa_inventory รอสคีมาผ่าน exports['hexa_core']:AwaitSchemaReady(ms)

-- ------------------------------------------------------------
-- users_vault - กระเป๋าถาวรที่ไม่ใช่ของผู้เล่น (สแตช/ตู้เซฟ/กระเป๋าม้า ฯลฯ)
-- ------------------------------------------------------------
-- ทุกอย่างที่ไม่ใช่ 'player' / 'otherplayer-<id>' / 'drop-<id>' ถือเป็น stash
-- และลงตารางนี้ (ดู Inventory.GetIdentifier ใน hexa_inventory/server/functions.lua)
-- `identifier` เป็นสตริงอิสระ เช่น hexa_horse_12, hexa_wagon_3
--
-- hexa_inventory/server/main.lua โหลดทุกแถวตอนบูต
-- การเซฟใช้ INSERT ... ON DUPLICATE KEY UPDATE คีย์ด้วย `identifier`
-- จึงต้องตั้ง `identifier` เป็น UNIQUE
--
-- เดิมชื่อ `inventories` — DB เก่าให้เปลี่ยนชื่อเองครั้งเดียวก่อนบูต:
--   RENAME TABLE `inventories` TO `users_vault`;
-- (ไม่ใส่ไว้ในไฟล์นี้เพราะ installer รันทุกครั้งที่บูต ถ้าใส่แล้วมีทั้งสองตาราง
--  อยู่พร้อมกันจะพังแบบเงียบๆ ยากกว่าเดิม)
--
-- โครงเก็บของเหมือนตาราง users ทุกประการ (ใช้ codec ชุดเดียวกันใน server/storage.lua):
--   items    = ของทั่วไป  {"bread":2,"water":1}   (*ไม่รวมอาวุธ*)
--   loadout  = อาวุธ            {"weapon_bow":{"ammo":0,"components":[],"tintIndex":0,"serie":"..."}}
--
-- ของเดิมคอลัมน์ items เก็บ "ช่องเก็บของทั้งก้อน" ดิบ ๆ ซึ่งซ้ำซ้อนกับแคตตาล็อกไอเทม
-- ทุกแถว (image/label/description/weight/type/unique/useable/shouldClose อ่านจาก
-- Shared.Items ได้อยู่แล้ว) กินพื้นที่หลายเท่าตัวโดยไม่ได้ข้อมูลอะไรเพิ่ม
CREATE TABLE IF NOT EXISTS `users_vault` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(255) NOT NULL,
    `items` LONGTEXT DEFAULT NULL,
    `loadout` LONGTEXT DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------
-- migration: คอลัมน์ loadout ของ users_vault
-- ------------------------------------------------------------
-- DB ที่สร้างก่อนมีคอลัมน์นี้ต้องเติมเข้าไป (DB ใหม่จะ fail แบบ benign แล้วข้ามไป)
-- การย้ายอาวุธจาก items เดิมไป loadout + ตัดฟิลด์ที่ซ้ำกับแคตตาล็อกออก ทำใน
-- hexa_inventory/server/vault_store.lua ตอนบูต เพราะต้องแกะ JSON ทีละแถว
ALTER TABLE `users_vault` ADD COLUMN `loadout` LONGTEXT DEFAULT NULL;

-- ------------------------------------------------------------
-- item_drops - ของที่ทิ้งไว้บนพื้น (ถุงของ)
-- ------------------------------------------------------------
-- เดิมถุงของเก็บไว้ในหน่วยความจำอย่างเดียว (ตัวแปร Drops) พอ restart resource
-- หรือ restart เซิร์ฟเวอร์ ตารางนั้นว่างเปล่าแต่ object ถุงยังค้างอยู่ในโลก
-- กลายเป็นถุงผีที่เปิดไม่ได้ หยิบไม่ได้ ของข้างในหายหมด
--
-- ตารางนี้ทำให้ถุงกลับมาได้หลังบูต: server/drops/store.lua จะโหลดทุกแถว
-- แล้ว spawn object ถุงขึ้นมาใหม่ที่พิกัดเดิม
--
-- *ห้ามเก็บ network id เป็นคีย์* — network id เกิดใหม่ทุกครั้งที่ spawn object
-- คีย์จริงคือ `id` (auto increment) ส่วน network id เป็นค่าชั่วคราวตอนรันไทม์
--
-- `created_at` ใช้กับตัวเก็บกวาดถุงเก่า (config.CleanupDropTime) ถุงที่หมดอายุ
-- ระหว่างเซิร์ฟเวอร์ปิดอยู่จะถูกลบทิ้งตอนบูตแทนที่จะ spawn กลับมา
CREATE TABLE IF NOT EXISTS `item_drops` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `items` LONGTEXT NOT NULL,
    `x` DOUBLE NOT NULL DEFAULT 0,
    `y` DOUBLE NOT NULL DEFAULT 0,
    `z` DOUBLE NOT NULL DEFAULT 0,
    `created_at` INT(11) NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_item_drops_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------
-- ตารางที่ถูกยกเลิกไปแล้ว (ลบทิ้งได้ถ้ายังค้างอยู่ใน DB เก่า)
-- ------------------------------------------------------------
--   shop_stock         สต็อกร้านค้าข้ามรีสตาร์ท — ยกเลิก สต็อกอยู่ในหน่วยความจำ
--                      รีเซ็ตเป็นค่าตั้งต้นทุกครั้งที่บูต (ทุกร้านใน hexa_store
--                      ตั้ง persistentStock = false อยู่แล้ว)
--   player_weapons     ทะเบียนเลขซีเรียลอาวุธ — ยกเลิก ซ้ำซ้อนกับ users.loadout
--                      ซึ่งเก็บ serie ของอาวุธแต่ละกระบอกไว้ให้แล้ว เจ้าของปืน
--                      คือคนที่ loadout มีซีเรียลนั้นอยู่
--   owned_accessories  เครื่องประดับรายตัวละคร — ยกเลิกทั้งฟีเจอร์
--
-- ไม่ได้ใส่ DROP TABLE ไว้โดยตั้งใจ: installer รันทุกครั้งที่บูต ถ้าใส่ DROP ไว้
-- ข้อมูลจะหายทันทีโดยไม่มีทางกู้ ถ้าต้องการเก็บกวาดให้รันเองครั้งเดียวใน DB:
--   DROP TABLE IF EXISTS `shop_stock`, `player_weapons`, `owned_accessories`;
