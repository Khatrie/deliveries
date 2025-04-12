fx_version 'cerulean'

game 'gta5'
description 'SD Logging'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua',
}

client_scripts{
    'client/*.lua',
}

server_scripts{
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua',
}

dependency{
    'oxmysql',
}
