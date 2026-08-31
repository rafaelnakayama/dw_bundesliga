CREATE OR ALTER PROCEDURE bronze.init_bronze AS

BEGIN

    /*
    Idempotent DDL. Creates what is missing and never destroys anything, so it
    is safe to run before every load. The destructive path lives in
    rebuild_bronze.sql and is triggered by hand.
    */

    IF OBJECT_ID ('bronze.dataframe', 'U') IS NULL
    BEGIN

        PRINT '>>> Creating table: bronze.dataframe';

        CREATE TABLE bronze.dataframe (

            -- matchID is the identity of a match in the source system, so the
            -- mirror keeps exactly one row per match
            matchID INT NOT NULL PRIMARY KEY,

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

    END
    ELSE
        PRINT '>>> Table bronze.dataframe already exists';

    IF OBJECT_ID ('bronze.dataframe_staging', 'U') IS NULL
    BEGIN

        PRINT '>>> Creating table: bronze.dataframe_staging';

        /*
        Landing table for one run. Python fills it, bronze.merge_bronze drains
        it. The primary key makes a duplicated matchID inside a single batch
        fail here, with a clear message, instead of failing inside the MERGE.
        */

        CREATE TABLE bronze.dataframe_staging (

            matchID INT NOT NULL PRIMARY KEY,
            matchDateTime DATETIME,
            timeZoneID VARCHAR(50),
            leagueId INT,
            leagueName NVARCHAR(75),
            leagueSeason INT,
            leagueShortcut VARCHAR(50),
            matchDateTimeUTC DATETIME,
            [group] NVARCHAR(MAX),
            team1 NVARCHAR(MAX),
            team2 NVARCHAR(MAX),
            lastUpdateDateTime DATETIME,
            matchIsFinished BIT,
            matchResults NVARCHAR(MAX),
            goals NVARCHAR(MAX),
            [location] NVARCHAR(MAX),
            numberOfViewers INT

        )

    END
    ELSE
        PRINT '>>> Table bronze.dataframe_staging already exists';

END
