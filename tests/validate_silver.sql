USE dw_hgg_database

-- How many matches do you expect vs how many are in silver.matches?

SELECT COUNT(*) AS number_of_matches
FROM silver.matches AS m
WHERE m.match_is_finished = 1

SELECT COUNT(*) AS number_of_results
FROM silver.match_results AS mr
WHERE mr.result_type_id = 2 OR mr.result_type_id = 0

-- Does every group_id in silver.matches exist in silver.groups?

SELECT DISTINCT sm.group_id, sg.group_id
FROM silver.matches AS sm
FULL OUTER JOIN silver.groups AS sg
    ON sm.group_id = sg.group_id