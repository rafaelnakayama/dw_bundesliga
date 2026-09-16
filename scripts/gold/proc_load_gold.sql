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

    PRINT '>>> Dropping table: gold.dim_locations';
    IF OBJECT_ID ('gold.dim_locations', 'U') IS NOT NULL
        DROP TABLE gold.dim_locations;

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
    
    -- Create and insert columns into dim_players

    CREATE TABLE gold.dim_players (
        player_id INT PRIMARY KEY,
        player_name VARCHAR(100)
    )

    INSERT INTO gold.dim_players (
        player_id,
        player_name
    )

    SELECT
        DISTINCT goal_getter_id AS player_id,
        goal_getter_name AS player_name
    FROM silver.match_goals

    -- Create and insert columns into dim_locations (dim_locations is a copy of silver.location)

    CREATE TABLE gold.dim_locations (
        location_id INT PRIMARY KEY,
        location_city VARCHAR(50),
        location_stadium VARCHAR(50)
    )

    INSERT INTO gold.dim_locations (
        location_id,
        location_city,
        location_stadium 
    )

    SELECT
        location_id,
        location_city,
        location_stadium

    FROM silver.location
    
    -- Create and insert columns into fact_matches

    CREATE TABLE gold.fact_matches (
        match_id INT PRIMARY KEY,
        group_id INT,
        location_id INT,
        CONSTRAINT fk_fact_matches_location_id FOREIGN KEY (location_id) REFERENCES gold.dim_locations(location_id),
        team1_id INT,
        CONSTRAINT fk_fact_matches_team1_id FOREIGN KEY (team1_id) REFERENCES gold.dim_teams(team_id),
        team2_id INT,
        CONSTRAINT fk_fact_matches_team2_id FOREIGN KEY (team2_id) REFERENCES gold.dim_teams(team_id),
        league_name NVARCHAR(75),
        league_season INT,
        match_date_time_utc DATETIME,
        number_of_viewers INT,
        goals_team1 INT,
        goals_team2 INT,
        total_goals INT,
        winner_team_id INT,
        CONSTRAINT fk_fact_matches_winner_team_id FOREIGN KEY (winner_team_id) REFERENCES gold.dim_teams(team_id)
    )

    INSERT INTO gold.fact_matches (
        match_id,
        group_id,
        location_id,
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
        MT.location_id,
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

    WHERE MT.match_is_finished = 1 AND (MR.result_type_id = 2 OR MR.result_type_id = 0)

    -- Create and insert columns into fact_goals

    CREATE TABLE gold.fact_goals (
        goal_id INT PRIMARY KEY,
        match_id INT,
        goal_getter_id INT,
        CONSTRAINT fk_fact_goals_goal_getter_id FOREIGN KEY (goal_getter_id) REFERENCES gold.dim_players(player_id),
        league_season INT,
        match_minute SMALLINT,
        is_penalty BIT,
        is_own_goal BIT,
        is_overtime BIT
    )

    INSERT INTO gold.fact_goals (
        goal_id,
        match_id,
        goal_getter_id,
        league_season,
        match_minute,
        is_penalty,
        is_own_goal,
        is_overtime
    )

    SELECT 
        MG.goal_id,
        MG.match_id,
        MG.goal_getter_id,
        MT.league_season,
        MG.match_minute,
        MG.is_penalty,
        MG.is_own_goal,
        MG.is_overtime

    FROM silver.match_goals AS MG
    INNER JOIN silver.matches as MT
    ON MG.match_id = MT.match_id
    
    COMMIT

END