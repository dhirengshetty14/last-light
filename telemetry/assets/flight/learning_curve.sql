/* @bruin
name: flight.learning_curve
type: duckdb.sql
description: "One row per robot per match, in the order the matches were played: its average reaction score, the change since its previous match in that mode, the score with and without Analyst advice, and the score by kind of moment."
owner: last-light-team
depends:
  - flight.reactions
  - flight.agent_decisions
  - flight.court_scoreboard
materialization:
  type: table
custom_checks:
  - name: One row per run and robot
    query: SELECT count(*) FROM (SELECT run, seat FROM flight.learning_curve GROUP BY ALL HAVING count(*) > 1)
    value: 0
@bruin */
-- One row per robot per match, in the order the matches were played: its average reaction score and
-- the change since its previous match of the same mode. This is the proof the robots improve.
WITH per_match AS (
    SELECT run, seat, any_value(robot) AS robot, count(*) AS reactions, round(avg(reaction), 4) AS reaction,
           round(avg(reaction) FILTER (WHERE advised), 4) AS reaction_when_advised,
           round(avg(reaction) FILTER (WHERE NOT advised), 4) AS reaction_unadvised,
           round(avg(reaction) FILTER (WHERE category = 'ball'), 4) AS ball,
           round(avg(reaction) FILTER (WHERE category = 'human'), 4) AS human,
           round(avg(reaction) FILTER (WHERE category = 'teammate'), 4) AS teammate,
           round(avg(reaction) FILTER (WHERE category = 'wall'), 4) AS wall
    FROM flight.reactions GROUP BY run, seat
), grades AS (
    SELECT run, seat, any_value(origin) AS origin, round(avg(score), 4) AS decision_grade
    FROM flight.agent_decisions WHERE score IS NOT NULL GROUP BY run, seat
)
SELECT p.run, try_cast(split_part(p.run, '-', 1) AS BIGINT) AS started_usec, s.mode, g.origin, p.seat, p.robot,
       row_number() OVER (PARTITION BY p.seat, s.mode ORDER BY try_cast(split_part(p.run, '-', 1) AS BIGINT)) AS match_number,
       p.reactions, p.reaction, p.reaction_when_advised, p.reaction_unadvised, p.ball, p.human, p.teammate, p.wall,
       g.decision_grade,
       round(p.reaction - lag(p.reaction) OVER (PARTITION BY p.seat, s.mode ORDER BY try_cast(split_part(p.run, '-', 1) AS BIGINT)), 4) AS reaction_change,
       s.gold_goals AS human_goals, s.blue_goals AS robot_goals, s.seconds_played
FROM per_match p
LEFT JOIN grades g ON g.run = p.run AND g.seat = p.seat
LEFT JOIN flight.court_scoreboard s ON s.run = p.run
