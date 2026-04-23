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
CROSS APPLY OPENJSON([group]) WITH ( -- applies a function to eahc row individually,
    groupName VARCHAR(50), -- for each row in the bronze table , take the group column and pass it to OPENJSONN
    groupOrderId INT,
    groupID INT
)

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
)

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

---------------------------------------------------------------

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

COMMIT