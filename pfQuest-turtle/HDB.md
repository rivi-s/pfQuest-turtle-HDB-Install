# pfQuest-turtle-HDB embedded HearthDB layout

The provider is loaded inside `pfQuest-turtle`. Keep `provider/core.lua` and
`provider/data/pfquest-turtle.sqlite` inside that addon; do not package the provider as another
addon. Turtle's enabled extension suppresses the vanilla provider and opens the
combined database from `pfQuest-turtle` instead.

Large Lua database files are not included in the active load manifests. This
HDB edition requires the client component and has no Lua database fallback.

Build from the provider directory:

```sh
python3 tools/build_database.py \
  --source /path/to/pfQuest-HDB \
  --turtle-source /path/to/pfQuest-turtle-HDB \
  --locales enUS \
  --output data/pfquest-turtle.sqlite
```

Generated databases remain excluded from source history; ready-to-install
repositories contain them. Existing published alpha packages are unchanged.

## Legacy provider compatibility

Leftover pfQuest-HearthDB and pfQuest-HearthDB-turtle addons cannot open their
old databases or retain ownership of the embedded API/status command. This
protection works even when installers leave the old runtime files unchanged.
Unrelated addons using HearthDB are unaffected. Install bundles also include
tiny inactive load-on-demand stubs at both old addon paths for in-place updates.
They are migration files, not required providers. Old tools/data left on disk
are not used. Cleanup is recommended; untouched old addons may still print
their own database-open failure messages.
