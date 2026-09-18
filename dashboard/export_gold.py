"""
Queries gold and writes every number the dashboard displays into a single JSON
file. The page never sees the warehouse: it reads this file, which is tens of
kilobytes rather than tens of megabytes, so the rendered HTML stays light and
the weekly diff stays small.

Aggregation happens here, in SQL, for the same reason. Quarto only plots.

Run with the database up:  python dashboard/export_gold.py
"""

import json
import logging
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

# connect() lives in the ingestion module and already handles the startup race
# against SQL Server. Importing it beats a second copy that can drift.
sys.path.insert(0, str(Path(__file__).parent.parent))
from ingestion.fetch_matches import connect  # noqa: E402

OUTPUT_PATH = Path(__file__).parent / "data" / "dashboard.json"

# The 3/1/0 rule lives here, not in gold: one match distributes points to two
# teams, so there is no single column to hold them at the match grain.
STANDINGS = """
WITH per_team AS (
    SELECT
        team1_id AS team_id,
        goals_team1 AS goals_for,
        goals_team2 AS goals_against,
        CASE
            WHEN winner_team_id = team1_id THEN 3
            WHEN winner_team_id IS NULL THEN 1
            ELSE 0
        END AS points
    FROM gold.fact_matches
    WHERE league_season = ?

    UNION ALL

    SELECT
        team2_id,
        goals_team2,
        goals_team1,
        CASE
            WHEN winner_team_id = team2_id THEN 3
            WHEN winner_team_id IS NULL THEN 1
            ELSE 0
        END
    FROM gold.fact_matches
    WHERE league_season = ?
)
SELECT
    T.team_name,
    COUNT(*) AS played,
    SUM(P.points) AS points,
    SUM(P.goals_for) AS goals_for,
    SUM(P.goals_against) AS goals_against,
    SUM(P.goals_for) - SUM(P.goals_against) AS goal_difference
FROM per_team AS P
INNER JOIN gold.dim_teams AS T ON T.team_id = P.team_id
GROUP BY T.team_name
ORDER BY points DESC, goal_difference DESC, goals_for DESC
"""

# is_own_goal is excluded because the source credits an own goal to the player
# who put it in his own net. Counting those would inflate his tally.
TOP_SCORERS_SEASON = """
SELECT TOP 15
    P.player_name,
    COUNT(*) AS goals
FROM gold.fact_goals AS G
INNER JOIN gold.dim_players AS P ON P.player_id = G.goal_getter_id
WHERE G.league_season = ? AND G.is_own_goal = 0
GROUP BY P.player_name
ORDER BY goals DESC
"""

TOP_SCORERS_ALL_TIME = """
SELECT TOP 15
    P.player_name,
    COUNT(*) AS goals
FROM gold.fact_goals AS G
INNER JOIN gold.dim_players AS P ON P.player_id = G.goal_getter_id
WHERE G.is_own_goal = 0
GROUP BY P.player_name
ORDER BY goals DESC
"""

MOST_WINS_ALL_TIME = """
SELECT TOP 15
    T.team_name,
    COUNT(*) AS wins
FROM gold.fact_matches AS F
INNER JOIN gold.dim_teams AS T ON T.team_id = F.winner_team_id
GROUP BY T.team_name
ORDER BY wins DESC
"""

# A venue is missing in two different ways. location_id is nullable, because
# silver resolves it with OUTER APPLY, and some rows that do exist carry an empty
# stadium name. Both are excluded here and counted together below, so the page can
# state the number instead of implying the ranking is complete.
MATCHES_BY_VENUE = """
SELECT TOP 15
    L.location_stadium,
    L.location_city,
    COUNT(*) AS matches
FROM gold.fact_matches AS F
INNER JOIN gold.dim_locations AS L ON L.location_id = F.location_id
WHERE L.location_stadium <> ''
GROUP BY L.location_stadium, L.location_city
ORDER BY matches DESC
"""

MATCHES_WITHOUT_VENUE = """
SELECT COUNT(*)
FROM gold.fact_matches AS F
LEFT JOIN gold.dim_locations AS L ON L.location_id = F.location_id
WHERE F.location_id IS NULL OR L.location_stadium = ''
"""

# The latest season actually present in the facts, rather than today's date. A
# season with no finished matches yet would otherwise render an empty page.
LATEST_SEASON = "SELECT MAX(league_season) FROM gold.fact_matches"

TOTALS = """
SELECT
    (SELECT COUNT(*) FROM gold.fact_matches) AS matches,
    (SELECT COUNT(*) FROM gold.fact_goals) AS goals,
    (SELECT COUNT(*) FROM gold.dim_teams) AS teams,
    (SELECT COUNT(*) FROM gold.dim_players) AS players
"""


def rows(cursor, query, *params):

    """
    Runs a query and returns a list of dicts keyed on the column names, which is
    what json.dump needs and what the page indexes into.
    """

    cursor.execute(query, *params)
    columns = [column[0] for column in cursor.description]
    return [dict(zip(columns, row)) for row in cursor.fetchall()]


def scalar(cursor, query, *params):
    cursor.execute(query, *params)
    return cursor.fetchone()[0]


def main():

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

    from dotenv import load_dotenv
    load_dotenv()

    connector = connect(os.environ["DB_DATABASE"])
    cursor = connector.cursor()

    season = scalar(cursor, LATEST_SEASON)
    if season is None:
        raise SystemExit("gold.fact_matches is empty, run the pipeline first")

    logging.info("Exporting season %s", season)

    payload = {
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
        "season": season,
        "totals": rows(cursor, TOTALS)[0],
        "standings": rows(cursor, STANDINGS, season, season),
        "top_scorers_season": rows(cursor, TOP_SCORERS_SEASON, season),
        "top_scorers_all_time": rows(cursor, TOP_SCORERS_ALL_TIME),
        "most_wins_all_time": rows(cursor, MOST_WINS_ALL_TIME),
        "matches_by_venue": rows(cursor, MATCHES_BY_VENUE),
        "matches_without_venue": scalar(cursor, MATCHES_WITHOUT_VENUE),
    }

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(payload, indent=2, ensure_ascii=False))

    logging.info("Wrote %s (%.1f KB)", OUTPUT_PATH, OUTPUT_PATH.stat().st_size / 1024)

    connector.close()


if __name__ == "__main__":
    main()
