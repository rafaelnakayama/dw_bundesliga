/*
=============================================================
Create Database and Schemas, idempotently
=============================================================
Script Purpose:
    Creates 'dw_hgg_database' and the bronze / silver / gold schemas only when
    they are missing. Safe to run before every load, which is exactly what the
    ingestion container does on startup.

    This is the counterpart of init_database.sql, which DROPS and recreates the
    database. That one stays the manual reset path; this one never destroys,
    the same split already used by proc_init_bronze.sql and rebuild_bronze.sql.

    CREATE SCHEMA has to be the first statement in its batch, which is why each
    one is wrapped in EXEC.
*/

USE master;
GO

IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dw_hgg_database')
    CREATE DATABASE dw_hgg_database;
GO

USE dw_hgg_database;
GO

IF SCHEMA_ID('bronze') IS NULL EXEC('CREATE SCHEMA bronze');
GO

IF SCHEMA_ID('silver') IS NULL EXEC('CREATE SCHEMA silver');
GO

IF SCHEMA_ID('gold') IS NULL EXEC('CREATE SCHEMA gold');
GO
