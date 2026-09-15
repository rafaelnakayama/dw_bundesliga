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

    -- Create and insert columns into fact_matches

    CREATE TABLE gold.fact_matches (
        match_id INT PRIMARY KEY,
        league_name NVARCHAR(75),
        league_season INT,
        match_date_time_utc DATETIME,
        match_is_finished BIT,
        number_of_viewers INT
    )

    INSERT INTO gold.fact_matches (
        match_id,
        league_name,
        league_season,
        match_date_time_utc,
        match_is_finished,
        number_of_viewers
    )

    SELECT 
        match_id,
        league_name,
        league_season,
        match_date_time_utc,
        match_is_finished,
        number_of_viewers

    FROM silver.matches

    WHERE match_is_finished = 1

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
    
    COMMIT

END