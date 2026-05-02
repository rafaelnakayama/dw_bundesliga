USE dw_hgg_database

-- How many matches do you expect vs how many are in silver.matches?

SELECT COUNT(*) AS number_of_matches
FROM silver.matches AS m
WHERE m.match_is_finished = 1

SELECT COUNT(*) AS number_of_results
FROM silver.match_results AS mr
WHERE mr.result_type_id = 2 OR mr.result_type_id = 0

-- Are there any matches where both team1_id and team2_id are the same team?

SELECT sm.team1_id, sm.team2_id
FROM silver.matches AS sm
WHERE sm.team1_id = sm.team2_id

-- Does the number of goals in silver.match_goals seem reasonable?

SELECT COUNT(*) FROM silver.match_goals

-- Does every group_id in silver.matches exist in silver.groups?

SELECT DISTINCT sm.group_id, sg.group_id
FROM silver.matches AS sm
FULL OUTER JOIN silver.groups AS sg
    ON sm.group_id = sg.group_id

-- Same question for teams:

SELECT DISTINCT sm.team1_id AS T_MATCHES, st.team_id AS T_TEAMS
FROM silver.matches AS sm
FULL OUTER JOIN silver.teams AS st
    ON sm.team1_id = st.team_id

-- and location:

SELECT DISTINCT sm.location_id AS matches_loc_id, sl.location_id AS loc_id
FROM silver.matches AS sm
FULL OUTER JOIN silver.location AS sl
    ON sm.location_id = sl.location_id