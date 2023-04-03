-- Football Matches Analysis

-- Q3
SELECT DATE_DIFF(MAX(DATE(date)), MIN(DATE(date)), DAY) as time_interval
FROM `Football_Match_Analysis.match`;

-- Q4 part 1
SELECT match.season, leagues.name as league_name, min(home_team_goal) as min_home_team_goal, ROUND(avg(home_team_goal),2) as avg_home_team_goal, (max(home_team_goal)-min(home_team_goal))/2 as mid_range, max(home_team_goal) as max_home_team_goal, sum(home_team_goal) as total_home_team_goal
FROM `Football_Match_Analysis.match` as match
LEFT JOIN `Football_Match_Analysis.leagues` as leagues
  on match.league_id = leagues.id
GROUP BY leagues.name, match.season
ORDER BY leagues.name ASC, match.season ASC;

-- Q4 part 2
SELECT match.season, leagues.name as league_name, sum(home_team_goal) as total_home_team_goal
FROM `Football_Match_Analysis.match` as match
LEFT JOIN `Football_Match_Analysis.leagues` as leagues
  on match.league_id = leagues.id
GROUP BY leagues.name, match.season
ORDER BY total_home_team_goal DESC
LIMIT 1;

-- Q5 Part 1
with table1 as (
  SELECT league_id, season
  FROM `Football_Match_Analysis.match`
  GROUP BY league_id, season
  )
SELECT COUNT (*) as nr_distinct_seasons
FROM table1;

-- Q5 Part 2
SELECT leagues.name as league_name, season, count (distinct match.id) as nr_matches
FROM `Football_Match_Analysis.match` as match
LEFT JOIN `Football_Match_Analysis.leagues` as leagues
  on match.league_id = leagues.id
GROUP BY league_name, season
ORDER BY nr_matches ASC, league_name, season, nr_matches;
-- Only 12 games were played in Belgium in the 2013/2014 season, it needs to be checked if the figure is correct

-- Q6a, 6b, 6c
CREATE TABLE Final_Exercise.PlayerBMI as
SELECT *, weight/2.205 as kg_weight, height/100 as m_height, (weight/2.205)/((height/100)*height/100) as BMI
FROM `Football_Match_Analysis.player`;

-- Q6d Part 1: viewing players with optimal BMI
SELECT *
FROM `Football_Match_Analysis.PlayerBMI`
WHERE BMI between 18.5 AND 24.9;
-- The matrix has 10197 rows

-- Q6d Part 2: counting players with optimal BMI
WITH table1 as (
  SELECT *
  FROM `Football_Match_Analysis.PlayerBMI`
  WHERE BMI between 18.5 AND 24.9
  )
SELECT COUNT (*) as nr_players_optimal_BMI
FROM table1;


-- Q7
WITH temp_table as (
  SELECT *
  FROM `Football_Match_Analysis.PlayerBMI`
  WHERE BMI < 18.5 OR BMI > 24.9
  )
SELECT COUNT (*) as nr_players_non_optimal_BMI
FROM temp_table;


--Q8 Part Zero: Check one-to-one correspondence between team_id and team_api_id
SELECT 
COUNT (*) as total_values,
COUNT (distinct id) as nr_team_id,
COUNT (distinct team_api_id) as nr_team_api_id
FROM `Football_Match_Analysis.team`;
-- CONCLUSION: since the "team" matrix has 299 rows, 299 distinct IDs and 299 distinct team_api_id, there is one-to-one correspondence between team.id and team.team_api_id therefore, from question 8 onwards, I will use team_api_id as the primary key equivalent for the dataset team
 

-- Q8 Version 1 (fast): UNION + LIMIT 1
-- Valid only for this specific dataset, knowing in advance that the last season played was 2015/2016 (Condition WHERE = "2015/2016" fixed) and assuming that the first place is not tied between two teams (LIMIT = 1 ); if the dataset is updated with new records from successive seasons or with others from the same season generating a tied first place, the query stops answering the question
WITH table1 as (
 SELECT season, home_team_api_id as team_id, home_team_goal as goal
 FROM `Football_Match_Analysis.match` as match
 UNION ALL
 SELECT season, away_team_api_id as team_id, away_team_goal as goal
 FROM `Football_Match_Analysis.match` as match
)
SELECT
 table1.season,
 table1.team_id,
 team.team_long_name as team,
 SUM(goal) as total_goal,
FROM table1
LEFT JOIN `Football_Match_Analysis.team` as team
   on table1.team_id=team.team_api_id
WHERE season = "2015/2016"
GROUP BY season, team_id, team
ORDER BY season DESC, total_goal DESC
LIMIT 1;

-- Q8 Version 2: SUM > GROUP BY > JOIN > RANK Score > WHERE
-- Also this version is valid only knowing in advance that the 2015/2016 season is the most recent, but returns all the values in case of first place tied
WITH table3 as (  
  WITH table2 as (
    WITH table1 as (
      SELECT season, home_team_api_id as home_id, SUM(home_team_goal) as home_goal
      FROM `Football_Match_Analysis.match`
      WHERE season = "2015/2016"
      GROUP BY home_team_api_id, season
      ),
      table2 as (
      SELECT season, away_team_api_id as away_id, SUM(away_team_goal) as away_goal
      FROM `Football_Match_Analysis.match`
      WHERE season = "2015/2016"
      GROUP BY away_team_api_id, season)
    SELECT 
      home_id as team_id, 
      home_goal + away_goal as total_goal,
    FROM table1
    LEFT JOIN table2
      on home_id = away_id
    )
  SELECT *,
    rank() over (order by total_goal DESC) as rank_score
  FROM table2
  LEFT JOIN `Football_Match_Analysis.team`
  on team_api_id = team_id
  ORDER BY total_goal DESC
  )
SELECT team_id, team_long_name as team_name, total_goal
FROM table3
WHERE rank_score = 1;

-- Q8 Version 2/bis: Query Q8 Version 1 + RANK Score = 1 condition; it has the same output as the Q8 Version 2 query
WITH table3 as (
 WITH table2 as (
   WITH table1 as (
     SELECT season, home_team_api_id as team_id, home_team_goal as goal
     FROM `Football_Match_Analysis.match` as match
     UNION ALL
     SELECT season, away_team_api_id as team_id, away_team_goal as goal
     FROM `Football_Match_Analysis.match` as match
     )
   SELECT
     table1.season,
     table1.team_id,
     team.team_long_name as team,
     SUM(goal) as total_goal,
   FROM table1
   LEFT JOIN `Football_Match_Analysis.team` as team
       on table1.team_id=team.team_api_id
   WHERE season = "2015/2016"
   GROUP BY season, team_id, team
   ORDER BY season DESC, total_goal DESC
   )
 SELECT *,
   RANK() over (partition by season order by total_goal DESC) as rank_score
 FROM table2
 )
SELECT season, team_id, team, total_goal
FROM table3
WHERE rank_score = 1;

-- Q8 Version 3 (Complete): UNION > SUM + GROUP BY > RANK Score > RANK Season
-- It’s the most complete version: if the dataset is updated with matches after the 2015/2016 season, the query dynamically returns the new record team for goals scored in the most recent season
WITH table5 as (
  -- Step 5: table5 adds rank based on how recent a season is; after table5 filter to get the most recent season
  WITH table4 as (
    -- Step 4: table4 filters the top scoring teams of each season
    WITH table3 as (
      -- Step 3: table3 adds the rank based on the number of total goals scored partitioned by season
      WITH table2 as (
        -- Step 2: table2 aggregates the goal values and joins the team table to associate the team names
        WITH table1 as (
          -- Step 1: table1 columns the home and away values into a single three-column table
          SELECT season, home_team_api_id as team_id, home_team_goal as goal
          FROM `Football_Match_Analysis.match` as match
          UNION ALL
          SELECT season, away_team_api_id as team_id, away_team_goal as goal
          FROM `Football_Match_Analysis.match` as match
        	)
        SELECT 
          table1.season, 
          table1.team_id, 
          team.team_long_name as team,
          SUM(goal) as total_goal,
        FROM table1
        LEFT JOIN `Football_Match_Analysis.team` as team
            on table1.team_id=team.team_api_id
        GROUP BY season, team_id, team_long_name
        ORDER BY season DESC, total_goal DESC
        )
      SELECT *,
      RANK() over (partition by season order by total_goal DESC) as rank_score
      FROM table2
      )
    SELECT *,
    FROM table3
    WHERE rank_score = 1
    )
  SELECT *,
    RANK() over (order by season DESC) as rank_season
  FROM table4
  ORDER BY season ASC
  )
SELECT
  season, 
  team_id, 
  team
FROM table5
WHERE rank_season = 1;

-- Q8 Version 4: it’s similar to Q8 Version 3, but allows more customization options with the final WHERE filter
WITH table5 as (
 -- Step2: table5 adds a descending score to the seasons in table4 based on how recent a season is
 WITH table4 as (
   -- Step 1: table4 creates a table containing the distinct seasons
   SELECT distinct season
   FROM `Football_Match_Analysis.match`
   )
 SELECT *,
 rank() over (order by season DESC) as rank_season
 FROM table4
 ),
 table3 as (
   -- Step 5: table3 adds the rank based on the number of total goals scored partitioned by season
     WITH table2 as (
       -- Step 4: table2 aggregates the goal values and joins the team table to associate team names
       WITH table1 as (
         -- Step 3: table1 columns the home and away values into a single three-column table
         SELECT season, home_team_api_id as team_id, home_team_goal as goal
         FROM `Football_Match_Analysis.match` as match
         UNION ALL
         SELECT season, away_team_api_id as team_id, away_team_goal as goal
         FROM `Football_Match_Analysis.match` as match
         )
       SELECT
         table1.season,
         table1.team_id,
         team.team_long_name as team,
         SUM(goal) as total_goal,
       FROM table1
       LEFT JOIN `Football_Match_Analysis.team` as team
         on table1.team_id=team.team_api_id
       GROUP BY season, team_id, team_long_name
       )
 SELECT *,
   rank() over (partition by season order by total_goal DESC) as rank_score
 FROM table2
 )
SELECT
-- Step 6: A join is made between table3 and table5 to associate the ranks of the seasons to table3; then the desired result is filtered with the conditions WHERE = 1
 table3.season,
 table3.team_id,
 table3.team,
 table3.total_goal,
FROM table3
LEFT JOIN table5
 on table3.season = table5.season
WHERE table3.rank_score = 1 AND table5.rank_season = 1
ORDER BY season DESC, total_goal DESC;
-- The Q8 Version 4 query allows us to dynamically search for other results; for example, replacing the previous WHERE with the condition WHERE table3.rank_score IN (1, 2, 3) AND table5.rank_season IN (2, 3) the three teams with the highest number of goals scored for each of the seasons from penultimate to third last are displayed


-- Q9 version 1: using the windows function to compare with the maximum
WITH table2 as (
  WITH table1 as (
    SELECT season, home_team_api_id as team_id, home_team_goal as goal
    FROM `Football_Match_Analysis.match` as match
    UNION ALL
    SELECT season, away_team_api_id as team_id, away_team_goal as goal
    FROM `Football_Match_Analysis.match` as match
  )
  SELECT 
    table1.season as season, 
    table1.team_id as team_id, 
    team.team_long_name as team, 
    SUM(goal) as total_goal,
    MAX(SUM(goal)) over (partition by season) as top_score
  FROM table1
  LEFT JOIN `Football_Match_Analysis.team` as team
    on table1.team_id=team.team_api_id
  GROUP BY season, team_id, team
  ORDER BY total_goal DESC
)
SELECT season, team_id, team, total_goal 
FROM table2
WHERE total_goal = top_score
ORDER BY season ASC;

-- Q9 version 2: using windows function with condition WHERE rank = 1
WITH table2 as (
  WITH table1 as (
    SELECT season, home_team_api_id as team_id, home_team_goal as goal
    FROM `Football_Match_Analysis.match` as match
    UNION ALL
    SELECT season, away_team_api_id as team_id, away_team_goal as goal
    FROM `Football_Match_Analysis.match` as match
  ) 
    SELECT 
      table1.season as season,
      table1.team_id as team_id,
      team.team_long_name as team_name,
      sum(goal) as total_goal,
      rank() over (partition by season order by SUM(goal) DESC) as rank
    FROM table1
    LEFT JOIN `Football_Match_Analysis.team` as team
        on table1.team_id=team.team_api_id
    GROUP BY season, team_id, team_name
    ORDER BY season ASC
  )
SELECT 
  season, team_id, team_name, total_goal, rank
FROM table2
WHERE rank=1;

-- Q9 Version 3: Look at the query Q8 Version 3, without the final condition WHERE rank_season = 1

-- Q9 Version 4: Look at the query Q8 Version 4, without the final condition WHERE rank_season = 1


-- Q10 Part 1 - Versione 1: RANK
CREATE TABLE Football_Match_Analysis.TopScorer as 
WITH table2 as (
  WITH table1 as (
    SELECT season, home_team_api_id as team_id, home_team_goal as goal
    FROM `Football_Match_Analysis.match` as match
    UNION ALL
    SELECT season, away_team_api_id as team_id, away_team_goal as goal
    FROM `Football_Match_Analysis.match` as match
    )
  SELECT table1.team_id, team.team_long_name, SUM(goal) as total_goal,
    RANK() over (order by SUM(goal) DESC) as rank
  FROM table1
  LEFT JOIN `Football_Match_Analysis.team` as team
    on table1.team_id=team.team_api_id
  GROUP BY team_id, team.team_long_name
  ORDER BY total_goal DESC
  )
SELECT *
FROM table2
WHERE rank <= 10
ORDER BY rank ASC;

-- Q10 Part 1 - Version 2: LIMIT (there is no tied tenth place, so it returns all values)
CREATE TABLE Football_Match_Analysis.TopScorer as 
WITH total_goal as (
  SELECT season, home_team_api_id as team_id, home_team_goal as goal
  FROM `Football_Match_Analysis.match` as match
  UNION ALL
  SELECT season, away_team_api_id as team_id, away_team_goal as goal
  FROM `Football_Match_Analysis.match` as match
  )
SELECT total_goal.team_id, team.team_long_name, SUM(goal) as total_goal
FROM total_goal
LEFT JOIN `Football_Match_Analysis.team` as team
  on total_goal.team_id=team.team_api_id
GROUP BY team_id, team.team_long_name
ORDER BY total_goal DESC
LIMIT 10;

--Q10 Part 2 Algebraic version
SELECT 
 CAST(count (*) * ((count (*)-1))/2 as INT) as nr_pair
FROM `Football_Match_Analysis.TopScorer`;

-- Q10 Part 2 Version SELF JOIN
WITH table1 as (
  SELECT a.team_id, b.team_id
  FROM `Football_Match_Analysis.TopScorer` as a
  INNER JOIN `Football_Match_Analysis.TopScorer` as b
  on a.team_id > b.team_id
  )
SELECT COUNT (*) as nr_pair
FROM table1

-- END

