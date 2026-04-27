USE dw_hgg_database

-- How many matches do you expect vs how many are in silver.matches?

SELECT COUNT(*) AS number_of_matches
FROM silver.matches

SELECT COUNT(*) AS number_of_results
FROM silver.match_results AS mr
WHERE mr.result_type_id = 2 OR mr.result_type_id = 0