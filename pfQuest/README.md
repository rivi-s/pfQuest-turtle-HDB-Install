# pfQuest-HDB

pfQuest maps, tracker, journal, browser, and gathering tracking with an English SQLite database supplied through HearthDB.

HDB requests data as needed instead of loading the full gameplay database into Lua at login. Queries run asynchronously, but result decoding, map work, and garbage collection can still cause pauses. First-time results may arrive after a short delay and are cached for the session.

## Install

For normal play, use **[pfQuest-HDB-Install](https://github.com/rivi-s/pfQuest-HDB-Install)**. It includes the ready-made SQLite database and the correct addon folder layout. This repository is the source tree.

HearthDB client support is required. The existing DLL works; [0.4.1-exp.3](https://github.com/rivi-s/HearthDB/releases/tag/v0.4.1-exp.3) is an optional experimental DLL. The main HDB package uses English data. There is no Lua database fallback.

Read the [setup, updating, troubleshooting, and hitch-capture guide](https://github.com/rivi-s/pfQuest-HDB/blob/main/SUPPORT.md). The [regular edition](https://github.com/rivi-s/pfQuest) uses Lua data and needs no HearthDB DLL.

## Features and reports

Quest objectives and turn-ins appear on the world map and minimap. Use `/db config` for settings, `/db show` for the browser, `/db journal` for the journal, and `/pfqhdb` for provider status.

[Report an issue](https://github.com/rivi-s/pfQuest-HDB/issues) with addon/DLL versions, quest or entity ID, character level/faction, map name, coordinates, and whether the problem affects an offer, objective, or turn-in. Use the [report checklist](https://github.com/rivi-s/pfQuest-HDB/blob/main/SUPPORT.md#report-a-problem) for details.

## Project status

Maintenance focuses on occasional database corrections and reported bugs. Updates have no fixed schedule. Compatibility with Raven's Classic Era 1.14 client is unverified; work on that port is paused. These packages target the existing 1.12 client.

## Build from source

Generated SQLite files belong in install bundles, not source history. See [HDB.md](HDB.md) and [provider build details](provider/README.md) for database generation and layout.

## Credits

Original pfQuest authors: Shagu and txtsd. Original Turtle extension: Shagu, with contributors listed in the addon TOC. Rivi maintains these forks and contributes features, database corrections, and HearthDB integration.
