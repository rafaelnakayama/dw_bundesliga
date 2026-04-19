import requests
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

    try:
        url = f'https://api.openligadb.de/getmatchdata/bl1/{seasons_param}/{matchday_param}'
        r = requests.get(url)

    except requests.RequestException:
        print("Error: Invalid value on either season/league")
        return [] # returning [] empty arrays instead of None doesn't break the code
    
    else:
        return r.json()

def loop_matches(seasons_loop, matchday_loop):

    """
    This function loops through the matchdays and seasons
    going all the way to select all data
    """
    
    store_data = []

    for i in seasons_loop:
        for j in matchday_loop:
            day = create_url(i, j)
            store_data.extend(day)
            time.sleep(1.0)
    
    return store_data

def write_down():

    """
    This function saves all the data gathered by the
    'loop_matches' function's list
    """

    dataframe = loop_matches(seasons, matchday)
    folder_path = Path(data_path)
    file_path = folder_path / "dataframe.json"

    folder_path.mkdir(parents=True, exist_ok=True)

    with open (file_path, "w") as file:
        json.dump(dataframe, file , indent=4)

if __name__ == "__main__":
    
    """
    It takes about 13 minutes to generate the .json file.
    there are 20 seasons x 35 matchdays, each matchday 
    from a season is a request, and time.sleep(1.0) makes
    each request sleep for a second before doing the next one
    """

    write_down()