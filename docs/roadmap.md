# Roadmap: multi-OS compatibility + leveling up the pipeline

This is a checklist, not a spec. Each phase names the goal, why it has to come
before the next one, and open questions to resolve yourself — no solutions
handed over, that's the point. Check items off as you go. Order matters: each
phase assumes the previous one actually works before you build on top of it.

## Current state

`dw_bundesliga` is a personal data-warehouse project (bronze/silver/gold,
medallion architecture, SQL Server as the engine) that fetches Bundesliga
match data from the OpenLigaDB API in Python and loads it via T-SQL stored
procedures. Development started in April 2026 and stalled for about four
months; it was built entirely on a Windows machine, and the owner now works
from a Mac (Apple Silicon) and Ubuntu instead, with no Windows box anymore.
Resuming surfaced two Windows-only couplings: a hardcoded `C:\Users\...` path
inside an `OPENROWSET(BULK ...)` load in `proc_load_bronze.sql` (the DB engine
itself was reading a host file path, which only worked because Windows had
SQL Server and Python on the same filesystem), and `pyodbc` depending on a
system-level ODBC driver (`unixODBC` + `msodbcsql`) that Windows bundles
invisibly but Mac/Ubuntu don't ship at all. A local, unpushed branch,
`fix/macos_compatibility`, already started the right fix — it deleted the
`BULK INSERT` logic and moved data loading into Python (`load_bronze()` in
`ingestion/fetch_matches.py`) using parameterized inserts, decoupling the
loader from any host filesystem path — but it's unfinished (not wired into
`main()`, connection details still hardcoded).

Decisions made so far, with reasoning, in case they need revisiting: keep SQL
Server as the engine rather than switching to Postgres now, because the
existing T-SQL (stored procs, `OPENJSON ... AS JSON`, bracket-quoting) isn't
portable and a rewrite wasn't wanted; run it via Docker Compose pinned to the
`2022-latest` image specifically, not `2025`, because SQL Server 2025's image
requires AVX instructions that crash under Apple Silicon's QEMU emulation
while 2022 doesn't have that requirement, and this project's data volume is
small enough that emulation-induced slowness (as opposed to the crash bug)
isn't a real cost. Postgres migration is intended eventually, once both
machines are permanently Unix-based, with the understanding that the
translation-heavy part will be the DDL/stored-procedure layer, not ordinary
querying, since T-SQL and Postgres diverge hardest exactly there (procedure
syntax, variable declaration, JSON functions, quoting, types). The ingestion
script will be containerized too (not left host-native), specifically because
the owner's actual goal is "anyone on any OS clones this and it runs with
only Docker installed" — that requires a `Dockerfile` for the script itself,
added as a second `docker-compose.yml` service on the same network as
`mssql`, addressed by service name instead of `localhost`, plus a fix for the
startup race where the ingestion container can start before SQL Server is
ready. Separately, the pipeline currently always does a full load (fetches
and reloads all seasons since 2006 every run, ~13 minutes, ~700+ API calls);
this is being redesigned into bootstrap-once-then-incremental, using a field
already present per match in the API response to detect real changes instead
of blindly re-fetching everything, with `proc_load_bronze.sql` and
`proc_load_silver.sql` changing from drop-and-rebuild to upsert. The owner
wants eventual hands-on experience with CI/CD, Airflow, Spark, Terraform, and
cloud environments as part of a broader Data Engineering career path beyond
this project, but for *this* project specifically, only CI/CD (a scheduled
GitHub Actions workflow to trigger the incremental run daily) is currently
judged the right fit — the rest are called out as better learned on
differently-shaped projects. One unresolved architectural point flagged for
before any CI/CD work begins: GitHub Actions runners are ephemeral, so if
`mssql` runs inside the CI job itself, its data won't persist between runs
and the incremental design gets silently defeated — where the database
actually lives long-term (an always-on machine, a real persistent database,
or decoupling "keep source data fresh" from "load into a database") is an
open decision, not yet made.

## Phase 0 — where you already are

- [x] Diagnosed the two things that tied the project to Windows: a hardcoded
      `C:\Users\...` path inside `OPENROWSET(BULK ...)`, and `pyodbc` needing a
      system-level ODBC driver that Windows bundles invisibly and Mac/Ubuntu
      don't.
- [x] `fix/macos_compatibility` branch already removed the `BULK INSERT` logic
      from `proc_load_bronze.sql` and started moving the load into Python
      (`load_bronze()` in `ingestion/fetch_matches.py`).
- [ ] Decide whether to keep working on that branch or fold its diff into a
      fresh one — either way, don't lose the work already there.

## Phase 1 — get SQL Server running in Docker, on its own, first

Goal: prove the database container works, completely decoupled from Python.
Don't touch the ingestion script yet.

- [ ] Start the Docker daemon (it's installed, just not running).
- [ ] Write a first-pass `docker-compose.yml` with **only** the `mssql`
      service. Pin the image to `2022-latest`, not `2025-latest` — the 2025
      image requires AVX instructions that crash under QEMU emulation on
      Apple Silicon; 2022 doesn't have that requirement.
- [ ] Bring it up, connect with any SQL client (Azure Data Studio, DBeaver,
      even `sqlcmd` if you install it) over `localhost:1433`, confirm you can
      run `init_database.sql` against it manually.

Done when: you have a working, empty SQL Server reachable from your host,
with zero Python involved.

## Phase 2 — get the host-native script talking to it

Goal: reproduce what worked on Windows, now against the Dockerized DB, script
still running directly on your machine (not containerized yet — one variable
at a time).

- [ ] Install the client-side ODBC stack on this Mac (`unixODBC` +
      `msodbcsql17`/`18` via Homebrew's Microsoft tap) — this has nothing to
      do with Docker, it's a separate host dependency. Do the same later on
      Ubuntu, the exact steps differ.
- [ ] Move the hardcoded connection details out of `fetch_matches.py`
      (`SERVER=localhost`, `UID=sa`, `PWD=passwordblabla`) into environment
      variables / a `.env` file that's gitignored. Not just cleanliness —
      you'll need this to be configurable anyway once the script runs inside
      a container in Phase 3, where `localhost` stops meaning what you think
      it means.
- [ ] Finish `load_bronze()` on the fix branch and wire it into `main()` so
      `write_down()` → `load_bronze()` runs end-to-end again.

Done when: running `python fetch_matches.py` on your bare Mac populates
`bronze.dataframe` inside the Dockerized SQL Server.

## Phase 3 — containerize the ingestion script

Goal: the only host dependency left for anyone cloning this repo becomes
Docker itself. This is the option-B call you already made.

- [ ] Write a `Dockerfile` for the ingestion script (Python + `unixODBC` +
      `msodbcsql` + `requirements.txt`, baked in once).
- [ ] Add it as a second service in `docker-compose.yml`, same network as
      `mssql`. Inside that network, containers address each other by service
      name, not `localhost` — this is exactly why the env-var connection
      string from Phase 2 matters now.
- [ ] Handle the startup race: the `ingestion` container can start before
      `mssql` has finished initializing. Look into `depends_on` +
      healthchecks in Compose, and/or a retry loop on the Python side.
- [ ] Mount your local `ingestion/` folder as a volume during development so
      you're not rebuilding the image on every code change.

Done when: `docker compose up` alone, no host Python, no manual driver
install, takes a clean clone from zero to a loaded database.

## Phase 4 — stop doing a full load every time

Goal: `bronze`/`silver` loads become idempotent and incremental instead of
drop-and-rebuild.

- [ ] Research (this is the "still have to study" part, on purpose):
      idempotent ETL design, `MERGE`/upsert patterns in T-SQL, and how to use
      a field you're already storing per match to detect "did this row
      actually change" without re-fetching everything.
- [ ] Redesign `fetch_matches.py` so a normal run only touches a small,
      recent window (e.g. current season) instead of 2006 → now.
- [ ] Rewrite `proc_load_bronze.sql` and `proc_load_silver.sql` — currently
      both start with a full `DROP TABLE`/rebuild. They need an upsert path
      that doesn't destroy what's already there.
- [ ] Keep the full-load path around, but make it something you trigger
      explicitly (first-ever bootstrap, or a manual disaster-recovery
      rebuild), not the default behavior.

Done when: re-running the pipeline on a day with no new match results is
fast and makes zero destructive changes to existing rows.

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

## Later, deliberately out of scope for this project

Tools you mentioned wanting real experience with — Airflow, Spark,
Databricks, Terraform, full cloud hosting — don't fit this project's actual
shape yet, and forcing them on teaches less than it looks like it would:

- **Airflow** is for orchestrating many interdependent tasks. You have one.
  Worth standing up later, explicitly as practice, on something with real
  task dependencies.
- **Spark** earns its keep on data too big for one machine's memory. This
  dataset never will be. Better to learn it against something genuinely
  large (a multi-GB public dataset) where its value shows up.
- **Terraform / cloud hosting** need real infrastructure to manage — that's
  a deliberate, bigger step (cost, credentials, security surface), not a
  bolt-on to what exists now. Natural next project after this one, not a
  phase of it.
