USE dw_hgg_database

BEGIN TRANSACTION

CREATE TABLE bronze.dataframe (

    matchID INT,
    matchDateTime DATE,
    timeZoneID VARCHAR(50),
    leagueId INT,
    leagueName VARCHAR(50),
    leagueSeason INT,
    leagueShortcut VARCHAR(50),
    matchDateTimeUTC DATE,
    
    -- extract nested types as raw .json strings
    [group] NVARCHAR(MAX),
    team1 NVARCHAR(MAX),
    team2 NVARCHAR(MAX),
    
    lastUpdateDateTime DATE,
    matchIsFinished VARCHAR(50),

    matchResults NVARCHAR(MAX),
    goals NVARCHAR(MAX),

    -- [] were used to identify 'location' as identifiers not keywords
    [location] NVARCHAR(MAX),
    numberOfViewers INT

)

COMMIT