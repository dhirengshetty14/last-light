/* @bruin
name: flight.robot_failure_modes
type: duckdb.sql
description: "Where each robot does badly, over all matches graded by the same checks: for each situation and move, how often each check is missed and how much verifier score is lost."
owner: last-light-team
columns:
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
  - name: situation
    type: varchar
    description: "The situation in words"
    primary_key: true
    checks:
      - name: not_null
  - name: move
    type: varchar
    description: "The move the robot chose"
    primary_key: true
    checks:
      - name: not_null
  - name: attempts
    type: bigint
    description: "Graded decisions"
    checks:
      - name: positive
  - name: lost_score
    type: double
    description: "Verifier score left on the table: attempts times the shortfall from 1"
    checks:
      - name: non_negative
depends:
  - flight.robot_decisions
materialization:
  type: table
custom_checks:
  - name: Miss rates are fractions from 0 to 1
    query: SELECT count(*) FROM flight.robot_failure_modes WHERE miss_outcome NOT BETWEEN 0 AND 1 OR miss_execution NOT BETWEEN 0 AND 1 OR miss_approach NOT BETWEEN 0 AND 1
    value: 0
@bruin */
-- Where each robot does badly, over every recorded match graded by the same generation of outcome
-- checks (`verifier`): one row per robot, situation and move,
-- with how often each verifier check is missed and the check it most often breaks at. `lost_score`
-- is the verifier score left on the table (attempts times the shortfall from 1), so sorting by it
-- puts the failure that costs most first.
SELECT verifier, robot, task, situation, move,
       count(*) AS attempts,
       round(avg(score), 4) AS mean_score,
       round(avg(full_pass::INTEGER), 4) AS full_rate,
       round(avg((NOT verifier_checks[3])::INTEGER), 4) AS miss_approach,
       round(avg((NOT verifier_checks[4])::INTEGER), 4) AS miss_execution,
       round(avg((NOT verifier_checks[5])::INTEGER), 4) AS miss_outcome,
       mode(breaks_at) AS breaks_at,
       round(count(*) * (1 - avg(score)), 1) AS lost_score
FROM flight.robot_decisions
GROUP BY verifier, robot, task, situation, move
HAVING count(*) >= 5
