/*
=============================================================
Create Database and Schemas
=============================================================
Script Purpose:
    This script creates a new database named 'dw_hgg_database' after checking if it already exists. 
    If the database exists, it is dropped and recreated. Additionally, the script sets up three schemas 
    within the database: 'bronze', 'silver', and 'gold'.
	
WARNING:
    Running this script will drop the entire 'dw_hgg_database' database if it exists. 
    All data in the database will be permanently deleted. Proceed with caution 
    and ensure you have proper backups before running this script.
*/

USE master;
GO

-- Drop and recreate the 'dw_hgg_database' database
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dw_hgg_database')
BEGIN
    ALTER DATABASE dw_hgg_database SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE dw_hgg_database;
END;
GO

-- Create the 'dw_hgg_database' database
CREATE DATABASE dw_hgg_database;
GO

USE dw_hgg_database;
GO

-- Create Schemas
CREATE SCHEMA bronze;
GO

CREATE SCHEMA silver;
GO

CREATE SCHEMA gold;
GO