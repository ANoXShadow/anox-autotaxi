fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'anox-autotaxi'
author 'Anox Studio'
description 'AUTO TAXI script compatible with ESX, QBCore, and QBox'
version '1.0.1'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/*.lua',
    'bridge/loader.lua'
}

client_scripts {
    'bridge/client/*.lua',
    'client/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server/*.lua',
    'server/*.lua'
}

files {
    'locales/*.json'
}

dependencies {
    'ox_lib',
    'oxmysql'
}