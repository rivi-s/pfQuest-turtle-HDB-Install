# pfQuest-turtle-HDB

pfQuest-turtle-HDB adds Turtle WoW content and features to
[pfQuest-HDB](https://github.com/rivi-s/pfQuest-HDB). It keeps the established
pfQuest-turtle interface while reading both the Vanilla and Turtle data sets
from one complete HearthDB SQLite database.

This is an early English-only alpha for World of Warcraft 1.12. It requires a
client with [HearthDB](https://github.com/copypasteonly/HearthDB) support and the matching pfQuest-HDB alpha. For the regular
Lua-database addon, use the
[live pfQuest-turtle project](https://github.com/rivi-s/pfQuest-turtle).

## What is included

- Turtle WoW quests, units, objects, items, spawns, and database corrections
- Turtle quest filters and world-map additions
- quest nameplate objectives
- party objective progress
- unit loot panels
- one merged English database containing Vanilla and Turtle records

The shared quest, map, journal, browser, tracker, and HearthDB adapter code lives
in pfQuest-HDB. This repository contains the Turtle-specific extension and the
tools needed to build its complete database.

## Install (embedded-provider development layout)

This unreleased layout embeds the HearthDB provider in the HDB addon folders.
Existing published alpha ZIPs still use their original separate provider layout.
Use the matching ready-to-install repository for this layout once published.

Close the client and replace the HDB addon folders. Remove legacy
`pfQuest-HearthDB` and `pfQuest-HearthDB-turtle` folders when upgrading.
Do not replace character settings in `WTF`.

Turtle uses `pfQuest` and `pfQuest-turtle`; vanilla uses only `pfQuest`.

The SQLite database belongs at `pfQuest-turtle/provider/data/pfquest-turtle.sqlite`.
The client still needs [HearthDB](https://github.com/copypasteonly/HearthDB)
installed. No separate provider addon is needed. Large Lua database files remain
outside the active load manifests; there is no Lua database fallback.

Restart and run `/pfqhdb`: it reports the database-owning addon and whether the
database opened. `/pfqhdb cacheclear` clears session query caches.

## Reporting alpha bugs

Include the quest or entity name, zone, affected feature, and full Lua error.
For map problems, say whether the issue appeared on the continent map, zone map,
or minimap. For party progress, include which character had the quest and which
character's tooltip was being viewed. For a delay, note whether it occurred only
on the first request or every time.

Content comes from the available Turtle database export plus the maintained
pfQuest-turtle corrections. A missing or incorrect record may therefore be a
source-data problem rather than a rendering problem, but both are useful alpha
reports.

## Building the complete Turtle database

The provider source is under `provider/`. Supply both source trees so the output
contains the Vanilla base and Turtle additions:

```sh
cd provider
python3 tools/build_database.py \
  --source /path/to/pfQuest-HDB \
  --turtle-source /path/to/pfQuest-turtle-HDB \
  --locales enUS \
  --output data/pfquest-turtle.sqlite
sqlite3 data/pfquest-turtle.sqlite 'PRAGMA integrity_check;'
```

Generated databases are intentionally excluded from Git. They belong in alpha
release packages so the Vanilla and Turtle repositories remain usable source
trees. See [HDB.md](HDB.md) and [provider/README.md](provider/README.md) for more
detail.

## Project background

pfQuest-turtle extends [pfQuest](https://github.com/shagu/pfQuest) with Turtle
WoW support. This HDB edition follows the live pfQuest-turtle history and keeps
Turtle-specific behavior here while shared behavior remains in pfQuest-HDB.

## Author credits

Original pfQuest-turtle author: Shagu. Existing contributors are listed in the addon TOC.

Rivi maintains this fork and contributes ongoing fixes, features, quest database corrections, and HearthDB integration.
