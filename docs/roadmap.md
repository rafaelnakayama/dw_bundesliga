# Roadmap: multi-OS compatibility + leveling up the pipeline

This is a checklist, not a spec. Each phase names the goal, why it has to come
before the next one, and open questions to resolve yourself — no solutions
handed over, that's the point. Check items off as you go. Order matters: each
phase assumes the previous one actually works before you build on top of it.

## Current state

`dw_bundesliga` is a personal data warehouse (bronze/silver/gold, medallion
architecture, SQL Server) that fetches Bundesliga match data from the
OpenLigaDB API in Python and loads it through T-SQL stored procedures. Bronze
and silver are implemented; gold is still a placeholder file
(`scripts/gold/placegolder.txt`).

Built on Windows in April 2026, stalled for four months, resumed on a Mac
(Apple Silicon) with an Ubuntu machine as the second target and no Windows box
anywhere. Phases 0 through 3 dealt with exactly that. The pipeline now comes up
from a single `docker compose up` on any OS that has Docker, loads
idempotently, and bootstraps its own database, schemas and procedures.

### Decisions still in force

**SQL Server, not Postgres, for now.** The existing T-SQL (stored procedures,
`OPENJSON ... AS JSON`, bracket quoting) is not portable and a rewrite was not
wanted. A Postgres migration is intended eventually, once both machines are
permanently Unix-based. The hard part will be the DDL and procedure layer, not
ordinary querying, since that is where the two dialects diverge most.

**Image pinned to `2022-latest`, not `2025`.** The 2025 image needs AVX
instructions that crash under Apple Silicon emulation. 2022 does not, and at
this data volume the emulation overhead costs nothing that matters.

**Bronze is a mirror, not a history.** One row per match, keyed on `matchID`,
updated in place by a `MERGE` when the source's `lastUpdateDateTime` moves.
Chosen because the API is re-fetchable, so bronze is a convenience rather than
the only surviving copy. A useful consequence: a fixture published before it is
played and the same match with its final score are one row that gets updated,
not two versions to reconcile later.

**Scope is deliberately small.** This is a personal project, not a platform.
Per-matchday change detection, an upsert path for silver, and any persisted
ingestion state were all considered and cut. Re-fetching the current season
daily is cheap, and silver rebuilds from bronze in seconds. The only automation
goal here is a scheduled GitHub Actions workflow. Airflow, Spark and Terraform
are wanted as career skills, but are better learned on differently shaped
projects.

**Unresolved, and blocking CI/CD.** GitHub Actions runners are ephemeral. If
`mssql` runs inside the CI job, its data disappears at the end of every run and
every incremental run silently becomes a full load again. Where the database
actually lives is Phase 5, and it is a decision, not code.

## Phase 0 — where you already are

- [x] Diagnosed the two things that tied the project to Windows: a hardcoded
      `C:\Users\...` path inside `OPENROWSET(BULK ...)`, and `pyodbc` needing a
      system-level ODBC driver that Windows bundles invisibly and Mac/Ubuntu
      don't.
- [x] `fix/macos_compatibility` branch already removed the `BULK INSERT` logic
      from `proc_load_bronze.sql` and started moving the load into Python
      (`load_bronze()` in `ingestion/fetch_matches.py`).
- [x] Decide whether to keep working on that branch or fold its diff into a
      fresh one — either way, don't lose the work already there.

Note on scope: the branch is named `fix/macos_compatibility`, but the actual
goal is broader — run identically on *any* OS, including a hypothetical
future return to Windows, not just "make it work on this Mac." Nothing in
Phases 1–6 is Mac-specific (Docker Compose, env vars, and containerizing the
script are all OS-agnostic by construction), so the work itself already
matches the real goal — just worth keeping in mind that the branch name is
narrower than the intent, and renaming it (e.g. to something like
`fix/os_portability`) before merging might save future confusion.

## Phase 1 — get SQL Server running in Docker, on its own, first

Goal: prove the database container works, completely decoupled from Python.
Don't touch the ingestion script yet.

- [x] Start the Docker daemon (it's installed, just not running).
- [x] Write a first-pass `docker-compose.yml` with **only** the `mssql`
      service. Pin the image to `2022-latest`, not `2025-latest` — the 2025
      image requires AVX instructions that crash under QEMU emulation on
      Apple Silicon; 2022 doesn't have that requirement.
- [x] Bring it up, connect with any SQL client (Azure Data Studio, DBeaver,
      even `sqlcmd` if you install it) over `localhost:1433`, confirm you can
      run `init_database.sql` against it manually.

Done when: you have a working, empty SQL Server reachable from your host,
with zero Python involved.

## Phase 2 — get the host-native script talking to it

Goal: reproduce what worked on Windows, now against the Dockerized DB, script
still running directly on your machine (not containerized yet — one variable
at a time).

- [x] Install the client-side ODBC stack on this Mac (`unixODBC` +
      `msodbcsql17`/`18` via Homebrew's Microsoft tap) — this has nothing to
      do with Docker, it's a separate host dependency. Do the same later on
      Ubuntu, the exact steps differ.
- [x] Move the hardcoded connection details out of `fetch_matches.py`
      (`SERVER=localhost`, `UID=sa`, `PWD=passwordblabla`) into environment
      variables / a `.env` file that's gitignored. Not just cleanliness —
      you'll need this to be configurable anyway once the script runs inside
      a container in Phase 3, where `localhost` stops meaning what you think
      it means.
- [x] Finish the Python loader on the fix branch and wire it into `main()` so
      the fetch → load chain runs end-to-end again. The function is now called
      `load_json()`, to stop colliding with the SQL procedure.

Done when: running `python fetch_matches.py` on your bare Mac populates
`bronze.dataframe` inside the Dockerized SQL Server.

## Phase 3 — containerize the ingestion script

Goal: the only host dependency left for anyone cloning this repo becomes
Docker itself. This is the option-B call you already made.

- [x] Write a `Dockerfile` for the ingestion script (Python + `unixODBC` +
      `msodbcsql` + `requirements.txt`, baked in once).
- [x] Add it as a second service in `docker-compose.yml`, same network as
      `mssql`. Inside that network, containers address each other by service
      name, not `localhost` — this is exactly why the env-var connection
      string from Phase 2 matters now.
- [x] Handle the startup race: the `ingestion` container can start before
      `mssql` has finished initializing. Look into `depends_on` +
      healthchecks in Compose, and/or a retry loop on the Python side.
- [x] Mount your local `ingestion/` folder as a volume during development so
      you're not rebuilding the image on every code change.

Done when: `docker compose up` alone, no host Python, no manual driver
install, takes a clean clone from zero to a loaded database.

## Phase 4 — stop doing a full load every time

Goal: a normal run costs seconds instead of thirteen minutes, and never
destroys what is already loaded.

- [x] Research: idempotent ETL, `MERGE`/upsert in T-SQL, and using a field
      already stored per match to detect real change. Landed on the mirror
      model, a `MERGE` fed from a staging table, and `lastUpdateDateTime` as
      the change marker.
- [x] Rewrite the bronze load. `proc_init_bronze.sql` is idempotent DDL that
      never drops, and `proc_merge_bronze.sql` upserts from
      `bronze.dataframe_staging` on the new `matchID` primary key.
- [x] Keep the full-load path around but explicit:
      `scripts/bronze/rebuild_bronze.sql`, manual only.
- [ ] Narrow the fetch window. `loop_and_write` still walks 2006 → now on every
      run, and that is the entire remaining cost. Make the season range a
      parameter defaulting to the current season, keeping the full range as an
      explicit bootstrap.

      Mind the season boundary: Bundesliga 2026 runs from August 2026 to May
      2027, so `datetime.now().year` is wrong from January through July.

Done when: a normal run fetches one season instead of twenty-one, and
re-running on a day with no new results changes nothing.

### Cut on purpose

Considered and rejected, so they do not get reopened by accident:

- **Per-matchday change detection** via `getlastchangedate`. Saves API calls
  that the current-season window already avoids. Optimizing an optimization.
- **Persisted ingestion state.** Pointless when every run simply re-fetches the
  current season; the `MERGE` decides what actually changed.
- **An upsert path for silver.** It is already idempotent and rebuilds
  deterministically from bronze in seconds. Not incremental is not the same as
  broken.
- **Retroactive edits to old seasons.** OpenLigaDB is collaborative, so someone
  could fix a 2009 match tomorrow. Accepted blind spot; `rebuild_bronze.sql`
  plus a full bootstrap is the answer if it ever matters.

## Phase 5 — resolve this *before* writing any CI/CD config

Open question, deliberately unanswered here: GitHub Actions runners are
ephemeral — a fresh VM per run, nothing persists between runs by default. If
`mssql` runs *inside* the CI job, its data vanishes at the end of every run,
and every "incremental" run silently becomes a full load again, undoing all
of Phase 4.

Decide where the database actually lives for daily automation to make sense:
an always-on machine you control, a real persistent (cloud) database reached
over the network, or decoupling "CI/CD keeps the raw source data fresh" from
"loading into a database," which stays a separate, manual/local step until
you have real persistent infra. No wrong answer, but pick one on purpose.

## Phase 6 — automate it

- [ ] GitHub Actions workflow on a `schedule: cron:` trigger, implementing
      whichever answer you landed on in Phase 5.
- [ ] DB credentials go into GitHub Actions secrets, never into the workflow
      file.
- [ ] Confirm a no-op day (nothing new from the API) still runs, exits fast,
      and changes nothing.

## Parked for later

Ideas already in mind, explicitly not sequenced into the phases above yet —
revisit once Phase 6 is done, or sooner if it makes sense:

- [ ] **Finish the gold layer.** Currently just `scripts/gold/placegolder.txt`
      — bronze and silver are the only implemented layers so far.
- [ ] **Switch `requirements.txt` to `uv`.** Already used it twice at work,
      found it fast and easy; do the swap once the Docker/dependency story
      above has settled, not mid-migration.
- [ ] **Build a dashboard on top of the gold layer**, in Python with Shiny
      (integrates with pandas/matplotlib). Still vague on purpose — data
      modeling, storytelling, and the actual look of it are a separate,
      sizable chunk of work that will get broken into its own smaller
      to-do list once it's actually started.
