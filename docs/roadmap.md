# Roadmap: multi-OS compatibility + leveling up the pipeline

A checklist, not a spec. Order matters: each phase assumes the previous one
actually works. Phases 0 through 5 are done; Phase 6 is the only open work.

## Current state

`dw_bundesliga` is a personal data warehouse (bronze/silver/gold, medallion
architecture, SQL Server) that fetches Bundesliga match data from the
OpenLigaDB API in Python and loads it through T-SQL stored procedures. Bronze
and silver are implemented; gold is still a placeholder file
(`scripts/gold/placegolder.txt`).

Built on Windows in April 2026, stalled for four months, resumed on a Mac
(Apple Silicon) with an Ubuntu machine as the second target and no Windows box
anywhere. The pipeline now comes up from a single `docker compose up` on any OS
that has Docker, bootstraps its own database, schemas and procedures, and loads
idempotently.

### How a run is incremental, and where it deliberately is not

Three stages. Only two of them are incremental, and that is on purpose.

| stage | code | incremental? |
|---|---|---|
| API to JSON | `loop_and_write()` | yes: current season only, 34 calls instead of 714 |
| JSON to staging | `load_json()` | **no**: re-reads all 714 files every run |
| staging to bronze | `bronze.merge_bronze` | yes: compares `lastUpdateDateTime`, zero writes when nothing changed |

The middle stage is a full load and stays one. It costs about eleven seconds,
it only refills a throwaway table that the `MERGE` truncates right after, and
the dataset is far too small for the fix to buy anything. Making it incremental
would mean tracking which files changed, which is state to maintain in exchange
for seconds nobody is waiting on. Recorded here so it does not get mistaken for
leftover technical debt: it is a decision, not an oversight.

### Decisions still in force

**SQL Server.** The stored procedures, `OPENJSON ... AS JSON` and bracket
quoting are T-SQL and stay T-SQL. No engine migration is planned for this
project.

**Image pinned to `2022-latest`, not `2025`.** The 2025 image needs AVX
instructions that crash under Apple Silicon emulation. 2022 does not, and at
this data volume the emulation overhead costs nothing that matters.

**Bronze is a mirror, not a history.** One row per match, keyed on `matchID`,
updated in place by a `MERGE` when the source's `lastUpdateDateTime` moves.
A fixture published before it is played and the same match with its final score
are one row that gets updated, not two versions to reconcile. Phase 6 gives the
history back for free: the weekly raw commit turns git into the history layer.

**Scope is deliberately small.** This is a personal project, not a platform.
The finish line is a scheduled fetch, a gold layer and a dashboard. Anything
that does not serve those three is out.

**Everything runs locally.** See Phase 5.

## Phases 0 to 3 (done)

- [x] **Phase 0. Diagnose the Windows coupling.** A hardcoded `C:\Users\...`
      path inside `OPENROWSET(BULK ...)`, and `pyodbc` needing a system-level
      ODBC driver that Windows bundles invisibly and Mac/Ubuntu do not. The
      `BULK INSERT` logic left `proc_load_bronze.sql` and moved into Python.
- [x] **Phase 1. SQL Server in Docker, alone.** `mssql` service only, pinned to
      `2022-latest`, reachable on `localhost:1433`, no Python involved.
- [x] **Phase 2. Host-native script against the Dockerized DB.** unixODBC plus
      `msodbcsql18` on the host, connection details moved out of the source and
      into a gitignored `.env`, and the Python loader (`load_json()`, renamed to
      stop colliding with the SQL procedure) wired into `main()`.
- [x] **Phase 3. Containerize the ingestion script.** A `Dockerfile` bakes
      Python plus the ODBC stack, a second Compose service joins the same
      network (so the DB is addressed by service name, not `localhost`), the
      startup race is handled by a retry loop in `connect()`, and `ingestion/`,
      `scripts/` and `datasets/` are mounted so code edits need no rebuild.

Done when a clean clone reaches a loaded database with `docker compose up` and
nothing else. Met.

## Phase 4. Stop doing a full load every time (done)

- [x] Landed on the mirror model: a `MERGE` fed from `bronze.dataframe_staging`,
      with `lastUpdateDateTime` as the change marker.
- [x] `proc_init_bronze.sql` is idempotent DDL that never drops.
      `proc_merge_bronze.sql` upserts on the `matchID` primary key.
- [x] The full-load path survives but is manual and explicit:
      `scripts/bronze/rebuild_bronze.sql`.
- [x] Narrowed the fetch window to the current season: 34 calls instead of 714,
      thirteen minutes down to eleven seconds. `current_season()` keys off the
      month, since a season crosses the year boundary and `datetime.now().year`
      is wrong from January through July. `BACKFILL=1` still fetches every
      season since 2006, and is a one-off bootstrap, never automated.

Done when a normal run fetches one season and a re-run on a quiet day changes
nothing. **Met**, verified by identical checksums across two consecutive runs.

### Cut on purpose

- **Per-matchday change detection** via `getlastchangedate`. Saves API calls the
  current-season window already avoids. Optimizing an optimization.
- **Persisted ingestion state.** Pointless when every run re-fetches the current
  season and the `MERGE` decides what actually changed.
- **An upsert path for silver.** Already idempotent, rebuilds from bronze in
  seconds.
- **Retroactive edits to old seasons.** OpenLigaDB is collaborative, so a 2009
  match could be fixed tomorrow. Accepted blind spot; `rebuild_bronze.sql` plus
  a full backfill is the answer if it ever matters.

## Phase 5. Where the database lives (done, decided)

The question was where `mssql` lives once runs are automated, since GitHub
Actions runners are ephemeral and anything loaded inside a job dies with it.

**Answer: nowhere new. CI keeps the raw JSON fresh; the database stays local
and on demand.**

The reasoning matters more than the answer:

- **The right question was not cost or speed, it was who reads the output.** A
  SQL Server built inside a runner and destroyed at the end of the job computes
  a warehouse nobody queries. It is not slow, it is pointless.
- **An ephemeral database would not undo Phase 4 anyway.** What is incremental
  is the fetch, which needs no database, and the `MERGE`, which holds no state
  between runs. The staging load is already full every run by design.
- **The source of truth is the JSON, not the database.** It is re-fetchable from
  the API and already versioned in git (714 files, about 20 MB, roughly a
  one-line diff per matchday). The warehouse is a derived layer that rebuilds
  from those files in seconds.
- **A hosted database was considered and rejected.** It only earns its keep when
  something that is not you, at an hour you did not choose, has to read the
  system. That is a question of availability, never of volume, and at 20 MB the
  volume never enters the argument. Renting one plus a host for the dashboard
  process is a real monthly bill for a system with exactly one reader.
- **And the dashboard does not need a served database at all.** Interactive is
  not the same as up to date. A Power BI file is interactive because the data
  travels inside it. The same shape works here: export gold to a flat file
  (parquet, CSV or DuckDB), ship it with the dashboard, publish the whole thing
  as static files. SQL Server goes back to being what it always was, a
  transformation tool, not a serving layer.

## Phase 6. Automate it (open)

The only remaining work. Scope: the workflow fetches, and nothing else.

- [x] **Split the entrypoint.** `__main__` used to run `deploy_schema()`, the
      fetch and `load_json()` back to back, and two of those need a database
      the runner does not have. `FETCH_ONLY=1` now gates the database half.
      It is independent from `BACKFILL`, which still decides only how much is
      fetched, so a run with no variables set keeps fetching one season *and*
      loading it. **Verified** with Docker fully down: the script downloaded
      the season and exited 0 without a single connection attempt.
- [ ] **No Docker and no ODBC in the runner.** Once the fetch is separable it
      needs `requests` and nothing more. No `mssql` service, no `pyodbc`, no
      driver install.
- [ ] **Weekly schedule, `0 21 * * 1`.** Cron in Actions is always UTC and
      ignores daylight saving. 21:00 UTC is 22:00 in the German winter and
      23:00 in summer, so it never fires before a Sunday round is finished, and
      Monday catches the whole round.
- [ ] **Commit the refreshed raw back to the repo.** Needs
      `permissions: contents: write`, and must skip the commit when the diff is
      empty so quiet weeks leave no noise. Target branch is `develop`, so the
      bot never makes `main` diverge and collide with open pull requests. Not
      final until the workflow actually exists.
- [ ] **`BACKFILL` never gets set in the workflow.** The backfill is a one-off
      bootstrap, run manually and locally, before any of this.
- [ ] **Secrets are not needed.** With no database in CI there is nothing to
      authenticate against.
- [ ] Confirm that a week with no new results runs, exits fast, and commits
      nothing.

## Parked for later

- [ ] **Finish the gold layer.** Still `scripts/gold/placegolder.txt`. This is
      the natural next project after Phase 6, and the only prerequisite the
      dashboard actually has.
- [ ] **Build the dashboard once, then leave it.** Python with Shiny, compiled
      to static files with `shinylive` and published on GitHub Pages, reading an
      exported gold file rather than connecting to a database. Deliberately not
      automated: rebuilding it weekly would mean running the whole pipeline in
      CI, which buys freshness nobody asked for on the least interesting part of
      the project. If a refreshed version is ever wanted, the four steps (run
      the pipeline locally, export gold, `shinylive export`, publish) are done
      by hand. The focus here is data engineering, and the gold layer is where
      that lives, not the dashboard.
- [ ] **Switch `requirements.txt` to `uv`.** Fast and easy at work; do the swap
      once the Docker story has settled, not mid-migration.
