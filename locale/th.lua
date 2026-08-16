local Translations = {
    error = {
        not_online                  = 'ผู้เล่นไม่ได้ออนไลน์',
        wrong_format                = 'รูปแบบไม่ถูกต้อง',
        missing_args                = 'กรอกข้อมูลไม่ครบทุกช่อง (x, y, z)',
        missing_args2               = 'ต้องกรอกข้อมูลให้ครบทุกช่อง!',
        no_access                   = 'คุณไม่มีสิทธิ์ใช้คำสั่งนี้',
        company_too_poor            = 'นายจ้างของคุณไม่มีเงินจ่าย',
        item_not_exist              = 'ไม่มีไอเทมนี้ในระบบ',
        too_heavy                   = 'กระเป๋าเต็ม',
        job_not_exist               = 'ไม่มีอาชีพนี้ในระบบ',
        no_valid_license            = '[HexaCORE] - ไม่พบ Rockstar License ที่ถูกต้อง',
        no_permission               = 'คุณไม่มีสิทธิ์ทำสิ่งนี้..',
        no_waypoint                 = 'ยังไม่ได้ปักหมุดปลายทาง',
        tp_error                    = 'เกิดข้อผิดพลาดขณะเทเลพอร์ต',
        connecting_database_error   = '[HexaCORE] - เกิดข้อผิดพลาดขณะเชื่อมต่อฐานข้อมูล กรุณาตรวจสอบว่า SQL server ทำงานอยู่ และข้อมูลใน server.cfg ถูกต้อง',
        connecting_database_timeout = '[HexaCORE] - การเชื่อมต่อฐานข้อมูลหมดเวลา กรุณาตรวจสอบว่า SQL server ทำงานอยู่ และข้อมูลใน server.cfg ถูกต้อง',
    },
    success = {
        teleported_waypoint = 'เทเลพอร์ตไปยังหมุดแล้ว',
        job_set = 'ตั้งอาชีพเรียบร้อยแล้ว',
    },
    info = {
        received_paycheck = 'คุณได้รับเงินเดือนจำนวน $%{value}',
        job_info = 'อาชีพ: %{value} | ระดับ: %{value2} | เข้าเวร: %{value3}',
        on_duty = 'คุณเข้าเวรแล้ว!',
        off_duty = 'คุณออกเวรแล้ว!',
        join_server = 'ยินดีต้อนรับ %s สู่ {Server Name}',
        exploit_dropped = 'คุณถูกเตะออกจากเซิร์ฟเวอร์เนื่องจากใช้โปรแกรมโกง',
    },
    command = {
        tp = {
            help = 'เทเลพอร์ตไปหาผู้เล่นหรือพิกัด (แอดมินเท่านั้น)',
            params = {
                x = { name = 'id/x', help = 'Citizen ID หรือตำแหน่ง X' },
                y = { name = 'y', help = 'ตำแหน่ง Y' },
                z = { name = 'z', help = 'ตำแหน่ง Z' },
            },
        },
        tpm = { help = 'เทเลพอร์ตไปยังหมุด (แอดมินเท่านั้น)' },
        noclip = { help = 'เปิด/ปิดโหมดทะลุวัตถุ (แอดมินเท่านั้น)' },
        addpermission = {
            help = 'เพิ่มสิทธิ์ให้ผู้เล่น (God เท่านั้น)',
            params = {
                id = { name = 'id', help = 'Citizen ID' },
                permission = { name = 'permission', help = 'ระดับสิทธิ์' },
            },
        },
        removepermission = {
            help = 'ลบสิทธิ์ของผู้เล่น (God เท่านั้น)',
            params = {
                id = { name = 'id', help = 'Citizen ID' },
                permission = { name = 'permission', help = 'ระดับสิทธิ์' },
            },
        },
        car = {
            help = 'เรียกยานพาหนะ (แอดมินเท่านั้น)',
            params = {
                model = { name = 'model', help = 'ชื่อโมเดลของยานพาหนะ' },
            },
        },
        dv = { help = 'ลบยานพาหนะ (แอดมินเท่านั้น)' },
        dvall = { help = 'ลบยานพาหนะทั้งหมด (แอดมินเท่านั้น)' },
        dvp = { help = 'ลบ Ped ทั้งหมด (แอดมินเท่านั้น)' },
        dvo = { help = 'ลบวัตถุทั้งหมด (แอดมินเท่านั้น)' },
        givemoney = {
            help = 'ให้เงินผู้เล่น (แอดมินเท่านั้น)',
            params = {
                id = { name = 'id', help = 'Citizen ID' },
                moneytype = { name = 'moneytype', help = 'ประเภทเงิน (cash, bank, bloodmoney)' },
                amount = { name = 'amount', help = 'จำนวนเงิน' },
            },
        },
        setmoney = {
            help = 'ตั้งจำนวนเงินของผู้เล่น (แอดมินเท่านั้น)',
            params = {
                id = { name = 'id', help = 'Citizen ID' },
                moneytype = { name = 'moneytype', help = 'ประเภทเงิน (cash, bank, bloodmoney)' },
                amount = { name = 'amount', help = 'จำนวนเงิน' },
            },
        },
        job = { help = 'ตรวจสอบอาชีพของคุณ' },
        setjob = {
            help = 'ตั้งอาชีพให้ผู้เล่น (แอดมินเท่านั้น)',
            params = {
                id = { name = 'id', help = 'Citizen ID' },
                job = { name = 'job', help = 'ชื่ออาชีพ' },
                grade = { name = 'grade', help = 'ระดับอาชีพ' },
            },
        },
        me = {
            help = 'ส่งข้อความบรรยายในพื้นที่',
            params = {
                message = { name = 'message', help = 'ข้อความที่ต้องการส่ง' }
            },
        },
    },
}

-- NOTE: en.lua is loaded first by fxmanifest and uses `Lang = Lang or ...`,
-- so a `Lang or` here would keep English forever. Assign unconditionally so
-- the Thai locale (loaded last) wins. Delete/rename this file to go back to EN.
Lang = Locale:new({
    phrases = Translations,
    warnOnMissing = true
})
