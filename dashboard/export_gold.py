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
SELECT TOP 10
    T.team_name,
    T.team_icon_url,
    COUNT(*) AS played,
    SUM(CASE WHEN P.points = 3 THEN 1 ELSE 0 END) AS won,
    SUM(CASE WHEN P.points = 1 THEN 1 ELSE 0 END) AS drawn,
    SUM(CASE WHEN P.points = 0 THEN 1 ELSE 0 END) AS lost,
    SUM(P.goals_for) AS goals_for,
    SUM(P.goals_against) AS goals_against,
    SUM(P.goals_for) - SUM(P.goals_against) AS goal_difference,
    SUM(P.points) AS points
FROM per_team AS P
INNER JOIN gold.dim_teams AS T ON T.team_id = P.team_id
GROUP BY T.team_name, T.team_icon_url
ORDER BY points DESC, goal_difference DESC, goals_for DESC, T.team_name
"""

# is_own_goal is excluded because the source credits an own goal to the player
# who put it in his own net. Counting those would inflate his tally.
#
# Every top-N here ends on a name, so ties resolve the same way twice. Without it
# the server picks freely among equals and the weekly export swaps names around
# with no change in the data underneath.
TOP_SCORERS_SEASON = """
SELECT TOP 5
    P.player_name,
    COUNT(*) AS goals
FROM gold.fact_goals AS G
INNER JOIN gold.dim_players AS P ON P.player_id = G.goal_getter_id
WHERE G.league_season = ? AND G.is_own_goal = 0
GROUP BY P.player_name
ORDER BY goals DESC, P.player_name
"""

# Janela movel de dez temporadas, contada da mais recente presente nos fatos. O
# piso importa: a fonte atribui varios goalGetterID a uma pessoa nas temporadas
# antigas, e Ribery aparece em tres ids que se sobrepoem. Os nomes se padronizam
# por volta de 2010, entao uma janela de dez anos cai inteira dentro da faixa
# confiavel e o ranking sai correto sem aviso nenhum na pagina.
TOP_SCORERS_LAST_10 = """
SELECT TOP 5
    P.player_name,
    COUNT(*) AS goals
FROM gold.fact_goals AS G
INNER JOIN gold.dim_players AS P ON P.player_id = G.goal_getter_id
WHERE G.is_own_goal = 0 AND G.league_season >= ?
GROUP BY P.player_name
ORDER BY goals DESC, P.player_name
"""

MOST_WINS_ALL_TIME = """
SELECT TOP 10
    T.team_name,
    COUNT(*) AS wins
FROM gold.fact_matches AS F
INNER JOIN gold.dim_teams AS T ON T.team_id = F.winner_team_id
GROUP BY T.team_name
ORDER BY wins DESC, T.team_name
"""

# Recortado em 2010 pelo mesmo motivo dos artilheiros: a cobertura de local e
# ruim nas temporadas antigas, entre location_id nulo, porque silver resolve com
# OUTER APPLY, e linhas com nome de estadio vazio. De 2010 em diante a cobertura
# se sustenta, entao o recorte entrega um ranking correto em vez de um parcial.
MATCHES_BY_VENUE = """
SELECT TOP 10
    L.location_stadium,
    L.location_city,
    COUNT(*) AS matches
FROM gold.fact_matches AS F
INNER JOIN gold.dim_locations AS L ON L.location_id = F.location_id
WHERE L.location_stadium <> '' AND F.league_season >= 2010
GROUP BY L.location_stadium, L.location_city
ORDER BY matches DESC, L.location_stadium
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
        "top_scorers_last_10": rows(cursor, TOP_SCORERS_LAST_10, season - 9),
        "most_wins_all_time": rows(cursor, MOST_WINS_ALL_TIME),
        "matches_by_venue": rows(cursor, MATCHES_BY_VENUE),
    }

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(payload, indent=2, ensure_ascii=False))

    logging.info("Wrote %s (%.1f KB)", OUTPUT_PATH, OUTPUT_PATH.stat().st_size / 1024)

    connector.close()


if __name__ == "__main__":
    main()
