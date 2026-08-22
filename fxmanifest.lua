fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

author 'Hexa Framework'
description 'Hexa Framework - core resource'
version '3.0.0'

shared_scripts {
    'config.lua',

    'shared/log.lua',
    'shared/locale.lua',
    'locale/en.lua',
    'locale/*.lua',
    'shared/main.lua',
    'shared/weapons.lua',
    'shared/keybinds.lua'
}

client_scripts {
    'client/main.lua',
    'client/functions.lua',
    'client/spawn.lua',
    'client/density.lua',
    'client/loops.lua',
    'client/events.lua',
    'client/drawtext.lua',
    'client/prompts.lua',
    'client/pvp.lua',
    'client/status.lua',
    'client/interiors.lua',
    'client/ipls.lua',
    'client/colormap.lua',
    'client/eagleeye.lua',
    -- ท้ายสุดเสมอ ชั้นรองรับชื่อเก่าต้องเห็นฟังก์ชันจริงครบก่อนถึงจะผูก alias ได้
    'client/compat.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    -- สร้างตารางฐานข้อมูลจาก install.sql ให้อัตโนมัติตอนเริ่ม
    'server/installer.lua',
    'server/main.lua',
    -- ต้องอยู่หลัง main.lua ที่สร้างตาราง Core และก่อน player.lua ที่ใช้ codec ชุดนี้อ่านเขียนแถว users
    'server/storage.lua',
    'server/functions.lua',
    'server/jobs.lua',
    'server/items.lua',
    'server/moneyitems.lua',
    'server/player.lua',
    'server/spawn.lua',
    'server/events.lua',
    'server/commands.lua',
    -- ต้องอยู่หลัง commands.lua ที่ให้ Core.Commands.Add และหลัง player.lua ที่ให้ GetPlayer
    'server/status.lua',
    'server/exports.lua',
    'server/debug.lua',
    -- รอบกวาดเซฟ ต้องอยู่หลัง player.lua ที่ให้ Player.Save และ Core.Players
    'server/save.lua',
    -- ท้ายสุดเสมอ ชั้นรองรับชื่อเก่าต้องเห็นฟังก์ชันจริงครบก่อนถึงจะผูก alias ได้
    'server/compat.lua',
}

dependencies {
    'oxmysql',
}
