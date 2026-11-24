/* @bruin
name: flight.score_windows
type: duckdb.sql
description: "Each robot's reaction score in every 15 seconds of every match, beside the court's own grade of its decisions in the same 15 seconds."
owner: last-light-team
depends:
  - flight.reactions
  - flight.agent_decisions
materialization:
  type: table
custom_checks:
  - name: One row per run, robot and 15-second window
    query: SELECT count(*) FROM (SELECT run, seat, window_index FROM flight.score_windows GROUP BY ALL HAVING count(*) > 1)
    value: 0
@bruin */
-- Each robot's reaction score, 0 to 1 (overall and for the ball, humans, teammates and walls), in every 15-second window of every match, beside the court's
-- own grade of its decisions in the same window.
WITH r AS (
    SELECT run, seat, any_value(robot) AS robot, tick // 900 AS window_index, count(*) AS reactions,
           round(avg(reaction), 4) AS reaction, round(avg(speed), 4) AS speed,
           round(avg(direction), 4) AS direction, round(avg(outcome), 4) AS outcome,
           round(avg(reaction) FILTER (WHERE category = 'ball'), 4) AS ball,
           round(avg(reaction) FILTER (WHERE category = 'human'), 4) AS human,
           round(avg(reaction) FILTER (WHERE category = 'teammate'), 4) AS teammate,
           round(avg(reaction) FILTER (WHERE category = 'wall'), 4) AS wall,
           count(*) FILTER (WHERE advised) AS advised_reactions
    FROM flight.reactions GROUP BY run, seat, tick // 900
), g AS (
    SELECT run, seat, tick // 900 AS window_index, count(*) AS decisions, round(avg(score), 4) AS decision_grade
    FROM flight.agent_decisions WHERE score IS NOT NULL GROUP BY run, seat, tick // 900
)
SELECT r.run, r.seat, r.robot, r.window_index, r.window_index * 15 AS start_second, r.reactions, r.reaction,
       r.speed, r.direction, r.outcome, r.ball, r.human, r.teammate, r.wall, r.advised_reactions, g.decisions, g.decision_grade
FROM r LEFT JOIN g ON g.run = r.run AND g.seat = r.seat AND g.window_index = r.window_index
