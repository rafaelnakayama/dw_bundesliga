## Integration Model, Silver Layer

### Silver Matches Table

```
silver.matches

└── match_id (PK)
└── group_id (FK)
└── team1_id (FK)
└── team2_id (FK)
└── location_id (FK)
└── match_results_id (FK)
└── goals_id (FK)
└── match_date_time
└── time_zone_id
└── league_id
└── league_name
└── league_season
└── league_shortcut
└── match_date_time_utc
└── last_update_date_time
└── match_is_finished
└── number_of_viewers
```

### Group Table

```
silver.groups

└── group_name
└── group_order_id
└── group_id (PK)
```

### Teams Table

```
silver.teams

└── team1_id (PK)
└── team1_name
└── team1_short_name
└── team1_team_icon_url
└── team1_group_name


└── team2_id (PK)
└── team2_name
└── team2_short_name
└── team2_team_icon_url
└── team2_group_name
```

### Location Table

```
silver.location

└── location_id (PK)
└── match_id (FK)
└── location_city
└── location_stadium
```

### Match Results Table

```
silver.match_results

└── result_id (PK)
└── result_name
└── points_team1
└── points_team2
└── result_order_id
└── result_type_id
└── result_description
```

### Goals Table

```
silver.match_goals

└── goal_id (PK)
└── score_team1
└── score_team2
└── match_minute
└── goal_getter_id
└── goal_getter_name
└── is_penalty
└── is_own_goal
└── is_overtime
└── comment
```