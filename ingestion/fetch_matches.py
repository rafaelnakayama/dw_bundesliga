import requests
import json

from pathlib import Path

seasons = range(2006, 2027) # We want all seasons from 2006 - 2026
matchday = range(1,35) # We want all the matchdays from the season

data_path = 'dw_huggingface/datasets'

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
    
    else:
        return r.json()

def loop_matches(seasons_loop, matchday_loop):

    """
    This function loops through the matchdays and seasons
    going all the way to select all data
    """

    try:
        store_data = []

        for i in seasons_loop:
            for j in matchday_loop:
                day = create_url(i, j)
                store_data.append(day)

    except requests.RequestException:
        print("Error: Connection failed.")

    else:
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