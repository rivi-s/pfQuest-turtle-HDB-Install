# pfQuest-turtle-HDB

Turtle WoW and RavenCraft quests, maps, and interface additions for pfQuest-HDB. Its combined English SQLite database includes Vanilla and Turtle content.

HDB requests data as needed instead of loading the full gameplay database into Lua at login. Queries run asynchronously, but result decoding, map work, and garbage collection can still cause pauses. First-time results may arrive after a short delay and are cached for the session.

## Install

For normal play, use **[pfQuest-turtle-HDB-Install](https://github.com/rivi-s/pfQuest-turtle-HDB-Install)**. It includes the ready-made SQLite database and the correct addon folder layout. This repository is the source tree.

HearthDB client support is required. The existing DLL works; [0.4.1-exp.3](https://github.com/rivi-s/HearthDB/releases/tag/v0.4.1-exp.3) is an optional experimental DLL. The main HDB package uses English data. The [optional Russian pack](https://github.com/rivi-s/pfQuest-turtle-HDB/blob/main/modules/pfQuest-turtle-HDB-ruRU/README.md) is separate; check its matching-version requirements. There is no Lua database fallback.

Read the [setup, updating, troubleshooting, and hitch-capture guide](https://github.com/rivi-s/pfQuest-HDB/blob/main/SUPPORT.md). The [regular edition](https://github.com/rivi-s/pfQuest-turtle) uses Lua data and needs no HearthDB DLL.

## Features and reports

Quest objectives and turn-ins appear on the world map and minimap. Use `/db config` for settings, `/db show` for the browser, `/db journal` for the journal, and `/pfqhdb` for provider status. The extension also supplies Turtle map additions, nameplate objectives, party progress, and loot panels.

[Report an issue](https://github.com/rivi-s/pfQuest-turtle-HDB/issues) with addon/DLL versions, quest or entity ID, character level/faction, map name, coordinates, and whether the problem affects an offer, objective, or turn-in. Use the [report checklist](https://github.com/rivi-s/pfQuest-HDB/blob/main/SUPPORT.md#report-a-problem) for details.

## Project status

Maintenance focuses on occasional database corrections and reported bugs. Updates have no fixed schedule. Compatibility with Raven's Classic Era 1.14 client is unverified; work on that port is paused. These packages target the existing 1.12 client.

## Build from source

Generated SQLite files belong in install bundles, not source history. See [HDB.md](HDB.md) and [provider build details](provider/README.md) for database generation and layout.

## Credits

Original pfQuest authors: Shagu and txtsd. Original Turtle extension: Shagu, with contributors listed in the addon TOC. Rivi maintains these forks and contributes features, database corrections, and HearthDB integration.
