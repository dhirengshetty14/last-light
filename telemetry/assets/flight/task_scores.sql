/* @bruin
name: flight.task_scores
type: duckdb.sql
depends:
  - flight.robot_decisions
materialization:
  type: table
custom_checks:
  - name: A task score is a fraction from 0 to 1
    query: SELECT count(*) FROM flight.task_scores WHERE mean_score NOT BETWEEN 0 AND 1 OR full_rate NOT BETWEEN 0 AND 1
    value: 0
@bruin */
-- The scoreboard of the RL environment: for each match, robot and task, how many decisions were
-- graded, their mean verifier score and the share that passed all five checks. A task is failing
-- when fewer than a quarter of at least ten decisions pass.
SELECT run, verifier, dense_rank() OVER (ORDER BY run) AS match_number, robot, task,
       count(*) AS attempts,
       round(avg(score), 4) AS mean_score,
       round(avg(full_pass::INTEGER), 4) AS full_rate,
       count(*) >= 10 AND avg(full_pass::INTEGER) < 0.25 AS failing
FROM flight.robot_decisions
GROUP BY run, verifier, robot, task
