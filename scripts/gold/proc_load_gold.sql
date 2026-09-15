CREATE OR ALTER PROCEDURE gold.load_gold AS

BEGIN

    BEGIN TRANSACTION

    -- Drop tables if they already exist
    
    PRINT '>>> Dropping table: gold.fact_matches';
    IF OBJECT_ID ('gold.fact_matches', 'U') IS NOT NULL
        DROP TABLE gold.fact_matches;

    PRINT '>>> Dropping table: gold.fact_goals';
    IF OBJECT_ID ('gold.fact_goals', 'U') IS NOT NULL
        DROP TABLE gold.fact_goals;

    PRINT '>>> Dropping table: gold.dim_players';
    IF OBJECT_ID ('gold.dim_players', 'U') IS NOT NULL
        DROP TABLE gold.dim_players;

    PRINT '>>> Dropping table: gold.dim_teams';
    IF OBJECT_ID ('gold.dim_teams', 'U') IS NOT NULL
        DROP TABLE gold.dim_teams;

    -- Create and insert columns into dim_teams (dim_teams is a copy of silver.teams)

    CREATE TABLE gold.dim_teams (
        team_id INT PRIMARY KEY,
        team_name VARCHAR(50),
        team_short_name VARCHAR(25),
        team_icon_url VARCHAR(250)
    )

    INSERT INTO gold.dim_teams (
        team_id,
        team_name,
        team_short_name,
        team_icon_url
    )

    SELECT
        team_id,
        team_name,
        team_short_name,
        team_icon_url

    FROM silver.teams

    -- Create and insert columns into fact_matches

    CREATE TABLE gold.fact_matches (
        match_id INT PRIMARY KEY,
        group_id INT,
        team1_id INT,
        team2_id INT,
        league_name NVARCHAR(75),
        league_season INT,
        match_date_time_utc DATETIME,
        number_of_viewers INT,
        goals_team1 INT,
        goals_team2 INT,
        total_goals INT,
        winner_team_id INT
    )

    INSERT INTO gold.fact_matches (
        match_id,
        group_id,
        team1_id,
        team2_id,
        league_name,
        league_season,
        match_date_time_utc,
        number_of_viewers,
        goals_team1,
        goals_team2,
        total_goals,
        winner_team_id
    )

    SELECT 
        MT.match_id,
        MT.group_id,
        MT.team1_id,
        MT.team2_id,
        MT.league_name,
        MT.league_season,
        MT.match_date_time_utc,
        MT.number_of_viewers,
        MR.points_team1 AS goals_team1,
        MR.points_team2 AS goals_team2,
        (MR.points_team1 + MR.points_team2) AS total_goals,

    CASE 
        WHEN MR.points_team1 > MR.points_team2
            THEN team1_id
        WHEN MR.points_team1 < MR.points_team2
            THEN team2_id
        ELSE NULL
    END AS winner_team_id

    FROM silver.matches AS MT
    INNER JOIN silver.match_results AS MR
    ON MT.match_id = MR.match_id

    WHERE MT.match_is_finished = 1 AND MR.result_type_id = 2
    
    COMMIT

END