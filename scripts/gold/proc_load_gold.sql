CREATE OR ALTER PROCEDURE gold.load_gold AS

BEGIN

    BEGIN TRANSACTION

    PRINT '>>> Dropping table: gold.dim_teams';
    IF OBJECT_ID ('gold.dim_teams', 'U') IS NOT NULL
        DROP TABLE gold.dim_teams;

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