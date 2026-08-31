CREATE OR ALTER PROCEDURE bronze.merge_bronze AS

BEGIN

    /*
    Drains bronze.dataframe_staging into bronze.dataframe.

    Mirror model: one row per match, matched on matchID. A row is only
    rewritten when the source is actually newer, so re-running on a day with
    no new results performs zero writes.

    There is deliberately no WHEN NOT MATCHED BY SOURCE ... DELETE clause.
    Staging holds only the window this run fetched, so a delete would wipe
    every match outside that window.
    */

    BEGIN TRANSACTION

    MERGE bronze.dataframe AS target
    USING bronze.dataframe_staging AS source
        ON target.matchID = source.matchID

    -- lastUpdateDateTime is the source's own "this changed" marker
    WHEN MATCHED AND source.lastUpdateDateTime > target.lastUpdateDateTime THEN
        UPDATE SET
            target.matchDateTime      = source.matchDateTime,
            target.timeZoneID         = source.timeZoneID,
            target.leagueId           = source.leagueId,
            target.leagueName         = source.leagueName,
            target.leagueSeason       = source.leagueSeason,
            target.leagueShortcut     = source.leagueShortcut,
            target.matchDateTimeUTC   = source.matchDateTimeUTC,
            target.[group]            = source.[group],
            target.team1              = source.team1,
            target.team2              = source.team2,
            target.lastUpdateDateTime = source.lastUpdateDateTime,
            target.matchIsFinished    = source.matchIsFinished,
            target.matchResults       = source.matchResults,
            target.goals              = source.goals,
            target.[location]         = source.[location],
            target.numberOfViewers    = source.numberOfViewers

    WHEN NOT MATCHED BY TARGET THEN
        INSERT (
            matchID, matchDateTime, timeZoneID, leagueId, leagueName,
            leagueSeason, leagueShortcut, matchDateTimeUTC, [group],
            team1, team2, lastUpdateDateTime, matchIsFinished,
            matchResults, goals, [location], numberOfViewers
        )
        VALUES (
            source.matchID, source.matchDateTime, source.timeZoneID,
            source.leagueId, source.leagueName, source.leagueSeason,
            source.leagueShortcut, source.matchDateTimeUTC, source.[group],
            source.team1, source.team2, source.lastUpdateDateTime,
            source.matchIsFinished, source.matchResults, source.goals,
            source.[location], source.numberOfViewers
        );

    PRINT '';
    PRINT '>>> Rows affected by merge: ' + CAST(@@ROWCOUNT AS VARCHAR);

    -- leave staging clean for the next run
    TRUNCATE TABLE bronze.dataframe_staging;

    COMMIT

END
