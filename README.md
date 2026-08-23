# hexa_core

The core framework for **RedM** roleplay servers - players, jobs, items, money, status, callbacks and
permissions in a single resource, on an ESX-style database layout.

Documentation: [hexa-development.github.io/hexa-docs](https://hexa-development.github.io/hexa-docs/)
&nbsp;|&nbsp; [ภาษาไทย](https://hexa-development.github.io/hexa-docs/th/)

## Features

- **Built for RedM.** Native support for RDR2 systems: prompts, eagle eye, IPLs and interiors,
  density control, the gold attribute cores, and a customised minimap.
- **ESX-style database.** A `users` table keyed by `identifier`, with an automatic schema installer
  (`install.sql`) that runs on first boot.
- **A complete player object.** Multiple money types, weighted and slotted inventory, jobs with duty
  state, metadata, and needs (hunger, thirst, cleanliness, stress).
- **Two-way callbacks.** `CreateCallback` and `TriggerCallback` between client and server, useable
  items, and exports for other resources.
- **Localisation.** Thai and English included; add a language with a single file.
- **Server-owned persistence.** The save cadence runs on the server, writes only players whose data
  actually changed, and spreads those writes so a full server does not hit the database in one tick.

## Requirements

| Requirement | Notes |
| --- | --- |
| RedM server (FXServer) | a recent artifact with `rdr3` support |
| MariaDB or MySQL | player data storage |
| [oxmysql](https://github.com/CommunityOx/oxmysql) | required, and must start before hexa_core |

## Installation

1. Clone into your resources folder:

   ```bash
   git clone https://github.com/hexa-development/hexa_core.git
   ```

2. Set the oxmysql connection string in `server.cfg`:

   ```ini
   set mysql_connection_string "mysql://user:password@localhost/hexa?charset=utf8mb4"
   ```

3. Add to `server.cfg`. Order matters:

   ```ini
   ensure oxmysql
   ensure hexa_core
   ```

4. Pick your identifier type in `config/main.lua`:

   ```lua
   Config.IdentifierType = 'license' -- 'steam' or 'license'
   ```

   With `'steam'`, players who did not launch the game through Steam are refused at connect.
   `'license'` is the safe choice - every RedM player has a Rockstar license.

5. Start the server. The installer creates the base tables on first boot.

## Usage

```lua
local Core = exports['hexa_core']:GetCoreObject()

-- server side
local Player = Core.GetPlayer(source)
if Player then
    Player.AddMoney('cash', 100, 'mission reward')
end
```

The API is flat: functions hang directly off the core object and off the player object. The older
`Core.Functions.X` and `Player.Functions.X` spellings still work for one release and print a
one-time deprecation warning naming the calling resource.

One distinction is worth learning before anything else:

```lua
Core.RegisterItem('bread', { ... }) -- adds an item TYPE to the server catalogue
Player.AddItem('bread', 1)          -- gives one bread to a person
```

These two used to share a verb. See the [upgrade
guide](https://hexa-development.github.io/hexa-docs/guide/upgrading) for the full rename table.

## Related projects

- [hexa-bridge](https://github.com/hexa-development/hexa-bridge) - run RSG and VORP scripts on
  hexa_core without code changes
- [hexa-docs](https://github.com/hexa-development/hexa-docs) - the documentation site
