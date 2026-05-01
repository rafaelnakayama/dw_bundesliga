USE dw_hgg_database

/*
    Searching for the highest scorer of the bundesliga in the available dataset,
    one name player stood out in the second place (144 goals) just below Robert Lewandowski,
    Whose id 0 and goal_getter_name NULL. This was latter confirmed to be an error,
    invalid goals were being stored inside of 'goals' json array, and even when null,
    they were still counted as valid goals.
*/

SELECT TOP 10 sg.goal_getter_id, sg.goal_getter_name , COUNT(sg.goal_id) AS total_goals
FROM silver.match_goals AS sg
GROUP BY sg.goal_getter_name, sg.goal_getter_id
ORDER BY total_goals DESC