import requests
#import pyodbc
import json
import time

from pathlib import Path

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
    This function loops through the matchdays and seasons
    going all the way to select all data, and writing it to
    a .json file at each call
    """

    for i in seasons_loop:
        for j in matchday_loop:
            
            day = create_url(i, j)
            file_path = data_path / "raw" / str(i) / f"{j}.json"
            file_path.parent.mkdir(parents=True, exist_ok=True)
        
            with open (file_path, "w") as file:
                json.dump(day, file , indent=4)
                
            time.sleep(0.3)

def load_bronze():

    """
    Loads the data from dataframe.json to the bronze layer
    """

    connector = pyodbc.connect(
        "DRIVER={ODBC Driver 17 for SQL Server};"
        "SERVER=localhost;"
        "DATABASE=dw_hgg_database;"
        "UID=sa;"
        "PWD=passwordblabla;" # Insert password here
    )

    cursor = connector.cursor()

    with open(dataframe_path) as file:
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
        json.dumps(match['group']), 
        json.dumps(match['team1']), 
        json.dumps(match['team2']), 
        match['lastUpdateDateTime'], 
        match['matchIsFinished'], 
        json.dumps(match['matchResults']), 
        json.dumps(match['goals']), 
        json.dumps(match['location']), 
        match['numberOfViewers']
    )
        
    connector.commit()


if __name__ == "__main__":

    loop_and_write(seasons, matchday)