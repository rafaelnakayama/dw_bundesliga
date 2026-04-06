import requests
import json

seasons = range(2006, 2027)
matchday = range(1,35)

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
        return r.content

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
    
loop_matches(seasons, matchday)