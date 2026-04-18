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

COMMIT