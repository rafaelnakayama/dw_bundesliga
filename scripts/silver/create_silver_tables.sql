USE dw_hgg_database

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

COMMIT