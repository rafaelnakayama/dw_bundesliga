CREATE OR ALTER PROCEDURE bronze.load_bronze AS

BEGIN

    PRINT '>>> Dropping table: bronze.dataframe';
    IF OBJECT_ID ('bronze.dataframe', 'U') IS NOT NULL
        DROP TABLE bronze.dataframe;

    BEGIN TRANSACTION

    CREATE TABLE bronze.dataframe (

        matchID INT,
        matchDateTime DATETIME,
        timeZoneID VARCHAR(50),
        leagueId INT,
        leagueName NVARCHAR(75),
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

    PRINT '';
    PRINT '>>> Empty bronze table successfuly created';
    PRINT '';

    COMMIT

END