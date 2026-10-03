# pfQuest-turtle-HDB-Install

This unreleased development layout includes the embedded HearthDB provider and
ready-made English SQLite database. Existing published alpha ZIPs are unchanged.
The client still requires HearthDB support: https://github.com/copypasteonly/HearthDB

## Install or update

1. Close World of Warcraft.
2. Download and extract this repository's ZIP.
3. Remove the old `pfQuest` and `pfQuest-turtle` addon folders.
4. Remove legacy `pfQuest-HearthDB` and `pfQuest-HearthDB-turtle` addon folders.
5. Copy `pfQuest` and `pfQuest-turtle` from this package into `Interface/AddOns`.
6. Restart and run `/pfqhdb` to verify the database opened.

Settings in `WTF` are preserved. There is no separate provider addon or large
Lua database loading. This edition requires HearthDB and has no Lua fallback.

The combined SQLite database is inside `pfQuest-turtle/provider/data/pfquest-turtle.sqlite`.
