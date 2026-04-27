USE dw_hgg_database

---------------------- (silver.groups) --------------------------

BEGIN TRANSACTION

INSERT INTO silver.groups (
    group_name,
    group_order_id,
    group_id
)

SELECT DISTINCT -- this entity appear in multiple match rows, so we use DISTINCT to get the unique ones
    groupName,
    groupOrderId,
    groupID

FROM bronze.dataframe
CROSS APPLY OPENJSON([group]) WITH ( -- applies a function to each row individually,
    groupName VARCHAR(50), -- for each row in the bronze table , take the group column and pass it to OPENJSONN
    groupOrderId INT,
    groupID INT
);

---------------------- (silver.location) --------------------------

INSERT INTO silver.[location] (
    location_id,
    location_city,
    location_stadium
)

SELECT DISTINCT -- ""
    locationID,
    locationCity,
    locationStadium

FROM bronze.dataframe

CROSS APPLY OPENJSON([location]) WITH (
    locationID INT,
    locationCity VARCHAR(50),
    locationStadium VARCHAR(50)
);

---------------------- (silver.teams) --------------------------

WITH teams_cte_1 AS (

    SELECT
        teamId,
        teamName,
        shortName,
        teamIconUrl

    FROM bronze.dataframe

    CROSS APPLY OPENJSON(team1) WITH (
        teamId INT,
        teamName VARCHAR(50),
        shortName VARCHAR(25),
        teamIconUrl VARCHAR(150)
    )

    UNION

    SELECT
        teamId,
        teamName,
        shortName,
        teamIconUrl

    FROM bronze.dataframe

    CROSS APPLY OPENJSON(team2) WITH (
        teamId INT,
        teamName VARCHAR(50),
        shortName VARCHAR(25),
        teamIconUrl VARCHAR(150)
    )

),

teams_cte_2 AS (

    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY C1.teamId ORDER BY C1.teamName) AS rn

    FROM teams_cte_1 AS C1

)

INSERT INTO silver.teams (
    team_id,
    team_name,
    team_short_name,
    team_icon_url
)

SELECT
    teamId,
    teamName,
    shortName,
    teamIconUrl

FROM teams_cte_2 AS C2

WHERE C2.rn = 1

---------------------- (silver.matches) --------------------------

INSERT INTO silver.matches (
    match_id,
    group_id,
    team1_id,
    team2_id,
    location_id,
    match_date_time,
    time_zone_id,
    league_id,
    league_name,
    league_season,
    league_shortcut,
    match_date_time_utc,
    last_update_date_time,
    match_is_finished,
    number_of_viewers
)

SELECT
    matchID,
    groupID,
    team1Id,
    team2Id,
    locationID,
    matchDateTime,
    timeZoneID,
    leagueId,
    leagueName,
    leagueSeason,
    leagueShortcut,
    matchDateTimeUTC,
    lastUpdateDateTime,
    matchIsFinished,
    numberOfViewers

FROM bronze.dataframe

CROSS APPLY OPENJSON([group]) WITH (
    groupID INT
)

CROSS APPLY OPENJSON(team1) WITH (
    team1Id INT '$.teamId'
)

CROSS APPLY OPENJSON(team2) WITH (
    team2Id INT '$.teamId'
)

OUTER APPLY OPENJSON([location]) WITH (
    locationID INT
) 

---------------------- (silver.match_results) --------------------------

INSERT INTO silver.match_results (
    result_id,
    match_id,
    result_name,
    points_team1,
    points_team2,
    result_order_id,
    result_type_id,
    result_description
)

SELECT
    resultID,
    matchID,
    resultName,
    pointsTeam1,
    pointsTeam2,
    resultOrderID,
    resultTypeID,
    resultDescription

FROM bronze.dataframe

CROSS APPLY OPENJSON(matchResults) WITH (
    resultID INT,
    resultName VARCHAR(50),
    pointsTeam1 TINYINT,
    pointsTeam2 TINYINT,
    resultOrderID TINYINT,
    resultTypeID TINYINT,
    resultDescription VARCHAR(100)
);

COMMIT