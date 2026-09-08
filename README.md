# dw_bundesliga

A personal data warehouse for German Bundesliga match data. It fetches matches from
the [OpenLigaDB](https://www.openligadb.de/) API, keeps the raw JSON versioned in
this repository, and loads it into SQL Server through a bronze / silver / gold
medallion architecture.

Every stage is idempotent: running the pipeline twice on unchanged data leaves the
database exactly as it was. A weekly GitHub Actions workflow keeps the raw JSON
fresh; the database itself runs locally, on demand, and is never part of CI.

Seasons from 2006 onward, one JSON file per season and matchday, around 20 MB in
total.

## Layout

| path | contents |
|---|---|
| `ingestion/` | Python fetch and load: `fetch_matches.py` |
| `scripts/` | T-SQL: schema bootstrap and stored procedures, by layer |
| `datasets/raw/` | source JSON, one directory per season |
| `tests/` | validation queries for the silver layer |
| `.github/workflows/` | the weekly fetch |

## Requirements

Docker and Docker Compose, plus disk for the SQL Server image. Nothing else is
needed on the host: Python, the ODBC driver and the database all live in
containers.

## Installation

Clone the repository:

```
git clone https://github.com/rafaelnakayama/dw_bundesliga.git
cd dw_bundesliga
```

Create a `.env` file in the repository root:

```
DB_SERVER=localhost
DB_DATABASE=dw_hgg_database
DB_USER=sa
DB_PASSWORD=<your password>
```

`DB_PASSWORD` becomes the SQL Server `sa` password, so it has to satisfy SQL
Server's complexity rules: at least eight characters, mixing upper case, lower case
and digits or symbols. The file is gitignored and never leaves your machine.

Start everything:

```
docker compose up
```

The first run creates the database, the `bronze`, `silver` and `gold` schemas and
the stored procedures, fetches the current season and loads it into bronze. Later
runs fetch the current season again and write only what actually changed.

## Running

The ingestion script is driven by two environment variables, both unset by default:

| variable | effect |
|---|---|
| `BACKFILL=1` | fetch every season since 2006 instead of only the current one. One-off bootstrap. |
| `FETCH_ONLY=1` | download the JSON and stop, skipping every database step. Used by CI. |

Bronze is loaded automatically. Silver is a manual step: connect to
`localhost:1433` with any SQL client and run `scripts/exec/runner.sql`.

Two destructive paths exist and are never called by the pipeline. Run them by hand
only when you mean it: `scripts/init/init_database.sql` drops and recreates the
database, and `scripts/bronze/rebuild_bronze.sql` does a full reload of bronze.

## Automation

`.github/workflows/cicd.yml` runs every Monday at 21:00 UTC, after the weekend
round. It fetches the current season with `FETCH_ONLY=1` and commits the refreshed
JSON back to the repository, skipping the commit entirely on weeks where nothing
changed. No database and no secrets are involved.

## Dashboard

TBD

### Building

TBD

### Publishing

TBD

## License

MIT. See `LICENSE`.
