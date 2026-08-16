fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'

description 'Hexa Developments'
version '2.3.10'

shared_scripts {
    'config.lua',

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
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    -- auto-create base DB tables from install.sql on start
    'server/installer.lua',
    'server/main.lua',
    -- ต้องอยู่หลัง main.lua เพราะ main.lua สั่ง HexaCore = {} (รีเซ็ตทั้งก้อน)
    -- ถ้าโหลดก่อน HexaCore.Storage จะถูกล้างทิ้ง
    -- และต้องอยู่ก่อน player.lua ซึ่งใช้ codec ชุดนี้เข้ารหัส/ถอดรหัสแถว users
    'server/storage.lua',
    'server/functions.lua',
    'server/jobs.lua',
    'server/items.lua',
    'server/moneyitems.lua',
    'server/player.lua',
    'server/spawn.lua',
    'server/events.lua',
    'server/commands.lua',
    -- ต้องอยู่หลัง commands.lua (ใช้ HexaCore.Commands.Add) และหลัง player.lua (ใช้ GetPlayer)
    'server/status.lua',
    'server/exports.lua',
    'server/debug.lua'
}

dependencies {
    'oxmysql',
}
