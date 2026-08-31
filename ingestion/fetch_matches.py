import requests
import pyodbc
import json
import time
from pathlib import Path

import os
from dotenv import load_dotenv
load_dotenv()

seasons = range(2006, 2027) # We want all seasons from 2006 - 2026
matchday = range(1,35) # We want all the matchdays from the season
data_path = Path(__file__).parent.parent / "datasets"

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

    for i in seasons_loop:
        for j in matchday_loop:
            
            day = create_url(i, j)
            day.sort(key=lambda match: match["matchID"])
            file_path = data_path / "raw" / str(i) / f"{j}.json"
            file_path.parent.mkdir(parents=True, exist_ok=True)
        
            with open (file_path, "w") as file:
                json.dump(day, file , indent=4)
                
            time.sleep(0.3)
            

def as_json(value):

    """
    Serializes a nested field, but keeps None as None so pyodbc binds a real
    SQL NULL. json.dumps(None) would return the string "null", which OPENJSON
    rejects with error 13609.
    """

    return json.dumps(value) if value is not None else None


def load_bronze():

    """
    Loads the data from datasets / raw to the bronze layer
    """

    connector = pyodbc.connect(
        "DRIVER={ODBC Driver 18 for SQL Server};"
        f"SERVER={os.environ['DB_SERVER']};"
        f"DATABASE={os.environ['DB_DATABASE']};"
        f"UID={os.environ['DB_USER']};"
        f"PWD={os.environ['DB_PASSWORD']};"
        "TrustServerCertificate=yes"
    )

    cursor = connector.cursor()

    for file_path in data_path.glob("raw/*/*.json"):
        with open(file_path) as file:
            data = json.load(file)

        for match in data:
            cursor.execute("""
            INSERT INTO bronze.dataframe (
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


if __name__ == "__main__":

    loop_and_write(seasons, matchday)
    load_bronze()