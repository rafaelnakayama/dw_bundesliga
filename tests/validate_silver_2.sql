USE dw_hgg_database

/*
    Searching for the highest scorer of the bundesliga in the available dataset,
    one name player stood out in the second place (144 goals) just below Robert Lewandowski,
    Whose id 0 and goal_getter_name NULL. This was later confirmed to be an error,
    invalid goals were being stored inside of 'goals' json array, and even when null,
    they were still counted as valid goals.
*/

SELECT TOP 10 sg.goal_getter_id, sg.goal_getter_name , COUNT(sg.goal_id) AS total_goals
FROM silver.match_goals AS sg
GROUP BY sg.goal_getter_name, sg.goal_getter_id
ORDER BY total_goals DESC

/*

Are there players whose names contain numbers? Extra spaces or even special characters?

- In the first query we already find a total of 189 cases where unecessary spaces exist
- In the second, we find no numbers or special characters whatsoever (@,!,%,^)
- In the third query things escalate, as we find over 8000 results. It isn't an error
tho, since most of the players are of German origin, their names contain these no ANSI
values (Ex: Thomas Müller).

*/

SELECT COUNT(*) AS trim_diff
FROM silver.match_goals AS sg
WHERE sg.goal_getter_name != TRIM(sg.goal_getter_name)

SELECT COUNT(*) AS has_numbers
FROM silver.match_goals AS sg
WHERE sg.goal_getter_name LIKE '[^a-zA-Z]'

SELECT COUNT(*) AS has_true_special_characters
FROM silver.match_goals AS sg
WHERE sg.goal_getter_name LIKE '%[^a-zA-Z0-9]%'

-- Does silver.teams suffers from that? No!

SELECT COUNT(*) AS trim_diff
FROM silver.teams AS st
WHERE st.team_name != TRIM(st.team_name)