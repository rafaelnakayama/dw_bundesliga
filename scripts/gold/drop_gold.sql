-- Roda antes de proc_load_gold.sql. Os drops dentro da proc nao servem aqui: o
-- corpo dela e compilado antes de rodar, e a compilacao valida o INSERT contra
-- a tabela antiga parada no banco. Sem tabela, nao ha coluna para validar.

IF OBJECT_ID('gold.fact_matches', 'U') IS NOT NULL DROP TABLE gold.fact_matches;
IF OBJECT_ID('gold.fact_goals', 'U') IS NOT NULL DROP TABLE gold.fact_goals;
IF OBJECT_ID('gold.dim_players', 'U') IS NOT NULL DROP TABLE gold.dim_players;
IF OBJECT_ID('gold.dim_teams', 'U') IS NOT NULL DROP TABLE gold.dim_teams;
IF OBJECT_ID('gold.dim_locations', 'U') IS NOT NULL DROP TABLE gold.dim_locations;
