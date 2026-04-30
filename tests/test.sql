USE dw_hgg_database

SELECT * FROM silver.match_goals WHERE goal_getter_id = 0

/*

USE dw_hgg_database

SELECT TOP 10 sg.goal_getter_id, sg.goal_getter_name , COUNT(sg.goal_id) AS total_goals
FROM silver.match_goals AS sg
GROUP BY sg.goal_getter_name, sg.goal_getter_id
ORDER BY total_goals DESC

*/