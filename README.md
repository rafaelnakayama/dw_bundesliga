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

## Requirements

Docker and Docker Compose, plus disk for the SQL Server image. The pipeline needs
nothing else on the host: Python, uv, the ODBC driver and the database all live in
containers.

Rendering the dashboard is the one thing that runs on the host, and it needs
[uv](https://docs.astral.sh/uv/) and [Quarto](https://quarto.org/). It never touches
the database.

## Installation

Clone the repository:

```
git clone https://github.com/rafaelnakayama/dw_bundesliga.git
cd dw_bundesliga
```

Create a `.env` file in the repository root:

```
cp .env.example .env
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
| `FETCH_ONLY=1` | download the JSON and stop, skipping every database step. |

Bronze, silver and gold are all loaded automatically by a single run.

Two destructive paths exist and are never called by the pipeline. Run them by hand
only when you mean it: `scripts/init/init_database.sql` drops and recreates the
database, and `scripts/bronze/rebuild_bronze.sql` does a full reload of bronze.

## Automation

`.github/workflows/cicd.yml` runs every Monday at 21:00 UTC, after the weekend
round. It fetches the current season, loads bronze, silver and gold into a throwaway
SQL Server, exports the dashboard JSON, commits whatever actually changed, then
renders the site and publishes it to Pages. Weeks with no new matches skip the
commit. The database exists only for the length of the run, and no secrets are
involved: the `sa` password is generated per run and discarded with it.

## Dashboard

A Quarto site rendered to static HTML and published on GitHub Pages. It reads a
precomputed JSON export, never the database, so the page is a few hundred
kilobytes and loads instantly.

The weekly workflow rebuilds it from the fresh data, so the steps below are only
needed to work on the page locally.

### Building

The export runs inside the ingestion container, where the ODBC driver already
lives, so nothing has to be installed on the host to talk to SQL Server:

```
docker compose run --rm python_ingestion python dashboard/export_gold.py
```

That writes `dashboard/data/dashboard.json`. Rendering needs Quarto and two pure
Python packages, and no database:

```
uv sync --group dashboard
cd dashboard && uv run quarto render
```

`uv run` puts the project's `.venv` first on `PATH`, which is how Quarto finds the
`jupyter` that executes the `.qmd`.

The site lands in `dashboard/_site`. `quarto preview` serves it with live reload
while editing.

Aggregation happens in SQL, inside `dashboard/export_gold.py`. The `.qmd` only
plots. Points follow the 3/1/0 rule and are computed at export time, because one
match distributes points to two teams and they do not fit the match grain.

## Project layout

```
    ├─ .github/workflows/  weekly fetch
    ├─ dashboard/          Quarto site and the gold export
    ├─ datasets/raw/       source JSON, one directory per season
    ├─ docs/               integration models and naming conventions
    ├─ ingestion/          fetch and load
    ├─ scripts/            T-SQL, one directory per layer
    │  ├─ init/            database and schema bootstrap
    │  ├─ bronze/          raw mirror
    │  ├─ silver/          cleaned and typed
    │  └─ gold/            facts and dimensions
    └─ tests/              silver validation queries
```
