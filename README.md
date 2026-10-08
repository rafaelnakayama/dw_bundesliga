# dw_bundesliga

A personal data warehouse for German Bundesliga match data. It fetches matches from
the [OpenLigaDB](https://www.openligadb.de/) API, keeps the raw JSON versioned in
this repository, and loads it into SQL Server through a bronze / silver / gold
medallion architecture.

Every stage is idempotent: running the pipeline twice on unchanged data leaves the
database exactly as it was. A weekly GitHub Actions workflow refreshes the JSON and
republishes the dashboard; the database is built on demand and never served.

Seasons from 2006 onward, one JSON file per season and matchday, around 20 MB in
total.

## Requirements

- [Docker](https://docs.docker.com/get-started/get-docker/) with Compose v2.
- [uv](https://docs.astral.sh/uv/getting-started/installation/) and
  [Quarto](https://quarto.org/docs/get-started/), only to build the dashboard locally.

| OS | Docker setup |
|---|---|
| Linux | [Docker Engine](https://docs.docker.com/engine/install/) and the [Compose plugin](https://docs.docker.com/compose/install/linux/). |
| macOS | [Docker Desktop](https://docs.docker.com/desktop/setup/install/mac-install/) or [OrbStack](https://orbstack.dev/). On Apple silicon the SQL Server image, x86-64 only, runs under Rosetta: automatic in OrbStack, a [setting](https://docs.docker.com/desktop/settings-and-maintenance/settings/) in Docker Desktop. |
| Windows | [Docker Desktop](https://docs.docker.com/desktop/setup/install/windows-install/) with the [WSL 2 backend](https://docs.docker.com/desktop/features/wsl/). |

## Installation

```
git clone https://github.com/rafaelnakayama/dw_bundesliga.git
cd dw_bundesliga
cp .env.example .env
```

Set `DB_PASSWORD` in `.env`. It becomes the SQL Server `sa` password and must follow
the [password policy](https://learn.microsoft.com/en-us/sql/relational-databases/security/password-policy):
at least 8 characters, from three of these four sets: uppercase, lowercase, digits,
symbols.

Start SQL Server and run the pipeline:

```
docker compose up
```

## Running

A run fetches the current season and loads bronze, silver and gold:

```
docker compose run --rm python_ingestion
```

Two environment variables change that, both unset by default:

| variable | effect |
|---|---|
| `BACKFILL=1` | fetch every season since 2006 instead of only the current one. |
| `FETCH_ONLY=1` | download the JSON and stop, skipping every database step. |

```
docker compose run --rm -e BACKFILL=1 python_ingestion
```

The warehouse is served at `localhost:1433`, database `dw_hgg_database`, user `sa`.

Two scripts are destructive and never run by the pipeline:
`scripts/init/init_database.sql` drops and recreates the database, and
`scripts/bronze/rebuild_bronze.sql` empties bronze for a full reload.

## Dashboard

A [Quarto](https://quarto.org/) page with the current standings, top scorers and
historical records, published on GitHub Pages.

A [GitHub Actions workflow](.github/workflows/cicd.yml) runs every Monday at 21:00
UTC: it fetches the new matches, rebuilds the warehouse and republishes the page.

To build it locally:

```
docker compose run --rm python_ingestion python dashboard/export_gold.py
cd dashboard
uv run --group dashboard quarto render
```

The first command exports the gold layer to `dashboard/data/dashboard.json`; skip it
to render the committed copy. The site is written to `dashboard/_site`.

Live page: https://rafaelnakayama.github.io/dw_bundesliga/

## Project layout

```
    ├─ .github/workflows/  weekly fetch, export and publish
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

## License

Released under the [MIT License](LICENSE).
