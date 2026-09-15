# pfQuest-HDB alpha

This repository follows the live pfQuest history and adds the asynchronous
HearthDB integration used by the HDB edition.

The `provider` directory is packaged as a second addon named
`pfQuest-HearthDB`. An English alpha release contains:

- the repository root packaged as `pfQuest`
- `provider` packaged as `pfQuest-HearthDB`
- `pfquest.sqlite` placed in `pfQuest-HearthDB/data`

Build the English database from `provider`:

```sh
python3 tools/build_database.py \
  --source /path/to/pfQuest \
  --locales enUS \
  --output data/pfquest.sqlite
```

Generated SQLite databases are release artifacts and are not committed.
