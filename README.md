<div align="center">

<a href="https://github.com/hexa-development">
  <img src="https://raw.githubusercontent.com/hexa-development/.github/main/assets/banner.png" alt="Hexa Development" width="880">
</a>

# HEXA CORE

### The core framework for RedM roleplay servers

A lightweight, modular foundation for players, jobs, inventory, economy, status, callbacks, permissions, and persistent character data.

<br>

[![Documentation](https://img.shields.io/badge/Documentation-Hexa_Docs-B45309?style=for-the-badge)](https://hexa-development.github.io/hexa-docs/)
[![ภาษาไทย](https://img.shields.io/badge/Docs-ภาษาไทย-D97706?style=for-the-badge)](https://hexa-development.github.io/hexa-docs/th/)
[![RedM](https://img.shields.io/badge/Platform-RedM-8B0000?style=for-the-badge)](https://redm.net/)
[![Lua](https://img.shields.io/badge/Lua-5.4-2C2D72?style=for-the-badge\&logo=lua\&logoColor=white)](https://www.lua.org/)

<br>

**Players · Jobs · Inventory · Economy · Status · Callbacks · Permissions**

</div>

---

## About

**hexa_core** is the foundation of the **Hexa Framework** ecosystem.

It is built specifically for **RedM / RDR2 roleplay servers**, providing the shared systems and APIs that other resources can build on without duplicating player, economy, inventory, permission, or persistence logic.

The framework uses a **flat API** and a straightforward relational database structure designed to stay easy to understand, extend, and maintain.

```text
RedM Server
     │
     ▼
┌──────────────────────┐
│      hexa_core       │
├──────────────────────┤
│ Players              │
│ Jobs                 │
│ Inventory            │
│ Money                │
│ Status               │
│ Callbacks            │
│ Permissions          │
│ Persistence          │
└──────────┬───────────┘
           │
           ▼
     Hexa Resources
```

---

## Features

### Built for RedM

Hexa is designed around RedM rather than treating it as a GTA framework with a cowboy hat glued on top.

Native framework support includes:

* RDR2 prompts
* Eagle Eye integration
* IPLs and interiors
* Population and density control
* Health, stamina, and Dead Eye cores
* Gold attribute cores
* Customised minimap behaviour
* RedM-specific player systems

---

### Player Object

Each connected player is represented by a server-owned player object.

```text
Player
├── Identity
├── Money
├── Inventory
├── Job
│   └── Duty State
├── Metadata
├── Status
│   ├── Hunger
│   ├── Thirst
│   ├── Cleanliness
│   └── Stress
└── Persistence State
```

The player object exposes direct methods for interacting with player data.

```lua
local Player = Core.GetPlayer(source)

if Player then
    Player.AddMoney('cash', 100, 'mission_reward')
end
```

---

### Economy

Multiple money types can be managed directly through the player object.

```lua
Player.AddMoney('cash', 100, 'mission_reward')
Player.RemoveMoney('cash', 50, 'shop_purchase')
```

Transaction reasons can be supplied so external resources can keep operations understandable and traceable.

---

### Inventory

Hexa includes inventory support with:

* Weighted items
* Slot-based storage
* Item metadata
* Item catalogue registration
* Player inventory operations
* Useable items

A key distinction exists between **registering an item type** and **giving an item to a player**:

```lua
Core.RegisterItem('bread', {
    -- item definition
})

Player.AddItem('bread', 1)
```

Think of it as:

```text
Core.RegisterItem()
        │
        ▼
Creates an item TYPE
in the server catalogue


Player.AddItem()
        │
        ▼
Creates an item INSTANCE
for a player
```

These operations previously shared similar naming. The current API separates them to make resource code clearer.

See the [upgrade guide](https://hexa-development.github.io/hexa-docs/guide/upgrading) for the complete rename table.

---

### Jobs

Player jobs support structured job data and duty state.

```text
Job
├── Name
├── Label
├── Grade
├── Grade Name
└── Duty State
```

This allows external resources to build systems such as:

* Law enforcement
* Medical roles
* Businesses
* Factions
* Whitelisted jobs
* Job-specific interactions

without owning the player job state themselves.

---

### Status & Needs

Hexa includes player status data for common roleplay mechanics.

Default needs include:

```text
Hunger
Thirst
Cleanliness
Stress
```

Additional metadata can be stored through the player data system for custom server mechanics.

---

### Two-Way Callbacks

Hexa provides callbacks between client and server.

```text
Client
   │
   │ TriggerCallback
   ▼
Server
   │
   │ CreateCallback
   ▼
Response
   │
   └──────────────► Client
```

This allows resources to request server-owned data without building custom event-response logic for every interaction.

---

### Useable Items

Resources can register items with behaviour that executes when players use them.

This keeps item definitions and gameplay resources separated while allowing external systems to hook into inventory usage cleanly.

---

### Permissions

Hexa provides a shared permission layer for resources that need controlled access.

Typical use cases include:

* Administrative commands
* Staff tools
* Developer commands
* Restricted resource actions
* Permission-gated callbacks

Resources can rely on the framework's permission state rather than implementing their own permission system.

---

### Localisation

Thai and English are included by default.

```text
Locales
├── English
└── ไทย
```

Additional languages can be added through a locale file without modifying framework logic.

---

## Persistence

Player persistence is owned by the server.

Instead of blindly saving every player on every interval, Hexa tracks whether persistent player data has changed.

```text
Player Data Changed?
       │
   ┌───┴───┐
   │       │
  No      Yes
   │       │
 Skip      ▼
       Mark Dirty
           │
           ▼
       Save Queue
           │
           ▼
        Database
```

The save system:

* Runs server-side
* Saves only changed player data
* Avoids unnecessary database writes
* Spreads saves across the configured cadence
* Prevents the entire server population from writing in a single tick

This keeps persistence predictable as player counts increase.

---

## Database

Hexa uses **MariaDB / MySQL** through [`oxmysql`](https://github.com/CommunityOx/oxmysql).

The base player data uses a flat relational layout centred around a `users` table keyed by player identifier.

### Automatic Installation

On first boot, Hexa can install its required base schema automatically using:

```text
install.sql
```

The normal startup flow is:

```text
Start Server
    │
    ▼
Start oxmysql
    │
    ▼
Start hexa_core
    │
    ▼
Check Database Schema
    │
    ├── Exists ─────► Continue
    │
    └── Missing
          │
          ▼
      Run Installer
          │
          ▼
        Ready
```

No manual import is required for the base schema under the normal installation flow.

---

## Requirements

| Requirement                                         | Description                         |
| :-------------------------------------------------- | :---------------------------------- |
| **FXServer / RedM**                                 | Recent artifact with `rdr3` support |
| **Lua 5.4**                                         | Resource runtime                    |
| **MariaDB / MySQL**                                 | Persistent player storage           |
| [`oxmysql`](https://github.com/CommunityOx/oxmysql) | Required database driver            |

`oxmysql` must start before `hexa_core`.

---

## Installation

### 1. Clone the repository

Clone `hexa_core` into your server resources directory:

```bash
git clone https://github.com/hexa-development/hexa_core.git
```

Example structure:

```text
resources/
│
└── [hexa]/
    └── hexa_core/
```

---

### 2. Configure the database

Add your `oxmysql` connection string to `server.cfg`.

```ini
set mysql_connection_string "mysql://user:password@localhost/hexa?charset=utf8mb4"
```

Replace the credentials and database name with your own configuration.

---

### 3. Configure startup order

Add:

```ini
ensure oxmysql
ensure hexa_core
```

Startup order matters.

```text
oxmysql
   │
   ▼
hexa_core
   │
   ▼
Hexa Resources
```

Any resource depending on Hexa should start after `hexa_core`.

---

### 4. Choose the identifier type

Open:

```text
config/main.lua
```

Configure:

```lua
Config.IdentifierType = 'license'
```

Available values:

```lua
Config.IdentifierType = 'license'
Config.IdentifierType = 'steam'
```

#### `license`

Recommended for most servers.

Every RedM player has a Rockstar license identifier available to FXServer.

#### `steam`

Requires the player to launch the game with Steam available.

Players without a Steam identifier will be refused during connection.

For general compatibility:

```lua
Config.IdentifierType = 'license'
```

is the safer default.

---

### 5. Start the server

On first startup, `hexa_core` checks the required database schema and installs the base tables when necessary.

Once initialization completes, resources can access the Hexa API.

---

## Quick Start

Get the core object:

```lua
local Core = exports['hexa_core']:GetCoreObject()
```

Retrieve a player on the server:

```lua
local Player = Core.GetPlayer(source)

if not Player then
    return
end
```

Add money:

```lua
Player.AddMoney(
    'cash',
    100,
    'mission_reward'
)
```

A complete example:

```lua
local Core = exports['hexa_core']:GetCoreObject()

RegisterNetEvent('example:server:reward', function()
    local src = source

    local Player = Core.GetPlayer(src)

    if not Player then
        return
    end

    Player.AddMoney(
        'cash',
        100,
        'mission_reward'
    )
end)
```

---

## API Design

Hexa uses a **flat API**.

Framework methods live directly on the core object:

```lua
Core.GetPlayer(source)
Core.RegisterItem(name, data)
```

Player methods live directly on the player object:

```lua
Player.AddMoney(type, amount, reason)
Player.AddItem(name, amount)
```

This keeps normal resource code concise:

```lua
local Core = exports['hexa_core']:GetCoreObject()

local Player = Core.GetPlayer(source)

if Player then
    Player.AddMoney('cash', 100, 'reward')
end
```

instead of requiring additional namespace layers for everyday operations.

---

## Legacy API Compatibility

The previous API syntax remains temporarily available for migration.

Old:

```lua
Core.Functions.GetPlayer(source)
Player.Functions.AddMoney('cash', 100, 'reward')
```

Current:

```lua
Core.GetPlayer(source)
Player.AddMoney('cash', 100, 'reward')
```

Legacy calls continue to work for **one release** and emit a one-time deprecation warning identifying the calling resource.

```text
Old Resource
     │
     ▼
Legacy API
     │
     ├── Still Works
     │
     └── Deprecation Warning
             │
             ▼
       Update Resource
             │
             ▼
          Flat API
```

New resources should use the flat API immediately.

For migration details, see:

### [Upgrade Guide →](https://hexa-development.github.io/hexa-docs/guide/upgrading)

---

## Architecture

Hexa keeps the core focused on shared framework responsibilities.

```text
                         ┌──────────────────┐
                         │    hexa_core     │
                         └────────┬─────────┘
                                  │
              ┌───────────────────┼───────────────────┐
              │                   │                   │
              ▼                   ▼                   ▼
       ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
       │ Hexa Banking│     │ Hexa Plants │     │ Hexa Scripts│
       └─────────────┘     └─────────────┘     └─────────────┘
                                  │
                                  ▼
                          ┌──────────────┐
                          │ hexa-bridge  │
                          └───────┬──────┘
                                  │
                    ┌─────────────┴─────────────┐
                    ▼                           ▼
                RSG Scripts                 VORP Scripts
```

Gameplay systems can remain separate resources while relying on the same player and server foundation.

This avoids turning `hexa_core` into a giant resource containing every system on the server.

---

## Resource Development

A typical Hexa resource starts by retrieving the core object:

```lua
local Core = exports['hexa_core']:GetCoreObject()
```

Then uses only the framework services it needs.

```lua
local Player = Core.GetPlayer(source)

if not Player then
    return
end

Player.AddMoney('cash', 100, 'example_reward')
```

Resources should interact with Hexa through public APIs rather than directly modifying internal player tables or framework state.

This keeps resources easier to:

* Maintain
* Debug
* Upgrade
* Reuse
* Bridge
* Document

---

## Documentation

Complete installation guides, API references, upgrade information, and development examples are available in the official documentation.

### [Open Documentation →](https://hexa-development.github.io/hexa-docs/)

### [เอกสารภาษาไทย →](https://hexa-development.github.io/hexa-docs/th/)

Documentation covers:

* Installation
* Configuration
* Core API
* Player API
* Inventory
* Economy
* Jobs
* Status
* Metadata
* Callbacks
* Events
* Permissions
* Useable items
* Persistence
* Migration
* Bridge compatibility

---

## Hexa Ecosystem

Every Hexa resource is a separate repository built on this one.

| Project | Description |
| :--- | :--- |
| **`hexa_core`** | Core framework — players, jobs, items, economy, status, callbacks, permissions <br> *(this repository)* |
| [`hexa_inventory`](https://github.com/hexa-development/hexa_inventory) | Persistent grid inventory — stashes, shops, ground drops, secure trading |
| [`hexa_progbar`](https://github.com/hexa-development/hexa_progbar) | Screen-fixed progress bar — drop-in for `ox_lib` `progressBar` |
| [`hexa-bridge`](https://github.com/hexa-development/hexa-bridge) | Compatibility layer for supported RSG and VORP resources |
| [`hexa-docs`](https://github.com/hexa-development/hexa-docs) | Official documentation and API reference (VitePress) |
| [`rdr2-unpack`](https://github.com/hexa-development/rdr2-unpack) | Read a local RDR2 install into open formats — GLB, PNG, `.ymap` JSON |
| [`txAdmin`](https://github.com/hexa-development/txAdmin) | One-click txAdmin recipe that deploys the whole Hexa stack |

Full API reference and installation guides live in [`hexa-docs`](https://github.com/hexa-development/hexa-docs) → [hexa-development.github.io/hexa-docs](https://hexa-development.github.io/hexa-docs/)

---

## hexa-bridge

Existing RedM resources do not necessarily need to be rewritten immediately when migrating to Hexa.

[`hexa-bridge`](https://github.com/hexa-development/hexa-bridge) provides compatibility layers for supported RSG and VORP APIs.

```text
Existing RSG / VORP Script
            │
            ▼
       hexa-bridge
            │
            ▼
        hexa_core
```

For new resources, use the native Hexa API directly.

For existing resources, the bridge provides a path for progressive migration.

---

## Development Status

Hexa Framework is under active development.

Framework APIs, compatibility layers, tooling, and documentation may continue to evolve as the ecosystem matures.

When updating a production server, review the documentation and upgrade guide for breaking or deprecated API changes.

---

<div align="center">

### A foundation for building RedM your way.

**Hexa Framework**

<br>

[Documentation](https://hexa-development.github.io/hexa-docs/) ·
[เอกสารภาษาไทย](https://hexa-development.github.io/hexa-docs/th/) ·
[hexa_core](https://github.com/hexa-development/hexa_core) ·
[hexa_inventory](https://github.com/hexa-development/hexa_inventory) ·
[hexa_progbar](https://github.com/hexa-development/hexa_progbar) ·
[hexa-bridge](https://github.com/hexa-development/hexa-bridge) ·
[Organization](https://github.com/hexa-development)

<br>

*Build the systems. Keep the core clean.*

</div>
