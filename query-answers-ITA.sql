-- Football Matches Analysis [Giuseppe Ciancia]

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
-- Nella stagione 2013/2014 in Belgio si sono giocate solo 12 partite, va verificato se il dato è corretto

-- Q6a, 6b, 6c
CREATE TABLE Final_Exercise.PlayerBMI as
SELECT *, weight/2.205 as kg_weight, height/100 as m_height, (weight/2.205)/((height/100)*height/100) as BMI
FROM `Football_Match_Analysis.player`;

-- Q6d Part 1: visualizzazione giocatori con BMI ottimale
SELECT *
FROM `Football_Match_Analysis.PlayerBMI`
WHERE BMI between 18.5 AND 24.9;
-- La matrice ha 10197 righe

-- Q6d Part 2: conteggio giocatori con BMI ottimale
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


--Q8 Part Zero: Verifica corrispondenza biunivoca tra team_id e team_api_id
SELECT 
COUNT (*) as total_values,
COUNT (distinct id) as nr_team_id,
COUNT (distinct team_api_id) as nr_team_api_id
FROM `Football_Match_Analysis.team`;
-- CONCLUSIONE: poiché la matrice "team" ha 299 righe, 299 id distinti e 299 team_api_id distinti, c'è corrispondenza biunivoca tra team.id e team.team_api_id pertanto, dalla domanda 8 in poi, utilizzerò team_api_id come equivalente della chiave primaria per il dataset team
 

-- Q8 Versione 1 (rapida): UNION + LIMIT 1
-- Valida solo per questo specifico dataset, sapendo a priori che l'ultima stagione disputata è quella 2015/2016 (Condizione WHERE = "2015/2016" fissata)  e ipotizzando che il primo posto non sia a pari merito tra due squadre (LIMIT = 1); se il dataset viene aggiornato con nuovi record di stagioni successive o con altri della stessa stagione generando un primo posto a pari merito, la query smette di rispondere alla domanda
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

-- Q8 Versione 2: SUM > GROUP BY > JOIN > RANK Score > WHERE
-- Anche questa versione è valida solo sapendo a priori che la stagione 2015/2016 è la più recente, ma restituisce tutti i valori in caso di primo posto a pari merito
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

-- Q8 Versione 2/bis: Query Q8 Versione 1 + Condizione RANK Score = 1; ha lo stesso output della query Q8 Versione 2
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

-- Q8 Versione 3 (Completa): UNION > SUM + GROUP BY > RANK Score > RANK Season
-- È la versione più completa: qualora il dataset venga aggiornato con partite successive alla stagione 2015/2016, la query restituisce dinamicamente la nuova squadra primatista per gol segnati nella stagione più recente
WITH table5 as (
  -- Step 5: La table5 aggiunge il rank in base a quanto è recente una stagione; successivamente alla table5 si filtra per avere la stagione più recente
  WITH table4 as (
    -- Step 4: La table4 filtra i top scorer team di ogni stagione
    WITH table3 as (
      -- Step 3: La table3 aggiunge il rank in base al numero dei gol totali segnati partizionato per stagione
      WITH table2 as (
        -- Step 2: La table 2 aggrega i valori dei goal ed effettua una join con la tabella team per associare i nomi delle squadre
        WITH table1 as (
          -- Step 1: La table1 incolonna i valori di home e away in un'unica tabella di tre colonne
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

-- Q8 Version 4: è simile alla Q8 Versione 3, ma permette più opzioni di personalizzazione col filtro finale WHERE
WITH table5 as (
 -- Step2: La table5 aggiunge alle stagioni della table4 uno score discendente in base a quanto è recente una stagione
 WITH table4 as (
   -- Step 1: La table4 crea una tabella contenente le stagioni distinte
   SELECT distinct season
   FROM `Football_Match_Analysis.match`
   )
 SELECT *,
 rank() over (order by season DESC) as rank_season
 FROM table4
 ),
 table3 as (
   -- Step 5: La table3 aggiunge il rank in base al numero dei gol totali segnati partizionato per stagione
     WITH table2 as (
       -- Step 4: La table2 aggrega i valori dei goal ed effettua una join con la tabella team per associare i nomi delle squadre
       WITH table1 as (
         -- Step 3: La table1 incolonna i valori di home e away in un'unica tabella di tre colonne
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
-- Step 6: Si effettua una join tra table3 e table5 per associare i rank delle stagioni alla table3; successivamente si filtra il risultato desiderato con le condizioni WHERE = 1
 table3.season,
 table3.team_id,
 table3.team,
 table3.total_goal,
FROM table3
LEFT JOIN table5
 on table3.season = table5.season
WHERE table3.rank_score = 1 AND table5.rank_season = 1
ORDER BY season DESC, total_goal DESC;
-- La query Q8 Versione 4 permette di cercare dinamicamente altri risultati; per esempio, sostituendo il WHERE precedente con la condizione WHERE table3.rank_score IN (1, 2, 3) AND table5.rank_season IN (2, 3) vengono visualizzate le tre squadre col maggior numero di reti realizzate per ognuna delle stagioni dalla penultima alla terzultima


-- Q9 versione 1: utilizzo delle windows function per confronto col massimo
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

-- Q9 versione 2: utilizzo della windows function con condizione WHERE rank = 1
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

-- Q9 Versione 3: Vedi query Q8 Versione 3, senza la condizione finale WHERE rank_season = 1

-- Q9 Versione 4: Vedi query Q8 Versione 4, senza la condizione finale WHERE rank_season = 1


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

-- Q10 Part 1 - Versione 2: LIMIT (non è presente un decimo posto a pari merito, quindi restituisce tutti i valori)
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

--Q10 Part 2 Versione algebrica
SELECT 
 CAST(count (*) * ((count (*)-1))/2 as INT) as nr_pair
FROM `Football_Match_Analysis.TopScorer`;

-- Q10 Part 2 Versione SELF JOIN
WITH table1 as (
  SELECT a.team_id, b.team_id
  FROM `Football_Match_Analysis.TopScorer` as a
  INNER JOIN `Football_Match_Analysis.TopScorer` as b
  on a.team_id > b.team_id
  )
SELECT COUNT (*) as nr_pair
FROM table1

-- FINE

