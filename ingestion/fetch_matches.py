import requests
import json

league = 'bl1'
seasons = 2006
matchday = 1

def create_url(league_param, seasons_param, matchday_param):

    """
    This function generates the url to gather data from
    the website
    """

    url = f'https://api.openligadb.de/getmatchdata/{league_param}/{seasons_param}/{matchday_param}'

    r = requests.get(url)

    return print(r.content)

create_url(league, seasons, matchday)