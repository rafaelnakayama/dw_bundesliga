## Integration Model, Gold Layer

`(DD)` marks a degenerate dimension: a key that carries its own meaning and has no
dimension table behind it.

### Fact Matches Table

```
gold.fact_matches

└── match_id (PK)
└── group_id (DD)
└── location_id (FK)
└── team1_id (FK)
└── team2_id (FK)
└── league_name
└── league_season (DD)
└── match_date_time_utc
└── number_of_viewers
└── goals_team1
└── goals_team2
└── total_goals
└── winner_team_id (FK)
```

### Fact Goals Table

```
gold.fact_goals

└── goal_id (PK)
└── match_id (DD)
└── goal_getter_id (FK)
└── league_season (DD)
└── match_minute
└── is_penalty
└── is_own_goal
└── is_overtime
```

### Dim Teams Table

```
gold.dim_teams

└── team_id (PK)
└── team_name
└── team_short_name
└── team_icon_url
```

### Dim Players Table

```
gold.dim_players

└── player_id (PK)
└── player_name
```

### Dim Locations Table

```
gold.dim_locations

└── location_id (PK)
└── location_city
└── location_stadium
```

### Foreign Keys

```
fact_matches.location_id     ──> dim_locations.location_id
fact_matches.team1_id        ──> dim_teams.team_id
fact_matches.team2_id        ──> dim_teams.team_id
fact_matches.winner_team_id  ──> dim_teams.team_id
fact_goals.goal_getter_id    ──> dim_players.player_id
```
