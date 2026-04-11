USE dw_hgg_database

BEGIN TRANSACTION

CREATE TABLE bronze.dataframe (

    matchID INT,
    matchDateTime DATETIME,
    timeZoneID VARCHAR(50),
    leagueId INT,
    leagueName VARCHAR(75),
    leagueSeason INT,
    leagueShortcut VARCHAR(50),
    matchDateTimeUTC DATETIME,
    
    -- extract nested types as raw .json strings
    [group] NVARCHAR(MAX),
    team1 NVARCHAR(MAX),
    team2 NVARCHAR(MAX),
    
    lastUpdateDateTime DATETIME,
    matchIsFinished BIT,

    matchResults NVARCHAR(MAX),
    goals NVARCHAR(MAX),

    -- [] were used to identify 'location' as identifiers not keywords
    [location] NVARCHAR(MAX),
    numberOfViewers INT

)

COMMIT