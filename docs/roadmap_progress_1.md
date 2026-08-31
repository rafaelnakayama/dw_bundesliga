# Roadmap progress 1

Session date: 2026-08-28. Branch: `fix/macos_compatibility`.

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

## Open issues

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

## Next

Phase 3, containerizing the ingestion script. Worth knowing before starting:
inside the compose network, `localhost` no longer means the database, so the
`.env` work from Phase 2 is what makes the address swappable.
