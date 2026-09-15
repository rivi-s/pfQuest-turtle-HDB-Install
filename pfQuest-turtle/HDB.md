# pfQuest-turtle-HDB alpha

This repository follows the live pfQuest-turtle history and contains only
Turtle-specific HDB behavior. General HDB integration remains in pfQuest-HDB.

The `provider` directory is packaged as a second addon named
`pfQuest-HearthDB-turtle`. An English alpha release contains:

- the repository root packaged as `pfQuest-turtle`
- `provider` packaged as `pfQuest-HearthDB-turtle`
- `pfquest-turtle.sqlite` placed in `pfQuest-HearthDB-turtle/data`

Build the complete English vanilla-and-Turtle database from `provider`:

```sh
python3 tools/build_database.py \
  --source /path/to/pfQuest \
  --turtle-source /path/to/pfQuest-turtle \
  --locales enUS \
  --output data/pfquest-turtle.sqlite
```

Generated SQLite databases are release artifacts and are not committed.
