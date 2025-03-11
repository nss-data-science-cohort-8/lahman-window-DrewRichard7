-- Question 1: Rankings
--------------------------------------------------------------------------------
---- Question 1a: Warmup Question
-- Write a query which retrieves each teamid and number of wins (w) for the 2016 season. Apply three window functions to the number of wins (ordered in descending order) - ROW_NUMBER, RANK, AND DENSE_RANK. Compare the output from these three functions. What do you notice?

SELECT 
    teamid, 
    w,
    RANK() OVER(ORDER BY w DESC) AS rank,
    DENSE_RANK() OVER(ORDER BY w DESC) AS dense_rank,
    ROW_NUMBER() OVER(ORDER BY w DESC) AS row_number
FROM teams 
WHERE yearid = 2016;

-- RANK() is the traditional ranking format. It will rank, and account for ties, but will skip the numbers for which teams tie so that each team is accounted for. so rank may go 1, T2, T2, 4, 5, T6, T6, T6, 9...
-- DENSE_RANK() will rank and account for ties, but will not skip numbers so that each team is accounted for. so dense_rank may go 1, 2, 2, 3, 4, 5, 5, 5, 6...
-- ROW_NUMBER() will rank but won't account for ties, but will not skip numbers so that each team is accounted for. so row_number may go 1, 2, 3, 4, 5, 6, 7, 8, 9... it essentially assigns the row number. 


---- Question 1b: 
-- Which team has finished in last place in its division (i.e. with the least number of wins) the most number of times? A team's division is indicated by the divid column in the teams table.

-- looks like the padres are have finished last the most times 
-- commenting out this first where clause will show that the phillies have finished last, which is accounting for the years when there was only one division (default).
WITH slim AS (
    SELECT 
        name,
        yearid,
        lgid||divid AS division,
        w
    FROM teams
    -- WHERE lgid IS NOT NULL
        -- AND divid IS NOT NULL
),

LastPlace AS (
    SELECT 
        name,
        yearid,
        division,
        w,
        RANK() OVER(PARTITION BY yearid, division ORDER BY w) as rank_in_division
    FROM slim 
)
SELECT 
    name,
    COUNT(*) as number_of_last_place_finishes
FROM LastPlace
WHERE rank_in_division = 1
GROUP BY name  
ORDER BY number_of_last_place_finishes DESC;



-- Question 2: Cumulative Sums
--------------------------------------------------------------------------------
---- Question 2a: 
-- Barry Bonds has the record for the highest career home runs, with 762. Write a query which returns, for each season of Bonds' career the total number of seasons he had played and his total career home runs at the end of that season. (Barry Bonds' playerid is bondsba01.)

SELECT 
    namefirst||' '||namelast AS playername,
    yearid,
    SUM(hr) OVER(ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_hr,
    RANK() OVER(ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_seasons
FROM batting AS b
INNER JOIN people AS p USING(playerid)
WHERE playerid = 'bondsba01'
ORDER BY yearid;



---- Question 2b:
-- How many players at the end of the 2016 season were on pace to beat Barry Bonds' record? For this question, we will consider a player to be on pace to beat Bonds' record if they have more home runs than Barry Bonds had the same number of seasons into his career. 


WITH hr_partition AS (
    SELECT 
        namefirst||' '||namelast AS playername,
        playerid,
        yearid,
        SUM(hr) OVER(PARTITION BY playerid ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_hr,
        DENSE_RANK() OVER(PARTITION BY playerid ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_seasons
    FROM batting AS b
        INNER JOIN people AS p USING(playerid)
    WHERE yearid <= 2016 -- comment out both WHERE to get all time players at end through their careers who were on pace to have more hr than BB 
),
bonds AS (
    SELECT 
        cumulative_seasons,
        cumulative_hr as bonds_hr
    FROM hr_partition
    WHERE playerid = 'bondsba01'
),
players_pace AS (
    SELECT 
        h.playername AS playername,
        h.yearid,
        h.cumulative_hr AS cumulative_hr,
        h.cumulative_seasons AS cumulative_seasons,
        b.bonds_hr,
        CASE WHEN h.cumulative_hr > b.bonds_hr THEN 'On Pace' ELSE 'Not On Pace' END AS pace
    FROM hr_partition AS h
    LEFT JOIN bonds AS b ON h.cumulative_seasons = b.cumulative_seasons
    WHERE h.yearid = 2016 -- comment out to get all time 
        AND h.playerid != 'bondsba01'
)
SELECT playername, cumulative_hr, cumulative_seasons 
FROM players_pace
WHERE pace = 'On Pace';



---- Question 2c: 
-- Were there any players who 20 years into their career who had hit more home runs at that point into their career than Barry Bonds had hit 20 years into his career? 

-- Looks like Atlanta Braves Legend Henry Aaron was on pace, and that's it. 
WITH hr_partition AS (
    SELECT 
        namefirst||' '||namelast AS playername,
        playerid,
        yearid,
        SUM(hr) OVER(PARTITION BY playerid ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_hr,
        RANK() OVER(PARTITION BY playerid ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_seasons
    FROM batting AS b
        INNER JOIN people AS p USING(playerid)
),
bonds AS (
    SELECT 
        cumulative_seasons,
        cumulative_hr as bonds_hr
    FROM hr_partition
    WHERE playerid = 'bondsba01'
),
players_pace AS (
    SELECT 
        h.playername AS playername,
        h.yearid,
        h.cumulative_hr AS cumulative_hr,
        h.cumulative_seasons AS cumulative_seasons,
        b.bonds_hr,
        CASE WHEN h.cumulative_hr > b.bonds_hr THEN 'On Pace' ELSE 'Not On Pace' END AS pace
    FROM hr_partition AS h
    LEFT JOIN bonds AS b ON h.cumulative_seasons = b.cumulative_seasons
    WHERE h.playerid != 'bondsba01'
)
SELECT playername, cumulative_hr, cumulative_seasons 
FROM players_pace
WHERE pace = 'On Pace'
    AND cumulative_seasons =20;


-- Question 3: Anomalous Seasons
--------------------------------------------------------------------------------
-- Find the player who had the most anomalous season in terms of number of home runs hit. To do this, find the player who has the largest gap between the number of home runs hit in a season and the 5-year moving average number of home runs if we consider the 5-year window centered at that year (the window should include that year, the two years prior and the two years after).

SELECT 
    namefirst||' '||namelast AS playername,
    yearid,
    hr,
    AVG(hr) OVER(ORDER BY yearid ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING) AS five_yr_avg, 
    hr - AVG(hr) OVER(ORDER BY yearid ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING) AS hr_diff
FROM batting AS b
    INNER JOIN people AS p USING (playerid)
ORDER BY hr_diff DESC;


-- Question 4: Players Playing for one Team
--------------------------------------------------------------------------------
-- For this question, we'll just consider players that appear in the batting table.
---- Question 4a: 
-- Warmup: How many players played at least 10 years in the league and played for exactly one team? (For this question, exclude any players who played in the 2016 season). Who had the longest career with a single team? (You can probably answer this question without needing to use a window function.)

-- brooks robinson played 23 years for one team
-- carl yastrzemski played 23 years but his team went through a name change so techincally he could be listed twice
WITH career AS (
    SELECT 
        playerid,
        COUNT(DISTINCT yearid) AS career_length,
        COUNT(DISTINCT teamid) AS n_teams,
        teamid
    FROM batting
    WHERE yearid <> 2016
    GROUP BY playerid, teamid
)
SELECT 
    DISTINCT namefirst||' '||namelast AS playername,
    career_length,
    n_teams,
    name AS team
FROM career AS c
    INNER JOIN people AS p USING(playerid)
    INNER JOIN teams AS t USING(teamid)
    WHERE career_length >= 10
        AND n_teams = 1
ORDER BY career_length DESC;


---- Question 4b: 
-- Some players start and end their careers with the same team but play for other teams in between. For example, Barry Zito started his career with the Oakland Athletics, moved to the San Francisco Giants for 7 seasons before returning to the Oakland Athletics for his final season. How many players played at least 10 years in the league and start and end their careers with the same team but played for at least one other team during their career? For this question, exclude any players who played in the 2016 season.

-- 203 players played for the same team at the beginning and end of their career, but for at least one other team in between 
WITH career_10_multiteam AS (
    SELECT 
        playerid,
        COUNT(DISTINCT yearid) AS career_length,
        COUNT(DISTINCT teamid) AS n_teams
    FROM batting
        INNER JOIN people USING (playerid)
    -- WHERE yearid <> 2016
    GROUP BY playerid
    HAVING COUNT(DISTINCT yearid) >= 10
        AND COUNT(DISTINCT teamid) > 1
        AND MAX(yearid) < 2016 -- looks at 2016 and excludes anyone who appears
),
first_last_teams AS (
    SELECT
        DISTINCT playerid,
        FIRST_VALUE(teamid) OVER (PARTITION BY playerid ORDER BY yearid, stint) as first_team,
        FIRST_VALUE(teamid) OVER (PARTITION BY playerid ORDER BY yearid DESC, stint DESC) as last_team
    FROM batting
    WHERE yearid <> 2016
)
SELECT DISTINCT 
    namefirst || ' ' || namelast AS playername,
    career_length,
    n_teams AS n_distinct_teams,
    first_team,
    last_team
FROM career_10_multiteam AS cm
    INNER JOIN people p USING (playerid)
    INNER JOIN first_last_teams AS flt USING (playerid)
WHERE career_length >= 10 
    AND n_teams > 1
    AND first_team = last_team
ORDER BY career_length DESC;

-- Question 5: Streaks
--------------------------------------------------------------------------------
---- Question 5a: 
-- How many times did a team win the World Series in consecutive years?

WITH winners AS (
    SELECT 
        teamid,
        yearid AS ws_win_year,
        LAG(yearid) OVER(PARTITION BY teamid ORDER BY yearid) AS prev_wswin,
        CASE WHEN (yearid - LAG(yearid) OVER(PARTITION BY teamid ORDER BY yearid)) = 1 THEN 'Y' ELSE 'N' END AS consecutive
    FROM teams
    WHERE wswin = 'Y' AND yearid >=1903
    ORDER BY 
        teamid, 
        yearid
)
SELECT 
    COUNT(*) AS n_consecutive_wins
FROM winners
WHERE consecutive = 'Y';

-- there have been 21 instances of back-to-back world series winners, and 22 instances of baseball championships won in consecutive years. this table contains records from before the 1903 world series, and there was one back-to-back winner before the WS was established. 

---- Question 5b: 
-- What is the longest steak of a team winning the World Series? Write a query that produces this result rather than scanning the output of your previous answer.


-- 1949-1953 NY yankees won 5 straight world series

WITH streaks AS (
    SELECT 
        name,
        teamid,
        yearid,
        yearid - ROW_NUMBER() OVER(PARTITION BY teamid ORDER BY yearid) AS streak_group
    FROM teams
    WHERE wswin = 'Y'
    ORDER BY teamid, yearid
)
SELECT 
    name,
    MIN(yearid) as streak_start,
    MAX(yearid) as streak_end,
    COUNT(*) as streak_length
FROM streaks
GROUP BY name, teamid, streak_group
HAVING COUNT(*) > 1
ORDER BY streak_length DESC;


---- Question 5c: 
-- A team made the playoffs in a year if either divwin, wcwin, or lgwin will are equal to 'Y'. Which team has the longest streak of making the playoffs? 

WITH playoffs AS (
    SELECT
        name,
        teamid,
        yearid,
        CASE WHEN divwin = 'Y' OR wcwin = 'Y' OR lgwin = 'Y' THEN 'Y' ELSE 'N' END AS playoff
    FROM teams
),
streaks AS (
    SELECT 
        name,
        teamid,
        yearid,
        yearid - ROW_NUMBER() OVER(PARTITION BY teamid ORDER BY yearid) AS streak_group
    FROM playoffs
    WHERE playoff = 'Y'
    ORDER BY teamid, yearid
)
SELECT 
    name,
    MIN(yearid) as streak_start,
    MAX(yearid) as streak_end,
    COUNT(*) as streak_length
FROM streaks
GROUP BY name, teamid, streak_group
HAVING COUNT(*) > 1
ORDER BY streak_length DESC;


---- Question 5d: 
-- The 1994 season was shortened due to a strike. If we don't count a streak as being broken by this season, does this change your answer for the previous part?

-- excluding the 1994 season, the longest postseason streak is the atlanta braves from 1991-2005, 
WITH playoffs AS (
    SELECT
        name,
        teamid,
        yearid,
        CASE WHEN divwin = 'Y' OR wcwin = 'Y' OR lgwin = 'Y' OR yearid=1994 THEN 'Y' ELSE 'N' END AS playoff
    FROM teams
),
streaks AS (
    SELECT 
        name,
        teamid,
        yearid,
        yearid - ROW_NUMBER() OVER(PARTITION BY teamid ORDER BY yearid) AS streak_group
    FROM playoffs
    WHERE playoff = 'Y' 
    ORDER BY teamid, yearid
)
SELECT 
    name||'*' AS teamname,
    MIN(yearid) as streak_start,
    MAX(yearid) as streak_end,
    COUNT(*) - 1 as streak_length
FROM streaks
GROUP BY name, teamid, streak_group
HAVING COUNT(*) > 1
ORDER BY streak_length DESC;


-- Question 6: Manager Effectiveness
--------------------------------------------------------------------------------
-- Which manager had the most positive effect on a team's winning percentage? To determine this, calculate the average winning percentage in the three years before the manager's first full season and compare it to the average winning percentage for that manager's 2nd through 4th full season. Consider only managers who managed at least 4 full years at the new team and teams that had been in existence for at least 3 years prior to the manager's first full season.
SELECT * FROM managers;

WITH winpct AS (

    SELECT
        namefirst||' '||namelast AS manager_name,
        playerid,
        teamid,
        yearid,
        w,
        l,
        g,
        ROW_NUMBER() OVER(PARTITION BY playerid, teamid ORDER BY yearid) AS year_of_stint,
        COUNT(*) OVER(PARTITION BY playerid, teamid) AS stint_length,
        yearid - ROW_NUMBER() OVER(PARTITION BY playerid, teamid ORDER BY yearid) + 1 AS start_year

    FROM managers
        INNER JOIN people USING(playerid)
),

qualified_stints AS (

    SELECT
        *

    FROM winpct
    WHERE stint_length >= 4
      AND EXISTS ( 

        SELECT 1
        FROM winpct AS w
        WHERE w.playerid = winpct.playerid
            AND w.teamid = winpct.teamid
            AND w.yearid <= winpct.start_year - 3
      )
)

SELECT
    manager_name,
    teamid,
    start_year,
    SUM(w)::FLOAT/(SUM(g)::FLOAT) AS win_prop,
    AVG(SUM(w)::FLOAT / SUM(g)::FLOAT) OVER(PARTITION BY playerid, teamid ORDER BY yearid ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING) AS prev_3yr_avg,
    AVG(SUM(w)::FLOAT / SUM(g)::FLOAT) OVER(PARTITION BY playerid, teamid ORDER BY yearid ROWS BETWEEN 2 FOLLOWING AND 4 FOLLOWING) AS next_3yr_avg,
    AVG(SUM(w)::FLOAT / SUM(g)::FLOAT) OVER(PARTITION BY playerid, teamid ORDER BY yearid ROWS BETWEEN 2 FOLLOWING AND 4 FOLLOWING) - AVG(SUM(w)::FLOAT / SUM(g)::FLOAT) OVER(PARTITION BY playerid, teamid ORDER BY yearid ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING) AS win_prop_diff

FROM qualified_stints AS q
GROUP BY manager_name, teamid, start_year, playerid, yearid
ORDER BY win_prop_diff DESC NULLS LAST;

-- i think this is rolling avg, not the required stints



-- fresh attempt  
--------------------------------------------------------------------------------

-- CTE to identify all manager stints with their first year and stint length
WITH manager_stints AS (

    SELECT 
        namefirst || ' ' || namelast AS manager_name,
        playerid,
        m.teamid,
        m.yearid,
        ROW_NUMBER() OVER(PARTITION BY playerid, m.teamid ORDER BY m.yearid) AS year_num,
        COUNT(*) OVER(PARTITION BY playerid, m.teamid) AS stint_length,
        MIN(m.yearid) OVER(PARTITION BY playerid, m.teamid) AS first_year

    FROM managers m
    INNER JOIN people p USING(playerid)
),

-- Get managers who managed at least 4 full years at the same team
qualified_managers AS (

    SELECT DISTINCT
        manager_name,
        playerid,
        teamid,
        first_year

    FROM manager_stints
    WHERE stint_length >= 4
),

-- Calculate team's average winning percentage for 3 years BEFORE manager's arrival
-- Using the teams table directly for win/loss data
team_before AS (

    SELECT
        qm.manager_name,
        qm.playerid,
        qm.teamid,
        qm.first_year,
        SUM(t.w)::FLOAT / SUM(t.g)::FLOAT AS pre_avg_win_pct  

    FROM qualified_managers qm
        INNER JOIN teams t ON qm.teamid = t.teamid 
    WHERE t.yearid BETWEEN qm.first_year - 3 AND qm.first_year - 1  -- 3 years before first year
    GROUP BY qm.manager_name, qm.playerid, qm.teamid, qm.first_year
    HAVING COUNT(*) = 3  -- Ensure team existed for all 3 years before manager arrived
),

-- Calculate manager's average winning percentage for years 2-4 of their tenure
-- Using the teams table and filtering by years when manager was active
manager_period AS (

    SELECT
        qm.manager_name,
        t.name AS team_name,
        qm.playerid,
        qm.teamid,
        qm.first_year,
        SUM(t.w)::FLOAT / SUM(t.g)::FLOAT AS manager_avg_win_pct  

    FROM qualified_managers qm
        INNER JOIN teams t ON qm.teamid = t.teamid
    WHERE t.yearid BETWEEN qm.first_year + 1 AND qm.first_year + 3  -- Years 2-4 of manager's tenure
    GROUP BY qm.manager_name, t.name, qm.playerid, qm.teamid, qm.first_year
    HAVING COUNT(*) = 3  
)

-- Join the before and after periods, calculate improvement, and rank by improvement
SELECT
    tb.manager_name,
    tb.teamid,
    mp.team_name,
    tb.first_year AS start_year,
    tb.pre_avg_win_pct AS avg_win_pct_before, 
    mp.manager_avg_win_pct AS avg_win_pct_during, 
    mp.manager_avg_win_pct - tb.pre_avg_win_pct AS win_pct_improvement,  
    (mp.manager_avg_win_pct - tb.pre_avg_win_pct) * 100 AS pct_point_improvement  

FROM team_before tb
    INNER JOIN manager_period mp 
        ON tb.playerid = mp.playerid 
        AND tb.teamid = mp.teamid 
        AND tb.first_year = mp.first_year
ORDER BY win_pct_improvement DESC;  