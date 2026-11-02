# pfQuest-HDB setup and troubleshooting

## Requirements and edition choice

Use the [Vanilla install bundle](https://github.com/rivi-s/pfQuest-HDB-Install) or the [Turtle/Raven install bundle](https://github.com/rivi-s/pfQuest-turtle-HDB-Install). They contain the addon files and ready-made English SQLite database. Source repositories contain build tools and are intended for development.

HDB requires a supported 1.12 client with the HearthDB DLL and its plugin loader. A regular pfQuest installation needs no HearthDB DLL. HDB has no Lua-database fallback if the client component or SQLite file is missing.

The existing HearthDB DLL remains supported through paged queries. The [0.4.1-exp.3 DLL](https://github.com/rivi-s/HearthDB/releases/tag/v0.4.1-exp.3) is an optional experimental replacement that spreads native result delivery across frames. It is a separate download, not a requirement to update the addons. It does not guarantee the removal of every hitch or GC pause.

To change that DLL, fully exit the game, back up the existing `mods/HearthDB.dll` outside `mods`, and follow the release instructions. A UI reload cannot replace a loaded DLL. To roll back, exit and restore the backup. Keep only one HearthDB DLL in the loader directory.

## Install and update

1. Fully close the client. Back up the addon folders when changing editions; preserve character settings in `WTF`.
2. Download the appropriate install repository using **Code > Download ZIP** and extract it.
3. Replace `Interface/AddOns/pfQuest`; for Turtle/Raven, replace `Interface/AddOns/pfQuest-turtle` from the same bundle too. Copy the inner addon folders, not the repository's outer directory.
4. Remove old `pfQuest-HearthDB` and `pfQuest-HearthDB-turtle` provider folders. Small inactive compatibility stubs may be included by the bundle; they are not required providers.
5. Enable the addons, restart, and run `/pfqhdb` to check database ownership and open status. Use `/db config` for settings and `/db show` for the database browser.

```text
Interface/AddOns/
  pfQuest/
    pfQuest.toc
    provider/
  pfQuest-turtle/             (Turtle/Raven bundle only)
    pfQuest-turtle.toc
    provider/data/pfquest-turtle.sqlite
```

The Vanilla bundle uses `pfQuest/provider/data/pfquest.sqlite`. The Turtle bundle uses one combined Vanilla + Turtle database at `pfQuest-turtle/provider/data/pfquest-turtle.sqlite`; the Turtle provider owns it when the extension is enabled. No separate provider addon is needed.

Do not mix regular and HDB folders. Do not update an HDB install by copying a regular Lua addon over it. Update both Turtle bundle folders together.

## If the database does not open

Check `/pfqhdb`, confirm the SQLite file exists at the path above, and check that HearthDB is actually loaded by the client. The addon and DLL are separate components. Restart after a DLL change. For stale session query results, `/pfqhdb cacheclear` clears query caches; it does not install a new database or synchronize completed quests.

## Missing markers or incorrect quest offers

1. Open `/db config`. Check **Show low-level quests**, the map's **Level Range**, and its tracking mode. Use **All Quests** while checking a report.
2. For an accepted quest, select it in the quest log and press **Show**. For an offer that still appears after completion, run `/db query` to request completed quest history from the server. This refreshes history; it does not download new database records.
3. Run `/db reset` to refresh quest nodes after checking the settings.
4. Check for duplicate addon folders and update the base and Turtle extension together. For a possible conflict, reproduce with pfQuest and its matching extension enabled and other map/nameplate addons disabled.

Quest level and minimum acceptance level are different. For example, a level 55 quest with minimum level 48 is hidden from a level 60 character when **Show low-level quests** is off. An offer may also require earlier quests, a faction, or a profession.

## Report a problem

Use the issue tracker for the edition you installed. Include:

- pfQuest and Turtle extension versions, regular or HDB edition, and client version.
- Character level and faction; relevant filter settings.
- Quest/NPC/object/item name and database link or ID.
- Whether the missing marker is an offer before acceptance, an objective, or a turn-in.
- Zone/map name, in-game coordinates, and a screenshot showing the map and tooltip if possible.
- Other map/nameplate addons, what you expected, and what happened after the checks above.
- Full Lua error text if one appeared. For HDB, include `/pfqhdb` output and which DLL you use.

Player reports and confirmed in-game coordinates are welcome. Database corrections are reviewed as maintenance time allows. Screenshots alone may not show the quest ID, completion history, or active filters.

## Capture a hitch

The optional [Hitch Profiler 1.0.3](https://github.com/rivi-s/HearthDB/releases/download/v0.4.1-exp.3/pfQuest-HDB-HitchProfiler-1.0.3.zip) is also included in the current install repositories as `pfQuest-HDB-HitchProfiler`. Install only one copy and disable the addon after diagnosis. Profiling has overhead; a GC memory drop alone cannot identify which addon created the garbage.

| Command | Effect |
| --- | --- |
| `/hdbhitch on` | Start a manual capture before reproducing the problem. |
| `/hdbhitch off` | Stop capture and save the manual log when file export is available. |
| `/hdbhitch status` | Show current capture state and saved login preference. |
| `/hdbhitch login on` | Enable a 45-second capture on the next login or reload. |
| `/hdbhitch login off` | Disable automatic login capture and stop a current automatic capture. |
| `/hdbroute` | Print route state for an arrow/map report. |

Login capture defaults to off for new installations. The preference is saved per character; existing preferences are preserved. Turning login capture off does not stop a manually started capture.

With the client's `ExportFile` API (Nampower), manual capture writes `Imports/hdb_hitch_manual.txt`, keeping the latest 2000 lines. It exports every 30 seconds and on stop/logout. A new manual capture replaces that file, so copy it before another test. Without `ExportFile`, send the chat capture.

The experimental DLL can also write native delivery diagnostics to `Logs/hdb_delivery_exp3.log`. At login capture completion the profiler requests that dump. After a manual reproduction, request it with:

```lua
/run if HDB_DumpDeliveryDiagnostics then DEFAULT_CHAT_FRAME:AddMessage(tostring(HDB_DumpDeliveryDiagnostics())) end
```

Review logs before sharing. Include addon and DLL versions, what triggered the hitch, and whether it repeats with the old DLL. The manual log and native delivery log are separate files. See the [profiler README](https://github.com/rivi-s/HearthDB/blob/main/diagnostics/pfQuest-HDB-HitchProfiler/README.md) for diagnostic details.
