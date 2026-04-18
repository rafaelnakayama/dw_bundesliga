USE dw_hgg_database

BEGIN TRANSACTION

IF OBJECT_ID ('silver.groups', 'U') IS NOT NULL
    DROP TABLE silver.groups;

CREATE TABLE silver.groups (

    group_name VARCHAR(50),
    group_order_id INT,
    group_id INT PRIMARY KEY

)

IF OBJECT_ID ('silver.teams', 'U') IS NOT NULL
    DROP TABLE silver.teams;

CREATE TABLE silver.teams (

    team_id INT PRIMARY KEY,
    team_name VARCHAR(50),
    team_short_name VARCHAR(25),
    team_icon_url VARCHAR(150)

)

IF OBJECT_ID ('silver.location', 'U') IS NOT NULL
    DROP TABLE silver.location;

CREATE TABLE silver.location (

    location_id INT PRIMARY KEY,
    location_city VARCHAR(50),
    location_stadium VARCHAR(50)

)

IF OBJECT_ID ('silver.matches', 'U') IS NOT NULL
    DROP TABLE silver.matches;

CREATE TABLE silver.matches (

    match_id INT PRIMARY KEY,
    CONSTRAINT group_id FOREIGN KEY (group_id) REFERENCES silver.groups(group_id),
    CONSTRAINT team1_id FOREIGN KEY (team1_id) REFERENCES silver.teams(team_id),
    CONSTRAINT team2_id FOREIGN KEY (team2_id) REFERENCES silver.teams(team_id),
    CONSTRAINT location_id FOREIGN KEY (location_id) REFERENCES silver.location(location_id),
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

COMMIT