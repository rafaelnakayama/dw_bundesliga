# Roadmap progress 1

Sessions: 2026-08-28 and 2026-08-31. Branch: `fix/macos_compatibility`.

This is a log of what actually happened against `roadmap.md`, including the
parts that went off-script. The roadmap is the plan; this is the diff between
the plan and reality.

## Phase 1 — closed for real

Phase 1 was already ticked, but only the DBeaver connection half had ever
happened. `init_database.sql` had never been run against the container, so
`dw_hgg_database` did not exist. This surfaced as a `pyodbc` error 4060,
"Cannot open database requested by the login", not as anything obviously
related to Phase 1.

Ran, in order: `init_database.sql`, then `proc_load_bronze.sql` to create the
procedure, then `EXEC bronze.load_bronze` to create the empty table.

Lesson: a ticked checkbox is not evidence. The done-when criteria are.

## Phase 2 — done

- ODBC stack installed on the Mac: `unixodbc` + `msodbcsql18` via Homebrew's
  Microsoft tap. Note the version: macOS/Apple Silicon has **18**, not 17.
  The `17` in the old code came from the Windows machine.
- Connection details moved to a gitignored `.env`, read via `python-dotenv`
  and `os.environ[...]` (not `os.getenv`, so a missing key fails loudly).
- `load_bronze()` finished and wired into `main()`. It had never been called
  from anywhere; on `main` it does not even exist.
- Driver 18 encrypts by default and rejects the container's self-signed
  certificate, so the connection string needs `TrustServerCertificate=yes`.
  Driver 17 did not encrypt by default, which is why this never came up on
  Windows.

Verified: a run produced 6426 distinct matches across 21 seasons.

## Off-script work (not on the roadmap)

**Per-file raw layer.** `fetch_matches.py` used to accumulate all ~714 API
responses in memory and write one `dataframe.json` at the very end. A crash at
minute 11 lost everything. Now each matchday is written immediately to
`datasets/raw/{season}/{matchday}.json`. `load_bronze()` reads them with
`data_path.glob("raw/*/*.json")`.

**Error handling.** `create_url` swallowed `RequestException`, printed a
message, and returned `[]`. Two problems: `requests` does not raise on HTTP
404/500, so the case the message described never reached the handler; and
returning `[]` meant `extend([])` silently dropped a matchday with no marker
anywhere. Replaced with `raise_for_status()` and no handler at all, plus a
`timeout=10` (without one, a hung connection never raises).

**Docker volume.** The compose file had no volume, so the database lived in
the container's writable layer and `docker compose down` would have destroyed
it. Added `mssql_data:/var/opt/mssql`. Note that `volumes:` must appear twice:
once inside the service (mount it) and once at the top level (declare it).
Only one of the two is not enough, and each half fails differently.

**Editor.** basedpyright in Zed defaults to `typeCheckingMode: "recommended"`,
far stricter than VS Code's Pylance. Pinned to `"standard"` globally. Ruff was
also running as a second language server and owned the import-sorting warning;
disabled it for Python. Both changes live in `~/.config/zed/settings.json`,
backed up in the `xperiunlab` repo. Zed has no run button, so `.zed/tasks.json`
holds tasks for the Python script and for running SQL files.

## Walls hit from later phases

**Phase 4 arrived early, twice.**

1. The pipeline is not idempotent. `load_bronze()` only `INSERT`s, never
   clears. Running the script three times produced 12276 rows for 6426 real
   matches, some matches present 3 times.
2. The API returns matches in an unstable order. 177 of 714 files showed as
   modified in git while containing identical data, just reshuffled. Confirmed
   by comparing sorted-by-`matchID`: same set, different sequence. This rules
   out file hashing or diffing as a change-detection strategy for Phase 4, and
   points at `lastUpdateDateTime` (already stored per match) as the field that
   actually answers "did this change".

## Open issues, as of 2026-08-28

- **Idempotency.** Stopgap: clear the table before loading (`TRUNCATE`, or call
  the existing drop/recreate proc from Python). Real fix is Phase 4's upsert
  on `matchID`.
- **No skip-if-exists.** Every run re-downloads all 714 matchdays even though
  seasons before the current one are frozen. Build `file_path` before the fetch
  and `continue` if it exists. Caveat: the current season is not frozen, so a
  blanket skip would leave it permanently stale.
- **Non-deterministic file output.** Sorting each matchday by `matchID` before
  `json.dump` would make git diffs meaningful.
- **Naming collision.** The SQL procedure `bronze.load_bronze` and the Python
  function `load_bronze()` share a name but no longer do the same thing: since
  the BULK load was stripped, the proc only creates an empty table and Python
  fills it.

All of these are resolved below except the fetch window.

---

# Session 2 — 2026-08-31

Went in planning to start Phase 3, ended up closing the bronze half of Phase 4
instead. The reason for the detour is the whole lesson of the session: Phase
3's done-when criterion is "`docker compose up` takes a clean clone to a loaded
database", and that is a test you run ten times in a row while fighting the
Dockerfile. With a non-idempotent load, every one of those runs corrupts the
table, so the oracle for Phase 3 was broken until Phase 4 landed.

## Modeling review

Went back to `integration_model.md` expecting to find missing keys. There were
none: every PK and FK in that document is already implemented in
`proc_load_silver.sql`, including the constraint naming and the parent-before-
child ordering of the `CREATE`s. The document and the code agree.

The only table with no key at all was `bronze.dataframe`, and that turned out
not to be an oversight but the unmade decision below.

Validated the model against the 6426 real matches on disk rather than
reasoning about it:

- `group_id` as PK is safe: 714 distinct groupIDs, zero reused across seasons.
- `location_id` as PK is safe: 178 distinct, zero conflicting attributes. And
  **4039 of 6426 matches have a null location**, which is why `silver.matches`
  needs `OUTER APPLY` where the other inserts use `CROSS APPLY`.
- `result_id` and `goal_id` are globally unique. Safe.
- `team_id` is safe with one caveat, below.

## Bronze: mirror, not history

The decision Phase 4 was actually waiting on. Two options for what bronze *is*:
a mirror of the source's current state (one row per match, upserted), or a
history of every version ever seen (append-only, silver picks the latest).

Chose **mirror**, on the grounds that the API is re-fetchable, so bronze is a
convenience rather than the only surviving copy.

That decision cascades: `matchID` becomes the primary key, the load becomes a
`MERGE`, and "create the table" and "wipe the table" stop being the same
operation.

## What shipped

**Bronze is idempotent.** Verified by rebuilding from scratch and running the
pipeline three times:

```
1st (backfill): bronze=6426 distinct=6426 staging=0 checksum=1746119722
2nd:            bronze=6426 distinct=6426 staging=0 checksum=1746119722
3rd:            bronze=6426 distinct=6426 staging=0 checksum=1746119722
```

Checksum, not just row count. Before this, three runs produced 12276+ rows.

The pieces:

- `proc_load_bronze.sql` → `proc_init_bronze.sql`. `bronze.init_bronze` is now
  idempotent DDL: `IF OBJECT_ID(...) IS NULL CREATE TABLE`, never a drop. It
  creates `bronze.dataframe` (with `matchID` as PK) and
  `bronze.dataframe_staging`.
- `proc_merge_bronze.sql`, new. `MERGE` from staging into bronze on `matchID`,
  then `TRUNCATE` the staging table.
- `rebuild_bronze.sql`, new. The destructive path, explicit and manual.
- `fetch_matches.py`: `load_json()` calls `init_bronze`, clears staging, inserts
  into staging, then calls `merge_bronze`.
- `runner.sql` and `.zed/tasks.json` pointed at the old procedure name.

Two choices worth remembering, both commented in the code:

1. The `UPDATE` arm only fires on
   `source.lastUpdateDateTime > target.lastUpdateDateTime`. That is what makes
   a day with no new results cost zero writes, which is Phase 4's done-when.
2. There is deliberately **no** `WHEN NOT MATCHED BY SOURCE ... DELETE`.
   Staging will eventually hold only the fetched window; a delete arm would
   erase every season outside it. This is the trap that the incremental
   redesign would otherwise walk straight into.

The staging table has its own PK so a duplicated `matchID` inside one batch
fails at the `INSERT`, with a readable message, instead of failing inside the
`MERGE` with "attempted to UPDATE or DELETE the same row more than once".

## Bugs found and fixed along the way

**A regression introduced by Phase 2, not yet triggered.** `json.dumps(None)`
returns the 4-character string `"null"`, not SQL `NULL`. Confirmed in the
container:

```
OPENJSON(CAST(NULL AS NVARCHAR(MAX)))  ->  0 rows, no error
OPENJSON('null')                       ->  Msg 13609, JSON text is not properly formatted
```

The old `OPENROWSET(BULK ...)` path wrote real `NULL`s, so this never came up
on Windows. The Python loader wrote the string, so `silver.load_silver` would
have aborted on the first of the 4039 location-less matches. It had not
surfaced only because bronze happened to be empty. Fixed with an `as_json()`
helper that passes `None` through untouched. Note that switching `CROSS APPLY`
to `OUTER APPLY` does *not* fix this: the error is raised by `OPENJSON`, not by
the `APPLY`.

**Silent truncation.** Measured every string field against its declared width:
`teamIconUrl` is really 193 characters (declared 150, 34 rows truncated) and
`resultDescription` is really 126 (declared 100, 306 rows truncated). Also
found four columns whose `OPENJSON` declaration disagreed with the target
column's width; those fit today but would fail on the first longer value.

**A non-deterministic dedup.** `silver.teams` picks one row per team with
`ROW_NUMBER() OVER (PARTITION BY teamId ORDER BY teamName)`. Bayern (teamId 40)
has two variants that differ only in `teamIconUrl`, and their `teamName` is
identical, so the `ORDER BY` had nothing to sort on and the winner was decided
by whatever plan the optimizer chose. Same input, potentially different output.

Worth being precise about what this was and was not: there is only one Bayern,
and `silver.teams` always had exactly 39 rows. The two rows existed only inside
the intermediate CTE, as two snapshots of the same team taken in different
seasons. The bug was never a duplicate; it was *which snapshot won*.

Fixed by carrying `matchID` and `matchDateTime` into the CTE and ordering
`matchDateTime DESC, matchID DESC`, which makes it a proper SCD type 1: the
most recently seen version wins, deterministically. Checked afterwards which
variant that is:

```
680 matches | seasons 2006-2026 | .../Logo_FC_Bayern_München_(2002–2017).svg  <- wins
 34 matches | seasons 2009-2009 | .../openligadb.de/.../Bayern_Muenchen.gif
```

Not a rebrand over time. The `.gif` appears only in season 2009, an isolated
inconsistency in the source. Recency picks correctly either way.

Rule taken from this: a `ROW_NUMBER` used for deduplication must have an
`ORDER BY` that ends in a unique column, or it hides a coin flip.

**Two edits that went the wrong way.** An unguarded `DROP TABLE` added above
the existing `IF OBJECT_ID` guard, which would have made the procedure fail on
a fresh database, and a bare `ORDER BY` in the procedure body, which is not
valid T-SQL at all. Both were reverted. The useful part is why they missed:
they were made in `proc_load_bronze.sql`, and nothing in the pipeline executed
that procedure. The duplication was happening in Python. The naming collision
logged in session 1 is exactly what made the wrong file look like the right one.

Also: a table has no inherent order. Ordering is a property of a query result,
produced by `ORDER BY` inside a `SELECT`. The reshuffling problem was never in
SQL at all; it was the order of the JSON array inside the raw files, fixed with
one `day.sort(key=...)` before `json.dump`.

## Verification

End-to-end, from an empty database, without touching the API (the 714 raw
files were already on disk):

| Check | Result |
|---|---|
| bronze rows / distinct | 6426 / 6426 |
| `[location]` stored as real NULL | 4039, zero `'null'` strings |
| silver loads without Msg 13609 | yes |
| location-less matches preserved | 4039 |
| Bayern | 1 row, stable icon |
| longest `teamIconUrl` survives | 193 |
| longest `resultDescription` survives | 126 |
| goals after the `!= 0` filter | 15379 = 15524 − 145 |
| three consecutive runs | identical checksum |

The `MERGE` update arm was tested separately by aging one row by hand
(`lastUpdateDateTime = '2000-01-01'`, `numberOfViewers = -1`) and re-running:
the real values came back, no new row appeared, total stayed 6426.

Load time for the full 6426-row backfill: 9 seconds.

## Still open at the end of this session

Superseded by `roadmap_progress_2.md`, which covers Phase 3 and the scope cut
that followed. Kept here only so the record of what was true on 2026-08-31
stays readable: at this point the fetch window was untouched and Phase 3 had
not been started.
