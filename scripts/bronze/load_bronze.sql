USE dw_hgg_database

DECLARE @json NVARCHAR(MAX); -- TRANSFORM THE .CSV FILE INTO A HUGE STRING

SELECT @json = BulkColumn

FROM OPENROWSET (
    BULK 'C:\Users\Rafae\Projetos\dw_huggingface\datasets\dataframe.json',
    SINGLE_CLOB
) AS src;

SELECT
    matchID,
    matchDateTime,
    timeZoneID,
    leagueId,
    leagueName,
    leagueSeason,
    leagueShortcut,
    matchDateTimeUTC,
    [group],
    team1,
    team2,
    lastUpdateDateTime,
    matchIsFinished,
    matchResults,
    goals,
    [location],
    numberOfViewers
FROM OPENJSON(@json)

WITH (
    matchID INT,
    matchDateTime DATETIME,
    timeZoneID VARCHAR(50),
    leagueId INT,
    leagueName NVARCHAR(75),
    leagueSeason INT,
    leagueShortcut VARCHAR(50),
    matchDateTimeUTC DATETIME,
    [group] NVARCHAR(MAX) AS JSON,
    team1 NVARCHAR(MAX) AS JSON,
    team2 NVARCHAR(MAX) AS JSON,
    lastUpdateDateTime DATETIME,
    matchIsFinished BIT,
    matchResults NVARCHAR(MAX) AS JSON,
    goals NVARCHAR(MAX) AS JSON,
    [location] NVARCHAR(MAX) AS JSON,
    numberOfViewers INT
)