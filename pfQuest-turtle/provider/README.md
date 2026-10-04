# Embedded HearthDB provider

This directory is part of `pfQuest-turtle`, not a separately installable addon.
`core.lua` implements asynchronous read-only database queries for pfQuest's HDB
adapter. HearthDB client support is required. English Vanilla data is supported;
Turtle uses one combined Vanilla/Turtle database.

Runtime database: `pfQuest-turtle/provider/data/pfquest-turtle.sqlite`.
Run `/pfqhdb` to check the database-owning addon and open state.

See [../HDB.md](../HDB.md) for building and packaging. Keep generated databases
out of source history. Never load both legacy separate providers alongside this
embedded layout; remove their addon folders when upgrading.

## Legacy provider compatibility

Leftover pfQuest-HearthDB and pfQuest-HearthDB-turtle addons cannot open their
old databases or retain ownership of the embedded API/status command. This
protection works even when installers leave the old runtime files unchanged.
Unrelated addons using HearthDB are unaffected. Install bundles also include
tiny inactive load-on-demand stubs at both old addon paths for in-place updates.
They are migration files, not required providers. Old tools/data left on disk
are not used. Cleanup is recommended; untouched old addons may still print
their own database-open failure messages.
