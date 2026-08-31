/*
=============================================================
Rebuild the bronze layer from scratch
=============================================================
Script Purpose:
    Drops bronze.dataframe and bronze.dataframe_staging, then recreates them
    empty via bronze.init_bronze.

    This is the disaster recovery / bootstrap path. It is NOT part of a normal
    run: the pipeline calls bronze.init_bronze (which never destroys) and
    bronze.merge_bronze (which upserts).

WARNING:
    Running this deletes every row in the bronze layer. The data is
    reconstructible from datasets/raw/, but silver depends on bronze, so
    silver.load_silver has to run again afterwards.
*/

USE dw_hgg_database;
GO

DROP TABLE IF EXISTS bronze.dataframe_staging;
DROP TABLE IF EXISTS bronze.dataframe;
GO

EXEC bronze.init_bronze;
GO
