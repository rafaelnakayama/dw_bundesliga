CREATE OR ALTER PROCEDURE silver.load_silver AS

BEGIN

    BEGIN TRANSACTION

    PRINT '>>> Dropping table: silver.match_goals';
    IF OBJECT_ID ('silver.match_goals', 'U') IS NOT NULL
        DROP TABLE silver.match_goals;

    PRINT '>>> Dropping table: silver.match_results';
    IF OBJECT_ID ('silver.match_results', 'U') IS NOT NULL
        DROP TABLE silver.match_results;

    PRINT '>>> Dropping table: silver.matches';
    IF OBJECT_ID ('silver.matches', 'U') IS NOT NULL
        DROP TABLE silver.matches;

    PRINT '>>> Dropping table: silver.groups';
    IF OBJECT_ID ('silver.groups', 'U') IS NOT NULL
        DROP TABLE silver.groups;

    PRINT '>>> Dropping table: silver.teams';
    IF OBJECT_ID ('silver.teams', 'U') IS NOT NULL
        DROP TABLE silver.teams;

    PRINT '>>> Dropping table: silver.location';
    IF OBJECT_ID ('silver.location', 'U') IS NOT NULL
        DROP TABLE silver.location;

    CREATE TABLE silver.groups (

        group_name VARCHAR(50),
        group_order_id INT,
        group_id INT PRIMARY KEY

    )

    CREATE TABLE silver.teams (

        team_id INT PRIMARY KEY,
        team_name VARCHAR(50),
        team_short_name VARCHAR(25),
        team_icon_url VARCHAR(150)

    )

    CREATE TABLE silver.location (

        location_id INT PRIMARY KEY,
        location_city VARCHAR(50),
        location_stadium VARCHAR(50)

    )

    CREATE TABLE silver.matches (

        match_id INT PRIMARY KEY,
        group_id INT,
        CONSTRAINT fk_matches_group_id FOREIGN KEY (group_id) REFERENCES silver.groups(group_id),
        team1_id INT,
        CONSTRAINT fk_matches_team1_id FOREIGN KEY (team1_id) REFERENCES silver.teams(team_id),
        team2_id INT,
        CONSTRAINT fk_matches_team2_id FOREIGN KEY (team2_id) REFERENCES silver.teams(team_id),
        location_id INT,
        CONSTRAINT fk_matches_location_id FOREIGN KEY (location_id) REFERENCES silver.location(location_id),
        match_date_time DATETIME,
        time_zone_id VARCHAR(50),
        league_id INT,
        league_name NVARCHAR(75),
        league_season INT,
        league_shortcut VARCHAR(50),
        match_date_time_utc DATETIME,
        last_update_date_time DATETIME,
        match_is_finished BIT,
        number_of_viewers INT

    )

    CREATE TABLE silver.match_results (

        result_id INT PRIMARY KEY,
        match_id INT,
        CONSTRAINT fk_match_results_match_id FOREIGN KEY (match_id) REFERENCES silver.matches(match_id),
        result_name VARCHAR(25),
        points_team1 TINYINT,
        points_team2 TINYINT,
        result_order_id TINYINT,
        result_type_id TINYINT,
        result_description VARCHAR(125)

    )

    CREATE TABLE silver.match_goals (

        goal_id INT PRIMARY KEY,
        match_id INT,
        CONSTRAINT fk_match_goals_match_id FOREIGN KEY (match_id) REFERENCES silver.matches(match_id),
        score_team1 TINYINT,
        score_team2 TINYINT,
        match_minute TINYINT,
        goal_getter_id INT,
        goal_getter_name VARCHAR(50),
        is_penalty BIT,
        is_own_goal BIT,
        is_overtime BIT,
        comment VARCHAR(100)

    )

    PRINT '';
    PRINT '>>> Empty silver tables successfuly created';
    PRINT '';

    ---------------------- (silver.groups) --------------------------

    PRINT '>>> Inserting Data Into: silver.groups';

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

    PRINT '';
    PRINT '>>> Inserting Data Into: silver.location';

    INSERT INTO silver.location (
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

    PRINT '';
    PRINT '>>> Inserting Data Into: silver.teams';

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

    PRINT '';
    PRINT '>>> Inserting Data Into: silver.matches';

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

    PRINT '';
    PRINT '>>> Inserting Data Into: silver.match_results';

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

    ---------------------- (silver.match_goals) --------------------------
    PRINT '';
    PRINT '>>> Inserting Data Into: silver.match_goals';

    INSERT INTO silver.match_goals (
        goal_id,
        match_id,
        score_team1,
        score_team2,
        match_minute,
        goal_getter_id,
        goal_getter_name,
        is_penalty,
        is_own_goal,
        is_overtime,
        comment
    )

    SELECT
        goalID,
        matchID,
        scoreTeam1,
        scoreTeam2,
        matchMinute,
        goalGetterID,
        TRIM(goalGetterName) AS goalGetterName,
        isPenalty,
        isOwnGoal,
        isOvertime,
        comment

    FROM bronze.dataframe

    CROSS APPLY OPENJSON(goals) WITH (
        goalID INT,
        scoreTeam1 TINYINT,
        scoreTeam2 TINYINT,
        matchMinute SMALLINT,
        goalGetterID INT,
        goalGetterName VARCHAR(100),
        isPenalty BIT,
        isOwnGoal BIT,
        isOvertime BIT,
        comment VARCHAR(150)
    )

    WHERE goalGetterID != 0

    PRINT '';
    PRINT '>>> Silver tables sucessfully loaded';

    COMMIT

END