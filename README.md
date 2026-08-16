# hexa_core

The core framework for **RedM** roleplay servers — players, jobs, items, money, status, callbacks, and permissions in a single resource, with an ESX-style database layout.

📖 Full documentation: [hexa-development.github.io/hexa-docs](https://hexa-development.github.io/hexa-docs/)

## Features

- 🤠 **Built for RedM** — native support for RDR2 systems: prompts, eagle eye, IPLs/interiors, density control, and a customized minimap
- 🗄️ **ESX-style database** — a `users` table keyed by `identifier`, with an automatic schema installer (`install.sql`)
- 🧩 **Complete player object** — multiple money types, weighted/slotted inventory, jobs with duty state, metadata, and needs (hunger/thirst)
- 📡 **Two-way callbacks** — `TriggerCallback` between client ↔ server, useable items, and exports for other resources
- 🌏 **Localization** — locale system with Thai and English included; add a language with a single file
- 🛡️ **Security-minded** — SQL exploit detection, multi-level permissions, routing bucket helpers, and automatic event logging

## Requirements

| Requirement | Notes |
| --- | --- |
| RedM Server (FXServer) | recent artifact with `rdr3` support |
| MariaDB / MySQL | player data storage |
| [oxmysql](https://github.com/CommunityOx/oxmysql) | required dependency — must start before hexa_core |

## Installation

1. Clone into your resources folder:

   ```bash
   git clone https://github.com/hexa-development/hexa_core.git
   ```

2. Set the oxmysql connection string in `server.cfg`:

   ```ini
   set mysql_connection_string "mysql://user:password@localhost/hexa?charset=utf8mb4"
   ```

3. Add to `server.cfg` (order matters):

   ```ini
   ensure oxmysql
   ensure hexa_core
   ```

4. Pick your identifier type in `config.lua`:

   ```lua
   Config.IdentifierType = 'license' -- 'steam' or 'license'
   ```

   > ⚠️ With `'steam'`, players not running the game through Steam are kicked on connect. `'license'` (Rockstar license) is the safe choice — every RedM player has one.

5. Start the server. On first boot the installer creates all base tables automatically.

## Usage

Grab the core object from any resource:

```lua
local HexaCore = exports['hexa_core']:GetCoreObject()

-- server-side example
local Player = HexaCore.Functions.GetPlayer(source)
if Player then
    Player.Functions.AddMoney('cash', 100, 'mission reward')
end
```

See the [API reference](https://hexa-development.github.io/hexa-docs/api/server-functions) for the full function list.

## Related projects

- [hexa-bridge](https://github.com/hexa-development/hexa-bridge) — run RSG/VORP scripts on hexa_core without code changes
- [hexa-docs](https://github.com/hexa-development/hexa-docs) — this documentation website
