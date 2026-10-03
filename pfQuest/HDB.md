# pfQuest-HDB embedded HearthDB layout

The provider is loaded inside `pfQuest`. Keep `provider/core.lua` and
`provider/data/pfquest.sqlite` inside that addon; do not package the provider as another
addon. Turtle's enabled extension suppresses the vanilla provider and opens the
combined database from `pfQuest-turtle` instead.

Large Lua database files are not included in the active load manifests. This
HDB edition requires the client component and has no Lua database fallback.

Build from the provider directory:

```sh
python3 tools/build_database.py \
  --source /path/to/pfQuest-HDB \
  --locales enUS \
  --output data/pfquest.sqlite
```

Generated databases remain excluded from source history; ready-to-install
repositories contain them. Existing published alpha packages are unchanged.
