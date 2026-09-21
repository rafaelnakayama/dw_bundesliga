-- Runs before proc_load_gold.sql. The drops inside the procedure cannot help:
-- its body compiles before it runs, and compiling validates the INSERT against
-- the old table still standing in the database.

IF OBJECT_ID('gold.fact_matches', 'U') IS NOT NULL DROP TABLE gold.fact_matches;
IF OBJECT_ID('gold.fact_goals', 'U') IS NOT NULL DROP TABLE gold.fact_goals;
IF OBJECT_ID('gold.dim_players', 'U') IS NOT NULL DROP TABLE gold.dim_players;
IF OBJECT_ID('gold.dim_teams', 'U') IS NOT NULL DROP TABLE gold.dim_teams;
IF OBJECT_ID('gold.dim_locations', 'U') IS NOT NULL DROP TABLE gold.dim_locations;
