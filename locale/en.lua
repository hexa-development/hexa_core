local Translations = {
    error = {
        not_online                  = 'Player not online',
        wrong_format                = 'Incorrect format',
        missing_args                = 'Not every argument has been entered (x, y, z)',
        missing_args2               = 'All arguments must be filled out!',
        no_access                   = 'No access to this command',
        company_too_poor            = 'Your employer is broke',
        item_not_exist              = 'Item does not exist',
        too_heavy                   = 'Inventory too full',
        job_not_exist               = 'Job does not exist',
        no_valid_license            = '[HexaCORE] - No Valid Rockstar License Found',
        no_permission               = 'You don\'t have permissions for this..',
        no_waypoint                 = 'No Waypoint Set.',
        tp_error                    = 'Error While Teleporting.',
        connecting_database_error   = '[HexaCORE] - An error occurred while connecting to the database. Ensure that the SQL server is running and that the details in the server.cfg file are correct.',
        connecting_database_timeout = '[HexaCORE] - The database connection has timed out. Ensure that the SQL server is running and that the details in the server.cfg file are correct.',
    },
    success = {
        teleported_waypoint = 'Teleported To Waypoint.',
        job_set = 'Job set successfully',
    },
    info = {
        received_paycheck = 'You received your paycheck of $%{value}',
        job_info = 'Job: %{value} | Grade: %{value2} | Duty: %{value3}',
        on_duty = 'You are now on duty!',
        off_duty = 'You are now off duty!',
        join_server = 'Welcome %s to {Server Name}.',
        exploit_dropped = 'You Have Been Kicked For Exploitation',
    },
    command = {
        tp = {
            help = 'TP To Player or Coords (Admin Only)',
            params = {
                x = { name = 'id/x', help = 'Citizen ID or X position' },
                y = { name = 'y', help = 'Y position' },
                z = { name = 'z', help = 'Z position' },
            },
        },
        tpm = { help = 'TP To Marker (Admin Only)' },
        noclip = { help = 'No Clip (Admin Only)' },
        addpermission = {
            help = 'Give Player Permissions (God Only)',
            params = {
                id = { name = 'id', help = 'Citizen ID' },
                permission = { name = 'permission', help = 'Permission level' },
            },
        },
        removepermission = {
            help = 'Remove Player Permissions (God Only)',
            params = {
                id = { name = 'id', help = 'Citizen ID' },
                permission = { name = 'permission', help = 'Permission level' },
            },
        },
        car = {
            help = 'Spawn Vehicle (Admin Only)',
            params = {
                model = { name = 'model', help = 'Model name of the vehicle' },
            },
        },
        dv = { help = 'Delete Vehicle (Admin Only)' },
        dvall = { help = 'Delete All Vehicles (Admin Only)' },
        dvp = { help = 'Delete All Peds (Admin Only)' },
        dvo = { help = 'Delete All Objects (Admin Only)' },
        givemoney = {
            help = 'Give A Player Money (Admin Only)',
            params = {
                id = { name = 'id', help = 'Citizen ID' },
                moneytype = { name = 'moneytype', help = 'Type of money (cash, bank, bloodmoney)' },
                amount = { name = 'amount', help = 'Amount of money' },
            },
        },
        setmoney = {
            help = 'Set Players Money Amount (Admin Only)',
            params = {
                id = { name = 'id', help = 'Citizen ID' },
                moneytype = { name = 'moneytype', help = 'Type of money (cash, bank, bloodmoney)' },
                amount = { name = 'amount', help = 'Amount of money' },
            },
        },
        job = { help = 'Check Your Job' },
        setjob = {
            help = 'Set A Players Job (Admin Only)',
            params = {
                id = { name = 'id', help = 'Citizen ID' },
                job = { name = 'job', help = 'Job name' },
                grade = { name = 'grade', help = 'Job grade' },
            },
        },
        me = {
            help = 'Show local message',
            params = {
                message = { name = 'message', help = 'Message to send' }
            },
        },
    },
}

Lang = Lang or Locale:new({
    phrases = Translations,
    warnOnMissing = true
})
