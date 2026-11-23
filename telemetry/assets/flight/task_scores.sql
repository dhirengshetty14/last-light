/* @bruin
name: flight.task_scores
type: duckdb.sql
description: "The RL scoreboard: for each match, robot and task, how many decisions were graded, their mean verifier score and the share that passed all five checks. A task is failing below 25% of at least ten decisions."
owner: last-light-team
columns:
  - name: run
    type: varchar
    description: "Match id"
    primary_key: true
    checks:
      - name: not_null
  - name: verifier
    type: integer
    description: "Generation of outcome checks"
    primary_key: true
    checks:
      - name: not_null
  - name: robot
    type: varchar
    description: "Robot name"
    primary_key: true
    checks:
      - name: accepted_values
        value: ["Pip", "Morrow", "Zip"]
  - name: task
    type: varchar
    description: "Task"
    primary_key: true
    checks:
      - name: accepted_values
        value: ["Win the star back", "Reach a loose star first", "Get open for a teammate", "Keep the star under pressure", "Carry the star forward", "Complete a pass", "Finish at the ring"]
  - name: attempts
    type: bigint
    description: "Graded decisions"
    checks:
      - name: positive
  - name: full_rate
    type: double
    description: "Share of decisions that passed all five checks"
    checks:
      - name: min
        value: 0
      - name: max
        value: 1
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
