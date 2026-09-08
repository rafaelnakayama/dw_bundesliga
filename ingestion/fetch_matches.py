import requests
import datetime
import json
import re
import time
import logging
import os
from pathlib import Path

DATA_PATH = Path(__file__).parent.parent / "datasets"
SCRIPTS_PATH = Path(__file__).parent.parent / "scripts"

def current_season():

    """
    The season a normal run should fetch. A Bundesliga season crosses the year
    boundary (2026 runs from August 2026 to May 2027), so datetime.now().year
    is wrong from January through July.
    """

    today = datetime.date.today()
    return today.year if today.month >= 7 else today.year - 1
    

def create_url(seasons_param, matchday_param):

    """
    This function generates the url to gather data from
    the website, it takes one day at a time.
    """

    url = f'https://api.openligadb.de/getmatchdata/bl1/{seasons_param}/{matchday_param}'
    request = requests.get(url, timeout=10)
    request.raise_for_status()
    return request.json()
    

def loop_and_write(seasons_loop, matchday_loop):

    """
    This function loops through each matchday and each season,
    going all the way to select all data, and writing it to
    a .json file at each call
    """
    
    skipped = 0

    for i in seasons_loop:
        for j in matchday_loop:
            time.sleep(0.3)
            try:
                day = create_url(i, j)
            except requests.RequestException:
                skipped += 1
                logging.warning("failed %s/%s, skipping", i, j)
                continue
                
            day.sort(key=lambda match: match["matchID"])
            file_path = DATA_PATH / "raw" / str(i) / f"{j}.json"
            file_path.parent.mkdir(parents=True, exist_ok=True)
        
            with open (file_path, "w") as file:
                json.dump(day, file , indent=4)
            
    logging.info("done, %s matchdays skipped", skipped)
            

def as_json(value):

    """
    Serializes a nested field, but keeps None as None so pyodbc binds a real
    SQL NULL. json.dumps(None) would return the string "null", which OPENJSON
    rejects with error 13609.
    """

    return json.dumps(value) if value is not None else None


def connect(database):

    """
    Opens a connection, retrying until SQL Server answers. Compose's depends_on
    only waits for the container to start, and the server accepts TCP a good
    while before it is ready to serve, so without this the ingestion container
    dies on the first run of a fresh stack.
    """

    import pyodbc

    connection_string = (
        "DRIVER={ODBC Driver 18 for SQL Server};"
        f"SERVER={os.environ['DB_SERVER']};"
        f"DATABASE={database};"
        f"UID={os.environ['DB_USER']};"
        f"PWD={os.environ['DB_PASSWORD']};"
        "TrustServerCertificate=yes"
    )

    attempt = 1

    while True:
        try:
            return pyodbc.connect(connection_string, timeout=5)
        except pyodbc.Error:
            if attempt == 30:
                raise
            logging.info("Waiting for %s (%s/30)", os.environ['DB_SERVER'], attempt)
            time.sleep(2)
            attempt += 1


def run_sql_file(cursor, file_path):

    """
    Executes a .sql file one batch at a time. GO is not T-SQL, it is a batch
    separator that sqlcmd understands and pyodbc does not, so the file has to
    be split on it before anything is sent.
    """

    batches = re.split(
        r"^\s*GO\s*$", file_path.read_text(), flags=re.MULTILINE | re.IGNORECASE
    )

    for batch in batches:
        if batch.strip():
            cursor.execute(batch)


def deploy_schema():

    """
    Applies the database, the schemas and the stored procedures, so a clean
    clone reaches a working database with nothing run by hand. Every script
    used here is idempotent; the destructive ones (init_database.sql and
    rebuild_bronze.sql) are deliberately left out.
    """

    # CREATE DATABASE cannot run inside a transaction, hence autocommit
    with connect("master") as connector:
        connector.autocommit = True
        logging.info("Applying: init_schemas.sql")
        run_sql_file(connector.cursor(), SCRIPTS_PATH / "init" / "init_schemas.sql")

    procedures = (
        Path("bronze") / "proc_init_bronze.sql",
        Path("bronze") / "proc_merge_bronze.sql",
        Path("silver") / "proc_load_silver.sql",
    )

    with connect(os.environ["DB_DATABASE"]) as connector:
        connector.autocommit = True
        for procedure in procedures:
            logging.info("Applying: %s", procedure.name)
            run_sql_file(connector.cursor(), SCRIPTS_PATH / procedure)


def load_json():

    """
    Loads the data from datasets / raw into bronze.dataframe_staging, then
    lets bronze.merge_bronze upsert it into bronze.dataframe. Running this
    twice on unchanged data leaves the bronze layer exactly as it was.
    """

    connector = connect(os.environ["DB_DATABASE"])

    cursor = connector.cursor()

    cursor.execute("EXEC bronze.init_bronze")
    cursor.execute("TRUNCATE TABLE bronze.dataframe_staging")
    connector.commit()

    for file_path in DATA_PATH.glob("raw/*/*.json"):
        with open(file_path) as file:
            data = json.load(file)

        for match in data:
            cursor.execute("""
            INSERT INTO bronze.dataframe_staging (
                matchID, matchDateTime, timeZoneID, leagueId, leagueName, 
                leagueSeason, leagueShortcut, matchDateTimeUTC, [group], 
                team1, team2, lastUpdateDateTime, matchIsFinished, 
                matchResults, goals, [location], numberOfViewers
            )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, 
            match['matchID'], 
            match['matchDateTime'], 
            match['timeZoneID'], 
            match['leagueId'], 
            match['leagueName'], 
            match['leagueSeason'], 
            match['leagueShortcut'], 
            match['matchDateTimeUTC'], 
            as_json(match['group']), 
            as_json(match['team1']), 
            as_json(match['team2']), 
            match['lastUpdateDateTime'], 
            match['matchIsFinished'], 
            as_json(match['matchResults']), 
            as_json(match['goals']), 
            as_json(match['location']), 
            match['numberOfViewers']
        )
            
        connector.commit()

    cursor.execute("EXEC bronze.merge_bronze")
    connector.commit()


if __name__ == "__main__":
    
    from dotenv import load_dotenv
    load_dotenv()
    
    seasons = range(2006, current_season() + 1) # full range, used for the one-off backfill
    matchday = range(1,35) # We want all the matchdays from the season

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
    )

    if os.environ.get("BACKFILL") == "1":
        loop_and_write(seasons, matchday)
    else:
        loop_and_write(range(current_season(), current_season() + 1), matchday)

    if os.environ.get("FETCH_ONLY") != "1":
        deploy_schema()
        load_json()
