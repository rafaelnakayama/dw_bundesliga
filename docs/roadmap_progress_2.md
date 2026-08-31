# Roadmap progress 2

Session date: 2026-08-31, afternoon. Branch: `feature/ingestion-containerization`.

Covers Phase 3 and the scope decision that reshaped Phase 4. Session 1 and 2
are in `roadmap_progress_1.md`.

## Phase 3 — done, verified

The acceptance test is the point of this phase, so it was run for real: stack
torn down, volume deleted, image removed, then a single `docker compose up`.

```
>>> Waiting for data_warehouse_db (1/30)
>>> Applying: init_schemas.sql
>>> Applying: proc_init_bronze.sql
>>> Applying: proc_merge_bronze.sql
>>> Applying: proc_load_silver.sql
[714 matchdays fetched]
python_ingestion-1 exited with code 0
```

Result: `bronze = 6426` rows, 6426 distinct, 21 seasons, staging drained. No
host Python, no ODBC driver installed by hand, no SQL run from a client. About
thirteen minutes, essentially all of it the fetch.

The retry loop fired once for real (`Waiting ... (1/30)`), which settles the
question of whether the startup race was hypothetical. It was not.

## Things that cost time and are worth remembering

**The Microsoft signing key is wrong in every tutorial.** `microsoft.asc`
carries key `EB3E94ADBE1229CF`; the Debian 13 (trixie) repository is signed by
`EE4D7792F748182B`. Debian 13 also swapped its verifier to `sqv`, stricter than
`gpgv`, so the mismatch aborts the build with `E: The repository is not signed`.
The key that works is `microsoft-2025.asc`.

**`debian/13` in the repo URL is coupled to `FROM`.** Bumping the base image to
a Debian 14 one silently breaks that line.

**Python buffers stdout when it is not a terminal.** Without
`ENV PYTHONUNBUFFERED=1`, no `print` reaches `docker compose logs` until the
process exits, which makes a thirteen-minute fetch indistinguishable from a
hung container. This wasted a debugging cycle.

**The container exposed a dependency that was never declared.** The script
imports `dotenv`; `requirements.txt` did not list `python-dotenv`. It worked on
the host because the virtualenv had accumulated it months earlier. Containerizing
is a decent honesty test for a manifest.

**Nothing deployed the SQL.** `load_json()` calls `EXEC bronze.init_bronze`,
which only existed because it had been run by hand in DBeaver. On a clean clone
there was no database, no schema and no procedure. `deploy_schema()` now applies
`init_schemas.sql` and the three `CREATE OR ALTER` procedures before any load,
deliberately excluding `init_database.sql` and `rebuild_bronze.sql`, both of
which start by destroying what they find.

`init_schemas.sql` is new: the non-destructive counterpart of
`init_database.sql`, mirroring the split already used between
`proc_init_bronze.sql` and `rebuild_bronze.sql`.

**`GO` is not T-SQL.** It is a `sqlcmd` batch separator, and `pyodbc` rejects
it, so `run_sql_file()` splits on it before sending anything.

## Scope cut

Phase 4 was described as open-ended research. After deciding what this project
actually needs, most of it went away.

The requirement, stated plainly: within 24 hours, any match that changed should
be reflected. Historical edits to seasons from years ago do not matter.

That requirement is satisfied by fetching the current season and letting the
existing `MERGE` decide what changed. No change-detection endpoint, no state
table, no silver rewrite. What remains of Phase 4 is turning the season range
into a parameter.

Recorded because it is easy to reopen by accident: `getlastchangedate`,
persisted ingestion state, a silver upsert, and support for retroactive edits
to old seasons were all considered and cut. Reasons are in `roadmap.md` under
"Cut on purpose".

A consequence of the mirror decision made in session 2 that only became obvious
here: OpenLigaDB publishes fixtures before they are played, with
`matchIsFinished: false` and null results. Those rows already land in bronze,
and when the match is played the API moves `lastUpdateDateTime` and the `MERGE`
updates them in place. The whole lifecycle of a match is one row. Under a
history model, each update would have been another version for silver to
reconcile.

## Still open

- **The fetch window**, the last item of Phase 4 and roughly ten lines of work.
  Watch the season boundary: Bundesliga 2026 runs to May 2027, so
  `datetime.now().year` is wrong from January through July.
- **Phase 5**, which is a decision rather than code, and the real blocker for
  CI/CD. Ephemeral runners mean that an `mssql` living inside the CI job
  defeats every bit of the idempotency work.
- **Idempotency through the container** was never re-verified; only one load ran
  that way. It was verified three times host-native in session 2. The test costs
  thirteen minutes today and seconds once the fetch window lands.

## State at the end of this session

Branch `feature/ingestion-containerization`, three commits, pushed. Phases 0
through 3 closed. Phase 4 has one item left.

Working today, verified:

| | |
|---|---|
| `docker compose up` from nothing | image, database, schemas, procedures, 6426 rows |
| bronze load | idempotent, `MERGE` on `matchID`, guarded by `lastUpdateDateTime` |
| silver | rebuilds from bronze in seconds, all PKs and FKs in place |
| raw files | written in a stable order, so a git diff means real change |
| startup race | retry loop, confirmed firing in a real cold start |

Still a full load on every run: `seasons = range(2006, 2027)` at line 11 of
`fetch_matches.py` is untouched, so each run is ~13 minutes and 714 API calls.

### Next session

Two modes instead of one range. The problem with simply narrowing it is that
the same range does the backfill: point it at the current season and the first
ever run has no history to load. So the season range becomes a parameter,
defaulting to the current season, with the full 2006 → now range reachable as
an explicit bootstrap. Same shape as `rebuild_bronze.sql` being the explicit
destructive path next to the idempotent `bronze.init_bronze`.

Two things to get right:

- The current season is not `datetime.now().year`. Bundesliga 2026 runs from
  August 2026 to May 2027, so that expression is wrong from January through
  July. Something keyed on the month is needed.
- Run `docker compose up` twice in a row afterwards. Idempotency has been
  verified three times host-native but only once through the container. That
  test costs 26 minutes today and about 40 seconds once the window lands.

After that, Phase 5, which is a decision and not code, and the actual blocker
for CI/CD.
